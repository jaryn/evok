#!/bin/bash

set -x -e

# Reference https://github.com/dhruvvyas90/qemu-rpi-kernel/

RASPIOS_IMAGE_NAME="2021-03-04-raspios-buster-armhf-lite"
RASPIOS_IMAGE_URL="https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2021-03-25/$RASPIOS_IMAGE_NAME.zip"
RASPIOS_IMAGE_SHA256="ea92412af99ec145438ddec3c955aa65e72ef88d84f3307cea474da005669d39"

RASPBERRY_KERNEL_NAME="kernel-qemu-5.4.51-buster"
RASPBERRY_KERNEL_URL="https://github.com/dhruvvyas90/qemu-rpi-kernel/raw/master/$RASPBERRY_KERNEL_NAME"
RASPBERRY_KERNEL_SHA256="813c55fad98686b00fb970595a961b0b021c5539c81781aedb74af92c575ff89"

RASPBERRY_DTB_NAME="versatile-pb-buster-5.4.51.dtb"
RASPBERRY_DTB_URL="https://github.com/dhruvvyas90/qemu-rpi-kernel/raw/master/$RASPBERRY_DTB_NAME"

TEST_VM_IMAGE_NAME="test_vm"

CACHE_DIR="$HOME/.cache/evok"
TMPDIR=`mktemp -d /var/tmp/evok-XXXXXXXX`

function cleanup {
  >&2 echo "Removing $TMPDIR"
  rm  -r "$TMPDIR"
}


function checksum_matches {
    FILE_NAME="$1"
    CHECKSUM="$2"
    >&2 echo Checking "$CHECKSUM" "$FILE_NAME"
    >&2 sha256sum -c <(echo "$CHECKSUM" "$FILE_NAME")
    return $?
}


function cached_download {
    URL="$1"
    EXPECTED_SHA_256="$2"
    unchecked_file="$CACHE_DIR/$EXPECTED_SHA_256.unchecked"

    if ! checksum_matches "$CACHE_DIR/$EXPECTED_SHA_256" "$EXPECTED_SHA_256"; then
        >&2 echo "File not found in cache. Downloading $URL."
        curl -L "$URL" --output "$unchecked_file"
        if checksum_matches "$unchecked_file" "$EXPECTED_SHA_256"; then
            mv "$unchecked_file" "$CACHE_DIR/$EXPECTED_SHA_256"
        fi
    fi

    >&2 echo "Computing checksum of cached file."
    if ! checksum_matches "$CACHE_DIR/$EXPECTED_SHA_256" "$EXPECTED_SHA_256"; then
        >&2 echo "The cached file checksum is wrong."
    fi
    cat "$CACHE_DIR/$EXPECTED_SHA_256"
}

function download {
    # From https://blog.agchapman.com/using-qemu-to-emulate-a-raspberry-pi/
    cached_download "$RASPIOS_IMAGE_URL" "$RASPIOS_IMAGE_SHA256" > "$TMPDIR/$RASPIOS_IMAGE_NAME"
    cached_download "$RASPBERRY_KERNEL_URL" "$RASPBERRY_KERNEL_SHA256" > "$TMPDIR/$RASPBERRY_KERNEL_NAME"
    curl -L "$RASPBERRY_DTB_URL" --output "$TMPDIR/$RASPBERRY_DTB_NAME"
}


function prepare_disk {
    BASE_IMAGE="$TMPDIR/$RASPIOS_IMAGE_NAME"
    TARGET_IMAGE="$TMPDIR/$TEST_VM_IMAGE_NAME"
    #qemu-img create -f qcow2 -o backing_file="$RASPIOS_PATH" "$TMPDIR/test_vm.qcow2" 2048M
    cat "$BASE_IMAGE" | funzip > "$TARGET_IMAGE"
}


function boot {
    IMAGE=$1
    qemu-system-arm \
    -M versatilepb \
    -cpu arm1176 \
    -m 256 \
    -drive "file=$TMPDIR/$TEST_VM_IMAGE_NAME,if=none,index=0,media=disk,format=raw,id=disk0" \
    -device "virtio-blk-pci,drive=disk0,disable-modern=on,disable-legacy=off" \
    -net "user,hostfwd=tcp::5022-:22" \
    -dtb "$TMPDIR/$RASPBERRY_DTB_NAME" \
    -kernel "$TMPDIR/$RASPBERRY_KERNEL_NAME" \
    -append 'root=/dev/vda2 panic=1' \
    -serial mon:stdio -nographic -no-reboot
}


trap cleanup EXIT

[ -e "$CACHE_DIR" ] || mkdir -p "$CACHE_DIR"
download
prepare_disk
boot
