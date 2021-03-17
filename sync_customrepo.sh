#!/bin/bash

# Description: This script will automate the process of syncing a customized repository with a channel
# Author: Jose Fernandes Neto - jfneto92@gmail.com / linkedin.com/in/jfneto7
# Input: run the script followed by the custom repo directory Example: ./$script <custom_repository_directory>
# Note: Only run this script when you have copied the .rpm packages to the custom repo directory.
# Date: 17.03.2021
# version: 1.0

# run only on SUMA
if [[ $HOSTNAME != suma_server1 ]] && [[ $HOSTNAME != suma_server2 ]]
then
        echo "Script must be executed from SUSE Manager."
        exit 5
fi

### variables ###
script=$(basename $0)
repodir=$1
version='1.0'
GPG=$(which gpg)
if [[ $? -ne 0 ]]
then
        echo "gpg not in PATH variable. Please check."
        exit 1
fi

CREATEREPO=$(which createrepo)
if [[ $? -ne 0 ]]
then
        echo "createrepo not in PATH variable. Please check."
        exit 1
fi

RPM=$(which rpm)
if [[ $? -ne 0 ]]
then
        echo "rpm not in PATH variable. Please check."
        exit 1
fi
### END variables ###

### functions ###
function usage(){

        echo -n "./$script <custom_repository_directory>

 It syncs the customized repository with a defined channel.
 Execute this one from SUMA suma_server1 (prod) or suma_server2 (test)
 ${bold}Options:${reset}
 -h, --help        Display this help and exit
 -v, --version     Output version information and exit
"
}


function runit(){

        cd $repodir
        if [[ $? -eq 0 ]]
        then
                if [[ $(ls *.rpm > /dev/null 2>&1 && echo $? || echo $?) -ne 0 ]]
                then
                        echo "No packages found in the directory $repodir"
                        echo "Exiting ..."
                        exit 3;
                fi
        else
                echo "Error to go to $repodir."
                exit 2;
        fi

        if [[ $(test -d repodata && echo $? || echo $?) -eq 0 ]]
        then
                rmdir repodata
                if [[ $? -ne 0 ]]
                then
                        echo "It was not possible to remove 'repodata', forcing it..."
                        rm -rf repodata
                fi
        fi
        $RPM --resign *.rpm
        $CREATEREPO $repodir
        if [[ $? -ne 0 ]]
        then
                echo "Error to create the repository. Exiting..."
                exit 3
        fi
        cd $repodir/repodata
        if [[ $? -ne 0 ]]
        then
                echo "Error to go to 'repodata'. Exiting..."
                exit 4
        fi
        $GPG --detach-sign --armor repomd.xml
        $GPG --export "Susemanager" > repomd.xml.key
        $GPG --import repomd.xml.key
        echo ""
        echo -n "Enter the channel you want to sync this repo with: "
        read CHANNEL
        echo ""
        echo -e "Syncing custom repo $repodir with channel $CHANNEL...\n"
        spacewalk-repo-sync -u file://$repodir --channel $CHANNEL
        echo "Successfully done. The packages from $repodir were added into the channel $CHANNEL."
}
### END functions ###

### code ###
while [[ $1 = -?* ]]; do
  case $1 in
    -h|--help) usage >&2 ;exit 0;;
    -v|--version) echo "$script version: ${version}"; exit 0;;
    --endopts) shift; break ;;
    *) echo "Invalid option: '$1'." ; exit 1;;
  esac
  shift
done


if [[ -z $repodir ]]
then
        usage
else
        runit
fi

### END code ###