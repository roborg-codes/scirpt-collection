#!/usr/bin/env bash

ALLOWED_USAGE="${1:?'Allowed usage argument missing'}"
[[ $EUID -eq 0 ]] || {
    echo "You need to be root to run this script."
    exit 1
}


disk_usage_before="$(journalctl --disk-usage | perl -ne 'm/up (.*) in/ && print "$1\n"')"

[[ -d /etc/systemd/journald.conf.d/ ]] || {
    mkdir -p /etc/systemd/journald.conf.d/
}

cat <<EOF > /etc/systemd/journald.conf.d/size.conf
[Journal]
SystemMaxUse=$ALLOWED_USAGE
EOF
systemctl restart systemd-journald.service

printf "Disk usage changed: %s -> %s\n" \
    "${disk_usage_before}" \
    "$(journalctl --disk-usage | perl -ne 'm/up (.*) in/ && print "$1\n"')"

