#!/bin/bash

################################################################################
#   < smarter.sh >
#
#   Script for parsing smartctl output
#
#                                         - Hoyong Jeong (hoyong5419@gmail.com)
################################################################################

##################################################
# Check sudo
##################################################
if [ "$EUID" -ne 0 ]
	then echo "This script must be run as root."
	exit
fi

##################################################
# Check number of arguments
##################################################
if [ $# -ne 1 ]
then
	echo "[Error] Number of arguments must be 1, which is any disk"
	echo "        Example: ./smarter.sh /dev/sda"
	exit
fi

##################################################
# Which disk to be checked
##################################################
DISK=${1}
if [ ! -e ${DISK} ]; then
	echo "Disk" ${DISK} "not found"
	exit 0
fi

##################################################
# Change input field separator to cut line by line
##################################################
IFS_backup="${IFS}"
IFS=$'\n'

##################################################
# Erase header part not used
##################################################
CUTLINE=`smartctl -A ${DISK} | grep -n 'ID#'`
CUTLINE=${CUTLINE%:*}
RAW=(`smartctl -A ${DISK} | sed -e '1,'${CUTLINE}'d'`)

##################################################
# Restore IFS
##################################################
IFS=${IFS_backup}

##################################################
# Divide them into each array
##################################################
N=${#RAW[*]}
for (( i=0; i<=$(( N -1 )); i++ ))
do 
	ARRAY=(${RAW[${i}]})
	echo -n ${ARRAY[0]} ${ARRAY[9]}" " 
done
	echo

exit 1
