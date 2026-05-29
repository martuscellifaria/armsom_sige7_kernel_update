# ArmSoM Sige7 Kernel Update Script


## Motivation

I noticed my ArmSoM Sige7 was stuck with some outdated unofficial kernel (Linux 6.1.75-rockchip-ge21cf49ee9a4-dirty) that I have got from installing Arch from the [repository suggested at the ArmSoM website](https://github.com/kwankiu/archlinux-installer).

It was fine at first, but then some vulnerabilities started happening such as the infamous [Copyfail](https://nvd.nist.gov/vuln/detail/CVE-2026-31431) and [Dirtyfrag](https://itcc.uni-koeln.de/en/services/information-security/it-security/vulnerability-cve-2026-43284-dirty-frag) and I started noticing that running `yay` wouldn't update the kernel. I also updated `mesa` from version `26.0.6` to `26.1.1` and it broke the support for `Wayland` completely as a side effect of [add kmsro support to Zink commit](https://gitlab.freedesktop.org/mesa/mesa/-/commit/adf18abb4097805c2896e350e06e3a5cad6ec68e).

I then went on the task of getting the mainline kernel repository and compile it to target my board, since it is supported there already. Also the support to `Panthor` started at Linux kernel version 6.10, so using 6.1.75 was still far behind optimal.

## Limitation

The ArmSoM Sige7 has a USB-C port which can also used as a HDMI output. The mainline kernel don't support this yet, so you will have to use the normal HDMI output and are limited to one monitor with it.

## How to use

First of all, a quick disclaimer: this is a Linux kernel update script, so you should know at least a little bit of what you are doing. Some things might break at the end if your hardware don't match mine, which is the [ArmSoM Sige7](https://docs.armsom.org/armsom-sige7).
Second, you should be aware of supply chain attacks such as the [Mini Shai-Hulud](https://arcticwolf.com/resources/blog/mini-shai-hulud-supply-chain-malware-attack/) and therefore I disencourage running code from someone else without reading it first. This is not much and is just bash.

### Requirements
You will need to clone the Linux kernel codebase and compile it, so you will need `git` and some build tools. Some examples:

Arch
```
sudo pacman -S --needed base-devel git bc kmod cpio mkinitcpio flex bison openssl
```

Ubuntu
```
sudo apt install build-essential git bc kmod cpio initramfs-tools flex bison libssl-dev libelf-dev
```

Fedora
```
sudo dnf install gcc make git bc kmod cpio dracut flex bison openssl-devel elfutils-libelf-devel
```

### Building the kernel

Supposing you cloned this repository, `cd` into it and then:

```
sh build_kernel.sh
```

This will handle everything for you. After that you can reboot you system.

### Post kernel update

This is also an important part. I noticed that after the first time updating the kernel to the mainline the both cooling fan and Wi-Fi stopped working. Therefore, I have also written the `post_update.sh` script. You should run it once you are booted again into your system. A less important "fix" was to just keep the green led on, as the mainline kernel makes it blink as a heartbeat function. I let it just on instead.

```
sh post_update.sh
```

## What's next

I will probably update here when something like the USB-C HDMI functionality comes to the mainline kernel.
I am of course open for suggestions and feedback.
Found this repository util? You are welcome to start it.

---
> I have no affiliation with the company [ArmSoM](https://www.armsom.org/). I just enjoy their products privately. They were also very receptive to a [3D case I designed](https://www.printables.com/model/1234582-armsom-sige7-case).
