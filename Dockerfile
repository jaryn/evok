FROM debian

RUN apt-get update && apt-get install -y devscripts dh-virtualenv dh-exec
COPY . /evok
RUN cd /evok && debuild
