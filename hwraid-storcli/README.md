Zabbix template for Storecli
============================

Install guide
-------------
Copy content of Script directory into the host on:

`/usr/libexec/zabbix-extensions/scripts/`

Copy `storecli.conf` in host:

`/etc/zabbix/zabbixagent.conf.d/`

Set cron copy `zabbix.storcli` in host:

`/etc/cron.d/`

Add the line

`zabbix ALL=(ALL) NOPASSWD:/usr/libexec/zabbix-extensions/scripts/`
 in sudoers file
 
Import **hwraid-storcli-template.xml** in zabbix Server

> nb. you must set "Hostname" parameter in zabbix_agentd.conf file (must be the same of the Host on the Zabbix Server)
> nb2. must be installed sudo 