#!/bin/bash

# This script allows you to chroot ("work on") 
# the raspbian image as if it's the raspberry pi
# on your Ubuntu desktop/laptop
# just much faster and more convenient

# make sure you have issued
# (sudo) apt install qemu qemu-user-static binfmt-support

# Invoke:
# (sudo) ./chroot-to-pi.sh <raspbian.img>

if [ "$1" == "" ]; then
    echo "USAGE:"
    echo "$0 <raspbian.img>"
    exit 1
fi

if [ "$EUID" -ne 0 ]; then
    echo "This script uses functionality which requires root privileges"
    exit 1
fi

if [ ! -x /usr/bin/qemu-arm-static ]; then
    echo "Please install qemu qemu-user-static binfmt-support packages first"
    echo "by issue the following instruct:"
    echo "sudo apt install qemu qemu-user-static binfmt-support"
    exit 1
fi

LOOP=$(losetup -f -P --show $1)

mkdir -p /mnt/rpi

# mount partition
mount ${LOOP}p2 /mnt/rpi
mount ${LOOP}p1 /mnt/rpi/boot

# mount binds
mount --bind /dev /mnt/rpi/dev/
mount --bind /sys /mnt/rpi/sys/
mount --bind /proc /mnt/rpi/proc/
mount --bind /dev/pts /mnt/rpi/dev/pts

# ld.so.preload fix
sed -i 's/^/#CHROOT /g' /mnt/rpi/etc/ld.so.preload

# copy qemu binary
if [ ! -e /mnt/rpi/usr/bin/qemu-arm-static ]; then
    cp /usr/bin/qemu-arm-static /mnt/rpi/usr/bin/
fi

echo "You will be transferred to the bash shell now."
echo "Issue 'exit' when you are done."
echo "Issue 'su pi' if you need to work as the user pi."

# chroot to raspbian
chroot /mnt/rpi /bin/bash

# ----------------------------
# Clean up
# revert ld.so.preload fix
sed -i 's/^#CHROOT //g' /mnt/rpi/etc/ld.so.preload

# unmount everything
umount /mnt/rpi/{dev/pts,dev,sys,proc,boot,}
