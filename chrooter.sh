#!/bin/bash

if [[ $# -lt 1 ]]
then
  echo "Specify what disk the root is on..."
  exit 1
fi

if ! stat $1
then
  echo "$1 is not a file"
  exit 1
fi

mount ${1}1 /mnt/gentoo
mount ${1}2 /mnt/gentoo/boot
cd /mnt/gentoo
mount --types proc /proc proc
mount --rbind /sys sys
mount --make-rslave sys
mount --rbind /dev dev
mount --make-rslave dev
chroot . /bin/bash
