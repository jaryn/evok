#!/bin/bash

# Reference https://github.com/dhruvvyas90/qemu-rpi-kernel/

function set_versatile_pb_dtb {
 RASPBERRY_DTB_NAME="versatile-pb.dtb"
 RASPBERRY_DTB_URL="https://github.com/dhruvvyas90/qemu-rpi-kernel/raw/master/$RASPBERRY_DTB_NAME"
 RASPBERRY_DTB_SHA256="16c99de32fadbfe3b05ac2cd3ab26ba9792fd0fc823918acdf9e85f56cb6bfc9"
}

function set_versatile_pb_dtb_buster {
 RASPBERRY_DTB_NAME="versatile-pb-buster.dtb"
 RASPBERRY_DTB_URL="https://github.com/dhruvvyas90/qemu-rpi-kernel/raw/master/$RASPBERRY_DTB_NAME"
 RASPBERRY_DTB_SHA256="1e72b73b6a5295d7929fe1993ea6e6af05d49e80a47b929538dc4bc3087af3a9"
}
function set_versatile_pb_dtb_buster_5_4_51 {
  RASPBERRY_DTB_NAME="versatile-pb-buster-5.4.51.dtb"
  RASPBERRY_DTB_URL="https://github.com/dhruvvyas90/qemu-rpi-kernel/raw/master/$RASPBERRY_DTB_NAME"
  RASPBERRY_DTB_SHA256="aac8f52884fbe568b1cabf5bb66187da7dc1e71c710003436883d1b070d60f5e"
}

function set_kernel_4_19_50 {
  RASPBERRY_KERNEL_NAME="kernel-qemu-4.19.50-buster"
  RASPBERRY_KERNEL_URL="https://github.com/dhruvvyas90/qemu-rpi-kernel/raw/master/$RASPBERRY_KERNEL_NAME"
  RASPBERRY_KERNEL_SHA256="47d1fb61fc2d6ffa87a3cc44b0a2209cb455d45b35c41dc0cdd2862a1e553ab3"
}

function set_kernel_5_4_51 {
  RASPBERRY_KERNEL_NAME="kernel-qemu-5.4.51-buster"
  RASPBERRY_KERNEL_URL="https://github.com/dhruvvyas90/qemu-rpi-kernel/raw/master/$RASPBERRY_KERNEL_NAME"
  RASPBERRY_KERNEL_SHA256="813c55fad98686b00fb970595a961b0b021c5539c81781aedb74af92c575ff89"
}

function set_raspios_buster {
  RASPIOS_IMAGE_NAME="2021-03-04-raspios-buster-armhf-lite"
  RASPIOS_IMAGE_URL="https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2021-03-25/$RASPIOS_IMAGE_NAME.zip"
  RASPIOS_IMAGE_SHA256="ea92412af99ec145438ddec3c955aa65e72ef88d84f3307cea474da005669d39"
}

function set_raspios_stretch {
  RASPIOS_IMAGE_NAME="2019-04-08-raspbian-stretch-lite"
  RASPIOS_IMAGE_URL="https://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2019-04-09/$RASPIOS_IMAGE_NAME.zip"
  RASPIOS_IMAGE_SHA256="03ec326d45c6eb6cef848cf9a1d6c7315a9410b49a276a6b28e67a40b11fdfcf"

  RASPBERRY_KERNEL_NAME="kernel-qemu-4.14.79-stretch"
  RASPBERRY_KERNEL_URL="https://github.com/dhruvvyas90/qemu-rpi-kernel/raw/master/$RASPBERRY_KERNEL_NAME"
  RASPBERRY_KERNEL_SHA256="c5ed7246e6a2edc8367c1d982aed932b2b1163517e32a7923f5c536f1aa26e60"

  RASPBERRY_DTB_NAME="versatile-pb.dtb"
  RASPBERRY_DTB_URL="https://github.com/dhruvvyas90/qemu-rpi-kernel/raw/master/$RASPBERRY_DTB_NAME"
  RASPBERRY_DTB_SHA256="aac8f52884fbe568b1cabf5bb66187da7dc1e71c710003436883d1b070d60f5e"
}

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
    cached_download "$RASPBERRY_DTB_URL" "$RASPBERRY_DTB_SHA256" > "$TMPDIR/$RASPBERRY_DTB_NAME"
}


function prepare_disk {
    BASE_IMAGE="$TMPDIR/$RASPIOS_IMAGE_NAME"
    TARGET_IMAGE="$TMPDIR/$TEST_VM_IMAGE_NAME"
    #qemu-img create -f qcow2 -o backing_file="$RASPIOS_PATH" "$TMPDIR/test_vm.qcow2" 2048M
    cat "$BASE_IMAGE" | funzip > "$TARGET_IMAGE"
}


function enable_ssh {
    guestfish -a "$TARGET_IMAGE" -i <<EOF
mount /dev/sda1 /boot
touch /boot/ssh
umount /boot

mkdir /home/pi/.ssh
copy-in "$HOME/.ssh/id_rsa.pub" /tmp
mv /tmp/id_rsa.pub /home/pi/.ssh/authorized_keys
chmod 0644 /home/pi/.ssh/authorized_keys
EOF
}

function wait_for_ssh_active {
  >&2 echo 'Waiting for ssh to become active on the guest.'
  while ! ssh -o ConnectTimeout=1 pi@localhost -p5022 true; do
    sleep 10
  done
  >&2 echo 'The sshd on the guest is now active.'
}

function shutdown {
  ssh pi@localhost -p5022 sudo systemctl poweroff
}

function boot {
    IMAGE=$1
    qemu-system-arm \
    -M versatilepb \
    -cpu arm1176 \
    -m 256 \
    -drive "file=$TMPDIR/$TEST_VM_IMAGE_NAME,if=none,index=0,media=disk,format=raw,id=disk0" \
    -device "virtio-blk-pci,drive=disk0,disable-modern=on,disable-legacy=off" \
    -device virtio-net-pci,netdev=net0 \
    -netdev user,id=net0,hostfwd=tcp::5022-:22 \
    -fsdev local,id=test_dev,path=/home/jhenner/projects/evok,security_model=none -device virtio-9p-pci,fsdev=test_dev,mount_tag=test_mount \
    -dtb "$TMPDIR/$RASPBERRY_DTB_NAME" \
    -kernel "$TMPDIR/$RASPBERRY_KERNEL_NAME" \
    -append 'root=/dev/vda2 panic=1' \
    -serial mon:stdio -nographic -no-reboot
}
    #-fsdev local,path=/home/jhenner/projects/evok,security_model=passthrough,id=fsdev-fs0,readonly \

# Detect sourcing of this file
[[ "${BASH_SOURCE[0]}" != "${0}" ]] || {
  set -e
  trap cleanup EXIT

  [ -e "$CACHE_DIR" ] || mkdir -p "$CACHE_DIR"
  set_versatile_pb_dtb
  set_kernel_4_19_50
  set_raspios_buster
  download
  prepare_disk
  enable_ssh
  boot &
  wait_for_ssh_active
  shutdown
}