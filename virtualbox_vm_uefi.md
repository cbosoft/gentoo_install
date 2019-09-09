# VirtualBox vm, UEFI

1. Create new vm, 4Gb memory, 4 cores, ensure EFI mode is enabled.
2. Boot to minimal installation medium
3. Set up partition using cfdisk:

```bash
$ cfdisk
```

Creating the GPT partition table, adding two partitions: one 500Mb EFI system
partition, and the remainder (7.5G) a linux partition.

4. Format the partitions as necessary

```bash
mkfs.vfat -F 32 /dev/sda1
mkfs.ext4 /dev/sda2
```

5. Mount the rootfs, change directory to its mount point

```bash
mount /dev/sda2 /mnt/gentoo
cd /mnt/gentoo
```

6. Obtain the stage3 tarball

Using links or whatever navigate to https://www.gentoo.org/downloads/mirrors.

```bash
links https://www.gentoo.org/downloads/mirrors/
```

go to the UK mirrors, select one. Go to `releases/amd64/autobuilds` and choose
the tarball that suits you.

7. unzip tarball

```bash
tar xvpf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner
```

8. Configure `make.conf`

```bash
nano /mnt/gentoo/etc/portage/make.conf
```

Update `COMMON_FLAGS`:

```bash
COMMON_FLAGS="-march=native -02 -pipe"
```

<ctrl-o>, <enter>, <ctrl-x> to save and then quit.

Add makeopts:

```bash
$ echo 'MAKEOPTS="-j5"' >> /mnt/gentoo/etc/portage/make.conf
```

9. Select mirrors

```bash
mirrorselect -i -o >> /mnt/gentoo/etc/portage/make.conf
```

10. ebuild repo settings

```bash
mkdir -p /mnt/gentoo/etc/portage/repos.conf
cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf/gentoo.conf
```

11. Network settings

Just using ethernet, no wifi settings to copy over

```bash
cp --dereference /etc/resolv.conf /mnt/gentoo/etc
```

12. Mount filesystems

```bash
mount --types proc /proc/mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
```

13. Entering the chroot

```bash
chroot /mnt/gentoo /bin/bash
source /etc/profile && export PS1="(chroot) $PS1"
```

14. Mount boot / EFI System Partition (ESP)

```bash
mount /dev/sda1 /boot
```

14a. Create `swapfile`

```bash
fallocate -l 2G /swapfile
mkswap /swapfile
swapon /swapfile
```

15. Update ebuild repository

```bash
emerge --sync
```

16. Selecting profile

Default profile should be fine (latest basic profile should be automatically
selected. Can, however, change profile with:

```bash
eselect profile list # to list profiles available
eselect profile set $n # replace $n with profile number to use
```

17. Update @world

```bash
emerge --ask --verbose --update --deep --newuse @world
```

18. Configure `USE` flags

Don't especially know what I want to add/remove yet. Do nothing for this step.

19. Timezone and locale

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

20. Update environment

```bash
env-update && source /etc/profile && export PS1="(chroot) $PS1"
```

21. Installing kernel sources

Want latest version of the Gentoo patched kernel sources, use `equery` to find
what is the latest available.

```bash
emerge app-portage/gentoolkit
```

```bash
emerge --ask =$(equery list -po sys-kernel/gentoo-sources | tail -1)
```

22. Managing config files

Installing packages sometimes requires an update to configuration files. This is
done with packages like `cfg-update` from `app-portage`.

```bash
emerge app-portage/cfg-update
```

If an install fails because config files need to update, run `cfg-update -u`.

23. Getting `genkernel`

```bash
emerge sys-kernel/genkernel
```

24. Mount `boot`

Genkernel needs to see the EFI partition, so we need to mount it.

```bash
mount /dev/sda1 /boot
```

25. Compile kernel and modules!

```bash
genkernel all
```

26. Flesh out `fstab`

```bash
echo "/dev/sda1 /boot vfat  defaults,noatime  0 2" >> /etc/fstab
echo "/dev/sda2 /     ext4  noatime           0 1" >> /etc/fstab
echo "/swapfile none  swap  sw                0 1" >> /etc/fstab
```

27. Hostname and domain

```bash
echo 'hostname="gbox"' > /etc/conf.d/hostname
echo 'dns_domain_lo="matrx"' > /etc/conf.d/net
```

28. Network config

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

29. Root password

```bash
passwd
```

30. Init config

Edit `rc.conf` as desired (at least enable parallel start).

```bash
nano /etc/rc.conf
```

31. Update keymaps

```bash
nano /etc/conf.d/keymaps
```

32. System logging

Keep it simple: use `sysklogd` as logger.

```bash
emerge app-admin/sysklogd
rc-update add sysklogd default
```

33. Filesystems

Install drivers for `vfat` filesystems.

```bash
emerge sys-fs/dosfstools
```

34. Networking tools

```bash
emerge net-misc dhcpcd
rc-update add dhcpcd default
```

35. Install boot manager (GRUB2)

Before we install GRUB2, we need to set what system we're going to be managing
in GRUB in `make.conf`:

```bash
echo 'GRUB_PLATFORMS="efi-64"' >> /etc/portage/make.conf
```

```bash
emerge sys-boot/grub:2
```

```bash
mkdir /boot/EFI
grub-install --target=x86_64-efi --efi-directory=/boot/EFI
```

36. Configure grub

```bash
grub-mkconfig -o /boot/grub/grub.cfg
```

37. Reboot

Reboot the system

```bash
exit # exit from the chroot
reboot
```

and remove the installation media. Log in to root with the password set earlier.

38. Check network

Check network is running properly

```bash
ping 8.8.8.8
```

39. Adding a(some) user(s)

Add a user with ability to use su, audio, portage, and video. Other groups
include `usb`, `games`, `floppy`.

```bash
useradd -m -G users,wheel,audio,portage,video -s /bin/bash <USER>
passwd <USER>
```

40. Done!

lol no, just getting started.

41. Issue with pulseaudio in vm

Have to disable audio via vm settings to get this to boot... Need to configure logs to persist after boot to debug this.
