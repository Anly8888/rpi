#!/bin/bash

LOOP=${1:-$(ls /dev/loop*p2)}
if [[ -z "$LOOP" ]]; then
    echo $0 </dev/loop<n>p2> needed
    exit 1
fi
mount ${LOOP} /mnt/rpi
