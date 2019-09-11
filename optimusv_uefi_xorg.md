# Optimus V laptop, UEFI, xorg, i3-gaps, compton (sdhand fork)...

# TOC
1. [Preparing the disks](#preparing-the-disks)
2. [Installing Stage3](#installing-stage3)
3. [Build the kernel](#build-the-kernel)
4. [Setting up the system](setting-up-the-system)
5. [Install base system](#install-base-system)
6. [Further system config](#further-system-config)
7. [Bootloader](#bootloader)
8. [Flesh out system](#flesh-out-system)

# Preparing the disks

1. Burn Manjaro (XFCE) to USB and boot **ensure to boot using EFI!**

2. Set up wifi

```bash
net-setup
```

3. Set up partition using fdisk:

```bash
fdisk
```

Creating the GPT partition table, adding two partitions: one 500Mb EFI system
partition, and the remainder a linux partition on the SSD (`/dev/sdb2`):

| Partition | Size | Use      | Format       |
|-----------|------|----------|--------------|
| /dev/sdb1 | 500M | boot/ESP | vfat (fat32) |
| /dev/sdb2 | rest | root     | ext4         |


4. Format the partitions as necessary

```bash
mkfs.vfat -F 32 /dev/sdb1
mkfs.ext4 /dev/sdb2
```

5. Mount the rootfs, change directory to its mount point

```bash
mount /dev/sdb2 /mnt/gentoo
cd /mnt/gentoo
```




# Installing stage3

1. Obtain the stage3 tarball

Using links or whatever navigate to https://www.gentoo.org/downloads/mirrors/#uk.

```bash
links https://www.gentoo.org/downloads/mirrors/#uk
```

Select a mirror. Go to `releases/amd64/autobuilds` and choose
the tarball that suits you.

A good mirror is `bytemark`:

```bash
links https://mirror.bytemark.co.uk/gentoo/releases/amd64/autobuilds/current-stage3-amd64/
```

2. unzip tarball

```bash
tar xvpf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner
```

and that's all there is to it!




# Install base system

1. Configure `make.conf`

```bash
nano /mnt/gentoo/etc/portage/make.conf
```

Update `COMMON_FLAGS`:

```bash
COMMON_FLAGS="-march=native -02 -pipe"
```

Add makeopts:

```bash
$ echo 'MAKEOPTS="-j9"' >> /mnt/gentoo/etc/portage/make.conf
```

2. Select mirrors

```bash
mirrorselect -i -o >> /mnt/gentoo/etc/portage/make.conf
```

3. ebuild repo settings

We'll be chrooting into the mounted rootfs, and using the `emerge` tool to install
base system. Copy the repos.conf over to the system so emerge has some default 
settings to work with.

```bash
cd /mnt/gentoo
mkdir -p etc/portage/repos.conf
cp usr/share/portage/config/repos.conf etc/portage/repos.conf/gentoo.conf
```

4. Network settings

In the chroot, need network (for downloading of stuff), so copy the dns config over.

```bash
cp --dereference /etc/resolv.conf /mnt/gentoo/etc
```

7. Mount (pseudo)filesystems

```bash
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
```

8. Entering the chroot

```bash
chroot /mnt/gentoo /bin/bash
source /etc/profile && export PS1="(chroot) $PS1"
```



# Setting up the system

1. Create `swapfile`

```bash
fallocate -l 2G /swapfile
chmod 0600 /swapfile
mkswap /swapfile
swapon /swapfile
```

2. Update ebuild repository

```bash
emerge --sync
```

3. Selecting profile

Default profile should be fine (latest basic profile should be automatically
selected. Can, however, change profile with:

```bash
eselect profile list # to list profiles available
eselect profile set $n # replace $n with profile number to use
```

4. Update @world

```bash
emerge --ask --verbose --update --deep --newuse @world
```

5. Configure `USE` flags

I know I want xorg, not wayland, I want gtk, no qt, I want python support baked into things:

```USE="xorg -wayland gtk -qt python"```

6. Timezone and locale

```bash
echo "Europe/London" > /etc/timezone
emerge --config sys-libs/timezone-data
echo "en_GB ISO-8859-1" >> /etc/locale.gen
echo "en_GB.UTF8 UTF8" >> /etc/locale.gen
locale-gen
```

Following the above creates 6 locales, the last being en_GB UTF-8.

```bash
eselect locale set 6
```

7. Update environment

```bash
env-update && source /etc/profile && export PS1="(chroot) $PS1"
```



# Build the kernel

1. Installing kernel sources

Want latest version of the Gentoo patched kernel sources, use `equery` to find
what is the latest available.

```bash
emerge app-portage/gentoolkit
```

Install latest kernel using:

```bash
emerge --ask =$(equery list -po sys-kernel/gentoo-sources | tail -1)
```

This will "unmask" this version of the kernel sources, and install it. To 
automatically always choose the latest version, unmask all `gentoo-sources` 
versions:

```bash
echo 'sys-kernel/gentoo-sources ~amd64' >> /etc/portage/package.keywords
```

2. Managing config files

Installing packages sometimes requires an update to configuration files. This is
done with packages like `cfg-update` from `app-portage`.

```bash
emerge app-portage/cfg-update
```

If an install fails because config files need to update, run `cfg-update -u`.

3. **Mount boot / EFI System Partition (ESP)**

**DO NOT FORGET THIS STEP IT WILL BE FRUSTRATING LATER***

```bash
mount /dev/sda1 /boot
```

4. Configure and build kernel

The Optimus V has an m2 SSD card, and a 1TB HDD, an internal wifi card, and an
ethernet adapter, a card reader, an NVIDIA 765M and some other stuff. To boot,
we need a video controller, a sata controller, a wifi controller, and some other
assorted stuff:

| Module          | Description                                             |
|-----------------|---------------------------------------------------------|
| ie31200_edac    | Host bridge, DRAM controller                            |
| pcieport        | PCI controller                                          |
| i915            | Intel integrated graphics, VGA controller               |
| snd_hda_intel   | Audio controller                                        |
| xhci_pci        | USB Controller: USB xHCI                                |
| ehci_pci        | USB controller: USB EHCI controller                     |
| lpc_ich         | ISA bridge                                              |
| ahci            | SATA controller                                         |
| i2c_i801        | SMBus controller                                        |
| nouveau         | 3D controller: NVIDIA GeForce GTX 765m                  |
| iwlwifi         | WiFi controller: Intel Centrino Wireless-N              |
| rtsx_pci        | PCIe card reader                                        |

Enable the required modules:

```bash
cd /usr/src/linux
make menuconfig
```

Make kernel!

```bash
make && make modules_install && make install
```

**alternatively...**

Use genkernel to get a good starting point from which to improve:

```bash
emerge sys-kernel/genkernel
genkernel --menuconfig
```

This may involve updating some config files, or policy stuff.




# Further system config

1. Flesh out `fstab`

```bash
echo "/dev/sda1 /boot vfat  defaults,noatime  0 2" >> /etc/fstab
echo "/dev/sda2 /     ext4  noatime           0 1" >> /etc/fstab
echo "/swapfile none  swap  sw                0 1" >> /etc/fstab
```

2. Hostname and domain

```bash
echo 'hostname="gbox"' > /etc/conf.d/hostname
echo 'dns_domain_lo="matrx"' > /etc/conf.d/net
```

3. Network config

```bash
emerge --ask --noreplace net-misc/netifrc
```

Important! replace <ETH> with the name of the ethernet device. (`enp0s3` or
whatever).

```bash
echo 'config_<ETH>="dhcp"' > /etc/config.d/net
```

```bash
cd /etc/init.d
ln -s net.lo net.<ETH>
rc-update add net.<ETH> default
```

4. Root password

```bash
passwd
```

5. Init config

Edit `rc.conf` as desired (at least enable parallel start).

```bash
nano /etc/rc.conf
```

6. Update keymaps

```bash
nano /etc/conf.d/keymaps
```

7. System logging

Keep it simple: use `sysklogd` as logger.

```bash
emerge app-admin/sysklogd
rc-update add sysklogd default
```

8. Filesystems

Install drivers for `vfat` filesystems.

```bash
emerge sys-fs/dosfstools
```

9. Networking tools

```bash
emerge net-misc/dhcpcd
rc-update add dhcpcd default
```




# Bootloader

1. Install boot manager (GRUB2)

Before we install GRUB2, we need to set what system we're going to be managing
in GRUB in `make.conf`:

```bash
echo 'GRUB_PLATFORMS="efi-64"' >> /etc/portage/make.conf
```

Build GRUB2:

```bash
emerge sys-boot/grub:2
```
Install GRUB2:

```bash
mkdir -p /boot/EFI
grub-install --target=x86_64-efi --efi-directory=/boot/EFI
```

2. Configure GRUB2:

```bash
grub-mkconfig -o /boot/grub/grub.cfg
```

3. Reboot

Reboot the system

```bash
exit # exit from the chroot
reboot
```

and remove the installation media. Log in to root with the password set earlier.




# Flesh out system

1. Check network

Check network is running properly

```bash
ping 8.8.8.8
```

2. Adding a(some) user(s)

Add a user with ability to use su, audio, portage, and video. Other groups
include `usb`, `games`, `floppy`.

```bash
useradd -m -G users,wheel,audio,portage,video -s /bin/bash <USER>
passwd <USER>
```

3. Done!

lol no, just getting started... xorg... i3... python3... vim... vimb...
