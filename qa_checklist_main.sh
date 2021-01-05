#!/bin/bash
###############################################################################
# Description: Script created by Jose Fernandes Neto, aiming to be the        #
# main Script to perform QA Checklist and call all the other childs.          #
# Author:       jfneto, IT jfneto92@gmail.com                                 #
# Input:                                                                      #
# Output:                                                                     #
# Date:        2020-07-06                                                     #
# Version:     2.0                                                            #
# Changes:     Added parallelism feature to improve time cost and performance #
#                                                                             #
###############################################################################

### variables ###
## COMMANDS ##
CAT=""
CUT=""
FIND=""
GREP=""
PRINTF=""
TR=""
SORT=""
## END COMMANDS ##

## OTHERS ##
CHECKLIST=()
DATE=$(date +%F-%H-%M-%S)
FAILEDAT=""
OS_VERSION=""
OUTPATH=""
WORKING_DIR=$PWD

out_path="/repository/project/CaP/QA/temp"
qa_check_path="/repository/project/CaP/QA/"
failed_code=() #array to grab all small scripts with return code != 0
counter=0 #just a counter to our array position
script_name=$(basename "$0")
version="2.0.0"
csv_file="checklist_${HOSTNAME}_${DATE}.csv"
csv_filepath="$qa_check_path/csv_reports/$csv_file"
## END OTHERS ##

### END variables ###

### HELP SECTION ###
usage() {
  echo -n "${script_name}
This script works triggering QA check scripts locally in this host.
 ${bold}Options:${reset}
  -h, --help        Display this help and exit
  -v, --version     Output version information and exit
"
}

while [[ $1 = -?* ]]; do
  case $1 in
    -h|--help) usage >&2 ;exit 0;;
    -v|--version) echo "$script_name ${version}"; exit 0;;
    --endopts) shift; break ;;
    *) echo "Invalid option: '$1'." ; exit 1;;
  esac
  shift
done
### END OF HELP SECTION ###


export OS_VERSION OUTFILE qa_check_path

### code ###

## FUNCTIONS ##

function init(){

 # check for CAT
 CAT=$(which cat)
 if [[ $? != 0 ]]; then
    let FAILEDAT=$(($FAILEDAT+1))
    $PRINTF "cat is not defined in \$PATH: $PATH. "
    $PRINTF "Make sure that the path to the command is definied in \$PATH.\n"
    exit $FAILEDAT;
 fi

 # check for CUT
 CUT=$(which cut)
 if [[ $? != 0 ]]; then
    let FAILEDAT=$(($FAILEDAT+1))
    $PRINTF "cut is not defined in \$PATH: $PATH. "
    $PRINTF "Make sure that the path to the command is definied in \$PATH.\n"
    exit $FAILEDAT;
 fi

 # check for FIND
 FIND=$(which find)
 if [[ $? != 0 ]]; then
    let FAILEDAT=$(($FAILEDAT+1))
    $PRINTF "find is not defined in \$PATH: $PATH. "
    $PRINTF "Make sure that the path to the command is definied in \$PATH.\n"
    exit $FAILEDAT;
 fi

 # check for GREP
 GREP=$(which grep)
 if [[ $? != 0 ]]; then
    let FAILEDAT=$(($FAILEDAT+1))
    $PRINTF "grep is not defined in \$PATH: $PATH. "
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

 # check for TR
 TR=$(which tr)
 if [[ $? != 0 ]]; then
    let FAILEDAT=$(($FAILEDAT+1))
    $PRINTF "tr is not defined in \$PATH: $PATH. "
    $PRINTF "Make sure that the path to the command is definied in \$PATH.\n"
    exit $FAILEDAT;
 fi

 # check for SORT
 SORT=$(which sort)
 if [[ $? != 0 ]]; then
    let FAILEDAT=$(($FAILEDAT+1))
    $PRINTF "sort is not defined in \$PATH: $PATH. "
    $PRINTF "Make sure that the path to the command is definied in \$PATH.\n"
    exit $FAILEDAT;
 fi

}

## END FUNCTIONS ##


## MAIN ##

init

# Ensuring you are in the right path
if [[ $WORKING_DIR != $qa_check_path ]]
then
  cd $qa_check_path
  if [[ $? != 0 ]]; then
     $PRINTF "$qa_check_path does not exist; please check the variable \$qa_check_path!\n"
     exit 5
  fi
fi

# Identify the OS release
OS_VERSION=$($CAT /etc/os-release | $GREP VERSION_ID | $CUT -d "=" -f2| $TR -d '\"' | $CUT -d "." -f1)

# collect list of QA checks to run
CHECKLIST=$($FIND $qa_check_path/global -type f | $GREP -E '*.sh$|*.py$')

# define the output file with absolute path
OUTFILE=${out_path}/${HOSTNAME}-${DATE}.out

#Creating CSV file's header
printf "Groups;Value;Command;Status;Description" > $csv_filepath

# loop to run/call 'global' and 'connector' scripts
for i in $CHECKLIST; do
$(dirname $i)/$(basename $i) >> $OUTFILE & 
check_return_code=$?

#Getting all child scripts' return code
if [[ $check_return_code  -eq 1 ]]
then
failed_code[counter]+=$i
let counter=counter+1
fi
done

#sleep 50
still_running=true
while $still_running;do
proc=$(ps aux | grep -E 'puppet agent -t|/repository/project/CaP/QA/SLES*|/repository/project/CaP/QA/global'| grep -v grep)
if [[ $proc ]]
then
sleep 1
else
sleep 2
$CAT $OUTFILE |$GREP -v '3[1,2,3,7]m' >> $csv_filepath
$CAT $OUTFILE |$GREP -E '3[1,2,3,7]m'| $SORT
still_running=false
fi
done



# Checking return codes
if [[ ${#failed_code[@]} -ne 0 ]]
then
echo "Scripts with RETURN CODE = '1': " ${failed_code[@]}
fi

## END MAIN ##
### END code ###