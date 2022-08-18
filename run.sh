#!/bin/bash

# display usage
function usage() {
	echo "`basename $0`: Build an ISO image for either Debian 11 or Rocky Linux 8"
	echo "Usage:

`basename $0` -t [ debian | rocky ]"
	exit 255
}

while getopts "t:" OPTION; do
    case ${OPTION} in
        t) target=${OPTARG};;
        *) usage;;
    esac
done

case ${target} in
  debian) true;;
  rocky) true;;
  *) echo -e "Invalid target!\n"; usage;;
esac

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

podman run --rm -it -v $(pwd):/mnt/data isobuilder /mnt/data/build-${target}.sh
