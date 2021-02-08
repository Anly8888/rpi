#!/bin/bash

usage() {
    echo "usage:"
    echo ""
    echo "$0 [options] <img> [size]"
    exit 1
}

IMG=$1
[ -e "$IMG" ] || usage
shift

SIZE=${1:-1024}
dd if=/dev/zero bs=1M count=$SIZE >> $IMG

echo resizepart 2 -1s | parted $IMG
LOOP=$(losetup -f -P --show $IMG)
e2fsck -f ${LOOP}p2
resize2fs ${LOOP}p2
losetup -d $LOOP
