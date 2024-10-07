#!/bin/bash

################################################################################
#   < Smarr-mon.sh >
#
#   Script for recording S.M.A.R.T. attributes to influxDB server.
#
#                                             - Hoyong Jeong (hoyong@gmail.com)
################################################################################

##################################################
# influxDB
##################################################
DBSERVER='foo'
USERNAME='bar'
PASSWORD='foo'
DATABASE='bar'
SERIES='smart'
DEVICE=(`ls /dev/sd?`)

##################################################
# Critical threshold table
##################################################
declare -A THR_CRIT
THR_CRIT[5]=1
THR_CRIT[10]=1
THR_CRIT[184]=1
THR_CRIT[187]=1
THR_CRIT[188]=1
THR_CRIT[196]=1
THR_CRIT[197]=1
THR_CRIT[198]=1
THR_CRIT[201]=1

##################################################
# Warning threshold table
##################################################
declare -A THR_WARN
THR_WARN[1]=1
THR_WARN[9]=80000
THR_WARN[194]=60

##################################################
# Send quary regularly
##################################################
LEN=${#DEVICE[@]}
while :
do
	for (( i=0; i<${LEN}; i++ ))
	do
		echo For ${DEVICE[i]},
		RESULT=(`./smarter/smarter.sh ${DEVICE[i]}`)
		if [ $? -eq 0 ]; then
			echo "Error occurred"
			exit 0
		fi

		LEN2=${#RESULT[@]}
		IS_CRIT=0
		IS_WARN=0
		for (( j=0; j<$((${LEN2}/2)); j++ ))
		do
			ID[j]=${RESULT[$((j*2))]}
			VAL[j]=${RESULT[$((j*2+1))]}

			if [ ! -v ${THR_CRIT[${ID[j]}]} ]; then
				if [ "${VAL[j]}" -ge "${THR_CRIT[${ID[j]}]}" ]; then
					echo Critical for ${ID[j]} with value ${VAL[j]} by threshold ${THR_CRIT[${ID[j]}]}
					IS_CRIT=1
				fi
			fi

			if [ ! -v ${THR_WARN[${ID[j]}]} ]; then
				if [ "${VAL[j]}" -ge "${THR_WARN[${ID[j]}]}" ]; then
					echo Warning for ${ID[j]} with value ${VAL[j]} by threshold ${THR_WARN[${ID[j]}]}
					IS_WARN=1
				fi
			fi
		done


		#-------------------------------------------------
		# Decide status
		#-------------------------------------------------
		if   [ ${IS_CRIT} == 1 ]; then
			STATUS=0
		elif [ ${IS_WARN} == 1 ]; then
			STATUS=1
		else
			STATUS=2
		fi

		echo "Crit:  " ${IS_CRIT}
		echo "Warn:  " ${IS_WARN}
		echo "Status:" ${STATUS}
		echo ""

		influx -host ${DBSERVER} -username ${USERNAME} -password ${PASSWORD} -database ${DATABASE} -execute "INSERT ${SERIES},host=${HOSTNAME},device=${DEVICE[i]} status=${STATUS}"

	done

	sleep 1800
done
