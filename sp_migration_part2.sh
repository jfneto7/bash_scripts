#!/bin/bash

# Author: Jose Fernandes Neto 
# Contact: jfneto92@gmail.com  / linkedin.com/in/jfneto7
# Date: 18.06.2021
# Version: 1.0
# Description: Second part of the Service Pack migration activity we are going to do
# massivelly. Mainly responsible for checking everything post reboot.

### Variables ###

PUPPET=$(which puppet)
if [[ $? -ne 0 ]];then
  echo "puppet is not defined in variable PATH"
  exit 1;
fi
RPM=$(which rpm)
if [[ $? -ne 0 ]];then
  echo "rpm is not defined in variable PATH"
  exit 1;
fi
ZYPPER=$(which zypper)
if [[ $? -ne 0 ]];then
  echo "zypper is not defined in variable PATH"
  exit 1;
fi
PPC64_CPU=$(which ppc64_cpu)
if [[ $? -ne 0 ]];then
  echo "ppc64_cpu is not defined in variable PATH"
  exit 1;
fi
LS=$(which ls)
if [[ $? -ne 0 ]];then
  echo "ls is not defined in variable PATH"
  exit 1;
fi
CAT=$(which cat)
if [[ $? -ne 0 ]];then
  echo "cat is not defined in variable PATH"
  exit 1;
fi
GREP=$(which grep)
if [[ $? -ne 0 ]];then
  echo "grep is not defined in variable PATH"
  exit 1;
fi
EGREP=$(which egrep)
if [[ $? -ne 0 ]];then
  echo "egrep is not defined in variable PATH"
  exit 1;
fi
AWK=$(which awk)
if [[ $? -ne 0 ]];then
  echo "awk is not defined in variable PATH"
  exit 1;
fi
PRINTF=$(which printf)
if [[ $? -ne 0 ]];then
  echo "printf is not defined in variable PATH"
  exit 1;
fi
MOUNT=$(which mount)
if [[ $? -ne 0 ]];then
  echo "mount is not defined in variable PATH"
  exit 1;
fi
UMOUNT=$(which umount)
if [[ $? -ne 0 ]];then
  echo "umount is not defined in variable PATH"
  exit 1;
fi
FINDMNT=$(which findmnt)
if [[ $? -ne 0 ]];then
  echo "findmnt is not defined in variable PATH"
  exit 1;
fi
CUT=$(which cut)
if [[ $? -ne 0 ]];then
  echo "cut is not defined in variable PATH"
  exit 1;
fi
TEE=$(which tee)
if [[ $? -ne 0 ]];then
  echo "tee is not defined in variable PATH"
  exit 1;
fi
SED=$(which sed)
if [[ $? -ne 0 ]];then
  echo "sed is not defined in variable PATH"
  exit 1;
fi

TIMESTAMP=$(date +%d.%m.%Y_%H:%M:%S)
#LOG="/dev/null"
LOG="/logdir/sp_migraton_${HOSTNAME}_${TIMESTAMP}_part2.log"
OS_LEVEL=$($CAT /etc/os-release | $GREP VERSION_ID| $CUT -d "=" -f2| $SED -e 's/\"//g')
KERNEL_VERSION=$(uname -r| $SED 's/-default//')
LETTER=$($CAT /etc/fstab | $GREP bind | $GREP /hana/data | $AWK '{print $2}' | $AWK -F '/' '{print $4}'|$EGREP -o "^[A-Z]")
SUSE_RELEASE_FILE="/etc/SuSE-release"
UNINSTALLED="0"
PROD=0
NONPROD=0
IB_PRESENT=0
SVC="no"
PUPPET_PARAM="/root/puppetParameterInfos"
NEW12VERSION="12.5"
NEW15VERSION="15.2"
VERSION="1.0"
SCRIPT_NAME=$(basename "$0")
### END Variables ###

### Functions ###
function usage (){
$PRINTF "\n$(dirname $0)/$SCRIPT_NAME \n
This script is the second (and FINAL) part of the Service Pack migration task. Mainly responsible
for checking everything after the reboot.

It creates a log file in /repodir/log with all outputs.

-h, --help        Display this help and exit
-v, --version     Output version information and exit
"
}

