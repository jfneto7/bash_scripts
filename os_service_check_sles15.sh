#!/bin/bash
########################################################################
# Description: Script to check service status for SLES 15 OS version   #
# (up/running and enabled or disabled.)                                #
# Author:      Jose Fernandes Neto, IT jfneto92@gmail.com              #
# Date:        2019-05-30                                              #
# Version:     2.0                                                     #
# Changes: 2020-05-06 v2.0 - Script changed to work on SLES 15         #
########################################################################

## Variables ###
### Commands ###
ECHO=""
PRINTF=""
### End commands ###
## OTHERS ##
script_name=$(basename "$0")
## END OTHERS
### FUNCTIONS ###
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
 PRINTF="$(which printf)"
 if [[ $? != 0 ]]; then
    let FAILEDAT=$(($FAILEDAT+1))
    $PRINTF "printf is not defined in \$PATH: $PATH. "
    $PRINTF "Make sure that the path to the command is definied in \$PATH.\n"
    exit $FAILEDAT;
 fi
}
## END FUNCTIONS ##
## MAIN ##
init


### code ###

####################################################
#
# All services from SLES15 which have to be running
#
####################################################

function irqbalance15 (){
### variables ###
irq_service_status_15=$(systemctl is-enabled irqbalance)
###END variables ###
        systemctl status irqbalance > /dev/null 2>&1
        
        if [[ $? -eq 0 || $irq_service_status_15 == enabled ]]
        then
                $ECHO "OS;irqbalance Service enabled;SLES15:systemctl status irqbalance;OK;Service is enable and running!"
                $ECHO "IRQ Service: " "\e[32mOK\e[0m. Service enable!"
                code01=0
        else
                $ECHO "OS;irqbalance Service disabled;SLES15:systemctl status irqbalance;NOT OK;Service is disabled - PLEASE CHECK!"
                $ECHO "IRQ Service: " "\e[32mNOT OK\e[0m. Please verify!"
                code01=1
        fi
}

function systat15 (){
### variables ###
sysstat_service_status_15=$(systemctl is-enabled sysstat)
### END variables ###
        systemctl status sysstat > /dev/null 2>&1
        
        if [[ $? -eq 0 && $sysstat_service_status_15 == enabled ]]
        then
                $ECHO "OS;sysstat enabled;SLES15:systemctl status sysstat;OK;Service is up/running and enabled on the system boot"
                $ECHO "Service sysstat: " "\e[32mOK\e[0m (service up/running and enabled)"
                code02=0
        else
                $ECHO "OS;sysstat enabled;SLES15:systemctl status sysstat;NOT OK;Service is stopped and/or disabled on the system boot - PLEASE CHECK!"
                $ECHO "Service sysstat: " "\e[31mNOT OK\e[0m. Please verify!"
                code02=1
        fi
}

#######
function puppet15 (){
### variables ###
puppet_service_status_15=$(systemctl is-enabled puppet)
### END variables ###
        systemctl status puppet > /dev/null 2>&1
        
        if [[ $? -eq 0 && $puppet_service_status_15 == enabled ]]
        then
                $ECHO "OS;puppet agent service;systemctl status puppet;OK;Service is up/running and enabled on the system boot"
                $ECHO "Service Puppet: " "\e[32mOK\e[0m (service up/running and enabled)"
                code03=0
        else
                $ECHO "OS;puppet agent service;systemctl status puppet;NOT OK;Service is stopped and/or disabled on the system boot - PLEASE CHECK!"
                $ECHO "Service Puppet: " "\e[31mNOT OK\e[0m. Please verify!"
                code03=1
        fi
}
#########
function njmon15 (){
### variables ###
njmon_service_status_15=$(systemctl is-enabled njmon)
### END variables ###
        systemctl status njmon.service > /dev/null 2>&1
        
        if [[ $? -eq 0 && $njmon_service_status_15 == enabled ]]
        then
                $ECHO "OS;Njmon service running;SLES15:systemctl status njmon.service;OK;Service is up/running and enabled on the system boot"
                $ECHO "Service Njmon: " "\e[32mOK\e[0m (service up/running and enabled)"
                code04=0
        else
                $ECHO "OS;Njmon service running;SLES15:systemctl status njmon.service;NOT OK;Service is stopped and/or disabled on the system boot - PLEASE CHECK!"
                $ECHO "Service Njmon: " "\e[31mNOT OK\e[0m. Please verify!"
                code04=1
        fi
}
#############
function chrony15 (){
### variables ###
chrony_service_status_15=$(systemctl is-enabled chronyd)
### END variables ###
        systemctl status chronyd.service > /dev/null 2>&1
        
        if [[ $? -eq 0 && $chrony_service_status_15 == enabled ]]
        then
                $ECHO "OS;Chrony configuration;systemctl status chronyd.service;OK;Service is up/running and enabled on the system boot"
                $ECHO "Service Chrony: " "\e[32mOK\e[0m (service up/running and enabled)"
                code05=0
        else
                $ECHO "OS;Chrony configuration;systemctl status chronyd.service;NOT OK;Service is stopped and/or disabled on the system boot - PLEASE CHECK!"
                $ECHO "Service Chrony: " "\e[31mNOT OK\e[0m. Please verify!"
                code05=1
        fi
}
#############
function udev15 (){
### variables ###
udev_service_status_15=$(systemctl is-enabled systemd-udevd)
### END variables ###
        systemctl status systemd-udevd > /dev/null 2>&1

        if [[ $? -eq 0 ]]
        then
                $ECHO "OS;udev service running;systemctl status systemd-udevd;OK;Service is up/running and enabled on the system boot"
                $ECHO "Service UDEV: " "\e[32mOK\e[0m (service up and running)"
                code06=0
        else
                $ECHO "OS;udev service running;systemctl status systemd-udevd;NOT OK;Service is stopped and/or disabled on the system boot - PLEASE CHECK!"
                $ECHO "Service UDEV: " "\e[31mNOT OK\e[0m. Please verify!"
                code06=1
        fi
}

function automic15 (){
### variables ###
automic_service_status_15=$(chkconfig -A | grep "automic" | awk {'print $2'})
### END variables ###
        systemctl status automic > /dev/null 2>&1
        if [[ $? -eq 0 && $automic_service_status_15 == on ]]
        then
                $ECHO "OS;UC4 Agent;systemctl status automic;OK;Service is up/running and enabled on the system boot"
                $ECHO "UC4: " "\e[32mOK\e[0m (service up/running and enabled)"
                code07=0
        else
                $ECHO "OS;UC4 Agent;systemctl status automic;NOT OK;Service is stopped and/or disabled on the system boot - PLEASE CHECK!"
                $ECHO "UC4: " "\e[31mNOT OK\e[0m. Please verify!"
                code07=1
        fi
}

##################################################
#
# Checking the services' status
#
##################################################
irqbalance15 $host
systat15 $host
puppet15 $host
njmon15 $host
chrony15 $host
udev15 $host
automic15 $host

# getting all the script output and making sure the right return code is there.
if [[ $code01 -eq 0 && $code02 -eq 0 && $code03 -eq 0 && $code04 -eq 0 && $code05 -eq 0 && $code06 -eq 0 && $code07 -eq 0 ]]
then
        exit 0;
else
        exit 1;
fi


### END code ###