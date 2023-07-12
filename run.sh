#!/bin/bash

# display usage
function usage() {
	echo "`basename $0`: Build an ISO image for either Debian 11 or Rocky Linux 8"
	echo "Usage:

`basename $0` -t [ debian | rocky ] -v [ version # ] [ -k name_of_kickstart.file ]"
	exit 255
}

while getopts "t:v:k:" OPTION; do
    case ${OPTION} in
        t) target=${OPTARG};;
        v) version=${OPTARG};;
        k) kickstart_file=${OPTARG};;
        *) usage;;
    esac
done

script_dir="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# This will *NOT* run on aarch64 architectures.
# syslinux was apparently not built for aarch64 on any RHEL or derivative.
# since right now I'm in a "fuck you RHEL mood... who cares."
#if [ "$(uname -m)" != "x86_64" ]; then
#  echo "Sorry, but this setup will only work on x86_64 architectures. Exiting."
#  exit 255
#fi

case ${target} in
  debian) true;;
  rocky) true;;
  *) echo -e "Invalid target!\n"; usage;;
esac

if [ -z "${kickstart_file}" ]; then
  kickstart_file="ks-rocky${version}"
fi

echo "Using kickstart file: ${kickstart_file}"

type podman >& /dev/null
if [ $? -ne 0 ]; then
  echo "You must have podman installed!"
  exit 255
fi

podman build . -t isobuilder -f ./Dockerfile
if [ $? -ne 0 ]; then
  echo "podman build exited with a non-zero status."
  exit 255
fi

# podman command is different when running a system with selinux
type getenforce >& /dev/null
if [ $? -eq 0 ]; then
  echo "SELinux detected..."
  podman run --rm -it -v $(pwd):/mnt/data:Z isobuilder /mnt/data/build-${target}.sh -v ${version} -k "${kickstart_file}"
else
  podman run --rm -it -v $(pwd):/mnt/data isobuilder /mnt/data/build-${target}.sh -v ${version} -k "${kickstart_file}"
fi

