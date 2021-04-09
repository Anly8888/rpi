#!/bin/bash
#
# usage:
#
# ./init-rpi-img.sh <raspbian.img> [part size]
#
# The script does the following things:
#
#  1. enlarge partion 2 by [part size] MB
#  2. enable ssh
#  3. add default WiFi conections
#  4. modify /boot/config.txt
#     4.1 set i2c_baudrate=400K
#     4.2 add two sc16is752-i2c devices
#     4.3 enable gpio-poweroff
#     4.4 add rtc ds3231
#     4.5 add i2s audio
#  5. disable rainbow screen
#  6. enable i2c_arm, spi
#  7. generate locale en_US.UTF-8, zh_CN.UTF-8
#  8. set LANG=zh_CN
#  9. install /usr/local/qt5.15
# 10. remove boot screen informations
# 11. generate /etc/asound.conf
# 12. change apt sources to mirror of China

if [ "$1" == "" ]; then
    echo "USAGE:"
    echo "$0 <raspbian.img> [part size]"
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


# image file name
IMG=$1

# size in MB
SIZE=${2-0}

if [ "$SIZE" -ne 0 ]; then
    # resize the image file
    dd if=/dev/zero bs=1M count=$SIZE >> $IMG

    # resize part 2
    echo resizepart 2 -1s | parted $IMG
    LOOP=$(losetup -f -P --show $IMG)
    e2fsck -f ${LOOP}p2
    resize2fs ${LOOP}p2
else
    LOOP=$(losetup -f -P --show $IMG)
fi


# mount partition
mount ${LOOP}p2 /mnt/rpi
mount ${LOOP}p1 /mnt/rpi/boot


# enable ssh
touch /mnt/rpi/boot/ssh


# add WiFi
cat <<"WPACONF" > /mnt/rpi/boot/wpa_supplicant.conf
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=CN

network={
	ssid="!!!!!"
	psk=44de2506005443a38981a5985501edcf05d3ec534b7b9df288748204f4583308
}
network={
	ssid="jishuyafabu_Wi-Fi5"
	psk=6a50a0c03ce59e0c0d58c0092752c161748cf71040ab51552914713cab4ffde6
}
network={
	ssid="yafashiyanshi"
	psk=89a23288f632098aac0fa9542dab5f87b4677b059f097ef27b24b3f6399e1eaf
}
network={
	ssid="yanfashiyashi"
	psk=d86844efebb6917614bdde00af0b4c540a4c2d9aec1f4f3259160c5de568c181
}
WPACONF


# add /etc/asound.conf
cat <<"ASOUNDCONF" > /mnt/rpi/etc/asound.conf
pcm.speakerbonnet {
   type hw card 0
}

pcm.dmixer {
   type dmix
   ipc_key 1024
   ipc_perm 0666
   slave {
     pcm "speakerbonnet"
     period_time 0
     period_size 1024
     buffer_size 8192
     rate 44100
     channels 2
   }
}

ctl.dmixer {
    type hw card 0
}

pcm.softvol {
    type softvol
    slave.pcm "dmixer"
    control.name "PCM"
    control.card 0
}

ctl.softvol {
    type hw card 0
}

pcm.!default {
    type             plug
    slave.pcm       "softvol"
}
ASOUNDCONF


# modify /boot/config.txt
grep 'dtparam=i2c_baudrate' /mnt/rpi/boot/config.txt &> /dev/null || \
cat <<"CONFIG" >> /mnt/rpi/boot/config.txt
dtparam=i2c_baudrate=400000
dtoverlay=sc16is752-i2c,int_pin=24,addr=0x48
dtoverlay=sc16is752-i2c,int_pin=23,addr=0x49
dtoverlay=i2c-rtc,ds3231
dtoverlay=hifiberry-dac
dtoverlay=i2s-mmap
dtoverlay=gpio-poweroff
disable_splash=1
CONFIG

sed -i 's/#dtparam=\(i2c_arm\|spi\)=on/dtparam=\1=on/g' /mnt/rpi/boot/config.txt
sed -i "s|^dtparam=audio=on$|#dtparam=audio=on|" /mnt/rpi/boot/config.txt


# modify /boot/cmdline.txt, remove boot messages
if ! grep 'logo.nologo' /mnt/rpi/boot/cmdline.txt &> /dev/null; then
    sed -i 's/$/ consoleblank=1 logo.nologo loglevel=0 plymouth.enable=0 vt.global_cursor_default=0 fastboot noatime nodiratime noram/' \
        /mnt/rpi/boot/cmdline.txt
fi

#
# apt sources
#

# /etc/apt/sources.list
sed -i 's@http://raspbian.raspberrypi.org@http://mirrors.bfsu.edu.cn/raspbian@' /mnt/rpi/etc/apt/sources.list
# /etc/apt/sources.list.d/raspi.list
sed -i 's@http://archive.raspberrypi.org/debian/@http://mirrors.bfsu.edu.cn/raspberrypi/@' /mnt/rpi/etc/apt/sources.list.d/raspi.list

# disable piwiz startup
rm /mnt/rpi/etc/xdg/autostart/piwiz.desktop



#
# prepare chroot
#

# copy qemu binary
if [ ! -e /mnt/rpi/usr/bin/qemu-arm-static ]; then
    cp /usr/bin/qemu-arm-static /mnt/rpi/usr/bin/
fi

# mount binds
mount --bind /dev /mnt/rpi/dev/
mount --bind /sys /mnt/rpi/sys/
mount --bind /proc /mnt/rpi/proc/
mount --bind /dev/pts /mnt/rpi/dev/pts

# ld.so.preload fix
sed -i 's/^/#CHROOT /g' /mnt/rpi/etc/ld.so.preload


# generate locale settings
if ! grep '^zh_CN' /mnt/rpi/etc/locale.gen &> /dev/null; then
    # modify /etc/locale.gen
    sed -i 's/^\s*\(.._..\)/# \1/g' /mnt/rpi/etc/locale.gen
    sed -i 's/^#\s*\(en_US\|zh_CN\)\.UTF-8/\1.UTF-8/g' /mnt/rpi/etc/locale.gen

    # generate locale
    chroot /mnt/rpi locale-gen
    chroot /mnt/rpi update-locale LANG=zh_CN.UTF-8
fi


# Qt library
rsync -a --no-g --no-o /opt/rpi/qt5.15 /mnt/rpi/usr/local/
echo /usr/local/qt5.15/lib > /mnt/rpi/etc/ld.so.conf.d/qt5.15.conf
chroot /mnt/rpi ldconfig


# update /etc/resolv.conf
#  or 
# echo nameserver 8.8.8.8 > /etc/resolv.conf
chroot resolvconf -u


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

# detach loop
losetup -d $LOOP

