FROM fedora
COPY . /evok
RUN sudo dnf install -y qemu-system-arm libguestfs-tools-c
ENTRYPOINT /evok/misc/test.sh