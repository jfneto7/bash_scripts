#!/bin/bash

# Author: Jose Fernandes Neto 
# Contact: jfneto92@gmail.com  / linkedin.com/in/jfneto7
# Date: 16.06.2021
# Version: 1.0
# Description: First part of the Service Pack migration activity we are going to do massivelly.
# Mainly responsible to prepare and apply all the updates in the server.

### Variables ###
DSMC=$(which dsmc)
if [[ $? -ne 0 ]];then
  echo "dsmc is not defined in variable PATH"
  exit 1;
fi
ZYPPER=$(which zypper)
if [[ $? -ne 0 ]];then
  echo "zypper is not defined in variable PATH"
  exit 1;
fi
LS=$(which ls)
if [[ $? -ne 0 ]];then
  echo "ls is not defined in variable PATH"
  exit 1;
fi
REBOOT=$(which reboot)
if [[ $? -ne 0 ]];then
  echo "reboot is not defined in variable PATH"
  exit 1;
fi
TEE=$(which tee)
if [[ $? -ne 0 ]];then
  echo "tee is not defined in variable PATH"
  exit 1;
fi
GREP=$(which grep)
if [[ $? -ne 0 ]];then
  echo "grep is not defined in variable PATH"
  exit 1;
fi
FINDMNT=$(which findmnt)
if [[ $? -ne 0 ]];then
  echo "findmnt is not defined in variable PATH"
  exit 1;
fi
PRINTF=$(which printf)
if [[ $? -ne 0 ]];then
  echo "printf is not defined in variable PATH"
  exit 1;
fi
CP=$(which cp)
if [[ $? -ne 0 ]];then
  echo "cp is not defined in variable PATH"
  exit 1;
fi
RPM=$(which rpm)
if [[ $? -ne 0 ]];then
  echo "rpm is not defined in variable PATH"
  exit 1;
fi
CAT=$(which cat)
if [[ $? -ne 0 ]];then
  echo "cat is not defined in variable PATH"
  exit 1;
fi
AWK=$(which awk)
if [[ $? -ne 0 ]];then
  echo "awk is not defined in variable PATH"
  exit 1;
fi
MKDIR=$(which mkdir)
if [[ $? -ne 0 ]];then
  echo "mkdir is not defined in variable PATH"
  exit 1;
fi
CUT=$(which cut)
if [[ $? -ne 0 ]];then
  echo "cut is not defined in variable PATH"
  exit 1;
fi
UMOUNT=$(which umount)
if [[ $? -ne 0 ]];then
  echo "umount is not defined in variable PATH"
  exit 1;
fi
MOUNT=$(which mount)
if [[ $? -ne 0 ]];then
  echo "mount is not defined in variable PATH"
  exit 1;
fi

SCRIPT_NAME=$(basename $0)
VERSION="1.0"
TIMESTAMP=$(date +%d.%m.%Y_%H:%M:%S)
LOG="/logdir/sp_migraton_${HOSTNAME}_${TIMESTAMP}_part1.log"
OS_LEVEL=$($CAT /etc/os-release | $GREP VERSION_ID| cut -d "=" -f2| sed -e 's/\"//g')
OLD12VERSION="12.4"
OLD15VERSION="15.1"
KERNEL_VERSION=$(uname -r| sed 's/-default//')
IB_PRESENT=0
OFED_PRESENT=0
PUPPET_PARAM="/root/puppetParameterInfos"

### End Variables ###

### Functions ###

function stopPuppet(){
while [[ $(ps aux | grep -E 'puppet agent -t'| grep -v grep) ]];do
  $PRINTF "Waiting Puppet stop running...\n\n" | $TEE -a $LOG
  sleep 5;
done
if [[ $(systemctl is-active puppet) == "active" ]];then
  systemctl stop puppet.service;
fi
if [[ $(systemctl is-enabled puppet) == "disabled" ]];then
  systemctl enable puppet
fi
}

