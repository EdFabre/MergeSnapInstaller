#!/bin/bash
#######################################################################
# This project is a Shell Script which will automatically install and
# configure your system to work with MergerFS and SnapRAID.
#
# Usage:
# ./mergesnap.sh [-t] [-q] [-u] [-d] [-h] [-y path_to_log] [-p someinteger]
#
# Options:
# -t              Runs the script in trial mode, shows what will happen if this flag removed
# -q              Runs script non-interactively using defaults
# -u              Runs the script in uninstall mode removing installed elements
# -d              Runs the script in debug mode, very loud output
# -h              Prints help menu, which you are currently reading
# -y /var/log/    Path to write log file
# -p N            Runs script non-interactively using with N parity disks
#
# Creator: Edge F.
# Maintainers: Edge F.
#######################################################################
# set -e
set -u
set -o pipefail

# Global Variables
SCRIPT_NAME=mergesnap
SNAPRAID_CONFIG_PATH=/etc/snapraid.conf
SNAPRAID_AUTOMATION_SCRIPT_SOURCE=snapraid_sync.sh
SNAPRAID_AUTOMATION_SCRIPT_EMAIL=null
SNAPRAID_AUTOMATION_SCRIPT=/usr/local/bin/snapraid_sync.sh
FSTAB_CONFIG_PATH=/etc/fstab
declare -A disksById
diskByIdLongestLine=0

# Global Functions
function commandexists() {
    if ! type "$1" >/dev/null 2>&1; then
        echo "E: Command '$1' is NOT Installed." >/dev/tty
        echo "E: Command '$1' is NOT Installed." >>$LOG_FILE
        echo "false"
    else
        echo "I: Command '$1' is Installed." >/dev/tty
        echo "I: Command '$1' is Installed." >>$LOG_FILE
        echo "true"
    fi
}

function split() {
    IFS="$2"
    read -ra ADDR <<<"$1"
    echo ${ADDR[@]}
    unset IFS
}

