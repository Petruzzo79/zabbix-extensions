#!/bin/bash
# Formating discovering device list to JSON format for zabbix

echo -e "{\n\t\"data\":["
LN=0
while IFS=' ' read -r -a attribute; do	
	if [[ $LN != 0 ]]; then
		echo ","
	fi
	echo -e "\t\t{ \"{#DEVNAME}\":\"${attribute[0]}\", \"{#DEVTYPE}\":\"${attribute[1]}\" }\c"
	LN=1
done  < /dev/stdin
echo -e "\n\t]\n}"
