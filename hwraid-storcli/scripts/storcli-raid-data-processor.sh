#!/usr/bin/env bash
# Author:       Lesovsky A.V.
# Description:  Gathering available information about MegaCLI supported devices.
# Description:  Analyze information and send data to zabbix server.
# Disclaimer:	VERY VERY EXPERIMENTAL. 

PATH="/usr/local/bin:/usr/local/sbin:/sbin:/bin:/usr/sbin:/usr/bin:/opt/bin"

storcli=$(which storcli64)
data_tmp="/run/storcli-raid-data-harvester.tmp"
data_out="/run/storcli-raid-data-harvester.out"
all_keys='/run/keys'
zbx_server=$(grep ^Server= /etc/zabbix/zabbix_agentd.conf |cut -d= -f2|cut -d, -f1)
zbx_hostname=$(grep ^Hostname= /etc/zabbix/zabbix_agentd.conf |cut -d= -f2|cut -d, -f1)
zbx_data='/run/zabbix-sender-storcli-raid-data.in'
adp_list=$(/usr/libexec/zabbix-extensions/scripts/storcli-adp-discovery.sh raw)
ld_list=$(/usr/libexec/zabbix-extensions/scripts/storcli-ld-discovery.sh raw)
pd_list=$(/usr/libexec/zabbix-extensions/scripts/storcli-pd-discovery.sh raw)

echo -n > $data_tmp

# берем список контроллеров и берем с каждого информацию.
echo "### adp section begin ###" >> $data_tmp
for adp in $adp_list; 
  do
    echo "### adp begin $adp ###" >> $data_tmp
    $storcli adpallinfo a$adp nolog >> $data_tmp
    echo "### adp end $adp ###" >> $data_tmp
  done
echo "### adp section end ###" >> $data_tmp

# перебираем все контроллеры и все логические тома на этих контроллерах
echo "### ld section begin ###" >> $data_tmp
  for ld in $ld_list;
    do
      a=$(echo $ld|cut -d: -f1)
      l=$(echo $ld|cut -d: -f2)
      echo "### ld begin $a $l  ###" >> $data_tmp
      $storcli ldinfo l$l a$a nolog >> $data_tmp
      echo "### ld end $a $l ###" >> $data_tmp
    done
echo "### ld section end ###" >> $data_tmp

# перебираем все контроллеры и все физические диски на этих контроллерах
echo "### pd section begin ###" >> $data_tmp
for pd in $pd_list;
  do
    a=$(echo $ld|cut -d: -f1)
    e=$(echo $pd|cut -d: -f2)
    p=$(echo $pd|cut -d: -f3)
    echo "### pd begin $a $e $p ###" >> $data_tmp
    $storcli pdinfo physdrv [$e:$p] a$a nolog >> $data_tmp
    echo "### pd end $a $e $p ###" >> $data_tmp
  done
echo "### pd section end ###" >> $data_tmp

mv $data_tmp $data_out

echo -n > $all_keys
echo -n > $zbx_data

# формируем список ключей для zabbix
for a in $adp_list; 
  do
    echo -n -e "storcli.adp.name[$a]\nstorcli.ld.degraded[$a]\nstorcli.ld.offline[$a]\nstorcli.pd.total[$a]\nstorcli.pd.critical[$a]\nstorcli.pd.failed[$a]\nstorcli.mem.err[$a]\nstorcli.mem.unerr[$a]\n"; 
  done >> $all_keys

for l in $ld_list;
  do
    echo -n -e "storcli.ld.state[$l]\n";
  done >> $all_keys

for p in $pd_list;
  do
    echo -n -e "storcli.pd.media_error[$p]\nstorcli.pd.other_error[$p]\nstorcli.pd.pred_failure[$p]\nstorcli.pd.state[$p]\nstorcli.pd.temperature[$p]\n";
  done >> $all_keys

