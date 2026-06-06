#!/bin/bash
#
# This script fetches the master branch of the Linux kernel,
# builds it targeting the ArmSoM Sige7 (Rockchip RK3588)
# and install to your current partition.
set -e

KERNEL_DIR="$HOME/linux-mainline"
CONFIG_SOURCE="$(pwd)/linux-sige7-config"
EXTLINUX_CONF="/boot/extlinux/extlinux.conf"
BOOT_DTS="arch/arm64/boot/dts/rockchip/rk3588-armsom-sige7.dtb"

if [ ! -f "$CONFIG_SOURCE" ]; then
    echo "Config file $CONFIG_SOURCE not found"
    exit 1
fi

if [ -d "$KERNEL_DIR" ]; then
    echo "Removing old shallow clone..."
    rm -rf "$KERNEL_DIR"
fi

git clone --depth=1 --branch master \
    https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git \
    "$KERNEL_DIR"

cd "$KERNEL_DIR"

cp "$CONFIG_SOURCE" .config
make olddefconfig

make -j$(nproc) Image dtbs modules

KERNEL_VERSION=$(make kernelrelease)

if [ -f "/boot/vmlinuz-$KERNEL_VERSION" ]; then
    echo "Kernel $KERNEL_VERSION is already up to date"
    exit 0
fi

if [ ! -f "$BOOT_DTS" ]; then
    echo "WARNING: $BOOT_DTS not found! Board DTB may not be mainlined yet."
    echo "Build will continue, but you may need a custom DTB."
fi

ROOT_UUID=$(findmnt -n -o UUID /)

sudo make modules_install
sudo cp arch/arm64/boot/Image "/boot/vmlinuz-$KERNEL_VERSION"
sudo cp "$BOOT_DTS" /boot/ 2>/dev/null || echo "Warning: DTB copy failed"

echo "Building initramfs..."
if sudo mkinitcpio -k "$KERNEL_VERSION" -g "/boot/initramfs-$KERNEL_VERSION.img"; then
    echo "Initramfs built successfully"
else
    EXIT_CODE=$?
    if [ -f "/boot/initramfs-$KERNEL_VERSION.img" ]; then
        echo "Initramfs built with warnings (exit code $EXIT_CODE) — continuing"
    else
        echo "ERROR: Initramfs build failed and no image was created!"
        exit 1
    fi
fi

if [ -f "$EXTLINUX_CONF" ]; then
    sudo cp "$EXTLINUX_CONF" "$EXTLINUX_CONF.bak.$(date +%Y%m%d-%H%M%S)"
fi

if ! grep -q "vmlinuz-$KERNEL_VERSION" "$EXTLINUX_CONF" 2>/dev/null; then
    echo "Adding new kernel entry as default..."
    NEW_ENTRY=$(cat << INNEREOF
label linux-mainline-$KERNEL_VERSION
    kernel /vmlinuz-$KERNEL_VERSION
    initrd /initramfs-$KERNEL_VERSION.img
    fdt /rk3588-armsom-sige7.dtb
    append root=UUID=$ROOT_UUID rw cma=640M quiet splash rknpu-mem=8G
INNEREOF
)
    if [ -f "$EXTLINUX_CONF" ]; then
        echo "$NEW_ENTRY" | cat - "$EXTLINUX_CONF" | sudo tee "$EXTLINUX_CONF" > /dev/null
    else
        echo "$NEW_ENTRY" | sudo tee "$EXTLINUX_CONF" > /dev/null
    fi
else
    echo "Entry for $KERNEL_VERSION already exists in extlinux.conf"
fi

echo "Kernel $KERNEL_VERSION built and installed."

echo "Applying post-install fixes..."

sudo tee /etc/udev/rules.d/99-fan.rules << 'EOF'
SUBSYSTEM=="hwmon", DEVPATH=="*/hwmon/hwmon*", ATTR{name}=="pwmfan", ATTR{pwm1_enable}="0"
EOF

FAN_HWMON=$(grep -l "pwmfan" /sys/class/hwmon/hwmon*/name 2>/dev/null | head -1 | sed 's|/name||')
THERMAL_ZONE="/sys/class/thermal/thermal_zone0/temp"

if [ -n "$FAN_HWMON" ]; then
    sudo tee /etc/fancontrol << EOF
INTERVAL=10
FCTEMPS=${FAN_HWMON}/pwm1=${THERMAL_ZONE}
FCFANS=${FAN_HWMON}/pwm1=
MINTEMP=${FAN_HWMON}/pwm1=40000
MAXTEMP=${FAN_HWMON}/pwm1=75000
MINSTART=${FAN_HWMON}/pwm1=100
MINSTOP=${FAN_HWMON}/pwm1=80
MINPWM=${FAN_HWMON}/pwm1=80
MAXPWM=${FAN_HWMON}/pwm1=255
EOF
    sudo systemctl enable --now fancontrol 2>/dev/null || true
    echo "Fan control configured on $FAN_HWMON"
else
    echo "WARNING: pwmfan not found — skipping fancontrol setup"
fi


sudo mkdir -p /usr/lib/firmware/brcm
sudo ln -sf /usr/lib/firmware/ap6275p/fw_bcm43752a2_pcie_ag.bin /usr/lib/firmware/brcm/brcmfmac43752a2-pcie.bin
sudo ln -sf /usr/lib/firmware/ap6275p/clm_bcm43752a2_pcie_ag.blob /usr/lib/firmware/brcm/brcmfmac43752-pcie.clm_blob
sudo ln -sf /usr/lib/firmware/ap6275p/nvram_ap6275p.txt /usr/lib/firmware/brcm/brcmfmac43752-pcie.txt

if lsmod | grep -q brcmfmac; then
    echo "Reloading WiFi module..."
    sudo modprobe -r brcmfmac 2>/dev/null || {
        echo "WiFi module in use — cannot reload while active."
        echo "WiFi will use new firmware after next reboot."
    }
    sudo modprobe brcmfmac 2>/dev/null || true
fi

sudo tee /etc/tmpfiles.d/leds.conf << 'EOF'
w /sys/class/leds/red:status/brightness - - - - 0
w /sys/class/leds/green:status/trigger - - - - default-on
EOF

echo "Done! New kernel $KERNEL_VERSION is installed and set as default."
