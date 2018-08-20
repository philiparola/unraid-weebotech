#!/bin/bash 

export OMIT=0

[ ${DEBUG:=0} -gt 0 ] && set -x -v

declare -a DRIVES MODELS CHOICE
typeset -x DRIVES MODELS CHOICE CMDS

TMPFILE="/tmp/identify_drive.$$"

trap "rm -f ${TMPFILE}" EXIT HUP INT QUIT TERM

CMDS="quit"

# --------------------------------------------------------------------- #
# Function    : LOAD_DRIVES                                             #
# Description : Reads directory with ls parses and stores into array.   #
#               used later to retreive drive for printing details       #
# Parameters  : Nothing                                                 #
# Returns     : Nothing                                                 #
# Environment : DRIVES array, MODELS array                              #
# --------------------------------------------------------------------- #
load_drives()
{
    ls -l /dev/disk/by-id/ | egrep 'ata\-' > ${TMPFILE}

    # rwxrwxrwx 1 root root  9 Apr 20 08:04 ata-Hitachi_HTS722020K9SA00_071007DP0400DTG101HA -> ../../sdf
    # lrwxrwxrwx 1 root root 10 Apr 20 08:04 ata-Hitachi_HTS722020K9SA00_071007DP0400DTG101HA-part1 -> ../../sdf1
    # I know it's inefficient.
    # but piping mount into loop creates a subprocess
    # whereby the export inside the loop never gets
    # back to the parent.

    i=0
    while read PERMS LINKS OWNER GROUP XX MONTH DD HHMM MODEL LINKER DEV
    do
        # ${parameter:offset:length}
        NAME=${DEV:6:4}                 # Save Whole Drive
        DEV=${DEV:6:3}                  # Remove Partition #
        if [ ${DEV} != ${NAME} ]; then continue; fi
        for OMODEL in ${OMIT_MODELS[*]}
        do  length=${#OMODEL}
            if [ ${MODEL:0:$length} = ${OMODEL} ];then OMIT=1;fi
        done
        if [ ${OMIT:=0} -gt 0 ]
           then OMIT=0
                continue
        fi
        DRIVES[$i]="/dev/${DEV}"
        MODELS[$i]="${MODEL}"
        CHOICE[$i]="/dev/${DEV} ${MODEL}"
        ((i++))
    done  < ${TMPFILE}

    rm -f ${TMPFILE}

}


present_drives()
{
    PS3="identify> "
    select DRIVE in "${CHOICE[@]}" ${CMDS}
    do
        echo "DRIVE: $DRIVE, REPLY: ${REPLY}"
        if [ -z "${DRIVE}" -a ! -z "${REPLY}" ]
           then DRIVE="${REPLY}"
        fi
        if [ -z "${DRIVE}" ]
           then return
        fi
        case "${DRIVE}" in
        q*|Q* )  exit;;
        e*|e* )  exit;;
        *     )  set ${DRIVE}; identify $@; return;;
        esac
   done
}



identify()
{

  ID=$1
  [ ! -z "${2}" ] && ID="$ID ($2)"

  echo -e "Reading ${ID}"
  while ! read -n1 -t1
  do
    echo -e "\r\007press ANY key to stop: [+]: \c"
    dd if=$1 of=/dev/null bs=1025K count=10   skip=${SKIP} 2>/dev/null 
    read -n1 -t1 && break
    ((SKIP=SKIP+1000))

    echo -e "\r\007press ANY key to stop: [x]: \c"
    dd if=$1 of=/dev/null bs=1025K count=10   skip=${SKIP} 2>/dev/null
    read -n1 -t1 && break
    ((SKIP=SKIP+1000))

    echo -e "\r\007press ANY key to stop: [-]: \c"
    dd if=$1 of=/dev/null bs=1025K count=100  skip=${SKIP} 2>/dev/null
    # sleep 1
    ((SKIP=SKIP+10000))
  done
  echo -e "\nDone."
}


if [ ! -z "${1}" ]
   then identify $1
        exit
fi

while true
do load_drives 
   present_drives
done
