#!/bin/bash

# disable apparmor
[ -d /etc/apparmor.d ] && ln -sfn /etc/apparmor.d/usr.sbin.mysqld /etc/apparmor.d/disabled/usr.sbin.mysqld &> /dev/null

sysctl -w vm.swappiness=0
echo "vm.swappiness = 0" | sudo tee -a /etc/sysctl.conf &> /dev/null

/usr/local/sbin/bootstrap-galera.sh
/usr/sbin/mysqld --init-file=/tmp/init.sql --skip-name-resolve