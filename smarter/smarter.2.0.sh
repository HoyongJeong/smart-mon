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
# Read attributes and fill array with that
##################################################
readarray ATTR < <(/usr/sbin/smartctl -A ${1} ${2} ${3})


##################################################
# Divide them into each array and extract essential values
##################################################
for (( i=7; i<=${#ATTR[@]}; i++ ))
do 
	ARRAY=(${ATTR[${i}]})
	echo -n ${ARRAY[0]} ${ARRAY[9]}" " 
done
echo

exit 0
