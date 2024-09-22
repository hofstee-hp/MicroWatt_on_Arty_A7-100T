# MicroWatt_on_Arty_A7-100T

## Description

This github page has a very narrow scope and is intended to provide a comprehensive description of how to build a small OpenPOWER ISA MicroWatt processor-based system on the Arty A7-100T FPGA board. We assume a basic Ubuntu 22.04.4 install as the starting point. 

Our main source is https://github.com/antonblanchard/microwatt  and issues/questions that are related to the MicroWatt project in general and issues with build environments other than Ubuntu 22.04.4 should be raised there.

## Getting Started

For background on the OpenPOWER ISA please refer to 

  https://openpowerfoundation.org/

also, this talk may be helpful 

 https://youtu.be/CnMwCrtz6MA

for an introduction to MicroWatt see

 https://github.com/antonblanchard/microwatt

and this talk covers the MicroWatt microarchitecture

 https://youtu.be/uEAoMCE6IKo

for a walkthrough and some additional background of the instructions on this page see

 < TO BE ADDED SOON >

### Dependencies

* We assume Ubuntu 22.04.4 (running on a x86-64 system) as the starting point, and we will use the free version of Vivado 2024.1 (which is pre-installed if you are using the CDAC development environment). In this repository we will not respond to issues if you have a different build environment.

### Simulating MicroWatt with GHDL and running MicroPython

* Installing some dependencies.
One reason we use this particular build environment is that all the dependencies we have for this first step are easy to resolve. The commands below install basic build tools, the git utility so we can access the git repositories, the ghdl VHDL simulator, the gnat ADA compiler (ghdl has an ADA dependency), and the ppc64le (64b powerpc little endian) cross compilers so we can build code for our OpenPOWER ISA processor in an x86-based build environment.

```
$ sudo apt-get update 
$ sudo apt-get upgrade 
$ sudo apt-get install -y build-essential git ghdl-common ghdl ghdl-llvm gnat
$ sudo apt-get install -y binutils-powerpc64le* gcc-powerpc64le-* g++-powerpc64le-*
```

* Build MicroPython
```
$ cd ~ 
$ git clone https://github.com/micropython/micropython.git 
$ cd micropython/ports/powerpc 
$ make 
```
* Build MicroWatt
```
$ cd ~ 
$ git clone https://github.com/antonblanchard/microwatt 
$ cd microwatt 
$ make 
```
* Run MicroPython on MicroWatt in the GHDL simulator
```
$ cd ~/microwatt 
$ ln -s micropython/firmware.bin main_ram.bin 
$ ./core_tb > /dev/null
```
* Note: While the above sequence shows microwatt running all the way to a micropython input prompt, actually providing input did not work. Until this is fixed please use the prebuilt ../micropython/firmware.bin instead of ../micropython/ports/powerpc/build/firmware.bin if you want to provide input.

## Install Vivado 2024.1

* Install Vivado 2024.1 (skip this step if you are running in the CDAC build environment as your VM will have Vivado pre-installed)

----- Vivado and installer dependencies
```
$ sudo apt update
$ sudo apt-get install -y python3-pip 
$ sudo apt-get install -y libncurses5
$ sudo apt-get install -y libtinfo5
```
------ download and build Vivado 24.1 

https://www.xilinx.com/support/download.html?_ga=2.241968386.128795933.1725229893-181584843.1724769065

https://docs.amd.com/r/en-US/ug973-vivado-release-notes-install-license/Download-and-Installation

------ We recommend the web installer version 291.7MB initial download

------ Single file download is 107GB (sic)

---- Install the digilent board packages
```
$ cd
$ git clone https://github.com/Digilent/vivado-boards.git
$ cd <Xilinx install dir>/Xilinx/Vivado/2024.1/data/boards
$ mkdir board_files
$ cp /home/$USER/vivado-boards/board_files/* board_files
$ cd <Xilinx install dir>/Xilinx/Vivado/2024.1/scripts/board
$ cp /home/$USER/vivado-boards/utility/Vivado_init.tcl .
```
------ Update paths
```
$ cd <Xilinx install dir>/Xilinx/Vivado/2024.1
$ source settings64.sh
```
----- If you are installing on a system that has the board attached
```
$ sudo apt-get install -y openocd
$ sudo apt-get install -y putty
$ sudo apt-get install -y gtkterm
$ cd <Xilinx install dir>/Xilinx/Vivado/2024.1/data/xicom/cable_drivers/
$ cd lin64/install_scripts/install_drivers
$ ./install_drivers 
$ sudo adduser $USER dialout
```
## Build MicroWatt bitfile for Arty A7-100T -- there are also instructions further down on how to download the bitfile if you do not want to build

