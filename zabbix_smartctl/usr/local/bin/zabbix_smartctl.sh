#!/bin/bash
# Sending collected data to the zabbix server
# Get device list and type from STDIN, produced by smartdiscovery.sh

PREFIX='/usr/local/bin'
AGENT_CFG='/etc/zabbix/zabbix_agentd.conf'
while IFS=' ' read -r -a attr; do
	smartctl -A -H -i -d ${attr[1]} /dev/${attr[0]} | $PREFIX/smart2zabbix.sh /dev/${attr[0]} ${attr[1]} - | /usr/bin/zabbix_sender -c $AGENT_CFG -i -
done < /dev/stdin
