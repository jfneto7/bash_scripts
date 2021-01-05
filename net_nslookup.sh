#!/bin/bash
########################################################################
# Description: Script ensures the DNS entry for each LAN               #
# Author:      Jose Fernandes Neto, IT jfneto92@gmail.com              #
# Input:       N/A                                                     #
# Output:      nslookuping each LAN and FQDN on the LPAR               #
# Date:        2019-05-30                                              #
# Version:     0.2                                                     #
# Changes:     2020.06.22 improved the output to check which one is    #
# "NOT OK" or 'failed' to resolv the name or IP. (nej8ca)              #
########################################################################

### variables ###
## COMMANDS ##
ECHO=""
GREP=""
AWK=""
SED=""
CUT=""
IP=""
PRINTF=""
NSLOOKUP=""
## END COMMANDS ##

## OTHERS ##
FAILEDAT=""
script_name=$(basename "$0")
version="0.2"
declare -a array_hostname
failed=()
counter=0 #counter for array_hostname
counter_failed=0 #counter for the 'failed' array
## END OTHERS ##
### END variables ###

## FUNCTIONS ##
function init() {

# check for ECHO
 ECHO="$(which echo) -e $script_name:"
 if [[ $? != 0 ]]; then
    let FAILEDAT=$(($FAILEDAT+1))
    $PRINTF "echo is not defined in \$PATH: $PATH. "
    $PRINTF "Make sure that the path to the command is definied in \$PATH.\n"
    exit $FAILEDAT;
 fi

# check for GREP
 GREP=$(which grep)
 if [[ $? != 0 ]]; then
    let FAILEDAT=$(($FAILEDAT+1))
    $PRINTF "grep is not defined in \$PATH: $PATH. "
    $PRINTF "Make sure that the path to the command is definied in \$PATH.\n"
 fi
# check for AWK
 AWK=$(which awk)
 if [[ $? != 0 ]]; then
    let FAILEDAT=$(($FAILEDAT+1))
    $PRINTF "awk is not defined in \$PATH: $PATH. "
    $PRINTF "Make sure that the path to the command is definied in \$PATH.\n"
 fi
# check for SED
 SED=$(which sed)
 if [[ $? != 0 ]]; then
    let FAILEDAT=$(($FAILEDAT+1))
    $PRINTF "sed is not defined in \$PATH: $PATH. "
    $PRINTF "Make sure that the path to the command is definied in \$PATH.\n"
 fi
# check for CUT
 CUT=$(which cut)
 if [[ $? != 0 ]]; then
    let FAILEDAT=$(($FAILEDAT+1))
    $PRINTF "cut is not defined in \$PATH: $PATH. "
    $PRINTF "Make sure that the path to the command is definied in \$PATH.\n"
 fi
# check for IP
 IP=$(which ip)
 if [[ $? != 0 ]]; then
    let FAILEDAT=$(($FAILEDAT+1))
    $PRINTF "ip is not defined in \$PATH: $PATH. "
    $PRINTF "Make sure that the path to the command is definied in \$PATH.\n"
 fi
# check for PRINTF
 PRINTF=$(which printf)
 if [[ $? != 0 ]]; then
    let FAILEDAT=$(($FAILEDAT+1))
    $PRINTF "printf is not defined in \$PATH: $PATH. "
    $PRINTF "Make sure that the path to the command is definied in \$PATH.\n"
 fi
# check for NSLOOKUP
 NSLOOKUP=$(which nslookup)
 if [[ $? != 0 ]]; then
    let FAILEDAT=$(($FAILEDAT+1))
    $PRINTF "nslookup is not defined in \$PATH: $PATH. "
    $PRINTF "Make sure that the path to the command is definied in \$PATH.\n"
 fi
}
## MAIN ##
init
## END FUNCTIONS ##

### HELP SECTION ###
usage() {
  $PRINTF "${script_name}\n This script ensures the DNS entry for each LAN.
 ${bold}Options:${reset}
  -h, --help        Display this help and exit
  -v, --version     Output version information and exit
"
}
while [[ $1 = -?* ]]; do
  case $1 in
    -h|--help) usage >&2 ;exit 0;;
    -v|--version) $PRINTF "$script_name ${version}\n"; exit 0;;
    --endopts) shift; break ;;
    *) $PRINTF "Invalid option: '$1'.\n" ; exit 1;;
  esac
  shift
done
### END OF HELP SECTION ###


ip=$($IP a | $GREP "inet 10." | $AWK {'print $2'} | $SED 's/\/22//')
sid=$($GREP '/hana/data/' /etc/fstab | $AWK '{print $2}' | $CUT -d '/' -f4)

### code ###
# "NSLOOKUP IP"
for i in $ip;
         do
                $NSLOOKUP $i > /dev/null 2>&1 #nslookuping each and every LAN IP
                return_ip=$?
                if [[ $return_ip -ne 0 ]]
                then
                        failed[$counter_failed]+=$i" "
                        let counter_failed=counter_failed+1
                fi
                array_hostname[$counter]+=`$NSLOOKUP $i| $GREP "name =" | $CUT -d "=" -f2| $SED 's/.$//'` #inserting each FQDN into the array
                let counter=counter+1
done;


# "NSLOOKUP FQDN"

for j in ${array_hostname[*]};
        do
                $NSLOOKUP $j > /dev/null 2>&1 #nslookuping each and every FQDN
                return_fqdn=$?
                if [[ $return_fqdn -ne 0 ]]
                then
                        failed[$counter_failed]+=$i" "
                        let counter_failed=counter_failed+1
                fi
done;
$NSLOOKUP "server"$sid"h0" > /dev/null 2>&1
return_cname=$?
if [[ $return_cname -ne 0 ]]
then
failed[$counter_failed]+="CNAME: "server"$sid"h0""
fi

if [[ -z "${failed[@]}" ]]
then
        $ECHO "Network;DNS entry: ALL LANs; nslookup <IP>, nslookup <Hostname>;OK;All IPs and DNS are being resolved. For all LANs"
        $ECHO "NSLOOKUP: \e[32mOK\e[0m"
        exit 0;
else
        $ECHO "Network;DNS entry: FALL LANs;nslookup <IP>, nslookup <Hostname>;NOT OK;Names or IPs cannot be resolved - ${failed[@]} - PLEASE CHECK!"
        $ECHO "NSLOOKUP: \e[31mNOT OK\e[0m - ${failed[@]}"
        exit 1;
fi

### END code ###