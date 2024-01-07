#!/bin/bash

APP_NAME=$1
PLATFORM=$(echo $APP_NAME | cut -d'_' -f 2-)

##### You can customize the values here
BUS="mmio"
BLK="y"
NET="y"
V9P="y"
V9P_PATH="./ruxos_bld"
NET_DEV="user"
NET_DUMP="n"
GRAPHIC="n"
QEMU_LOG="n"
SMP="1"
ARGS="./redis-server,--bind,0.0.0.0,--port,5555,--save,\"\",--appendonly,no,--protected-mode,no,--ignore-warnings,ARM64-COW-BUG"
ENVS=""
DISK_IMG="./ruxos_bld/disk.img"
#####

if [ "$PLATFORM" == "x86_64-qemu-q35" ]; then
    BUS="pci"
fi

BIN_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && cd .. && pwd )/app-bin"
APP_PATH="${BIN_DIR}/${APP_NAME}"

if [ ! -f "$APP_PATH" ]; then
    echo "$APP_NAME not found in $BIN_DIR!"
    exit 1
fi

case "$PLATFORM" in
    "x86_64-qemu-q35")
        QEMU="qemu-system-x86_64"
        QEMU_ARGS="-machine q35 -kernel $APP_PATH"
        ;;
    "aarch64-qemu-virt")
        QEMU="qemu-system-aarch64"
        QEMU_ARGS="-cpu cortex-a72 -machine virt -kernel $APP_PATH"
        ;;
    "riscv64-qemu-virt")
        QEMU="qemu-system-riscv64"
        QEMU_ARGS="-machine virt -bios default -kernel $APP_PATH"
        ;;
    *)
        echo "Unsupported platform: $PLATFORM"
        exit 1
        ;;
esac

case "$BUS" in
    "mmio")
        VDEV_SUFFIX="device"
        ;;
    "pci")
        VDEV_SUFFIX="pci"
        ;;
    *)
        echo "\"BUS\" must be one of \"mmio\" or \"pci\""
        exit 1
        ;;
esac

QEMU_ARGS+=" -m 128M -smp $SMP -append \";$ARGS;$ENVS\""

if [ "$BLK" = "y" ]; then
    if [ ! -f "$DISK_IMG" ]; then
        echo "Creating FAT32 disk image \"$DISK_IMG\" ..."
        dd if=/dev/zero of=$DISK_IMG bs=1M count=64
        mkfs.fat -F 32 $DISK_IMG
    fi
    QEMU_ARGS+=" -device virtio-blk-$VDEV_SUFFIX,drive=disk0 -drive id=disk0,if=none,format=raw,file=$DISK_IMG"
fi

if [ "$NET" = "y" ]; then
    QEMU_ARGS+=" -device virtio-net-$VDEV_SUFFIX,netdev=net0"
fi

if [ "$V9P" = "y" ]; then
    QEMU_ARGS+=" -fsdev local,id=myid,path=$V9P_PATH,security_model=none -device virtio-9p-$VDEV_SUFFIX,fsdev=myid,mount_tag=rootfs"
fi

if [ "$NET" = "y" ]; then
    case "$NET_DEV" in
        "user")
            QEMU_ARGS+=" -netdev user,id=net0,hostfwd=tcp::5555-:5555,hostfwd=udp::5555-:5555"
            ;;
        "tap")
            QEMU_ARGS+=" -netdev tap,id=net0,ifname=tap0,script=no,downscript=no"
            ;;
        *)
            echo "\"NET_DEV\" must be one of \"user\" or \"tap\""
            exit 1
            ;;
    esac
fi

if [ "$NET_DUMP" = "y" ]; then
    QEMU_ARGS+=" -object filter-dump,id=dump0,netdev=net0,file=netdump.pcap"
fi

if [ "$GRAPHIC" = "y" ]; then
    QEMU_ARGS+=" -device virtio-gpu-$VDEV_SUFFIX -vga none -serial mon:stdio"
elif [ "$GRAPHIC" = "n" ]; then
    QEMU_ARGS+=" -nographic"
fi

if [ "$QEMU_LOG" = "y" ]; then
    QEMU_ARGS+=" -D qemu.log -d in_asm,int,mmu,pcall,cpu_reset,guest_errors"
fi

# Running QEMU
echo -e "\033[1m\033[32mCommand:\033[0m $QEMU $QEMU_ARGS"
$QEMU $QEMU_ARGS