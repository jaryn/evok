#!/bin/sh

# Reference https://github.com/dhruvvyas90/qemu-rpi-kernel/

RASPIOS_PATH="`pwd`/2021-03-04-raspios-buster-armhf-lite.img"
RASPBERRY_KERNEL_URL="https://github.com/dhruvvyas90/qemu-rpi-kernel/raw/master/kernel-qemu-5.4.51-buster"
RASPBERRY_DTB_URL="https://github.com/dhruvvyas90/qemu-rpi-kernel/raw/master/versatile-pb-buster-5.4.51.dtb"
TMPDIR=`mktemp -d`

function cleanup {
  echo "Removing $TMPDIR"
  rm  -r "$TMPDIR"
}

function download {
    # From https://blog.agchapman.com/using-qemu-to-emulate-a-raspberry-pi/
    curl -L "$RASPBERRY_KERNEL_URL" --output "$TMPDIR/kernel-qemu-5.4.51-buster"
    curl -L "$RASPBERRY_DTB_URL" --output "$TMPDIR/versatile-pb-buster-5.4.51.dtb"
}


function prepare_disk {
    #qemu-img create -f qcow2 -o backing_file="$RASPIOS_PATH" "$TMPDIR/test_vm.qcow2" 2048M
    cp "$RASPIOS_PATH" "$TMPDIR/test_vm.qcow2"
}


function boot {
    qemu-system-arm \
    -M versatilepb \
    -cpu arm1176 \
    -m 256 \
    -drive "file=$TMPDIR/test_vm.qcow2,if=none,index=0,media=disk,format=raw,id=disk0" \
    -device "virtio-blk-pci,drive=disk0,disable-modern=on,disable-legacy=off" \
    -net "user,hostfwd=tcp::5022-:22" \
    -dtb "$TMPDIR/versatile-pb-buster-5.4.51.dtb" \
    -kernel "$TMPDIR/kernel-qemu-5.4.51-buster" \
    -append 'root=/dev/vda2 panic=1' \
    -serial mon:stdio -nographic -no-reboot
}

trap cleanup EXIT
download
prepare_disk
boot
