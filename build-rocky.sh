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

`basename $0` [ -p kickstart_name.file ]
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
while getopts "k:" OPTION; do
    case ${OPTION} in
        k) kickstart_file=${OPTARG};;
        *) usage;;
    esac
done

# where we'll download the ISO
cachedir="${script_dir}/.cache"
mirror_url="https://download.rockylinux.org/pub/rocky/8/isos/x86_64/"
newiso="rocky-8-custom-$(date --iso).iso"
label="ROCKY-8-CUST"

# if preseed is not specified, we use the default one
if [ -z "${kickstart_file}" ]; then
    kickstart_file="${script_dir}/kickstart/kickstart.cfg"
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

# we need to know what the latest ISO on the mirror is
curl -s ${mirror_url}/CHECKSUM | grep minimal.iso | grep -v '^#' > sha256 
iso_name=$(cat sha256 | awk '{ print $2 }' | tr -d \(\))
mv sha256 ${iso_name}.sha256

if [ -f ${iso_name} ]; then
    echo "ISO already downloaded, continuing..."
else
    wget ${mirror_url}/${iso_name}
fi

# check the sha256 hash
sha256sum -c ${iso_name}.sha256
if [ $? -ne 0 ]; then
    echo "Error validating hash -- exiting."
    exit 255
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

# mbr boot tweaks
sed -i 's/menu label ^Install Rocky Linux 8/menu label \^Automated Install Rocky Linux 8/g' build/isolinux/isolinux.cfg
sed -i "s/append initrd=initrd.img inst.stage2=hd:LABEL=Rocky-8-6-x86_64-dvd quiet/append initrd=initrd.img inst.stage2=hd:LABEL=Rocky-8-6-x86_64-dvd quiet inst.ks=hd:LABEL=${label}:\/$(basename ${kickstart_file})/g" build/isolinux/isolinux.cfg
sed -i '/menu default/d' build/isolinux/isolinux.cfg
sed -i '/menu label \^Automated Install Rocky Linux 8/a \ \ menu default' build/isolinux/isolinux.cfg

# uefi boot tweaks
sed -i 's/menuentry '\''Install Rocky Linux 8/menuentry '\''Automated Install Rocky Linux 8/g' build/EFI/BOOT/grub.cfg
sed -i "/linuxefi \/images\/pxeboot\/vmlinuz inst.stage2=hd:LABEL=Rocky-8-6-x86_64-dvd quiet/ s/$/ inst.ks=hd:LABEL=${label}:\/$(basename ${kickstart_file})/" build/EFI/BOOT/grub.cfg
sed -i 's/set default="1"/set default="0"/g' build/EFI/BOOT/grub.cfg

# the LABEL has to match what we're going to label the ISO
for file in build/isolinux/isolinux.cfg build/EFI/BOOT/grub.cfg; do
    sed -i "s/LABEL=Rocky-8-6-x86_64-dvd/LABEL=${label}/g" "${file}"
done

# don't know why these files are the same, but who am I to argue
cp build/EFI/BOOT/grub.cfg build/EFI/BOOT/BOOT.conf

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

