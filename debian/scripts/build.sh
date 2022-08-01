#!/bin/bash
script_dir="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# display usage
function usage() {
	echo "`basename $0`: Build a Debian ISO with injected preseed file."
	echo "Usage:

`basename $0` [ -p pressed_name.file ]
do not specify full path to preseed - the file must be located in ${script_dir}/preseed directory."
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
while getopts "p:" OPTION; do
    case ${OPTION} in
        p) preseed_name=${OPTARG};;
        *) usage;;
    esac
done

# where we'll download the ISO
cachedir="${HOME}/tmp/debian-iso-remaster"
mirror_url="http://mirror.xmission.com/debian-cd/current/amd64/iso-cd"
newiso="debian-11-custom-$(date --iso).iso"

# if preseed is not specified, we use the default one
if [ -z "${preseed_name}" ]; then
    preseed_file="${script_dir}/../preseed/preseed.cfg"
else
    preseed_file="${script_dir}/../preseed/${preseed_name}"
fi

# we should also make sure the preseed file exists
if [ ! -f "${preseed_file}" ]; then
    echo "Error: ${preseed_file} not found."
    exit 255
fi

# head to the cache dir for the work that's about to begin...
pushd "${cachedir}"

# we need to know what the latest ISO on the mirror is
curl -s http://mirror.xmission.com/debian-cd/current/amd64/iso-cd/SHA256SUMS | grep debian-11 > sha256 
iso_name=$(cat sha256 | awk '{ print $2 }')
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

# extract the ISO
7z x -obuild ${iso_name}

# remove cruft
rm -rf build/'[BOOT]'

# add preseed
## TODO: prompt and generate password...? maybe?
echo "script running from ${script_dir} -- I think"
cp "${preseed_file}" build/

# mangle gtk.cfg for isolinux (MBR-based boot)
sed -i 's/menu label \^Graphical install/menu label \^Automated install/g' build/isolinux/gtk.cfg 
sed -i 's/append.*/append vga=788 initrd=\/install.amd\/gtk\/initrd.gz auto=true preseed\/file=\/cdrom\/preseed.cfg locale=en_US.UTF-8 keymap=us language=us country=US theme=dark --- quiet/g' build/isolinux/gtk.cfg 

# we need to do something else for UEFI, but I can't remember what... may have to fix it tomorrow
sed -i "s/menuentry --hotkey=g 'Graphical install'/menuentry --hotkey=g 'Automated install'/g" build/boot/grub/grub.cfg
sed -i '/menuentry --hotkey=g '\''Automated install/{n;n;s/.*/    linux    \/install.amd\/vmlinuz vga=788 auto=true preseed\/file=\/cdrom\/preseed.cfg locale=en_US.UTF-8 keymap=us language=us country=US theme=dark --- quiet/}' build/boot/grub/grub.cfg

# fix the md5sums
pushd build && find -follow -type f ! -name md5sum.txt -print0 | xargs -0 md5sum > md5sum.txt && popd

# run xorriso
xorriso -as mkisofs -graft-points -b isolinux/isolinux.bin -no-emul-boot -boot-info-table -boot-load-size 4 -c isolinux/boot.cat -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
-eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot -isohybrid-gpt-basdat -V "Debian 11 Custom" -o "${newiso}" -r build --sort-weight 0 / --sort-weight 1 /boot

# later we'll clean up, but this time we won't
rm -rf build

echo "${cachedir}/${newiso} generated, exiting..."

exit 0

