#!/bin/sh

# Reference https://github.com/dhruvvyas90/qemu-rpi-kernel/

RASPIOS_IMAGE_NAME="2021-03-04-raspios-buster-armhf-lite"
RASPIOS_IMAGE_URL="https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2021-03-25/2021-03-04-raspios-buster-armhf-lite.zip"
RASPBERRY_KERNEL_NAME="kernel-qemu-5.4.51-buster"
RASPBERRY_KERNEL_URL="https://github.com/dhruvvyas90/qemu-rpi-kernel/raw/master/$RASPBERRY_KERNEL_NAME"
RASPBERRY_DTB_NAME="versatile-pb-buster-5.4.51.dtb"
RASPBERRY_DTB_URL="https://github.com/dhruvvyas90/qemu-rpi-kernel/raw/master/$RASPBERRY_DTB_NAME"


TMPDIR=`mktemp -d`

function cleanup {
  echo "Removing $TMPDIR"
  rm  -r "$TMPDIR"
}


function download {
    # From https://blog.agchapman.com/using-qemu-to-emulate-a-raspberry-pi/
    curl -L "$RASPIOS_IMAGE_URL" "$TMPDIR/raspios.zip" | funzip > "$TMPDIR/$RASPIOS_IMAGE_NAME"
    curl -L "$RASPBERRY_KERNEL_URL" --output "$TMPDIR/$RASPBERRY_KERNEL_NAME"
    curl -L "$RASPBERRY_DTB_URL" --output "$TMPDIR/$RASPBERRY_DTB_NAME"
}


function prepare_disk {
    #qemu-img create -f qcow2 -o backing_file="$RASPIOS_PATH" "$TMPDIR/test_vm.qcow2" 2048M
    cp "$TMPDIR/$RASPIOS_IMAGE_NAME" "$TMPDIR/test_vm.qcow2"
}


function boot {
    qemu-system-arm \
    -M versatilepb \
    -cpu arm1176 \
    -m 256 \
    -drive "file=$TMPDIR/test_vm.qcow2,if=none,index=0,media=disk,format=raw,id=disk0" \
    -device "virtio-blk-pci,drive=disk0,disable-modern=on,disable-legacy=off" \
    -net "user,hostfwd=tcp::5022-:22" \
    -dtb "$TMPDIR/$RASPBERRY_DTB_NAME" \
    -kernel "$TMPDIR/$RASPBERRY_KERNEL_NAME" \
    -append 'root=/dev/vda2 panic=1' \
    -serial mon:stdio -nographic -no-reboot
}


trap cleanup EXIT
download
prepare_disk
boot