function partition_disks() {
    echo "I: Partitioning Disks for Merger-Snapraid" |& tee -a $LOG_FILE
    currBootDiskPart=$(
        eval $(lsblk -oMOUNTPOINT,PKNAME -P | grep 'MOUNTPOINT="/"')
        echo $PKNAME
    )
    currBootDisk=$(echo $currBootDiskPart | sed 's/[0-9]*$//')
    currBootDiskPath=/dev/$currBootDisk
    curridracVFlash=$(
        eval $(lsblk -oNAME,MODEL -P | grep "Virtual_Flash")
        echo $NAME
    )

    set +e
    if [ -z "$curridracVFlash" ]; then
        disksizes=($(lsblk -d /dev/sd*[a-z] -o NAME -b -x SIZE | grep -v "$currBootDisk"))
    else
        echo "I: Current Virtual Flash Disk is '$curridracVFlash'" |& tee -a $LOG_FILE
        disksizes=($(lsblk -d /dev/sd*[a-z] -o NAME -b -x SIZE | grep -v "$currBootDisk\|$curridracVFlash"))
    fi
    set -e
    echo "I: Current Root Disk is '$currBootDisk'" |& tee -a $LOG_FILE
    echo "I: Current Root Disk partition is '$currBootDiskPart'" |& tee -a $LOG_FILE
    echo "I: Current Root Disk Path is '$currBootDiskPath'" |& tee -a $LOG_FILE

    let totaldisks=${#disksizes[*]}-1
    if (($NUM_PARITY_DISKS >= $totaldisks)); then
        echo "E: Number of requested parity disks is greater than or equal to total available disks! Please request Parity disks less than $totaldisks!" |& tee -a $LOG_FILE
        exit
    fi
    let numdatadisks=$totaldisks-$NUM_PARITY_DISKS
    paritydisks=("${disksizes[@]: -$NUM_PARITY_DISKS:100}")
    datadisks=("${disksizes[@]:1:$numdatadisks}")
    echo "I: There are a total of $NUM_PARITY_DISKS disks available for parity" |& tee -a $LOG_FILE
    echo "I: Parity disks are: "${paritydisks[@]}"" |& tee -a $LOG_FILE
    echo "I: There are a total of $numdatadisks disks available for data" |& tee -a $LOG_FILE
    echo "I: Data disks are: "${datadisks[@]}"" |& tee -a $LOG_FILE

    # Stop script if flag exists
    if [ "$t_value" = "true" ]; then
        echo "W: Script ending here! Remove the '-t' flag to run whole script" |& tee -a $LOG_FILE
        exit 0
    fi

    for i in "${paritydisks[@]}"; do
        local disk=/dev/$i
        block=$(lsblk $disk)
        echo "I: Boot OS is NOT installed on parity disk '$disk'. Formatting now!" |& tee -a $LOG_FILE
        parted -a optimal -s $disk mklabel gpt mkpart primary ext4 0% 100%
        sleep 2
        if [ "$d_value" = "true" ]; then echo "D: parted /dev/$i" |& tee -a $LOG_FILE; fi
        disksById[$i]=/dev/disk/by-id/$(ls -l /dev/disk/by-id/ | grep "ata" | grep "part1" | grep "$i" | tr -s ' ' | cut -d " " -f9)
        if [ "$d_value" = "true" ]; then echo "D: disksById[$i]=${disksById[$i]}" |& tee -a $LOG_FILE; fi
        strLength=$(expr length ${disksById[$i]})
        if [ "$d_value" = "true" ]; then echo "D: strLength=$strLength" |& tee -a $LOG_FILE; fi
        if (($strLength > $diskByIdLongestLine)); then
            diskByIdLongestLine=$strLength
        fi
        if [ "$d_value" = "true" ]; then echo "D: diskByIdLongestLine=$diskByIdLongestLine" |& tee -a $LOG_FILE; fi
    done
    for i in "${datadisks[@]}"; do
        local disk=/dev/$i
        block=$(lsblk $disk)
        echo "I: Boot OS is NOT installed on data disk '$disk'. Formatting now!" |& tee -a $LOG_FILE
        parted -a optimal -s $disk mklabel gpt mkpart primary ext4 0% 100%
        sleep 2
        if [ "$d_value" = "true" ]; then echo "D: parted /dev/$i" |& tee -a $LOG_FILE; fi
        disksById[$i]=/dev/disk/by-id/$(ls -l /dev/disk/by-id/ | grep "ata" | grep "part1" | grep "$i" | tr -s ' ' | cut -d " " -f9)
        if [ "$d_value" = "true" ]; then echo "D: disksById[$i]=${disksById[$i]}" |& tee -a $LOG_FILE; fi
        strLength=$(expr length ${disksById[$i]})
        if [ "$d_value" = "true" ]; then echo "D: strLength=$strLength" |& tee -a $LOG_FILE; fi
        if (($strLength > $diskByIdLongestLine)); then
            diskByIdLongestLine=$strLength
        fi
        if [ "$d_value" = "true" ]; then echo "D: diskByIdLongestLine=$diskByIdLongestLine" |& tee -a $LOG_FILE; fi
    done
}

function downloadLatestLinuxGitRelease() {
    gitReleasesURL=($(split "$1" "/"))
    downloadURL=$(curl --silent "https://api.github.com/repos/${gitReleasesURL[2]}/${gitReleasesURL[3]}/releases/latest" | grep "browser_download_url" | grep "tar.gz" | sed -E 's/.*"([^"]+)".*/\1/')

    gitFileName=($(split "$downloadURL" "/"))
    echo "I: Downloading '$downloadURL' to '$(pwd)/${gitFileName[-1]}'" >/dev/tty
    echo "I: Downloading '$downloadURL' to '$(pwd)/${gitFileName[-1]}'" >>$LOG_FILE
    wget -q $downloadURL -O ${gitFileName[-1]}
    echo ${gitFileName[-1]}
}

function uninstall() {
    echo "I: Uninstalling MergerFS and SnapRAID" |& tee -a $LOG_FILE
    # Find Old MergerFS/SnapRAID FSTAB info if any and clear it
    oldLineStart=$(awk '/Start MergerFS\/SnapRAID Config/{ print NR }' $FSTAB_CONFIG_PATH)
    oldLineEnd=$(awk '/End MergerFS\/SnapRAID Config/{ print NR }' $FSTAB_CONFIG_PATH)

    echo "I: Removing MergerFS Configurations from '$FSTAB_CONFIG_PATH'" |& tee -a $LOG_FILE
    if [ "$oldLineStart" = "" ]; then
        if grep -q mergerfs "$FSTAB_CONFIG_PATH"; then
            echo "W: MergerFS wasn't complete removed, manually remove from $FSTAB_CONFIG_PATH." |& tee -a $LOG_FILE
        fi
    else
        sed -i "$oldLineStart,${oldLineEnd}d" $FSTAB_CONFIG_PATH
    fi

    echo "I: Removing SnapRAID Configuration File '$SNAPRAID_CONFIG_PATH'" |& tee -a $LOG_FILE
    rm -rf $SNAPRAID_CONFIG_PATH

    echo "I: Uninstalling SnapRaid program" |& tee -a $LOG_FILE
    rm -rf /var/lib/snapraid
    rm -rf /usr/local/bin/snapraid
    rm -rf /usr/local/share/man/man1/snapraid*
    rm -rf /var/snapraid/
    apt autoclean snapraid -y -qq >/dev/null 2>&1

    echo "I: Removing apt repos." |& tee -a $LOG_FILE
    sed -i '/deb \[arch=amd64\] https:\/\/download.docker.com\/linux\/debian buster stable/d' /etc/apt/sources.list
    sed -i '/# deb-src \[arch=amd64\] https:\/\/download.docker.com\/linux\/debian buster stable/d' /etc/apt/sources.list
    sed -i '/deb http:\/\/ftp.us.debian.org\/debian stretch main contrib/d' /etc/apt/sources.list
    sed -i '/deb http:\/\/ftp.us.debian.org\/debian stretch contrib main/d' /etc/apt/sources.list
    sed -i '/# deb-src http:\/\/ftp.us.debian.org\/debian stretch main contrib/d' /etc/apt/sources.list

    echo "I: Uninstalling MergerFS program" |& tee -a $LOG_FILE
    apt autoremove mergerfs -y -qq >/dev/null 2>&1

    echo "I: Unmounting MergerFS Disks" |& tee -a $LOG_FILE
    mountedMFSDisks=($(df -h | (egrep "/mnt/parity*|/mnt/data*|/mnt/storage" || true) | tr -s ' ' | cut -d " " -f6))

    for i in "${mountedMFSDisks[@]}"; do
        umount $i
    done

    echo "I: Removing Mount Points" |& tee -a $LOG_FILE
    rm -rf /mnt/parity*
    rm -rf /mnt/data*
    rm -rf /mnt/storage

    echo "I: Finished removing MergerFS and SnapRAID, reboot machine!" |& tee -a $LOG_FILE
    exit 0
}

# Read Flags using getopts
# Default flag values
p_value='none'
q_value='false'
t_value='false'
d_value='false'
y_value='/var/log/'

# Set Log File
LOG_FILE=$y_value'/'$SCRIPT_NAME.log

while getopts 'tqudhy:p:' OPTION; do
    case "$OPTION" in
    t)
        t_value='true'
        ;;

    q)
        q_value='true'
        ;;

    d)
        d_value='true'
        ;;

    h)
        echo "Usage:"
        echo "$(basename $0) [-t] [-q] [-u] [-d] [-h] [-y path_to_log] [-p someinteger]"
        echo ""
        echo "Options:"
        echo "  -t              Runs the script in trial mode, shows what will happen if this flag removed"
        echo "  -q              Runs script non-interactively using defaults"
        echo "  -u              Runs the script in uninstall mode removing installed elements"
        echo "  -d              Runs the script in debug mode, very loud output"
        echo "  -h              Prints help menu, which you are currently reading"
        echo "  -y /var/log/    Path to write log file"
        echo "  -p N            Runs script non-interactively using with N parity disks"
        exit 1
        ;;

    p)
        p_value="$OPTARG"
        ;;

    y)
        y_value="$OPTARG"

        # Set Log File
        LOG_FILE=$y_value'/mergerfs_snapraid_install.log'
        echo "I: Starting new Log File" >$LOG_FILE
        ;;

    u)
        uninstall
        ;;

    ?)
        echo "Usage:"
        echo "$(basename $0) [-t] [-q] [-u] [-d] [-h] [-y path_to_log] [-p someinteger]"
        echo ""
        echo "Options:"
        echo "  -t              Runs the script in trial mode, shows what will happen if this flag removed"
        echo "  -q              Runs script non-interactively using defaults"
        echo "  -u              Runs the script in uninstall mode removing installed elements"
        echo "  -d              Runs the script in debug mode, very loud output"
        echo "  -h              Prints help menu, which you are currently reading"
        echo "  -y /var/log/    Path to write log file"
        echo "  -p N            Runs script non-interactively using with N parity disks"
        exit 1
        ;;
    esac
