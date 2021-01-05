#!/bin/bash
#####################################################################
# Description: Script created by Jose Fernandes Neto, aiming to arp #
# each bond (and eth) device to its corresponding gateway.          #
# Author:    jfneto, IT jfneto92@gmail.com                          #
# Date: 2019-05-27                                                  #
# Version: 0.3                                                      #
# Changes: 2020-05-06 - Script changed to work on SLES 15 [ple8ca]  #
#         [07.07.2020] - changed the "not ok" output to show which  #
# interface and ip failed to arping. [nej8ca]
#####################################################################

### variables ###
### COMMANDS ###
ECHO=""
PRINTF=""
ARPING=""
### END COMMANDS ###
### OTHERS###
script_name=$(basename $0)
version="0.3"
FAILEDAT=""
array_bond=()
array_gateway=()
bondcounter=0
gwcounter=0
arpcounter=0
arping_failed=()
failed_return=()
return_counter=0

### END variables ###

function init() {
# check for ECHO
 ECHO="$(which echo) -e $script_name:"
 if [[ $? != 0 ]]; then
    let FAILEDAT=$(($FAILEDAT+1))
    $PRINTF "echo is not defined in \$PATH: $PATH. "
    $PRINTF "Make sure that the path to the command is definied in \$PATH.\n"
    exit $FAILEDAT;
 fi

# check for PRINTF
 PRINTF=$(which printf)
 if [[ $? != 0 ]]; then
    let FAILEDAT=$(($FAILEDAT+1))
    $PRINTF "printf is not defined in \$PATH: $PATH. "
    $PRINTF "Make sure that the path to the command is definied in \$PATH.\n"
    exit $FAILEDAT;
 fi

# check for ARPING
 ARPING=$(which arping)
 if [[ $? != 0 ]]; then
    let FAILEDAT=$(($FAILEDAT+1))
    $PRINTF "arping is not defined in \$PATH: $PATH. "
    $PRINTF "Make sure that the path to the command is definied in \$PATH.\n"
    exit $FAILEDAT;
 fi

}
### END FUNCTIONS ###
## MAIN ##
init
## END MAIN ##

sriov_adapter=$(lspci | grep -i ethernet | wc -l) # number of SRIOV adapter
varbond=$(ip route show | grep -e eth -e bond | grep -E "^10." | awk '{print $3}')
vargateway=$(ip route show | grep -e eth -e bond | grep -E "^10."| awk {'print $1'}| sed 's/\.[0-9]\/22*$/.1/')


### code ###
if [[ $sriov_adapter -eq 0 ]]
then
        $ECHO "Network;ARPING all Intefaces to their network;arping -I <interface> <arptarget>;NA;No SRIOV adapter were found"
        $ECHO "ARPING: \e[32m Not required\e[0m - No SRIOV adapter were found."
        exit 0;
else

# putting the bonds into an array
for i in $varbond;
        do
                array_bond[$bondcounter]+=$i
                let bondcounter=bondcounter+1
done;
#putting the gateways into an array
for j in $vargateway;
         do
                 array_gateway[$gwcounter]+=$j
                 let gwcounter=gwcounter+1
done;
# arping each bond and its corresponding gateway
for k in ${array_bond[*]};
        do
                $ARPING -c 1 -I ${array_bond[$arpcounter]} ${array_gateway[$arpcounter]} > /dev/null 2>&1
                result_code=$?
                if [ $result_code -ne 0 ]
                then
                        failed_return[$return_counter]+=$result_code
                        arping_failed[$return_counter]+="${array_bond[$arpcounter]} ${array_gateway[$arpcounter]}"
                        let return_counter=return_counter+1
                fi
                let arpcounter=arpcounter+1
done;
fi

if [[ ${failed_return[@]} =~ 1 ]]
then
        $ECHO "Network;ARPING all Intefaces to their network;arping -I <interface> <arptarget>;NOT OK;Arping failed: ${arping_failed[@]}"
        $ECHO "ARPING: \e[31mNOT OK\e[0m - ${arping_failed[@]}"
        exit 1;
else
        $ECHO "Network;ARPING all Intefaces to their network;arping -I <interface> <arptarget>;OK;All interfaces are pinging sucessfully their gateways"
        $ECHO "ARPING: \e[32mOK\e[0m"
        exit 0;
fi

### END code ###