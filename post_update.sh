#!/bin/bash

# This post update script resolves some incompatibilities I had
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
