#!/bin/bash
# Format output from smartctl to zabbix_sender input
# $1 is path for examine device
# $2 type of device is used in smartctld -d paramentr
# $3 hostname of monitoring system, can set to '-', if using -s or -c paramentr in zabbix_sender

DEV_PATH=$1
DEV_TYPE=$2
HOSTNAME=$3
HEADERS=(id attribute_name flag value worst thresh type updated when_failed raw_value)
DEVICE=$(basename $DEV_PATH)
SECTION=''
while IFS='' read -r line; do
	case $line in
		'=== START OF INFORMATION SECTION ===')
			SECTION='INFO'
			continue
		;;
		'=== START OF READ SMART DATA SECTION ===')
			SECTION='HEALF'
			continue
		;;
		'ID#'*)
			SECTION='ATTR'
			continue
		;;
	esac
	case $SECTION in
		'INFO')
			if [ -z "$line" ]; then
				SECTION=''
			else
				IFS=':' read -r -a attribute <<< "$line"
				PRE="$HOSTNAME smartctl.info[$DEVICE,"
				ATTR_V=$( echo ${attribute[1]} | sed -e 's/^[ \t]*//' )
				ATTR_N=$(echo ${attribute[0]} | tr '[:upper:]' '[:lower:]' | sed 's/ /_/' )
				case ${attribute[0]} in
					'Model Family')
						echo "${PRE}$ATTR_N] \"$ATTR_V\""
					;;
					'Device Model')
						echo "${PRE}$ATTR_N] \"$ATTR_V\""
					;;
					'Serial Number')
						echo "${PRE}$ATTR_N] \"$ATTR_V\""
					;;
					'Firmware Version')
						echo "${PRE}$ATTR_N] \"$ATTR_V\""
					;;
					'User Capacity')
						echo "${PRE}$ATTR_N] \"$ATTR_V\""
					;;
					'Sector Size' | 'Sector Sizes')
						ATTR_N=$(echo 'Sector Size' | tr '[:upper:]' '[:lower:]' | sed 's/ /_/' )
						echo "${PRE}$ATTR_N] \"$ATTR_V\""
					;;
					'Rotation Rate')
						echo "${PRE}$ATTR_N] \"$ATTR_V\""
					;;
				esac
			fi
			
		;;
		'HEALF')
			if [ -z "$line" ]; then
				SECTION=''
			else
				IFS=':' read -r -a attribute <<< "$line"
				PRE="$HOSTNAME smartctl.smart[$DEVICE,"
				ATTR=$( echo ${attribute[1]} | sed -e 's/^[ \t]*//' )
				case ${attribute[0]} in
					'SMART overall-health self-assessment test result')
						echo "${PRE}test_result] \"$ATTR\""
					;;
				esac				
			fi
		;;
		'ATTR')
			if [ -z "$line" ]; then
				SECTION=''
			else
				read -r -a attribute <<< "$line"
				PRE="$HOSTNAME smartctl.smart[$DEVICE,"
				for i in "${!attribute[@]}";do
					if [[ $i == 0 ]]; then
						continue
					fi
					case ${attribute[$i]} in
						''|*[!0-9]*) ATTR="\"${attribute[$i]}\"" ;;
						*) ATTR="$(echo ${attribute[$i]} | sed 's/0*//')" ;;
					esac
					if [ -z "$ATTR" ]; then
						ATTR=0
					fi
					echo "${PRE}${attribute[0]},${HEADERS[$i]}] $ATTR"
				done				
			fi
		;;
	esac
done < /dev/stdin