function startPuppet(){
if [[ ! $(systemctl is-active puppet.service) == "active" ]];then
  systemctl start puppet
fi
}
function init(){
### LOG FILE HEADER ###
$PRINTF "################# LOG FILE FOR $HOSTNAME SERVICE PACK UPGRADE Q3 2021 (POST REBOOT) #################\n\n" >> $LOG

}
function prod_nonprod(){
if [[ $LETTER == P ]];then
  PROD=1
else
  NONPROD=1
fi
}
function infinibandPresence(){

#######################################
# Checking if IB adapters are present #
#######################################
if [[ $(lspci| $GREP -i infiniband) ]];then
  MMDIAG=$(which mmdiag)
  if [[ $? -ne 0 ]];then
    echo "mmdiag is not defined in variable PATH"
    exit 1;
  fi

  IB_PRESENT=1
fi
}

function checkPuppetProcess(){
while [[ $(ps aux | grep -E 'puppet agent -t'| grep -v grep) ]];do
  $PRINTF "Waiting Puppet stop running... \n\n" | $TEE -a $LOG
  sleep 5;
done
}

function checkZypperProcess(){

#############################################################################
# Waiting zypper process to finish, otherwise we can not use zypper command #
#############################################################################
while [[ ! $($ZYPPER ll) ]];do
  $PRINTF "Waiting zypper process finish... \n\n" | $TEE -a $LOG
  sleep 5;
done
}

function infinibandServiceCheck(){

########################################################
# Checking IB service if it is up/running, and enabled #
########################################################
DATE=$(date)
openibd_status_active=$(systemctl is-active openibd.service)
if [[ $openibd_status_active == active ]];then
   $PRINTF "\n$DATE - Infiniband service is up and running \n" | $TEE -a $LOG
elif [[ $openibd_status_active == inactive ]];then
   $PRINTF "\n$DATE - Starting up Infiniband service \n" | $TEE -a $LOG
   systemctl start openibd.service| $TEE -a $LOG
else
  $PRINTF "\n$DATE - Status of 'openibd.service' is unknown. Trying to start it... \n" | $TEE -a $LOG
  systemctl start openibd.service| $TEE -a $LOG
fi

openibd_status_enable=$(systemctl is-enabled openibd.service)
if [[ $openibd_status_enable == enabled ]];then
  $PRINTF "\n$DATE - Infiniband service is ENABLED\n" | $TEE -a $LOG
elif [[ $openibd_status_enable == disabled ]];then
  $PRINTF "\n$DATE - Enabling Infiniband service \n\n" | $TEE -a $LOG
  systemctl enable openibd.service| $TEE -a $LOG
else
  $PRINTF "\n$DATE - Status of 'openibd.service' is unknown. Trying to enable it... \n" | $TEE -a $LOG
  systemctl enable openibd.service| $TEE -a $LOG
fi
$PRINTF "\n\n"
systemctl status openibd.service
}

function gpfsPackagesCheck(){

##########################################################################
# Check if all gpfs packages are installed (for non SVC), if any missing #
# then install it right away                                             #
##########################################################################
DATE=$(date)
checkZypperProcess
if [[ $SVC == no ]];then
  $PRINTF "\n$DATE - Double checking if GPFS packages are installed\n" | $TEE -a $LOG
  if [[ $OS_LEVEL == $NEW12VERSION ]];then
  sles12_gpfs_packages_necessary='gpfs.base-5.0.5-8
gpfs.gpl-5.0.5-8
gpfs.gplbin-4.12.14-122.74-default-5.0.5-8
gpfs.gskit-8.0.55-12
gpfs.gss.pmsensors-5.0.5-8.sles12
gpfs.docs-5.0.5-8
gpfs.msg.en_US-5.0.5-8
gpfs.license.std-5.0.5-8
'

  for package in $sles12_gpfs_packages_necessary;do
    if [[ $($RPM -qa| $GREP $package) ]];then
      $PRINTF "$package - ALREADY INSTALLED\n" | $TEE -a $LOG
    else
      $PRINTF "$package - NOT INSTALLED. Installing it right away ...\n" | $TEE -a $LOG
      $ZYPPER --quiet --no-gpg install --auto-agree-with-licenses --no-confirm /repodir/gpfs_rpms/${package}* | $TEE -a $LOG
    fi
  done

  elif [[ $OS_LEVEL == $NEW15VERSION ]];then
  sles15_gpfs_packages_necessary='gpfs.gplbin-5.3.18-24.67-default-5.0.5-8
gpfs.base-5.0.5-8.ppc64le
gpfs.docs-5.0.5-8.noarch
gpfs.msg.en_US-5.0.5-8.noarch
gpfs.gss.pmsensors-5.0.5-8.sles15.ppc64le
gpfs.license.std-5.0.5-8.ppc64le
gpfs.gskit-8.0.55-12.ppc64le
gpfs.gpl-5.0.5-8.noarch
'

  for package in $sles15_gpfs_packages_necessary;do
    if [[ $($RPM -qa| $GREP $package) ]];then
      $PRINTF "$package - ALREADY INSTALLED\n" | $TEE -a $LOG
     else
      $PRINTF "$package - NOT INSTALLED. Installing it right away ...\n" | $TEE -a $LOG
      $ZYPPER --quiet --no-gpg-checks install --auto-agree-with-licenses --no-confirm /repodir/gpfs_rpms/${package}*
    fi
  done
  fi
fi
}