cat $all_keys | while read key; do
  if [[ "$key" == *storcli.adp.name* ]]; then
     adp=$(echo $key |grep -o '\[.*\]' |tr -d \[\] |cut -d, -f1)
     value=$(sed -n -e "/adp begin $adp/,/adp end $adp/p" $data_out |grep -m1 -w "Product Name" |cut -d: -f2)
     echo "\"$zbx_hostname\" $key $value" >> $zbx_data
  fi
  if [[ "$key" == *storcli.ld.degraded* ]]; then
     adp=$(echo $key |grep -o '\[.*\]' |tr -d \[\] |cut -d, -f1)
     value=$(sed -n -e "/adp begin $adp/,/adp end $adp/p" $data_out |grep -A1 -m1 -w "Virtual Drives" |grep -w "Degraded" |cut -d: -f2 |tr -d " ")
     echo "\"$zbx_hostname\" $key $value" >> $zbx_data
  fi
  if [[ "$key" == *storcli.ld.offline* ]]; then
     adp=$(echo $key |grep -o '\[.*\]' |tr -d \[\] |cut -d, -f1)
     value=$(sed -n -e "/adp begin $adp/,/adp end $adp/p" $data_out |grep -A2 -m1 -w "Virtual Drives" |grep -w "Offline" |cut -d: -f2 |tr -d " ")
     echo "\"$zbx_hostname\" $key $value" >> $zbx_data
  fi
  if [[ "$key" == *storcli.pd.total* ]]; then
     adp=$(echo $key |grep -o '\[.*\]' |tr -d \[\] |cut -d, -f1)
     value=$(sed -n -e "/adp begin $adp/,/adp end $adp/p" $data_out |grep -A1 -m1 -w "Physical Devices" |grep -w "Disks" |cut -d: -f2 |tr -d " ")
     echo "\"$zbx_hostname\" $key $value" >> $zbx_data
  fi
  if [[ "$key" == *storcli.pd.critical* ]]; then
     adp=$(echo $key |grep -o '\[.*\]' |tr -d \[\] |cut -d, -f1)
     value=$(sed -n -e "/adp begin $adp/,/adp end $adp/p" $data_out |grep -A2 -m1 -w "Physical Devices" |grep -w "Critical Disks" |cut -d: -f2 |tr -d " ")
     echo "\"$zbx_hostname\" $key $value" >> $zbx_data
  fi
  if [[ "$key" == *storcli.pd.failed* ]]; then
     adp=$(echo $key |grep -o '\[.*\]' |tr -d \[\] |cut -d, -f1)
     value=$(sed -n -e "/adp begin $adp/,/adp end $adp/p" $data_out |grep -A3 -m1 -w "Physical Devices" |grep -w "Failed Disks" |cut -d: -f2 |tr -d " ")
     echo "\"$zbx_hostname\" $key $value" >> $zbx_data
  fi
  if [[ "$key" == *storcli.mem.err* ]]; then
     adp=$(echo $key |grep -o '\[.*\]' |tr -d \[\] |cut -d, -f1)
     value=$(sed -n -e "/adp begin $adp/,/adp end $adp/p" $data_out |grep -m1 -w "Memory Correctable Errors" |cut -d: -f2 |tr -d " ")
     echo "\"$zbx_hostname\" $key $value" >> $zbx_data
  fi
  if [[ "$key" == *storcli.mem.unerr* ]]; then
     adp=$(echo $key |grep -o '\[.*\]' |tr -d \[\] |cut -d, -f1)
     value=$(sed -n -e "/adp begin $adp/,/adp end $adp/p" $data_out |grep -m1 -w "Memory Uncorrectable Errors" |cut -d: -f2 |tr -d " ")
     echo "\"$zbx_hostname\" $key $value" >> $zbx_data
  fi
  if [[ "$key" == *storcli.ld.state* ]]; then
     adp=$(echo $key |grep -o '\[.*\]' |tr -d \[\] |cut -d: -f1)
     enc=$(echo $key |grep -o '\[.*\]' |tr -d \[\] |cut -d: -f2)
     value=$(sed -n -e "/ld begin $adp $enc/,/ld end $adp $enc/p" $data_out |grep -m1 -w "^State" |cut -d: -f2 |tr -d " ")
     echo "\"$zbx_hostname\" $key $value" >> $zbx_data
  fi
  if [[ "$key" == *storcli.pd.media_error* ]]; then
     adp=$(echo $key |grep -o '\[.*\]' |tr -d \[\] |cut -d: -f1)
     enc=$(echo $key |grep -o '\[.*\]' |tr -d \[\] |cut -d: -f2)
     pd=$(echo $key |grep -o '\[.*\]' |tr -d \[\] |cut -d: -f3)
     value=$(sed -n -e "/pd begin $adp $enc $pd/,/ld end $adp $enc $pd/p" $data_out |grep -m1 -w "^Media Error Count:" |cut -d: -f2 |tr -d " ")
     echo "\"$zbx_hostname\" $key $value" >> $zbx_data
  fi
  if [[ "$key" == *storcli.pd.other_error* ]]; then
     adp=$(echo $key |grep -o '\[.*\]' |tr -d \[\] |cut -d: -f1)
     enc=$(echo $key |grep -o '\[.*\]' |tr -d \[\] |cut -d: -f2)
     pd=$(echo $key |grep -o '\[.*\]' |tr -d \[\] |cut -d: -f3)
     value=$(sed -n -e "/pd begin $adp $enc $pd/,/ld end $adp $enc $pd/p" $data_out |grep -m1 -w "^Other Error Count:" |cut -d: -f2 |tr -d " ")
     echo "\"$zbx_hostname\" $key $value" >> $zbx_data
  fi
  if [[ "$key" == *storcli.pd.pred_failure* ]]; then
     adp=$(echo $key |grep -o '\[.*\]' |tr -d \[\] |cut -d: -f1)
     enc=$(echo $key |grep -o '\[.*\]' |tr -d \[\] |cut -d: -f2)
     pd=$(echo $key |grep -o '\[.*\]' |tr -d \[\] |cut -d: -f3)
     value=$(sed -n -e "/pd begin $adp $enc $pd/,/ld end $adp $enc $pd/p" $data_out |grep -m1 -w "^Predictive Failure Count:" |cut -d: -f2 |tr -d " ")
     echo "\"$zbx_hostname\" $key $value" >> $zbx_data
  fi
  if [[ "$key" == *storcli.pd.state* ]]; then
     adp=$(echo $key |grep -o '\[.*\]' |tr -d \[\] |cut -d: -f1)
     enc=$(echo $key |grep -o '\[.*\]' |tr -d \[\] |cut -d: -f2)
     pd=$(echo $key |grep -o '\[.*\]' |tr -d \[\] |cut -d: -f3)
     value=$(sed -n -e "/pd begin $adp $enc $pd/,/ld end $adp $enc $pd/p" $data_out |grep -m1 -w "^Firmware state:" |cut -d" " -f3 |tr -d ,)
     echo "\"$zbx_hostname\" $key $value" >> $zbx_data
  fi
  if [[ "$key" == *storcli.pd.temperature* ]]; then
     adp=$(echo $key |grep -o '\[.*\]' |tr -d \[\] |cut -d: -f1)
     enc=$(echo $key |grep -o '\[.*\]' |tr -d \[\] |cut -d: -f2)
     pd=$(echo $key |grep -o '\[.*\]' |tr -d \[\] |cut -d: -f3)
     value=$(sed -n -e "/pd begin $adp $enc $pd/,/ld end $adp $enc $pd/p" $data_out |grep -m1 -w "^Drive Temperature" |awk '{print $3}' |grep -oE '[0-9]+')
     echo "\"$zbx_hostname\" $key $value" >> $zbx_data
  fi
  done

zabbix_sender -z $zbx_server -i $zbx_data &> /dev/null
