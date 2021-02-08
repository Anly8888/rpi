#!/bin/bash
rsync -av --delete /mnt/rpi/lib /opt/rpi/sysroot
rsync -av --delete /mnt/rpi/usr/lib /opt/rpi/sysroot/usr
rsync -av --delete /mnt/rpi/usr/include /opt/rpi/sysroot/usr
rsync -av --delete /mnt/rpi/opt/vc /opt/rpi/sysroot/opt
~/rpi/rpi/sysroot-relativelinks.py /opt/rpi/sysroot