function doubleCheckInfinibandVersion(){

####################################################################
# Making sure everything is alright with the Ofed Driver installed #
####################################################################
DATE=$(date)
$PRINTF "\n\n$DATE - #### Checking current OFED driver version #### \n" | $TEE -a $LOG
OFED_VERSION=$(ofed_info -s|$AWK -F "-" {'print $2"-"$3'}| $CUT -d ":" -f1)

if [[ $($FINDMNT | $GREP -i "/mnt/mlnx") ]];then
  $UMOUNT /mnt/mlnx
fi

if [[ $OFED_VERSION != 4.9-3.1.5.0 ]];then
  $PRINTF "\n[ERROR] OFED driver was not installed - Do the upgrade process manually!\n" | $TEE -a $LOG
  $PRINTF "\nFOR SLES 12 the process should be: \n" | $TEE -a $LOG
  $PRINTF "\nInstall: 'mkdir /mnt/mlnx; mount -o loop /repodir/MLNX_OFED_LINUX-4.9-3.1.5.0-sles12sp5-ppc64le.iso /mnt/mlnx/;/mnt/mlnx/mlnxofedinstall -q --without-fw-update --enable-affinity --enable-mlnx_tune --distro sles12sp5'\n\n\n" | $TEE -a $LOG
  $PRINTF "\nFOR SLES 15 the process should be: \n" | $TEE -a $LOG
  $PRINTF "\nInstall: 'mount -o loop /repodir/MLNX_OFED_LINUX-4.9-3.1.5.0-sles15sp2-ppc64le.iso /mnt/mlnx/;/mnt/mlnx/mlnxofedinstall -q --without-fw-update --enable-affinity --enable-mlnx_tune --distro sles15sp2'\n" | $TEE -a $LOG
  exit 9;
else
  $PRINTF "\n[SUCCESS] Ofed Driver installed successfully. Current version: $OFED_VERSION \n\n" | $TEE -a $LOG
  mv /opt/ofed_uninstalled_sp_migration_part1 /opt/ofed_uninstalled_sp_migration_part1_done
fi

}

function installOfedDriver(){
DATE=$(date)
$PRINTF "\n\n$DATE - #### Installing OFED Driver #### \n" | $TEE -a $LOG
if [[ ! -d /mnt/mlnx ]];then
  $MKDIR /mnt/mlnx
fi
if [[ $($FINDMNT | $GREP -i "/mnt/mlnx") ]];then
  $UMOUNT /mnt/mlnx
fi

if [[ $OS_LEVEL == $NEW12VERSION ]];then
  $MOUNT -o loop /repodir/MLNX_OFED_LINUX-4.9-3.1.5.0-sles12sp5-ppc64le.iso /mnt/mlnx/;/mnt/mlnx/mlnxofedinstall -q --without-fw-update --enable-affinity --enable-mlnx_tune --distro sles12sp5 | $TEE -a $LOG
  doubleCheckInfinibandVersion
elif [[ $OS_LEVEL == $NEW15VERSION ]];then
  $MOUNT -o loop /repodir/MLNX_OFED_LINUX-4.9-3.1.5.0-sles15sp2-ppc64le.iso /mnt/mlnx/;/mnt/mlnx/mlnxofedinstall -q --without-fw-update --enable-affinity --enable-mlnx_tune --distro sles15sp2 | $TEE -a $LOG
  doubleCheckInfinibandVersion
fi
$UMOUNT /mnt/mlnx
}

