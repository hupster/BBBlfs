BBBlfs
======
[![Build Status](https://travis-ci.org/ungureanuvladvictor/BBBlfs.svg?branch=master)](https://travis-ci.org/ungureanuvladvictor/BBBlfs)

Beagle Bone Black Linux Flash System

This project provides a way to flash a BeagleBone Black via USB from a Linux machine. The project was developed during Google Summer of Code '13.


Install
----------
1) Install Ubuntu 14.04.1 LTS: http://old-releases.ubuntu.com/releases/14.04.1/ubuntu-14.04.1-desktop-i386.iso
Newer versions of Ubuntu or Debian won't work.

2) Optionally remove the desktop environment:
```
sudo apt-get install tasksel
sudo tasksel remove ubuntu-desktop
```
Edit /etc/default/grub:
```
GRUB_CMDLINE_LINUX="text"
GRUB_TERMINAL=console
```

3) The 32-bit version was added as binary. To build for another architecture:
```
sudo apt-get install libusb-1.0-0-dev automake
./autogen.sh
./configure
make
```

Usage
-----------
1) Connect the board to the host PC using the micro-USB cable. If the BeagleBone Black is not empty, the S2 button needs to be pressed to make the board start into USB boot mode.

2) Enter the bin/ directory and execute ```flash_script.sh``` It needs the flashing image as argument to be provided.

```sudo ./flash_script.sh  [ debian | ubuntu | image.xz ]```

* debian and ubuntu will use tarball from armhf.com website


How to build the binary blobs
--------------------------------

The full system works as follow:

* The AM335x ROM when in USB boot mode exposes a RNDIS interface to the PC and waits to TFTP a binary blob that it executes. That binary blob is the SPL
* Once the SPL runs it applies the same proceure as the ROM and TFTPs U-Boot
* Again U-Boot applies the same thinking and TFTPs a FIT(flatten image tree) which includes a Kernel, Ramdisk and the DTB
* U-Boot runs this FIT and boots the Kernel
* When the kernel starts the init script exports the eMMC using the g_mass_storage kernel module as an USB stick to the Linux so it can be flashed


## Building U-Boot for USB booting
* Grab the latest U-Boot sources from [git://git.denx.de/u-boot.git](git://git.denx.de/u-boot.git)
* Checkout commit id 524123a70761110c5cf3ccc5f52f6d4da071b959
* Install your favourite cross-compiler, I am using arm-linux-gnueabihf-
* Apply this patch to U-Boot sources [https://raw.githubusercontent.com/ungureanuvladvictor/BBBlfs/master/tools/USB_FLash.patch](https://raw.githubusercontent.com/ungureanuvladvictor/BBBlfs/master/tools/USB_FLash.patch )

```bash
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- am335x_evm_usbspl_config
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi-
```
Now you have u-boot.img which is the uboot binary and spl/u-boot-spl.bin which is the spl binary


## Building the Kernel
* Grab the latest from [https://github.com/beagleboard/kernel](https://github.com/beagleboard/kernel)
```bash
git checkout 3.14
./patch.sh
cp configs/beaglebone kernel/arch/arm/configs/beaglebone_defconfig
wget http://arago-project.org/git/projects/?p=am33x-cm3.git\;a=blob_plain\;f=bin/am335x-pm-firmware.bin\;hb=HEAD -O kernel/firmware/am335x-pm-firmware.bin
cd kernel
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- beaglebone_defconfig -j4
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- zImage dtbs modules -j4
```

* After compilation you have in arch/arm/boot/ the zImage


## Building the ramdisk

* Our initramfs will be built around BusyBox. First we create the basic folder structure.
```bash
mkdir initramfs
mkdir -p initramfs/{bin,sbin,etc,proc,sys}
cd initramfs
wget -O init https://raw.githubusercontent.com/ungureanuvladvictor/BBBlfs/master/tools/init
chmod +x init
```
* Now we need to cross-compile BusyBox for our ARM architecture
```bash
git clone git://git.busybox.net/busybox
cd busybox
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- defconfig
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- menuconfig
```
* Now here we need to compile busybox as a static binary: Busybox Settings --> Build Options --> Build Busybox as a static binary (no shared libs)  -  Enable this option by pressing "Y"
```bash
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- -j4
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- install CONFIG_PREFIX=/path/to/initramfs
```
* Now we need to install the kernel modules in our initramfs
```bash
cd /path/to/kernel/sources
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- modules_install INSTALL_MOD_PATH=/path/to/initramfs
```


## Packing things up

* Now we need to put our initramfs in a .gz archive that the kernel knows how to process
```bash
mkdir maker
cd /path/to/initramfs
find . | cpio -H newc -o > ../initramfs.cpio
cd .. && cat initramfs.cpio | gzip > initramfs.gz
mv initramfs.gz /path/to/maker/folder/ramdisk.cpio.gz
```
* Now we need to pack all things in a FIT image. In order to do so we need some additional packages installed, namely the mkimage and dtc compiler.
```bash
sudo apt-get update
sudo apt-get install u-boot-tools device-tree-compiler
cd /path/to/maker/folder
wget -O maker.its https://raw.githubusercontent.com/ungureanuvladvictor/BBBlfs/master/tools/maker.its
cp /path/to/kernel/arch/arm/boot/zImage .
cp /path/to/kernel/arch/arm/boot/dts/am335x-boneblack.dtb .
mkimage -f maker.its FIT
```
* At this point we have all things put into place. You need to copy the binary blobs in the bin/ folder and run ```flash_script.sh```

#Contact
vvu@vdev.ro

vvu on #beagle, #beagle-gsoc
