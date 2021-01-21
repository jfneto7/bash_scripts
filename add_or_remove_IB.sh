#!/bin/bash
########################################################################
# Description: Script created by Jose Fernandes Neto, aiming to        #
# add or remove an IB adapter of a given LPAR.                         #
# Author:      jfneto92@gmail.com /  https://github.com/jfneto7        #
# Input:       You have to enter the script and the host you want to   #
#              remove the IB adapter of.                               #
# Output:      Remove IB adapter of an LPAR                            #
# Date:        2021-01-11                                              #
# Version:     1.0                                                     #
# Changes:                                                             #
########################################################################

# Making sure this script's been ran from EMS rb3i0001 or rb3i1001m
if [[ $HOSTNAME != ems01 ]] && [[ $HOSTNAME != ems02 ]]
then
echo "Please run this script either from EMS ems01 or in ems02."
exit 2;
fi

### variables ###
host=$1
hmclist="hmcserver1.domain.com
hmcserver2.domain.com
hmcserver3.domain.com
hmcserver4.domain.com
hmcserver5.domain.com
hmcserver6.domain.com "
datetime=$(date '+%d.%m.%y_%H.%M.%S')
FILE="/repo/project/CaP/jfneto/log/IB_adapters_${datetime}.out"
script_name=$(basename "$0")
version="1.0"

### OTHER vars ###
ECHO=$(which echo)
if [[ $? -ne 0 ]]
then
$ECHO "echo is not defined in 'PATH:' $PATH."
exit 1;
fi
CAT=$(which cat)
if [[ $? -ne 0 ]]
then
$ECHO -n "cat is not defined in \$PATH: $PATH.\n"
exit 1;
fi
CUT=$(which cut)
if [[ $? -ne 0 ]]
then
$ECHO "cut is not defined in \$PATH: $PATH.\n"
exit 1;
fi
GREP=$(which grep)
if [[ $? -ne 0 ]]
then
$ECHO "grep is not defined in 'PATH:' $PATH."
exit 1;
fi


usage() {
  $ECHO -n "${script_name} <LPAR>

It adds or removes an IB adapter from an specific LPAR, depending on your choice.
It adds or removes on Infiniband adapter at a time.
It has to be executed from EMS ems01 or ems02
 ${bold}Options:${reset}
  -h, --help        Display this help and exit
  -v, --version     Output version information and exit
"
}

while [[ $1 = -?* ]]; do
  case $1 in
    -h|--help) usage >&2 ;exit 0;;
    -v|--version) $ECHO "$script_name version: ${version}"; exit 0;;
    --endopts) shift; break ;;
    *) $ECHO "Invalid option: '$1'." ; exit 1;;
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

###########################
# Add function
###########################

function add_ib(){
# Nested loop to find frame and lpar
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
  done | grep -w '$host'| cut -d ":" -f2')

if [[ ! -z $frame ]]
then

  # Bring all adapters which are free (not being used by any lpar)
  ssh -q hscroot@$hmc lshwres -r io --rsubtype slot -m $frame -F drc_name,lpar_name,description,drc_index| grep IB| grep null > $FILE

  # Only bring up the adapter physical location code, to not cause any confusion.
  $CAT $FILE | $CUT -d "," -f1

  $ECHO -n "Enter the IB adapter want to add into the $host: "
  read add_ib_adapter

  # Checking if the IB adapter chosen is a valid one
  $GREP -w $add_ib_adapter $FILE > /dev/null 2>&1
  if [[ $? -ne 0 ]]
  then
    $ECHO "[!]IB adapter id not valid. Exiting..."
    exit 111;
  fi

  adapter_id=$($CAT $FILE| $GREP $add_ib_adapter| $CUT -d "," -f4)

  #Confirmation that it can be added
  $ECHO -n "Are you sure you want to add $add_ib_adapter into $host? [yes/no]: "
  read confirmation
  if [[ $confirmation == yes ]]
  then
  $ECHO -e "Adding IB adapter: "$add_ib_adapter "from lpar: "$host "\n"
  ssh -q hscroot@$hmc chhwres -r io -m $frame -o a -p $host -l $adapter_id
  exit 0
  elif [[ $confirmation == no ]]
  then
  $ECHO "Not adding any IB adapter. Exiting..."
  exit 3
  else
  $ECHO "Type only 'yes' or 'no'"
  fi
fi
done


# Informing in case LPAR chosen is not valid
if [[ -z $frame ]]
then
$ECHO "Invalid host!"
exit 3;
fi
}


###########################
# Remove function
###########################



function remove_ib(){
    
# Nested loop to find frame and lpar
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
  done | grep -w '$host'| cut -d ":" -f2')
  if [[ ! -z $frame ]]
  then
    ssh -q hscroot@$hmc lshwres -r io --rsubtype slot -m $frame -F drc_name,lpar_name,description,drc_index| grep $host > $FILE

    # Only bring up the adapter physical location code, to not cause any confusion.
    $CAT $FILE | cut -d "," -f1

    $ECHO -n "Enter the IB adapter want to remove: "
    read rem_ib_adapter

    # Checking if the IB adapter chosen is a valid one
    $GREP -w $rem_ib_adapter $FILE > /dev/null 2>&1
    if [[ $? -ne 0 ]]
    then
      $ECHO "[!]IB adapter id not valid. Exiting..."
      exit 111;
    fi

    adapter_id=$(cat $FILE| grep $rem_ib_adapter| cut -d "," -f4)

  #Confirmation that it can be removed
  $ECHO -n "Are you sure you want to remove $rem_ib_adapter from $host? [yes/no]: "
  read confirmation
  if [[ $confirmation == yes ]]
  then
  $ECHO "Removing IB adapter: "$rem_ib_adapter "from lpar: "$host
  ssh -q hscroot@$hmc chhwres -r io -m $frame -o r -p $host -l $adapter_id
  exit 0
  elif [[ $confirmation == no ]]
  then
  $ECHO "Not removing IB adapter. Exiting..."
  exit 3
  else
  echo "Type only 'yes' or 'no'"
  fi
  fi
done

# Informing in case LPAR chosen is not valid
if [[ -z $frame ]]
then
$ECHO "Invalid host!"
exit 3;
fi

exit 0
}

## initiating the script cheking which is the adm's choice
function begin(){
$ECHO -n "Please select your action:
 1 - ADD IB
 2 - REMOVE IB
 [Enter 1 or 2]:  "
read answer_action
$ECHO ""
if [[ $answer_action == 1 ]]
then
  add_ib
elif [[ $answer_action == 2 ]]
then
  remove_ib
else
 $ECHO "Type only '1' or '2'."
 begin
fi
}
begin

### END Code ###