function checkInfinibandVersion(){

#################################################
# Checking if Ofed Driver needs to be installed #
#################################################
DATE=$(date)

which ofed_info > /dev/null 2>&1
if [[ $? -ne 0 ]];then
  installOfedDriver
else

  OFED_VERSION=$(ofed_info -s|$AWK -F "-" {'print $2"-"$3'}| $CUT -d ":" -f1)
  $PRINTF "\n\n$DATE - #### Verifying current OFED Driver version installed #### \n" | $TEE -a $LOG
  if [[ -z $OFED_VERSION ]];then
    $PRINTF "There is no OFED Driver installed at the moment, it will be done now. \n" | $TEE -a $LOG
    installOfedDriver
  else
    if [[ $OFED_VERSION != 4.9-3.1.5.0 ]];then
      doubleCheckInfinibandVersion
    else
      $PRINTF "OFED Driver already up to date. Current version running: $OFED_VERSION" | $TEE -a $LOG
      if [[ $($FINDMNT | $GREP -i "/mnt/mlnx") ]];then
        $UMOUNT /mnt/mlnx
      fi
    fi
  fi
fi
}

function afterRebootCheck1(){

############################################
# Check kernel version when system come up #
############################################

DATE=$(date)
if [[ $OS_LEVEL == $NEW12VERSION ]];then
  $PRINTF "\n\n$DATE - #### Checking kernel version after reboot #### \n" | $TEE -a $LOG
  if [[ $KERNEL_VERSION == 4.12.14-122.74 ]];then
    $PRINTF "\nKernel has been updated successfully. Current version: $KERNEL_VERSION\n" | $TEE -a $LOG
  else
    $PRINTF "\n[WARNING] Kernel upgrade has FAILED. Stopping the script to be validated manually.\n" | $TEE -a $LOG
    exit 1;
  fi
elif [[ $OS_LEVEL == $NEW15VERSION ]];then
  $PRINTF "\n\n$DATE - #### Checking kernel version after reboot #### \n" | $TEE -a $LOG
  if [[ $KERNEL_VERSION == 5.3.18-24.67 ]];then
    $PRINTF "\nKernel has been updated successfully. Current version: $KERNEL_VERSION\n" | $TEE -a $LOG
  else
    $PRINTF "\n[WARNING] OS upgrade has FAILED. Stopping the script to be validated manually.\n" | $TEE -a $LOG
    exit 1;
  fi
else
  $PRINTF "\n[WARNING] OS upgrade has FAILED. Stopping the script to be validated manually.\n" | $TEE -a $LOG
  exit 1;
fi

#######################################################################
# Change the version of the OS in this file, so puppet recognizes it. #
#######################################################################
if [[ -f $SUSE_RELEASE_FILE ]];then
  if [[ $OS_LEVEL == $NEW12VERSION ]];then
    $SED -i 's/PATCHLEVEL = [0-9]/PATCHLEVEL = 5/g' $SUSE_RELEASE_FILE
    $CAT $SUSE_RELEASE_FILE| $TEE -a $LOG
  elif [[ $OS_LEVEL == $NEW15VERSION ]];then
    $SED -i 's/PATCHLEVEL = [0-9]/PATCHLEVEL = 2/g' $SUSE_RELEASE_FILE
    $CAT $SUSE_RELEASE_FILE| $TEE -a $LOG
  fi
fi

DATE=$(date)
$PRINTF "\n\n$DATE - #### Running puppet to install gpfs packages and the OFED driver \n" | $TEE -a $LOG
checkZypperProcess
startPuppet
checkPuppetProcess
$PUPPET agent -t
#checkInfinibandVersion
#infinibandPresence
if [[ $IB_PRESENT -eq 1 ]];then
# commenting out the line below because Puppet is handling the
# installation of Ofed Driver.
#  checkInfinibandVersion
  infinibandServiceCheck
fi
if [[ -f $PUPPET_PARAM ]];then
  if [[ $($GREP "doNotInstallGPFS=true" $PUPPET_PARAM ) ]];then
  $PRINTF "\n\nSVC\n\n"| $TEE -a $LOG
  SVC="yes"
  fi
else
  if [[ $($CAT /etc/fstab| $GREP -i gpfs) ]];then
    SVC="no"
  fi
fi

#########################################################
# Validate if all necessary gpfs packages are installed #
#########################################################
gpfsPackagesCheck

# Running Puppet once more
DATE=$(date)
$PRINTF "\n\n$DATE - #### Running puppet once more for a double check #### \n" | $TEE -a $LOG
checkZypperProcess
$PUPPET agent -t
}

