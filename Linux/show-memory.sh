#!/usr/bin/env bash

free | awk '/Mem/ { printf "%d MiB/%d MiB\n", $3 * 1024.0, $2 * 1024.0 }'