### Install fusesoc
```
$ cd ~
$ sudo ln -s /usr/bin/python3 /usr/local/bin/python
$ sudo apt-get install -y python3-pip
$ pip3 install --user -U fusesoc
$ export PATH=$PATH:~/.local/bin
```
### Build MicroWatt bitfile for Arty A7-100T

You can skip the first step below if you are in the CDAC environment as getting the Xilinx paths has been added to .bashrc there
```
$ source <Xilinx install dir>/Xilinx/Vivado/2024.1/settings64.sh
$ mkdir arty
$ fusesoc library add microwatt microwatt
$ fusesoc fetch uart16550
$ fusesoc run --build --target=arty_a7-100 microwatt --no_bram --memory_size=0
$ cp build/microwatt_0/arty_a7-100-vivado/microwatt_0.bit ~/arty
```
The last command is the actual build and invokes Vivado. The output is build/microwatt_0/arty_a7-100-vivado/microwatt_0.bit.

## Building the Linux kernel -- you can skip this step if you want to run the precompiled buildroot elf image and jump ahead to "Program Arty"

The linux build requires flex and bison
```
$ sudo apt-get install -y flex
$ sudo apt-get install -y bison
```
Use buildroot to create a userspace.

A small change is required to glibc in order to support the VMX/AltiVec-less Microwatt, as float128 support is mandatory and for this in GCC requires VSX/AltiVec. This change is included in a buildroot fork, along with a defconfig:

```
$ cd ~
$ git clone -b microwatt https://github.com/shenki/buildroot
$ cd buildroot
$ make ppc64le_microwatt_defconfig
$ make
```
The output is output/images/rootfs.cpio.

Next build the Linux kernel
```
$ git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
$ cd linux
$ make ARCH=powerpc microwatt_defconfig
$ make ARCH=powerpc CROSS_COMPILE=powerpc64le-linux-gnu- CONFIG_INITRAMFS_SOURCE=/buildroot/output/images/rootfs.cpio -j$(nproc)
$ cp arch/powerpc/boot/dtbImage.microwatt.elf ~/arty
```

The output is arch/powerpc/boot/dtbImage.microwatt.elf.

## Program Arty with the MicroWatt bitfile and  Linux image

* Get the linux buildroot elf file if you did not build it yourself, the second "gdown" command allows you to get the bitfile if you did not build it yourself
```
$ pip3 install gdown
$ cd ~/arty
$ gdown https://drive.google.com/uc?id=1JRmkKseXCFwHaXCmdC5NrvXIwwQXpkey
$ gdown https://drive.google.com/uc?id=1v7KqhiqnXxnyWRlK-5k4L4S6MJzLmkW3
```

This next operation will overwrite the contents of the flash on the Arty board .

```
$ cd ~/arty
$ ~/microwatt/openocd/flash-arty -f a100 microwatt_0.bit
$ ~/microwatt/openocd/flash-arty -f a100 dtbImage.microwatt.elf -t bin -a 0x400000
```
### See it boot!

Connect to the second USB TTY device exposed by the FPGA
```
$ gtkterm -p /dev/ttyUSB1
```

The gateware has firmware that will look at FLASH_ADDRESS and attempt to parse an ELF there, loading it to the address specified in the ELF header and jumping to it. You may have to push the “program” button if you don’t see it starting automatically.

### Log in and enable SSH on the Arty

If you want to use Arty in an edge type environment, you will likely want to enable remote access over the Ethernet. To do this you’ll need to connect your Arty to an Ethernet router.

In your gtkterm terminal after the system boots you should see

```
...
Welcome to Buildroot
microwatt login: ( enter “root” – without quotes )
# passwd root
# udhcpc -i eth0
```
The first command sets the root password (you’ll see some complaints but you can ignore those for now) and the second starts the network. In the output from Arty you’ll see “udhcpc: lease of x.y.z.u obtained from …”. x.y.z.u is the Ethernet address you can use to ssh to Arty ( ssh root@x.y.z.u ) from another system on the network. If you reset your Arty system multiple times then on the system you use to connect to it you may end up with non-matching keys in ~/.ssh/known_hosts on the machine from which you are trying to connect to your Arty Microwatt system. If this happens manually remove the entry in that file for x.y.z.u

### Setting up a file system

To Do … adding a MicroSD on one of the Arty Pmod ports so we can have a permanent file system.

## FAQ

## Version History

* 0.0 – Sep 21 2024
    * Initial Version

## License

The instructions on this page are free to use for any purpose, including commercial use, and no attribution is required if you copy these instructions. No warranty or guarantees of any kind are provided. For licenses on the various projects we reference, please see the original github repositories.

## Authors

Madhavan Srinivasan, Jayakumar Singaram, and H. Peter Hofstee contributed to this list of instructions.

## Acknowledgments

We sincerely appreciate those who built the original projects and tools this github page tries to provide some further assistance with, and of course specifically the creators of and contributors to MicroWatt.
