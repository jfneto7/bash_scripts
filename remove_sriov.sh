#!/bin/bash
########################################################################
# Description: Script created by Jose Fernandes Neto, aiming to        #
# remove an SRIOV adapter of a given LPAR.                             #
# Author:      jfneto, IT jfneto92@gmail.com                           #
# Input:       You have to enter the script and the host you want to   #
#              remove the SRIOV adapter of.                            #
# Output:      Remove SRIOV adapter of an LPAR                         #
# Date:        2020-12-16                                              #
# Version:     1.0                                                     #
# Changes:                                                             #
########################################################################

# Making sure this script's running from EMS ems-server1 or ems-server2
if [[ $HOSTNAME != ems-server1 ]] && [[ $HOSTNAME != ems-server2 ]]
then
echo "Please run this script either from EMS ems-server1 or in ems-server2."
exit 2;
fi

### variables ###
host=$1
hmclist="hmc1.server.com
hmc2.server.com
hmc3.server.com
hmc4.server.com
hmc5.server.com
hmc6.server.com "
datetime=$(date '+%d.%m.%y_%H.%M.%S')
FILE="/repo/project/CaP/jfneto/log/SRIOV_adapters_${datetime}.out"
script_name=$(basename "$0")
version="1.0"
### END variables ###

## USAGE + getopts section ## =D
usage() {
  echo -n "${script_name} <LPAR>

It removes an SRIOV adapter (one at a time) from an specific LPAR.
Execute this one from EMS rb3i0001 or rb3i1001m
 ${bold}Options:${reset}
  -h, --help        Display this help and exit
  -v, --version     Output version information and exit
"
}

while [[ $1 = -?* ]]; do
  case $1 in
    -h|--help) usage >&2 ;exit 0;;
    -v|--version) echo "$script_name version: ${version}"; exit 0;;
    --endopts) shift; break ;;
    *) echo "Invalid option: '$1'." ; exit 1;;
  esac
  shift
done

# Script has to be executed followed by a host as parameter
if [[ -z $1 ]]
then
usage
exit 1
fi

### Code ###
# Finding frame and lpar in our stack
for hmc in $hmclist
do
  frame=$(ssh hscroot@$hmc 'lssyscfg -r sys -F name | \
  while read FRAME
  do
    echo
    lssyscfg -r lpar -m "${FRAME}" -F name | \
    while read SERVER
    do
      echo "FRAME:$FRAME: - LPAR: $SERVER"
      done
  done | grep '$host'| cut -d ":" -f2')
  if [[ ! -z $frame ]]
  then
    ssh -q hscroot@$hmc lshwres -r sriov --rsubtype logport -m $frame --level eth -F lpar_name,location_code,adapter_id,logical_port_id| grep $host > $FILE
    cat $FILE| awk -F "," {'print$2'}

    # check if machine has SRIOV adapter attached to it.
    if [ ! -s $FILE ]
    then
      echo "NO SRIOV attached in this LPAR."
      exit 4;
    fi

    echo -n "Enter the sriov adapter want to remove: "
    read rem_sriov_adapter

# Checking if selected SRIOV adapter is valid
    grep -w $rem_sriov_adapter $FILE > /dev/null 2>&1
    if [[ $? -ne 0 ]]
    then
       echo "[!]SRIOV not valid. Exiting..."
       exit 1;

    adapter_id=$(cat $FILE| grep $rem_sriov_adapter| cut -d "," -f3)
    logical_port_id=$(cat $FILE| grep $rem_sriov_adapter| cut -d "," -f4)

  #Confirmation that it can be removed
  echo -n "Are you sure you want to remove $rem_sriov_adapter from $host? [yes/no]: "
  read confirmation
  if [[ $confirmation == yes ]]
  then
  echo "Removing SRIOV: "$rem_sriov_adapter "from lpar: "$host
  ssh -q hscroot@$hmc chhwres -r sriov -m $frame --rsubtype logport -o r -p $host -a adapter_id=$adapter_id,logical_port_id=$logical_port_id
    exit 0
  elif [[ $confirmation == no ]]
  then
  echo "Not removing SRIOV adapter. Exiting..."
  exit 3
  else
  echo "Type only 'yes' or 'no'"
  fi
  fi
done
### END Code ###