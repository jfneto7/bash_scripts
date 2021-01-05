#!/bin/bash
########################################################################
# Description: Script created by Jose Fernandes Neto, aiming to        #
# check the bootlist if there are 4 entries and diskaccess and paths   #
# are properly setup.                                                  #
# Author:      jfneto, IT jfneto92@gmail.com                           #
# Input:       N/A. Run local in the LPAR                              #
# Output:      'OK' or 'NOT OK' message                                #
# Date:        2020-06-29                                              #
# Version:     0.1                                                     #
# Changes:                                                             #
########################################################################


### variables ###
OK=0
CRITICAL=1

#Checking if 'multipath' is an existing command
which /sbin/multipath > /dev/null 2>&1
if [ $? -ne 0 ]
then
echo "Command multipath does not exist."
exit $CRITICAL;
fi

#Checking if 'bootlist' is an existing command
which /usr/sbin/bootlist > /dev/null 2>&1
if [ $? -ne 0 ]
then
echo "Command bootlist does not exist."
exit $CRITICAL;
fi

bootlist=$(/usr/sbin/bootlist -m normal -o )
bootlist_amount=$(/usr/sbin/bootlist -m normal -o|grep ^[a-z]|wc -w )
array_group=()

### code ###

#Making sure there are 4 boot disks
if [[ $bootlist_amount -ne 4 ]]
then
echo "NOT OK - This server has "$bootlist_amount "boot disk(s)."
exit $CRITICAL
fi

function execute(){
for disk in $bootlist;do
array_group[0]+=`/sbin/multipath -ll|grep [0-9].[0-9].[0-9].[0-9]| grep $disk| awk -F ":" {'print $3'}`
done

#Checking multipath access path order (failover purpose)
if [[ ${array_group[@]} == 5544 ]] || [[ ${array_group[@]} == 4455 ]] || [[ ${array_group[@]} == 5454 ]] || [[ ${array_group[@]} == 4545 ]] || [[ ${array_group[@]} == 0011 ]] || [[ ${array_group[@]} == 1100 ]] || [[ ${array_group[@]} == 0101 ]] || [[ ${array_group[@]} == 1010 ]]
then
echo "OK"
exit $OK
else
echo "NOT OK - Check BOOTLIST disk order"
exit $CRITICAL
fi
}

execute

### END code ###