#!/bin/bash
########################################################################
# Description: Script to check service availability (up/running and    #
# enabled or disabled.)                                                #
# Author:      Jose Fernandes Neto, IT jfneto92@gmail.com              #
# Input:       N/A                                                     #
# Output:                                                              #
# Date:        2019-05-30                                              #
# Version:     0.1                                                     #
# Changes:                                                             #
########################################################################
scriptname=$(basename "$0")
ECHO=""

### FUNCTIONS ###

function init() {
 # check for ECHO
 ECHO="$(which echo) -e $scriptname:"
 if [[ $? != 0 ]]; then
    let FAILEDAT=$(($FAILEDAT+1))
    $PRINTF "echo is not defined in \$PATH: $PATH. "
    $PRINTF "Make sure that the path to the command is definied in \$PATH.\n"
    exit $FAILEDAT;
 fi
}

## END FUNCTIONS ##
## MAIN ##
init


### code ###

###########################################################
#
# All services from SLES12 which DO NOT have to be running
#
###########################################################

### variables ###
irq_service_status_12=$(systemctl is-enabled irqbalance)
###END variables ###
systemctl status irqbalance > /dev/null 2>&1
if [[ $? -eq 0 || $irq_service_status_12 == enabled ]]
then
   echo "OS;irqbalance Service disabled;SLES12:systemctl status irqbalance;NOT OK;Service is either running or enabled - PLEASE CHECK!"
   $ECHO "IRQ Service: " "\e[31mNOT OK\e[0m. Please verify!"
   code01=1
else
   echo "OS;irqbalance Service disabled;SLES12:systemctl status irqbalance;OK;Service is disabled and stopped"
   $ECHO "IRQ Service: " "\e[32mOK\e[0m (service disabled and stopped)"
   code01=0
fi


####################################################
#
# All services from SLES12 which have to be running
#
####################################################

### variables ###
sysstat_service_status_12=$(systemctl is-enabled sysstat)
### END variables ###
systemctl status sysstat > /dev/null 2>&1
if [[ $? -eq 0 && $sysstat_service_status_12 == enabled ]]
then
   echo "OS;sysstat enabled;SLES12:systemctl status sysstat;OK;Service is up/running and enabled on the system boot"
   $ECHO "Service sysstat: " "\e[32mOK\e[0m (service up/running and enabled)"
   code03=0
else
   echo "OS;sysstat enabled;SLES12:systemctl status sysstat;NOT OK;Service is stopped and/or disabled on the system boot - PLEASE CHECK!"
   $ECHO "Service sysstat: " "\e[31mNOT OK\e[0m. Please verify!"
   code03=1
fi

#######
### variables ###
puppet_service_status_12=$(systemctl is-enabled puppet)
### END variables ###
systemctl status puppet > /dev/null 2>&1
if [[ $? -eq 0 && $puppet_service_status_12 == enabled ]]
then
   echo "OS;puppet agent service;systemctl status puppet;OK;Service is up/running and enabled on the system boot"
   $ECHO "Service Puppet: " "\e[32mOK\e[0m (service up/running and enabled)"
   code04=0
else
   echo "OS;puppet agent service;systemctl status puppet;NOT OK;Service is stopped and/or disabled on the system boot - PLEASE CHECK!"
   $ECHO "Service Puppet: " "\e[31mNOT OK\e[0m. Please verify!"
   code04=1
fi

#############
### variables ###
ganglia_service_status_12=$(systemctl is-enabled gmond.service)
### END variables ###
systemctl status gmond.service > /dev/null 2>&1
if [[ $? -eq 0 && $ganglia_service_status_12 == enabled ]]
then
   echo "OS;ganglia service running;SLES12:systemctl status gmond.service;OK;Service is up/running and enabled on the system boot"
   $ECHO "Service Ganglia: " "\e[32mOK\e[0m (service up/running and enabled)"
   code05=0
else
   echo "OS;ganglia service running;SLES12:systemctl status gmond.service;NOT OK;Service is stopped and/or disabled on the system boot - PLEASE CHECK!"
   $ECHO "Service Ganglia: " "\e[31mNOT OK\e[0m. Please verify!"
   code05=1
fi

#############
### variables ###
ntp_service_status_12=$(systemctl is-enabled ntpd)
### END variables ###
systemctl status ntpd > /dev/null 2>&1
if [[ $? -eq 0 && $ntp_service_status_12 == enabled ]]
then
   echo "OS;ntp configuration;systemctl status ntpd;OK;Service is up/running and enabled on the system boot"
   $ECHO "Service NTP: " "\e[32mOK\e[0m (service up/running and enabled)"
   code06=0
else
   echo "OS;ntp configuration;systemctl status ntpd;NOT OK;Service is stopped and/or disabled on the system boot - PLEASE CHECK!"
   $ECHO  "Service NTP: " "\e[31mNOT OK\e[0m. Please verify!"
   code06=1
fi

#############
### variables ###
udev_service_status_12=$(systemctl is-enabled systemd-udevd)
### END variables ###
systemctl status systemd-udevd > /dev/null 2>&1
if [[ $? -eq 0 ]]
then
   echo "OS;udev service running;systemctl status systemd-udevd;OK;Service is up/running and enabled on the system boot"
   $ECHO "Service UDEV: " "\e[32mOK\e[0m (service up and running)"
   code07=0
else
   echo "OS;udev service running;systemctl status systemd-udevd;NOT OK;Service is stopped and/or disabled on the system boot - PLEASE CHECK!"
   $ECHO "Service UDEV: " "\e[31mNOT OK\e[0m. Please verify!"
   code07=1
fi

#############
### variables ###
automic_service_status_12=$(chkconfig -A | grep "automic" | awk {'print $2'})
### END variables ###
systemctl status automic > /dev/null 2>&1
if [[ $? -eq 0 && $automic_service_status_12 == on ]]
then
   echo "OS;UC4 Agent;systemctl status automic;OK;Service is up/running and enabled on the system boot"
   $ECHO "UC4: " "\e[32mOK\e[0m (service up/running and enabled)"
   code08=0
else
   echo "OS;UC4 Agent;systemctl status automic;NOT OK;Service is stopped and/or disabled on the system boot - PLEASE CHECK!"
   $ECHO "UC4: " "\e[31mNOT OK\e[0m. Please verify!"
   code08=1
fi

#####

# getting all the script output and making sure the right return code is there.
if [[ $code01 -eq 0 && $code02 -eq 0 && $code03 -eq 0 && $code04 -eq 0 && $code05 -eq 0 && $code06 -eq 0 && $code07 -eq 0 && $code08 -eq 0 ]]
then
        exit 0;
else
        exit 1;
fi


### END code ###