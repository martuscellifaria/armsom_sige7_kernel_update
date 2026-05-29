#!/bin/bash
#
# This script fetches the master branch of the Linux kernel,
# builds it targeting the ArmSoM Sige7 (Rockchip RK3588)
# and install to your current partition.
# I made this script to save some time and not having to
# go through all of the painpoints such as having to add
# drivers that weren't imported to the older config.
set -e

KERNEL_DIR="linux-mainline"
CONFIG_SOURCE="linux-sige7-config"

if [ ! -f "$CONFIG_SOURCE" ]; then
    echo "Config file $CONFIG_SOURCE not found"
    exit 1
fi

if [ ! -d "$KERNEL_DIR" ]; then
    git clone --depth=1 --branch master https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git "$KERNEL_DIR"
fi

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

sudo tee "$EXTLINUX_CONF" << EOF
label linux-mainline-$KERNEL_VERSION
    kernel /vmlinuz-$KERNEL_VERSION
    initrd /initramfs-$KERNEL_VERSION.img
    fdt /rk3588-armsom-sige7.dtb
    append root=UUID=$ROOT_UUID rw cma=640M quiet splash
EOF

echo "Kernel $KERNEL_VERSION built and installed"