function afterRebootCheck2(){

############################################
# Start GPFS client and mount file systems #
############################################
DATE=$(date)
gpfsPackagesCheck
$PRINTF "\n\n$DATE - #### Starting GPFS client and mounting file systems\n" | $TEE -a $LOG
bash /repodir/v2_mountfs_alex.sh | $TEE -a $LOG

############################################################
# Check if there are connections going through the fabrics #
############################################################
if [[ $IB_PRESENT -eq 1 ]];then
  DATE=$(date)
  $PRINTF "\n\n$DATE - #### Checking if there are connections going through the fabrics\n" | $TEE -a $LOG
  $MMDIAG --network | $TEE -a $LOG
  $MMDIAG --network | $GREP -i fabric > /dev/null 2>&1
  if [[ $? -ne 0 ]];then
    $PRINTF "#####################################################\n" | $TEE -a $LOG
    $PRINTF "\n\n[WARNING] No fabric connections going through. \n " | $TEE -a $LOG
    $PRINTF "#####################################################\n" | $TEE -a $LOG
    #exit 3
  fi
fi

####################################################
# Double check whether SMT is set in the right way #
####################################################
DATE=$(date)
if [[ $OS_LEVEL == $NEW12VERSION ]];then
  if [[ $($CAT /root/puppetParameterInfos | $GREP -i smt_level) ]];then
    smt=$($CAT /root/puppetParameterInfos | $GREP -i smt_level| $CUT -d "=" -f2)
    $PPC64_CPU --smt=${smt}
  else
    $PPC64_CPU --smt=4
  fi
elif [[ $OS_LEVEL == $NEW15VERSION ]];then
  if [[ $($CAT /root/puppetParameterInfos | $GREP -i smt_level) ]];then
    smt=$($CAT /root/puppetParameterInfos | $GREP -i smt_level| $CUT -d "=" -f2)
    $PPC64_CPU --smt=${smt}
  else
    $PPC64_CPU --smt=8
  fi
fi

###############################
# Checking if PROD or NONPROD #
###############################
prod_nonprod
}

function irqtuning(){

############################
# If PROD, run IRQ Tunning #
############################
DATE=$(date)
if [[ $PROD -eq 1 ]];then
  $PRINTF "\n\n$DATE - #### Running IRQ Tunning script ###\n" | $TEE -a $LOG
  bash /repodir/irq_tuning_auto.sh | $TEE -a $LOG
fi
}

function afterRebootFinalCheck(){
if [[ $($FINDMNT | $GREP -i "/mnt/mlnx") ]];then
  $UMOUNT /mnt/mlnx
fi
##################
# Collect config #
##################
DATE=$(date)
$PRINTF "\n\n$DATE - #### Collecting configuration ###\n" | $TEE -a $LOG
bash /repodir/collect-config.sh

#############################################################
# Run another QA Checklist and fix the issues if they exist #
#############################################################
DATE=$(date)
$PRINTF "\n\n$DATE - #### Running QA Checklist ###\n" | $TEE -a $LOG
bash /repodir/qa_check_main.sh | $TEE -a $LOG

$PRINTF "\n\n###############################################\n" | $TEE -a $LOG
$PRINTF "\n\n  [!]     #### IMPORTANT REMINDER ###\n" | $TEE -a $LOG
$PRINTF "\n\n###############################################\n" | $TEE -a $LOG
$PRINTF "\nPlease DO NOT FORGET to change 'BaselineCI' status on CMDB to the right SLES SP RELEASE\n\n"| $TEE -a $LOG
}

### Code ###
while [[ $1 = -?* ]]; do
  case $1 in
    -h|--help) usage >&2 ;exit 0;;
    -v|--version) $PRINTF "$SCRIPT_NAME version: ${VERSION}\n"; exit 0;;
    --endopts) shift; break ;;
    *) $PRINTF "Invalid option: '$1'.\n" ; exit 1;;
  esac
  shift
done

init
afterRebootCheck1
afterRebootCheck2
irqtuning
afterRebootFinalCheck

### END Code ###