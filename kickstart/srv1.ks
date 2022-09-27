url --url="http://ord.mirror.rackspace.com/rocky/8/BaseOS/x86_64/os/"
repo --name=epel --baseurl=https://mirrors.xmission.com/fedora-epel/8/Everything/x86_64/

# force text mode, please
text

# System language
lang en_US.UTF-8

# disable firstboot
firstboot --disable

# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'

# Disable firewall (We use hardware firewalls)
firewall --disabled

# Set SELinux to enforcing (Which is default)
selinux --enforcing

# Set the timezone
timezone America/Denver --isUtc

# We are the boot loader
#bootloader --location=partition

# Set the root password
rootpw resetm3n0w

# add a user
user --name=bbrown --groups=wheel --password=p@ssw0rd

# Reboot after installation
reboot --eject

# partitioning depends on uefi/mbr config
%include /tmp/uefi
%include /tmp/legacy

# include network information that will be generated in pre
%include /tmp/network.ks

%pre --logfile /tmp/kickstart.install.pre.log --interpreter=/usr/bin/bash
exec < /dev/tty6 > /dev/tty6 2> /dev/tty6

chvt 6
echo "#######################################"
echo "Kickstarted CentOS 7 x64"
echo "Enter details to continue"
echo "#######################################"
sleep 1

ROOTDRIVE=""
FOUND=""
PRVSIZE=0
for DEVN in /sys/block/* ; do
  DEV=$(basename ${DEVN})
  if [ $(cat /sys/block/${DEV}/dev | cut -d: -f 1) -eq 8 -o $(cat /sys/block/${DEV}/dev | cut -d: -f 1) -eq 259 ]; then
    if [ $(cat /sys/block/${DEV}/removable) -eq 1 ]; then
      continue
    fi
    FOUND="${FOUND} ${DEV}"
    SIZE=$(cat /sys/block/${DEV}/size)
    echo "Found hard drive: ${DEV} (size: ${SIZE})"
    if [ ${SIZE} -gt ${PRVSIZE} ]; then
      ROOTDRIVE=${DEV}
      PRVSIZE=${SIZE}
    fi
  fi
done

echo "Found the following drives: ${FOUND}"
echo "Selected drive ${ROOTDRIVE} for installation."
echo "Enter a new device name, or press ENTER to accept selected drive: "
read NEWROOTDEV

if [ -n "${NEWROOTDEV}" ]; then
  test -d /sys/block/${DEV}
  if [ $? -ne 0 ]; then
    echo "Invalid device, sorry, using ${ROOTDRIVE}, because you're dumb."
  else
    ROOTDRIVE=${NEWROOTDEV}
  fi
fi

while [ -z "${NEWHOSTNAME}" ]; do
    read -p "Enter hostname: " NEWHOSTNAME
done

read -p "Type STATIC (all caps) to assign an IP, anything else for DHCP: " NETMODE

if [ "${NETMODE}" == "STATIC" ]; then
    CONFIRM="N"
    while [ "${CONFIRM}" == "N" ]; do
        read -p "IP Address: " IPADDR
        read -p "Subnet Mask: " NETMASK
        read -p "Gateway: " GATEWAY
        read -p "DNS Server: " DNS
        echo
        echo "Does this look right?"
        echo
        echo "IP Address: ${IPADDR} -- Subnet mask: ${NETMASK} -- Gateway: ${GATEWAY} -- DNS: ${DNS}"
        echo
        read -p "CONFIRM by typing Y (any other input will repeat the questions): " CONFIRM
    done
    echo
    sleep 1

    echo "network --onboot=yes --device=link --bootproto=static --noipv6 --activate --hostname=${NEWHOSTNAME} --gateway=${GATEWAY} --ip=${IPADDR} --netmask=${NETMASK} --nameserver=${DNS}" > /tmp/network.ks
else
    sleep 1
    echo "network --onboot=yes --device=link --bootproto=dhcp --noipv6 --activate --hostname=${NEWHOSTNAME}" > /tmp/network.ks
fi

if [ -d /sys/firmware/efi ] ; then

cat >> /tmp/uefi <<END
clearpart --all --initlabel --drives=$ROOTDRIVE
part /boot/efi --fstype=efi --size=512
part /boot --fstype="xfs"  --ondisk=$ROOTDRIVE --size=1024
part pv.01  --fstype="lvmpv" --ondisk=$ROOTDRIVE --size=1   --grow
volgroup vg00 --pesize=4096 pv.01
logvol swap --fstype="swap" --name="swap" --vgname="vg00" --size=128
logvol /    --fstype="ext4" --name="root" --vgname="vg00" --size=4096 --grow

END

else

cat >> /tmp/legacy <<END
clearpart --all --initlabel --drives=$ROOTDRIVE
bootloader --location=mbr --boot-drive=$ROOTDRIVE
part /boot --fstype="xfs"  --ondisk=$ROOTDRIVE --size=1024
part pv.01  --fstype="lvmpv" --ondisk=$ROOTDRIVE --size=1   --grow
volgroup vg00 --pesize=4096 pv.01
logvol swap --fstype="swap" --name="swap" --vgname="vg00" --size=128
logvol /    --fstype="ext4" --name="root" --vgname="vg00" --size=4096 --grow

END

fi 

if [ -d /sys/firmware/efi ] ; then
touch /tmp/legacy
else 
touch /tmp/uefi
fi
chvt 1
exec < /dev/tty1 > /dev/tty1 2> /dev/tty1

%end
%packages
@core --nodefaults
@^minimal-environment
vim-enhanced
bash-completion
wget
dnf-plugins-core
%end

%post
# add my ssh pubkey to this server
mkdir -m0700 /home/bbrown/.ssh/

cat <<EOF >/home/bbrown/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCowXscQiAAV6MUR0C2cpLdjS/BO+jQPV9yhnzuXL0cy8djivV0/ULqKCIb76Ddu0ZqKMwq39jhVN0O6hmu9ixqjHu3bVtkiuPbkcnl1jyVea55efRpPcM6r07dKlsyhj/wPp0vB2zdn13fkMPGUfyUCeV1lReMYagz0a9/p3KMOjAaf2ZlAB7qqB5tqMqX1IjNSJ1zRMo2VdmfddnC+0z9AFup24ghtDJvPvKIiqKnNN00vtRc74MKGqObskGl+moJ9Q40RjjgQ/i1m0cJLyAhxHneGSgE3bYge48rGA+0P0Xw49+/YhOPemuWnh3bJxsBvCfX8kFw8U9ujOXjSMCDcVFIujHqkr0pQId/3uFmFCggUophat7ZZ43/yQCpgFy3L9rAgNGgXZkpuJA1Fd1HofQsEs9DN8LCRrOPchuEcZj7Ml+ReXHCvyN9NtlnJG4nvnFVQqUvo+cnzBYIpSU7BhCEYNnwGsPpcYgdkvE/6A9bYl6UAblZTYQTj+tAs70= bbrown@adminwks
EOF

### set permissions
chmod 0600 /home/bbrown/.ssh/authorized_keys

### set ownership
chown -R bbrown:bbrown /home/bbrown/.ssh

### fix up selinux context
restorecon -R /home/bbrown/.ssh/

### allow sudo without password
sed -i 's/^%wheel/\#%wheel/g' /etc/sudoers
sed -i 's/^\# %wheel/%wheel/g' /etc/sudoers

### why can't epel install from packages? Oh well
dnf config-manager --set-enabled PowerTools
dnf -y install epel-release

## show the IP address on the login screen
echo -e "IPv4: \\\4\n" >> /etc/issue

# End of kickstart script
%end