done
shift "$(($OPTIND - 1))"

echo "I: Starting new Log File" >$LOG_FILE

# Set number of parity disks desired for snapraid
if [ "$q_value" = "true" -a "$p_value" = "none" ]; then
    echo "I: Script running non-interactively using defaults" |& tee -a $LOG_FILE
    NUM_PARITY_DISKS=1
elif [ "$p_value" != "none" ]; then
    echo "I: Script running non-interactively using provided options" |& tee -a $LOG_FILE
    NUM_PARITY_DISKS=$p_value
else
    echo "How many parity disks would you like to configure?"
    read NUM_PARITY_DISKS
    echo "What email should alerts be sent to? You will still need to configure 'mutt' and 'msmtp'."
    read SNAPRAID_AUTOMATION_SCRIPT_EMAIL
fi
echo "I: Requested that $NUM_PARITY_DISKS parity disks be made available!" |& tee -a $LOG_FILE
echo "I: Requested that snapraid alerts be sent to '$SNAPRAID_AUTOMATION_SCRIPT_EMAIL'!" |& tee -a $LOG_FILE

# Skip pre-reqs for script if flag exists
if [ "$t_value" = "true" ]; then
    echo "I: Script running in trial mode! Remove the '-t' flag to run whole script" |& tee -a $LOG_FILE
    partition_disks
