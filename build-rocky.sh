#!/bin/bash

# if we're running on MacOS - tell the user this needs to be run from a container.
if [ "$(uname -s)" == "Darwin" ]; then
  echo "Please use the podman implementation for MacOS :: exiting."
  exit 255
fi

script_dir="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# display usage
function usage() {
	echo "`basename $0`: Build a Rocky Linux ISO with injected kickstart file."
	echo "Usage:

`basename $0` [ -k kickstart_name.file ]
do not specify full path to the kickstart file - the file must be located in ${script_dir}/kickstart directory."
	exit 255
}

# make sure proper tools are installed
for tool in 7z xorriso curl wget sha256sum sed; do
    if not type ${tool} >& /dev/null; then
        echo "Error: ${tool} is not installed (or in \$PATH)"
        exit 255
    fi
done

# allow user to specify which preseed to push into ISO
while getopts "k:v:" OPTION; do
    case ${OPTION} in
        k) kickstart_file=${OPTARG};;
        v) version=${OPTARG};;
        *) usage;;
    esac
done

if [ -z "${version}" ]; then
  # default to rocky 8
  version=8
fi

# where we'll download the ISO
cachedir="${script_dir}/.cache"
mirror_url="https://download.rockylinux.org/pub/rocky/${version}/isos/x86_64"
newiso="rocky-${version}-custom-$(date --iso).iso"
label="ROCKY-${version}-CUST"

# if preseed is not specified, we use the default one
if [ -z "${kickstart_file}" ]; then
    kickstart_file="${script_dir}/kickstart/ks-rocky${version}.cfg"
else
    kickstart_file="${script_dir}/kickstart/${kickstart_file}"
fi

# we should also make sure the preseed file exists
if [ ! -f "${kickstart_file}" ]; then
    echo "Error: ${kickstart_file} not found."
    exit 255
fi

# make sure the cache dir exists, if not, create it
if [ ! -d "${cachedir}" ]; then
  mkdir -p "${cachedir}"
  if [ $? -ne 0 ]; then
    echo "Error: could not create directory ${cachedir}. Exiting."
    exit 255
  fi
fi

# head to the cache dir for the work that's about to begin...
pushd "${cachedir}"

# rocky has changed some things on their mirror and now provides a static named file
# we'll need to rename it so we don't clobber a downloaded 8 iso with 9, for example
iso_name="rocky-${version}-minimal.iso"

if [ -f ${iso_name} ]; then
    echo "ISO already downloaded, continuing..."
else
    wget ${mirror_url}/Rocky-x86_64-minimal.iso
    if [ $? -ne 0 ]; then
      echo "Error downloading Rocky-x86_64-minimal.iso -- exiting."
      exit 255
    fi
    mv Rocky-x86_64-minimal.iso ${iso_name}
fi

# check the sha256 hash
# grab the hash via curl
sha256hash=$(curl -s ${mirror_url}/CHECKSUM | grep ^SHA256.\*Rocky-x86_64-minimal | awk '{ print $4 }')

# validate we got a hash with regex
if ! [[ "${sha256hash}" =~ ^[0-9a-f]{64}$ ]]; then  
    echo "ERROR - curl did not return sha256 hash. Exiting."
    exit 255
fi

# build sha256 file
echo "${sha256hash}  ${iso_name}" > ${iso_name}.sha256

echo -n "Validating SHA256SUM... "
sha256sum -c ${iso_name}.sha256
if [ $? -ne 0 ]; then
    echo "Error validating hash -- exiting."
    exit 255
else
  echo "OK"
fi

popd
tmpdir=$(mktemp -d)
pushd ${tmpdir}

# extract the ISO
7z x -obuild ${cachedir}/${iso_name}

# remove cruft
rm -rf build/'[BOOT]'

# add kickstart
## TODO: prompt and generate password...? maybe?
cp "${kickstart_file}" build/

# back up isolinux.cfg for debug comparison
cp build/isolinux/isolinux.cfg ${tmpdir}/isolinux.cfg
cp build/EFI/BOOT/grub.cfg ${tmpdir}/grub.cfg
cp build/EFI/BOOT/BOOT.conf ${tmpdir}/BOOT.conf

# mbr boot tweaks
sed -i "s/menu label ^Install Rocky Linux ${version}/menu label \^Automated Install Rocky Linux ${version}/g" build/isolinux/isolinux.cfg
sed -i "s/append initrd=initrd.img inst.stage2=hd:LABEL=Rocky-.*-x86_64-dvd quiet/append initrd=initrd.img inst.stage2=hd:LABEL=Rocky-.*-x86_64-dvd quiet inst.ks=hd:LABEL=${label}:\/$(basename ${kickstart_file})/g" build/isolinux/isolinux.cfg
sed -i '/menu default/d' build/isolinux/isolinux.cfg
sed -i "/menu label \^Automated Install Rocky Linux ${version}/a \ \ menu default" build/isolinux/isolinux.cfg

# uefi boot tweaks
#sed -i 's/menuentry '\''Install Rocky Linux 8/menuentry '\''Automated Install Rocky Linux 8/g' build/EFI/BOOT/grub.cfg
sed -i "s/menuentry 'Install Rocky Linux ${version}/menuentry 'Automated Install Rocky Linux ${version}/g" build/EFI/BOOT/grub.cfg
sed -i "/linuxefi \/images\/pxeboot\/vmlinuz inst.stage2=hd:LABEL=Rocky-.*-x86_64-dvd quiet/ s/$/ inst.ks=hd:LABEL=${label}:\/$(basename ${kickstart_file})/" build/EFI/BOOT/grub.cfg
sed -i 's/set default="1"/set default="0"/g' build/EFI/BOOT/grub.cfg

# the LABEL has to match what we're going to label the ISO
for file in build/isolinux/isolinux.cfg build/EFI/BOOT/grub.cfg; do
    sed -i "s/LABEL=Rocky-.*-x86_64-dvd/LABEL=${label}/g" "${file}"
    if [ $? -ne 0 ]; then
      echo "Error running sed command -- exiting."
      exit 255
    fi
done

# don't know why these files are the same, but who am I to argue
cp build/EFI/BOOT/grub.cfg build/EFI/BOOT/BOOT.conf

# DEBUGGING: diff
#echo "DIFF: isolinux.cfg"
#echo "============"
#diff build/isolinux/isolinux.cfg ${tmpdir}/isolinux.cfg

#echo "DIFF: grub.cfg"
#echo "============"
#diff build/EFI/BOOT/grub.cfg ${tmpdir}/grub.cfg

#echo "DIFF: BOOT.conf"
#echo "============"
#diff build/EFI/BOOT/BOOT.conf ${tmpdir}/BOOT.conf

# run xorriso
xorriso -as mkisofs -graft-points -b isolinux/isolinux.bin -no-emul-boot -boot-info-table -boot-load-size 4 -c isolinux/boot.cat -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
-eltorito-alt-boot -e images/efiboot.img -no-emul-boot -isohybrid-gpt-basdat -V "${label}" -o "${newiso}" -r build --sort-weight 0 /
if [ $? -eq 0 ]; then
  echo "Generated ISO: ${newiso}"
  rm -rf build
  echo "Copying ${newiso} to /mnt/data..."
  cp ${newiso} /mnt/data
  if [ $? -eq 0 ]; then
    echo "Completed."
  else
    echo "Error copying file. I won't exit until you press ENTER, though, just in case you want to preserve the files."
    read
  fi
fi

exit 0

