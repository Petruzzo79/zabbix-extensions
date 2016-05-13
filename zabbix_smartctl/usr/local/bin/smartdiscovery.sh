#!/bin/bash
# require: sg module and sg_map util
# Get know generic scsi device from sg_map or from /usr/local/etc/smartdev.lst (is prefered used),
# and then try to read some S.M.A.R.T. attribue, if success, echo output combination to SDTOUT

#/usr/sbin/modprobe sg
/sbin/modprobe sg

# dev_type so limit? becose i can`t test it on corresponding controller, /usr/local/etc/smartdev.lst can use for set dev_type manual
DEV_TYPE=(sat scsi ata)
DEV_LST='/usr/local/etc/smartdev.lst'
while read -r -a attr; do
	if [ -z "${attr[1]}" ]; then
		DEV=${attr[0]}
	else
		DEV=${attr[1]}
	fi
	for i in "${DEV_TYPE[@]}";do
		/usr/sbin/smartctl -A -d $i $DEV | grep -q 'ID#'
		if [[ $? == 0 ]]; then
			DEV=$(basename $DEV)
			if [ -f $DEV_LST ]; then			
				grep -q $DEV $DEV_LST 
				if [[ $? != 0 ]]; then
					echo "$DEV $i"
				fi
			fi
			break
		fi
	done
done  < <(/usr/bin/sg_map)
if [ -f $DEV_LST ]; then
	cat $DEV_LST
fi