fi

# Install Docker, MergerFS and other neccesary tools
echo "I: Installing Docker, MergerFS and other neccesary tools." |& tee -a $LOG_FILE
apt-get install -y lsb-release software-properties-common -qq >/dev/null
curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add - >/dev/null 2>&1
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
add-apt-repository "deb http://ftp.us.debian.org/debian stretch main contrib"

apt-get update -qq
apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common mergerfs fuse docker-ce docker-ce-cli docker-compose containerd.io git libgconf-2-4 parted gcc make checkinstall python-markdown ssmtp -qq >/dev/null

# Confirm packages above installed
$(commandexists "mergerfs")
$(commandexists "docker")
$(commandexists "curl")
$(commandexists "parted")
$(commandexists "gcc")
$(commandexists "make")

# Format the drives
partition_disks

# Make mount locations
echo "I: Creating $NUM_PARITY_DISKS parity mounts at /mnt/parity{0-$(($NUM_PARITY_DISKS - 1))}" |& tee -a $LOG_FILE
for ((c = 0; c < $NUM_PARITY_DISKS; c++)); do
    mkdir -p /mnt/parity$c
done

echo "I: Creating $numdatadisks data mounts at /mnt/data{0-$(($numdatadisks - 1))}" |& tee -a $LOG_FILE
for ((c = 0; c < $numdatadisks; c++)); do
    mkdir -p /mnt/data$c
done
echo "I: Creating 1 pool mount at /mnt/storage" |& tee -a $LOG_FILE
mkdir -p /mnt/storage

# Find Old MergerFS/SnapRAID FSTAB info if any and clear it
oldLineStart=$(awk '/Start MergerFS\/SnapRAID Config/{ print NR }' $FSTAB_CONFIG_PATH)
oldLineEnd=$(awk '/End MergerFS\/SnapRAID Config/{ print NR }' $FSTAB_CONFIG_PATH)

