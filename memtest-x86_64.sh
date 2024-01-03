#!/bin/bash

APP_NAME="memtest-x86_64"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
APP_PATH="${SCRIPT_DIR}/${APP_NAME}"

if [ ! -f "$APP_PATH" ]; then
    echo "$APP_NAME not found!"
    exit 1
fi

qemu-system-x86_64 -m 128M -smp 1 -machine q35 -kernel $APP_PATH -append ";;" -nographic