function assignToChannel(){

#############################################
# Assign the LPAR to the right channel repo #
#############################################
DATE=$(date)
$PRINTF "\n\n$DATE - ####  Assigning the  LPAR to the right channel repo #### \n" | $TEE -a $LOG
if [[ $OS_LEVEL == $OLD12VERSION ]];then
  $ZYPPER lr| grep "sap-hana-2021-04-16-development" > /dev/null 2>&1
  if [[ $? -ne 0 ]];then
    bash /repodir/bootstrap_sles12-SP4.sh | $TEE -a $LOG
    spacewalk-channel -l | $GREP "sap-hana-2021-04-16-development-suse-packagehub-12-sp4" > /dev/null 2>&1
    if [[ $? -ne 0 ]];then
      bash /repodir/bootstrap_sles12-SP4.sh
    else
      spacewalk-channel -l >> $LOG 2>&1
    fi
  else
    $PRINTF "LPAR already assigned to the right channel.\n" | $TEE -a $LOG
  fi
elif [[ $OS_LEVEL == $OLD15VERSION ]];then
  $ZYPPER lr| grep "sles15sap-hana2021-04-16-development" > /dev/null 2>&1
  if [[ $? -ne 0 ]];then
    bash /repodir/bootstrap_sles15-SP1.sh | $TEE -a $LOG
    spacewalk-channel -l| $GREP "sles15sap-hana2021-04-16-development" > /dev/null 2>&1
    if [[ $? -ne 0 ]];then
      bash /repodir/bootstrap_sles15-SP1.sh | $TEE -a $LOG
    else
      spacewalk-channel -l >> $LOG 2>&1
    fi
  else
    $PRINTF "LPAR already assigned to the right channel.\n" | $TEE -a $LOG
  fi
fi

}

function usage (){
$PRINTF "\n$(dirname $0)/$SCRIPT_NAME \n
This script is the first part of the Service Pack migration activity we are going to do massivelly.
Mainly responsible to prepare and apply all the updates in the server.

It creates a log file in /repodir/log with all outputs.

-h, --help        Display this help and exit
-v, --version     Output version information and exit
"
}

