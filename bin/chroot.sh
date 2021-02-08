#!/bin/bash

mount --bind /dev /mnt/rpi/dev/
mount --bind /sys /mnt/rpi/sys/
mount --bind /proc /mnt/rpi/proc/
mount --bind /dev/pts /mnt/rpi/dev/pts
chroot /mnt/rpi $@
