#!/bin/bash
#
# This script fetches the master branch of the Linux kernel,
# builds it targeting the ArmSoM Sige7 (Rockchip RK3588)
# and install to your current partition.
# I made this script to save some time and not having to
# go through all of the painpoints such as having to add
# drivers that weren't imported to the older config.
set -e

KERNEL_DIR="$HOME/linux-mainline"
CONFIG_SOURCE="$(pwd)/linux-sige7-config"
SCRIPT_DIR="$(pwd)"

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
git pull --depth=1

cp "$CONFIG_SOURCE" .config
make olddefconfig

make -j$(nproc) Image dtbs modules

KERNEL_VERSION=$(make kernelrelease)

if [ -f "/boot/vmlinuz-$KERNEL_VERSION" ]; then
    echo "Kernel $KERNEL_VERSION is already up to date"
    exit 0
fi

ROOT_UUID=$(findmnt -n -o UUID /)
EXTLINUX_CONF="/boot/extlinux/extlinux.conf"

sudo make modules_install
sudo cp arch/arm64/boot/Image /boot/vmlinuz-$KERNEL_VERSION
sudo cp arch/arm64/boot/dts/rockchip/rk3588-armsom-sige7.dtb /boot/

sudo mkinitcpio -k $KERNEL_VERSION -g /boot/initramfs-$KERNEL_VERSION.img

if [ -f "$EXTLINUX_CONF" ]; then
    sudo cp "$EXTLINUX_CONF" "$EXTLINUX_CONF.bak.$(date +%Y%m%d-%H%M%S)"
fi

if grep -q "vmlinuz-$KERNEL_VERSION" "$EXTLINUX_CONF" 2>/dev/null; then
    echo "Entry for $KERNEL_VERSION already exists in extlinux.conf"
else
    sudo tee -a "$EXTLINUX_CONF" << EOF
label linux-mainline-$KERNEL_VERSION
    kernel /vmlinuz-$KERNEL_VERSION
    initrd /initramfs-$KERNEL_VERSION.img
    fdt /rk3588-armsom-sige7.dtb
    append root=UUID=$ROOT_UUID rw cma=640M quiet splash
EOF
fi

echo "Kernel $KERNEL_VERSION built and installed. Proceeding to the post update."

# This post update part resolves some incompatibilities I had
# after installation of the mainline kernel.
# Among the problems were: the fan wasn't working at all.
# Wifi wasn't working.
# LED was blinking the whole time.
#
sudo tee /etc/udev/rules.d/99-fan.rules << 'EOF'
SUBSYSTEM=="hwmon", DEVPATH=="*/hwmon/hwmon*", ATTR{name}=="pwmfan", ATTR{pwm1_enable}="0"
EOF

sudo tee /etc/modules-load.d/khadas-fan.conf << 'EOF'
khadas_mcu_fan
EOF

sudo tee /etc/fancontrol << 'EOF'
INTERVAL=10
FCTEMPS=/sys/class/hwmon/hwmon8/pwm1=/sys/class/thermal/thermal_zone0/temp
FCFANS=/sys/class/hwmon/hwmon8/pwm1=
MINTEMP=/sys/class/hwmon/hwmon8/pwm1=40000
MAXTEMP=/sys/class/hwmon/hwmon8/pwm1=75000
MINSTART=/sys/class/hwmon/hwmon8/pwm1=100
MINSTOP=/sys/class/hwmon/hwmon8/pwm1=80
MINPWM=/sys/class/hwmon/hwmon8/pwm1=80
MAXPWM=/sys/class/hwmon/hwmon8/pwm1=255
EOF

sudo systemctl enable --now fancontrol

sudo ln -sf /usr/lib/firmware/ap6275p/fw_bcm43752a2_pcie_ag.bin /usr/lib/firmware/brcm/brcmfmac43752a2-pcie.bin
sudo ln -sf /usr/lib/firmware/ap6275p/clm_bcm43752a2_pcie_ag.blob /usr/lib/firmware/brcm/brcmfmac43752-pcie.clm_blob
sudo ln -sf /usr/lib/firmware/ap6275p/nvram_ap6275p.txt /usr/lib/firmware/brcm/brcmfmac43752-pcie.txt

sudo modprobe -r brcmfmac
sudo modprobe brcmfmac

sudo tee /etc/tmpfiles.d/leds.conf << 'EOF'
w /sys/class/leds/red:status/brightness - - - - 0
w /sys/class/leds/green:status/trigger - - - - default-on
EOF