function init(){
### LOG FILE HEADER ###
$PRINTF "################# LOG FILE FOR $HOSTNAME SERVICE PACK UPGRADE Q3 2021 #################\n\n" >> $LOG
$PRINTF "\n Preparing the system to be patched. \n\n"| $TEE -a $LOG
#################################################
# If SLES is different of 12.4 or 15.1, exit... #
#################################################
if [[ $OS_LEVEL != $OLD12VERSION ]] && [[ $OS_LEVEL != $OLD15VERSION ]];then
  $PRINTF "This SLES version $OS_LEVEL will not be migrated. Exiting..." | $TEE -a $LOG
  exit 1;
fi

stopPuppet
assignToChannel

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

function gpfsGplbinUninstallGplbin(){
checkZypperProcess
DATE=$(date)
$PRINTF "$DATE - Removing GPFS GPLBIN old version\n"
while [[ $($RPM -qa | $GREP gpfs| $GREP gplbin) ]];do
  $ZYPPER remove -y gpfs.gplbin* | $TEE -a $LOG
done
}

function ofedDriverPresence(){

## Checking if OFED Driver is present ##
which ofed_info > /dev/null 2>&1
if [[ $? -eq 0 ]];then
  OFED_PRESENT=1
  OFED_VERSION=$(ofed_info -s|$AWK -F "-" {'print $2"-"$3'}| $CUT -d ":" -f1)
else
  OFED_PRESENT=0
fi
}

function infinibandPresence(){
# Function not in use at the moment
## Checking if IB adapters are present ##
if [[ $(lspci| $GREP -i infiniband) ]];then
  OFED_INFO=$(which ofed_info)
  if [[ $? -ne 0 ]];then
    echo "ofed_info is not defined in variable PATH"
  exit 1;
  fi
  MMDIAG=$(which mmdiag)
  if [[ $? -ne 0 ]];then
    echo "mmdiag is not defined in variable PATH"
    #exit 1;
  fi

  IB_PRESENT=1
  OFED_VERSION=$($OFED_INFO -s|$AWK -F "-" {'print $2"-"$3'}| $CUT -d ":" -f1)
fi
}

function uninstallOldOfedDriver(){
if [[ ! -d /mnt/mlnx ]];then
  $MKDIR /mnt/mlnx
fi

if [[ $($FINDMNT | $GREP -i "/mnt/mlnx") ]];then
  $UMOUNT /mnt/mlnx
fi

checkZypperProcess

if [[ $OS_LEVEL == $OLD12VERSION ]];then
  $MOUNT -o loop /repodir/MLNX_OFED_LINUX-${OFED_VERSION}-sles12sp4-ppc64le.iso /mnt/mlnx/;/mnt/mlnx/uninstall.sh --force | $TEE -a $LOG
  if [[ ! $($RPM -qa| $GREP -i mlnx) ]];then
    UNINSTALLED="ok"
    $UMOUNT /mnt/mlnx
  else
    UNINSTALLED="nok"
    $UMOUNT /mnt/mlnx
  fi
elif [[ $OS_LEVEL == $OLD15VERSION ]];then
  # I checked in all islands SLES15.1 we just have ofed driver version 4.7-3.2.9.0 running
  $MOUNT -o loop /repodir/MLNX_OFED_LINUX-${OFED_VERSION}-sles15sp1-ppc64le.iso /mnt/mlnx/;/mnt/mlnx/uninstall.sh --force | $TEE -a $LOG
  if [[ ! $($RPM -qa| $GREP -i mlnx) ]];then
    UNINSTALLED="ok"
    while [[ $($FINDMNT| $GREP -i /mnt/mlnx) ]];do
      $UMOUNT /mnt/mlnx
    done
  else
    UNINSTALLED="nok"
    while [[ $($FINDMNT| $GREP -i /mnt/mlnx) ]];do
      $UMOUNT /mnt/mlnx
    done
  fi
fi
}

function checkOfedVersion(){
if [[ $OS_LEVEL == $OLD12VERSION ]] && [[ $OFED_VERSION != 4.9-3.1.5.0 ]];then
  DATE=$(date)
  $PRINTF "$DATE - Uninstalling the current Ofed Driver version $OFED_VERSION\n" | $TEE -a $LOG
  uninstallOldOfedDriver
  if [[ $($RPM -qa| $GREP -i mlnx) ]];then
    $PRINTF "\n\n###################################################################################################\n"
    $PRINTF "\n[WARNING] Error to remove OFED driver. Do it manually. Run '/usr/sbin/ofed_uninstall.sh '\n"
    $PRINTF "\n\n###################################################################################################\n"
  fi
  if [[ $UNINSTALLED == ok ]];then
    $PRINTF "Ofed Driver uninstalled successfully\n" | $TEE -a $LOG
    touch /opt/ofed_uninstalled_sp_migration_part1
  else
    $PRINTF "[ERROR] Something went wrong uninstalling the ofed driver. Please uninstall it manually (running: bash /usr/sbin/ofed_uninstall.sh) and run this script again.\n" | $TEE -a $LOG
    exit 3;
  fi
elif [[ $OS_LEVEL == $OLD15VERSION ]] && [[ $OFED_VERSION != 4.9-3.1.5.0 ]];then
  DATE=$(date)
  $PRINTF "$DATE - Uninstalling the current Ofed Driver version $OFED_VERSION\n" | $TEE -a $LOG
  uninstallOldOfedDriver
  if [[ $($RPM -qa| $GREP -i mlnx) ]];then
    $PRINTF "\n\n###################################################################################################\n"
    $PRINTF "\n[WARNING] Error to remove OFED driver. Do it manually. Run '/usr/sbin/ofed_uninstall.sh '\n"
    $PRINTF "\n\n###################################################################################################\n"
  fi
  if [[ $UNINSTALLED == ok ]];then
    $PRINTF "Ofed Driver uninstalled successfully\n" | $TEE -a $LOG
    touch /opt/ofed_uninstalled_sp_migration_part1
  else
    $PRINTF "[ERROR] Something went wrong uninstalling the ofed driver. Please uninstall it manually (running: /usr/sbin/ofed_uninstall.sh) and run this script again.\n" | $TEE -a $LOG
    exit 3;
  fi
fi
}

function gpfsStopAandUmount(){

####################################
# Stop GPFS and umount filesystems #
####################################
DATE=$(date)
$PRINTF "\n\n$DATE - #### Stop GPFS and umount filesystems #### \n" | $TEE -a $LOG
bash /repodir/umountfs_alex.sh | $TEE -a $LOG
$FINDMNT| $GREP -iE 'gpfs|hana|solagent'
if [[ $? -eq 0 ]];then
  bash /repodir/umountfs_alex.sh >> $LOG 2>&1
fi
/usr/lpp/mmfs/bin/mmgetstate | $GREP active >> $LOG 2>&1
if [[ $? -eq 0 ]];then
  $PRINTF "[ERROR] GPFS client is still running in the LPAR. Check it manually and once you fixed it, you can run this script again."
  exit 10
fi
}

function gpfsUninstallPackages(){
checkZypperProcess
DATE=$(date)
$PRINTF "$DATE - Uninstalling GPFS packages (filesystem SVC)\n" | $TEE -a $LOG

for package in $($RPM -qa| $GREP -i gpfs);do
  $PRINTF "Uninstalling $package" | $TEE -a $LOG
  $ZYPPER remove -y $i| $TEE -a $LOG
done
}

function preparation(){

################################################
# Check that HDB is stopped and remove remains #
################################################
DATE=$(date)
if [[ -z $(ps -ef | $GREP -i indexserver | $GREP -v $GREP) ]]; then
  $PRINTF "$DATE - Cleaning up HANA remains\n";
  /repodir/stop-sapremains.sh;
else
  $PRINTF "$DATE - HDB Indexserver is running; Make sure that HDB is stopped propperly\n" | $TEE -a $LOG
  exit 1;
fi

##################
# Collect config #
##################
DATE=$(date)
$PRINTF "\n\n$DATE - #### Collect config #### \n" | $TEE -a $LOG
bash /repodir/collect-config.sh >> $LOG 2>&1

###################
# TSM File backup #
###################
DATE=$(date)
$PRINTF "\n\n$DATE - #### TSM BACKUP #### \n" | $TEE -a $LOG
$DSMC incre >> $LOG 2>&1
if [[ $? -ne 0 ]];then
$PRINTF "\n[WARNING] Backup failed! But the script will go on..." | $TEE -a $LOG
fi

##################################################################
# Checking if 'cloud-init' package is present, if so removing it #
##################################################################
DATE=$(date)
checkZypperProcess
for cloudinit_pkg in $($RPM -qa| $GREP -i cloud-init);do
  $PRINTF "\n\n$DATE - Uninstalling 'cloud-init' package now...\n" | $TEE -a $LOG
  $ZYPPER remove -y cloud-init | $TEE -a $LOG
done

############################################################
# Backuping /etc/udev/rules.d/70-persistent-net.rules file #
############################################################
DATE=$(date)
$PRINTF "\n\n$DATE - #### Backuping /etc/udev/rules.d/70-persistent-net.rules file to /tmp #### \n" | $TEE -a $LOG
$CP /etc/udev/rules.d/70-persistent-net.rules /tmp/bkp_${TIMESTAMP}_70-persistent-net.rules
if [[ $? -ne 0 ]];then
  $PRINTF "[WARNING] Failed to backup file /etc/udev/rules.d/70-persistent-net.rules \n" | $TEE -a $LOG
else
  $PRINTF "[Success] File /tmp/bkp_${TIMESTAMP}_70-persistent-net.rules saved.\n" | $TEE -a $LOG
  ls -l /tmp/bkp_${TIMESTAMP}_70-persistent-net.rules >> $LOG
fi

#################################
# Backuping network ifcfg files #
#################################
DATE=$(date)
$PRINTF "\n\n$DATE - #### Backuping /etc/sysconfig/network directory ### \n" | $TEE -a $LOG
$CP -r /etc/sysconfig/network /tmp/backup_${TIMESTAMP}_network


################################################################
# Uninstalling all gpfs packages for LPARs with FS SVC mounted #
################################################################
if [[ -f $PUPPET_PARAM ]];then
  if [[ $($GREP "doNotInstallGPFS=true" $PUPPET_PARAM ) ]];then
    echo "SVC"
    gpfsUninstallPackages
  else
    gpfsStopAandUmount
  fi
else
  if [[ $($CAT /etc/fstab| $GREP -i gpfs) ]];then
    gpfsStopAandUmount
  else
    gpfsUninstallPackages
  fi
fi

#################################
# Remove locks for rpm packages #
#################################
checkZypperProcess
DATE=$(date)
$PRINTF "\n\n$DATE - #### Removing locks for rpm packages  #### \n" | $TEE -a $LOG

# Cleaning out
while [[ $($ZYPPER locks | $GREP Name) ]];do
  $ZYPPER removelock 1 >> $LOG 2>&1;
done

###############################################
# Make sure 'sapconf' is stopped and disabled #
###############################################
DATE=$(date)
$PRINTF "\n\n$DATE - #### Making sure 'sapconf' is stopped and disabled #### \n" | $TEE -a $LOG
which sapconf > /dev/null 2>&1
if [[ $? -ne 0 ]];then
  echo "sapconf is not installed. Skipping task..." | $TEE -a $LOG
else
  echo "Stopping/ disabling sapconf.service..." | $TEE -a $LOG
  systemctl disable sapconf
  while [[ $(systemctl is-enabled sapconf) != disabled ]];do
    systemctl disable sapconf
  done
  systemctl stop sapconf
  while [[ $(systemctl is-active sapconf) != inactive ]];do
    systemctl stop sapconf
  done
fi

######################################################################################
# Check /etc/sysctl.d/sap-hana-bosch.conf and renaming it (if it is an existing one) #
######################################################################################
DATE=$(date)
$PRINTF "\n\n$DATE - #### Checking if /etc/sysctl.d/sap-hana-bosch.conf exists and renaming it (if so) #### \n" | $TEE -a $LOG
test -f /etc/sysctl.d/sap-hana-bosch.conf
if [[ $? -eq 0 ]];then
  mv /etc/sysctl.d/sap-hana-bosch.conf /etc/sysctl.d/00-sap-hana-bosch.conf
  $LS -l /etc/sysctl.d/ | $TEE -a $LOG
fi

##############################################################
# Check GPFS GPLBIN package. Remove gpfs.gplbin old version. #
##############################################################
DATE=$(date)
if [[ $OS_LEVEL == $OLD12VERSION ]];then
  if [[ ! $($RPM -qa| $GREP "gpfs.gplbin-4.12.14-122.74") ]];then
    gpfsGplbinUninstallGplbin
  fi
elif [[ $OS_LEVEL == $OLD15VERSION ]];then
  if [[ ! $($RPM -qa| $GREP "gpfs.gplbin-5.3.18-24.67") ]];then
    gpfsGplbinUninstallGplbin
  fi
fi
$RPM -qa| $GREP gpfs >> $LOG 2>&1

###############################################################
# Remove ofed driver if version is different than 4.9-3.1.5.0 #
###############################################################
ofedDriverPresence
if [[ $OFED_PRESENT -eq 1 ]];then
  checkOfedVersion
fi

####################################
# Stopping Logrotate to upgrade it #
####################################
DATE=$(date)
$PRINTF "\n\n$DATE - #### Stopping logrotate service ####\n" | $TEE -a $LOG
logrotate_config="/etc/systemd/system/logrotate.service"
test -f $logrotate_config
if [[ $? -eq 0 ]];then
  sed -i 's/ExecStartPre/#ExecStartPre/' $logrotate_config
  systemctl stop logrotate.service
fi
}

function rebootingServer(){
DATE=$(date)
$PRINTF "\n\n$DATE - #### Rebooting $HOSTNAME now #### \n" | $TEE -a $LOG
$REBOOT
}


function servicePackMigration(){
#################################################
# Apply all updates to upgrade the service pack #
#################################################
DATE=$(date)
$PRINTF "\n\n$DATE - #### System can be patched now. Run the following commands. ### \n" | $TEE -a $LOG
if [[ $OS_LEVEL == $OLD12VERSION ]];then
$PRINTF "- zypper patch
- bash /repodir/bootstrap_sles12-SP5.sh
- zypper ref -f -s
- zypper dup
- zypper lu (check if there are no updates to be done)
- reboot
" | $TEE -a $LOG
elif [[ $OS_LEVEL == $OLD15VERSION ]];then
$PRINTF "- zypper patch
- bash /repodir/bootstrap_sles15-SP2.sh
- zypper ref -f -s
- zypper dup
- zypper lu (check if there are no updates to be done)
- reboot
" | $TEE -a $LOG
else
$PRINTF "- zypper patch
- SLES12: bash /repodir/bootstrap_sles12-SP5.sh OR SLES15: bash /repodir/bootstrap_sles15-SP2.sh
- zypper ref -f -s
- zypper dup
- zypper lu (check if there are no updates to be done)
- reboot
" | $TEE -a $LOG
fi
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
preparation
servicePackMigration

### END Code ###