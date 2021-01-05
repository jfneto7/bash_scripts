#!/bin/bash
######################################################################
# Description: Connector script to call the script                   #
# os_service_check.sh [11|12|15].sh                                  #
# Author:      Jose Fernandes Neto, IT jfneto92@gmail.com            #
# Input:       N/A                                                   #
# Output:      checklist results                                     #
# Date:        2020-07-14                                            #
# Version:     0.1                                                   #
# Changes:                                                           #
######################################################################

### variables ###
### COMMANDS ###
PRINTF=""
### END COMMANDS ###

### OTHERS ###
DATE=$(date +%F-%H-%M-%S)
#FILENAME=$(basename $0 | sed -e 's/.sh$//') ## doesn't work declared up here
#FILENAMEOS="${FILENAME}_sles${OS_VERSION}.sh" ## doesn't work declared up here
out_path="/repository/project/CaP/QA/temp/"
qa_check_path="/repository/project/CaP/QA"
csv_file="checklist_${HOSTNAME}_${DATE}.csv"
csv_filepath="$qa_check_path/csv_reports/$csv_file"
script_name=$(basename "$0")
version="1.0.0"
### END OTHERS ###
### END variables ###


## FUNCTIONS ##

function init(){

# check for PRINTF
 PRINTF=$(which printf)
 if [[ $? != 0 ]]; then
    let FAILEDAT=$(($FAILEDAT+1))
    $PRINTF "printf is not defined in \$PATH: $PATH. "
    $PRINTF "Make sure that the path to the command is definied in \$PATH.\n"
    exit $FAILEDAT;
 fi
}

function execute(){
$qa_check_path/SLES$OS_VERSION/OS/$FILENAMEOS >> $OUTFILE
}
## END FUNCTIONS ##


## MAIN ##

FILENAME=$(basename $0 | sed -e 's/.sh$//')
FILENAMEOS="${FILENAME}_sles${OS_VERSION}.sh"
init
execute

### HELP SECTION ###
usage() {
  $PRINTF  "${script_name}
This script works calling small os_service_check.sh [11|12|15].sh according to the LPAR's OS version,
for QA Checklist script.\n
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
### CODE ###

### END CODE ###