if [ "$oldLineStart" = "" ]; then
    echo "I: MergerFS/SnapRAID Config does not yet exist, writing now!" |& tee -a $LOG_FILE
    if grep -q mergerfs "$FSTAB_CONFIG_PATH"; then
        echo "W: MergerFS seems to already be managing FSTAB, you may want to review and remove old mergerfs settings." |& tee -a $LOG_FILE
    fi
else
    echo "I: MergerFS/SnapRAID Config already exists, re-writing now!" |& tee -a $LOG_FILE
    sed -i "$oldLineStart,${oldLineEnd}d" $FSTAB_CONFIG_PATH
fi
echo "I: This next part will take some time while parity and data disks are formatted." |& tee -a $LOG_FILE
echo "# Start MergerFS/SnapRAID Config" >>$FSTAB_CONFIG_PATH
paddedHeader="# <file system>"
printf -v paddedHeader %-$diskByIdLongestLine.${diskByIdLongestLine}s "$paddedHeader"
echo "${paddedHeader}  <mount point>  <type> <options>                   <dump>  <pass>" >>$FSTAB_CONFIG_PATH
for ((c = 0; c < $NUM_PARITY_DISKS; c++)); do
    mkfs.ext4 -F -q /dev/${paritydisks[$c]}1 >/dev/null 2>&1
    paddedFS="${disksById[${paritydisks[$c]}]}"
    printf -v paddedFS %-$diskByIdLongestLine.${diskByIdLongestLine}s "$paddedFS"
    echo "$paddedFS  /mnt/parity$c   auto   defaults,errors=remount-ro  0       0" >>$FSTAB_CONFIG_PATH
done
for ((c = 0; c < $numdatadisks; c++)); do
    mkfs.ext4 -F -q /dev/${datadisks[$c]}1 >/dev/null 2>&1
    paddedFS="${disksById[${datadisks[$c]}]}"
    printf -v paddedFS %-$diskByIdLongestLine.${diskByIdLongestLine}s "$paddedFS"
    echo "$paddedFS  /mnt/data$c     auto   defaults,errors=remount-ro  0       0" >>$FSTAB_CONFIG_PATH
done
echo "/mnt/data*               /mnt/storage  fuse.mergerfs  direct_io,defaults,allow_other,minfreespace=50G,fsname=mergerfs  0       0" >>$FSTAB_CONFIG_PATH
echo "# End MergerFS/SnapRAID Config" >>$FSTAB_CONFIG_PATH
echo "I: Finished modifying '$FSTAB_CONFIG_PATH', attempting 'mount -a'" |& tee -a $LOG_FILE
mount -a

# Adding generic Docker user
usermod -aG docker $USER

echo "I: Creating SnapRAID Configuration File '$SNAPRAID_CONFIG_PATH'" |& tee -a $LOG_FILE
echo "# Example configuration for snapraid" >$SNAPRAID_CONFIG_PATH
echo "" >>$SNAPRAID_CONFIG_PATH
echo "# Defines the file to use as parity storage" >>$SNAPRAID_CONFIG_PATH
echo "# It must NOT be in a data disk" >>$SNAPRAID_CONFIG_PATH
echo '# Format: "parity FILE_PATH"' >>$SNAPRAID_CONFIG_PATH
for ((c = 0; c < $NUM_PARITY_DISKS; c++)); do
    echo "parity /mnt/parity$c/snapraid.parity" >>$SNAPRAID_CONFIG_PATH
done
echo "" >>$SNAPRAID_CONFIG_PATH
echo "# Defines the files to use as content list" >>$SNAPRAID_CONFIG_PATH
echo "# You can use multiple specification to store more copies" >>$SNAPRAID_CONFIG_PATH
echo "# You must have least one copy for each parity file plus one. Some more don't hurt" >>$SNAPRAID_CONFIG_PATH
echo "# They can be in the disks used for data, parity or boot," >>$SNAPRAID_CONFIG_PATH
echo "# but each file must be in a different disk" >>$SNAPRAID_CONFIG_PATH
echo '# Format: "content FILE_PATH"' >>$SNAPRAID_CONFIG_PATH
echo "content /var/snapraid/snapraid.content" >>$SNAPRAID_CONFIG_PATH
for ((c = 0; c < $numdatadisks; c++)); do
    echo "content /mnt/data$c/snapraid.content" >>$SNAPRAID_CONFIG_PATH
