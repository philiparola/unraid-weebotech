#!/bin/bash

[ ${DEBUG:=0} -gt 0 ] && set -x -v

P=${0##*/}              # basename of program
R=${0%%$P}              # dirname of program
P=${P%.*}               # strip off after last . character

bs=${bs:=1024}
count=${count:=1024000}
parallel=${parallel:=no}

if [ -z "${1}" ]
   then echo "Usage: $0 a b c d"
        echo "       a b c d is single drive letter character to test. (no limit)."
	echo "Options:"
        echo " "
	echo "parallel=yes bs=${bs} count=${count}"
        echo " Where parallel is optional to run tests simultaneously in background"
        echo " bs=blocksize, count=count of blocks to read."
	echo " total size = bs*count"
	echo " "
	echo "Example:"
	echo " parallel=yes $0 a b c d"
	echo " parallel=yes bs=${bs} count=${count} $0 a b c d"
        echo " "
        echo "Defaults: "
        echo " No tests are run by default"
        echo " Parallel=${parallel} bs=${bs} count=${count}"
	echo " "
        fdisk -l 2>/dev/null | grep 'Disk /'
        exit
fi

if [ "${1}" = "parallel" ]
   then parallel=yes
        shift
fi

for i in $*
do
    if [[ "${parallel}" = "yes" ]] ; then
        echo "hdparm /dev/sd${i}" `hdparm -i /dev/sd${i} 2>/dev/null | sed -n "/Model=/s/,.*$//p" | sed -n "s/Model=//p"` `hdparm -t --direct /dev/sd${i} | sed -n "s/^.*= / = /p"` > /tmp/${P}.${$}_${i} &
    else
        echo "hdparm /dev/sd${i}" `hdparm -i /dev/sd${i} 2>/dev/null | sed -n "/Model=/s/,.*$//p" | sed -n "s/Model=//p"` `hdparm -t --direct /dev/sd${i} | sed -n "s/^.*= / = /p"`
    fi
done

wait 
for i in $*
do [ ! -f /tmp/${P}.${$}_${i} ] && continue
   cat /tmp/${P}.${$}_${i}
   rm  /tmp/${P}.${$}_${i}
done

for i in $*
do
    if [[ "${parallel}" = "yes" ]] ; then
        # echo "Spawning Background Parallel DD Read: /dev/sd${i}: "
	dd of=/dev/null bs=2048 count=1024000 if=/dev/sd${i} > /tmp/${P}.${$}_${i} 2>&1 &
    else
        echo -e "dd     /dev/sd${i} = \c"
	dd of=/dev/null bs=2048 count=1024000 if=/dev/sd${i} > /tmp/${P}.${$}_${i} 2>&1
	grep -i copied  /tmp/${P}.${$}_${i}
        rm -f           /tmp/${P}.${$}_${i}
    fi
done

wait

for i in $*
do [ ! -f  /tmp/${P}.${$}_${i} ] && continue
    echo -e "dd     /dev/sd${i} = \c"
    grep -i copied /tmp/${P}.${$}_${i}
    rm             /tmp/${P}.${$}_${i}
done
