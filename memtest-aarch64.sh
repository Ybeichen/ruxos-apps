#!/bin/bash

APP_NAME="memtest-aarch64"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
APP_PATH="${SCRIPT_DIR}/${APP_NAME}"

if [ ! -f "$APP_PATH" ]; then
    echo "$APP_NAME not found!"
    exit 1
fi

qemu-system-aarch64 -m 128M -smp 4 -cpu cortex-a72 -machine virt -kernel $APP_PATH -append ";;" -nographic