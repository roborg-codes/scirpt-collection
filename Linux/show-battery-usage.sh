#!/usr/bin/env bash

cat /sys/class/power_supply/BAT0/capacity \
    -< <(printf "%%:") \
    -< <(tr '[:upper:]' '[:lower:]' < /sys/class/power_supply/BAT0/status) \
    | tr -d '\n'