done
echo "" >>$SNAPRAID_CONFIG_PATH
echo "# Defines the data disks to use" >>$SNAPRAID_CONFIG_PATH
echo "# The order is relevant for parity, do not change it" >>$SNAPRAID_CONFIG_PATH
echo "# Format: 'disk DISK_NAME DISK_MOUNT_POINT'" >>$SNAPRAID_CONFIG_PATH
for ((c = 0; c < $numdatadisks; c++)); do
    echo "disk data$c /mnt/data$c" >>$SNAPRAID_CONFIG_PATH
done
echo "" >>$SNAPRAID_CONFIG_PATH
echo "# Excludes hidden files and directories (uncomment to enable)." >>$SNAPRAID_CONFIG_PATH
echo "nohidden" >>$SNAPRAID_CONFIG_PATH
echo "" >>$SNAPRAID_CONFIG_PATH
echo "# Defines files and directories to exclude" >>$SNAPRAID_CONFIG_PATH
echo "# Remember that all the paths are relative at the mount points" >>$SNAPRAID_CONFIG_PATH
echo '# Format: "exclude FILE"' >>$SNAPRAID_CONFIG_PATH
echo '# Format: "exclude DIR/"' >>$SNAPRAID_CONFIG_PATH
echo '# Format: "exclude /PATH/FILE"' >>$SNAPRAID_CONFIG_PATH
echo '# Format: "exclude /PATH/DIR/"' >>$SNAPRAID_CONFIG_PATH
echo "exclude /lost+found/" >>$SNAPRAID_CONFIG_PATH

echo "I: Installing SnapRaid..." |& tee -a $LOG_FILE
echo "I: Saving SnapRaid Automation Script to '$SNAPRAID_AUTOMATION_SCRIPT'" |& tee -a $LOG_FILE
cp $SNAPRAID_AUTOMATION_SCRIPT_SOURCE $SNAPRAID_AUTOMATION_SCRIPT
chmod +x $SNAPRAID_AUTOMATION_SCRIPT
sed -i 's/# EMAIL_ADDRESS="null"/EMAIL_ADDRESS="'"$SNAPRAID_AUTOMATION_SCRIPT_EMAIL"'"/g' $SNAPRAID_AUTOMATION_SCRIPT
rm -rf /var/lib/snapraid
rm -rf /var/snapraid/
rm -rf /usr/local/bin/snapraid
rm -rf /usr/local/share/man/man1/snapraid*
mkdir -p /var/lib/snapraid
mkdir -p /var/snapraid/
mkdir -p /usr/local/share/man/
chmod a+w /var/lib/snapraid
cd /var/lib/snapraid
fileName=$(downloadLatestLinuxGitRelease "https://github.com/amadvance/snapraid/releases")
tar -xzf $fileName
cd ${fileName%".tar.gz"}
res=$(./configure | grep "creating config.h")
if [ "$res" = "config.status: creating config.h" ]; then
    echo "I: Ready to make SnapRAID" |& tee -a $LOG_FILE
    make -j8 -s
    checkinstall -Dy >/dev/null 2>&1
    rm /var/lib/snapraid/$fileName
    snapraid sync
    echo "I: Finished installing snapraid and ran initial snapraid sync." |& tee -a $LOG_FILE
    echo "I: You will have to run the command 'snapraid sync' anytime you make changes to keep the array up to date." |& tee -a $LOG_FILE
    echo "I: If you want to automate this, add the '$SNAPRAID_AUTOMATION_SCRIPT' script to your cron jobs to automate the process." |& tee -a $LOG_FILE
    echo "I: You will need to install and configure 'mutt' to enable email alerts. Use this tutorial 'https://medium.com/@itsjefftong/mutt-gmail-59447a4bffef'." |& tee -a $LOG_FILE
    echo "I: If you ran this script in non-interactive mode, you will also need to edit the line 'EMAIL_ADDRESS="null"' in '$SNAPRAID_AUTOMATION_SCRIPT' script to send emails to your email inbox." |& tee -a $LOG_FILE
else
    echo "E: SnapRAID install failed due to config.h" |& tee -a $LOG_FILE
fi
