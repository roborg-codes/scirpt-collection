#!/usr/bin/env bash

readonly IFACE="${1:?'Interface name argument missing'}"

if [ "$(cat /sys/class/net/"${IFACE}"/operstate)" = 'down' ]; then
    echo "Network down"
    exit 1
fi

ip addr show "${IFACE}" |
    sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p'

