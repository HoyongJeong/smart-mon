#!/bin/bash

################################################################################
#   < SmartMon.sh >
#
#   Script for recording S.M.A.R.T. attributes to influxDB server.
#
#                                          - Hoyong Jeong (hoyong5419@gmai.com)
################################################################################

##################################################
# influxDB
##################################################
DBSERVER='foo'
USERNAME='bar'
PASSWORD='foo'
DATABASE='bar'
SERIES='smart'

##################################################
# Critical threshold table
##################################################
declare -A THR_CRIT
#THR_CRIT[1]=1
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
# STEP 1: Scan list of SMART devices
##################################################
readarray LIST < <(smartctl --scan-open)
LEN_LIST=${#LIST[@]}

#-------------------------------------------------
# Debug printing
#-------------------------------------------------
echo "< List of Devices >"
for (( i=0; i<${LEN_LIST}; i++ )); do
	echo ${LIST[i]}
done
echo ""


##################################################
# STEP 2: Are these drives smart supported?
##################################################
echo "< SMART Availability Check >"
declare -A SMART_SUPPORT
for (( i=0; i<${LEN_LIST}; i++ )); do
	DEVICE=(${LIST[$i]})
	if [ ${DEVICE[0]} = "#" ]; then
		SMART_SUPPORT[$i]="Unavailable"
	else
		RAW=(`smartctl -i ${DEVICE[0]} ${DEVICE[1]} ${DEVICE[2]} | grep "SMART support is" | head -n 1`)
		SMART_SUPPORT[$i]=${RAW[3]}
	fi
	echo ${DEVICE[0]}, ${DEVICE[2]} is ${SMART_SUPPORT[$i]}
done
echo ""


##################################################
# STEP 3: Check SMART attributes and send query regularly
##################################################
while :; do
	#-------------------------------------------------
	# Initialize
	#-------------------------------------------------
	N_DEVI=0
	N_OKAY=0
	N_WARN=0
	N_CRIT=0

	#-------------------------------------------------
	# Inspect devices
	#-------------------------------------------------
	for (( i=0; i<${LEN_LIST}; i++ )); do
		# Unavailable case
		if   [ -z ${SMART_SUPPORT[$i]} ] || [ ${SMART_SUPPORT[$i]} = "Unavailable" ]; then
			echo ${LIST[$i]} "is unavailable for SMART. Skip inspecting this device."
			continue
		# Available case
		elif [ ${SMART_SUPPORT[$i]} = "Available"   ]; then
			echo "For" ${LIST[$i]},
			DEVICE=(${LIST[$i]})
			RESULT=(`./smarter/smarter.sh ${DEVICE[0]} ${DEVICE[1]} ${DEVICE[2]}`)
			if [ $? -ne 0 ]; then
				echo "Error accured"
			exit 1
			fi
		fi

		LEN2=${#RESULT[@]}
		IS_CRIT=0
		IS_WARN=0
		for (( j=0; j<$((${LEN2}/2)); j++ )); do
			ID[j]=${RESULT[$((j*2))]}
			VAL[j]=${RESULT[$((j*2+1))]}
			echo ${ID[j]} ${VAL[j]}

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


		# Count
		N_DEVI=$((N_DEVI+1))
		if   [ ${IS_CRIT} == 1 ]; then
			N_CRIT=$((N_CRIT+1))
		elif [ ${IS_WARN} == 1 ]; then
			N_WARN=$((N_WARN+1))
		else
			N_OKAY=$((N_OKAY+1))
		fi
	done

	#-------------------------------------------------
	# Declare status
	#-------------------------------------------------
	if   [ $N_CRIT -ne 0 ]; then
		STATUS=0
	elif [ $N_WARN -ne 0 ]; then
		STATUS=1
	else
		STATUS=2
	fi

	echo "< Summary >"
	echo $N_DEVI devices inpected
	echo "# of Crit: " $N_CRIT
	echo "# of Warn: " $N_WARN
	echo "# of Okay: " $N_OKAY
	echo "Status = " $STATUS
	echo ""

	#-------------------------------------------------
	# Influx
	#-------------------------------------------------
	influx -host ${DBSERVER} -username ${USERNAME} -password ${PASSWORD} -database ${DATABASE} -execute "INSERT ${SERIES},host=${HOSTNAME} status=${STATUS},ndev=$N_DEVI,ncrit=$N_CRIT,nwarn=$N_WARN,nokay=$N_OKAY"

	unset RESULT

	sleep 1800
done
