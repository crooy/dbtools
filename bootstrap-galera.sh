#!/bin/bash

# Bootstrap Galera Cluster for MySQL.
# Copyright (C) 2012  Alexander Yu <alex@alexyu.se>

# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

rel_dir=`dirname "$0"`
root_dir=`cd $rel_dir;pwd`
root_dir=${root_dir%/*}
echo "root_dir=$root_dir"
cd $root_dir/galera

shopt -s expand_aliases
alias sed="sed -i"
[[ $OSTYPE =~ ^darwin ]] && alias sed="sed -i ''"

datadir=/var/lib/mysql
rundir=/var/run/mysqld
innodb_buffer_pool_size=2G
innodb_log_file_size=1G
my_cnf=/etc/mysql/my.cnf
mysql_service=mysql
stop_fw="service ufw stop"
stop_fw_redhat="service iptables stop"

wsrep_cluster_name=my_galera_cluster
wsrep_sst_method=rsync
wsrep_slave_threads=1

os=ubuntu
user="$USER"
ssh_key="$HOME/.ssh/id_rsa.pub"
port=22

stagingdir=.stage
hosts=""
[ -e etc/config ] && . etc/config
[ -e $stagingdir/etc/hosts ] && hosts=($(cat $stagingdir/etc/hosts))

wsrep_provider=/usr/lib/galera/libgalera_smm.so
wsrep_provider_redhat=/usr/lib64/galera/libgalera_smm.so

ask() {
  read -p "$1" x
  [ -z "$x" ] || [[ "$x" == ["$2${2^^}"] ]] && return 0
  return 1
}

gen_scripts() {

  read -p "InnoDB buffer pool size ($innodb_buffer_pool_size): " x
  [ ! -z "$x" ] && innodb_buffer_pool_size=$x

  read -p "InnoDB log file size ($innodb_log_file_size): " x
  [ ! -z "$x" ] && innodb_log_file_size=$x

  # modify my.cnf
  etcdir=/etc/mysql
  sed "s|^innodb_buffer_pool_size.*=*|innodb_buffer_pool_size = $innodb_buffer_pool_size|" $etcdir/my.cnf
  sed "s|^innodb_log_file_size.*=*|innodb_log_file_size = $innodb_log_file_size|" $etcdir/my.cnf

  read -p "Where are your Galera hosts (${hosts[*]}) [ip1 ip2 ... ipN]: " x
  [ ! -z "$x" ] && hosts=($x)

  wsrep_cluster_address="gcomm://${hosts[*]}"

  sed "s|^.*wsrep_cluster_address.*=.*|wsrep_cluster_address = $wsrep_cluster_address|" $etcdir/my.cnf
  sed "s|^wsrep_provider.*=.*|wsrep_provider = $wsrep_provider|" $etcdir/my.cnf

  read -p "What is the current node name($wsrep_node_name): " x
  [ ! -z $x ] && wsrep_node_name=$x

  read -p "What is the current node IP($wsrep_node_address): " x
  [ ! -z $x ] && wsrep_node_address=$x

  read -p "Name your Galera Cluster ($wsrep_cluster_name): " x
  [ ! -z $x ] && wsrep_cluster_name=$x

  read -p "SST method [rsync|xtrabackup] ($wsrep_sst_method): " x
  [ ! -z $x ] && wsrep_sst_method=$x

  read -p "Writeset slaves/parallel replication ($wsrep_slave_threads): " x
  [ ! -z $x ] && wsrep_slave_threads=$x

  sed -i "s|^.*wsrep_node_address.*=.*|wsrep_node_address = $wsrep_node_address|" ~/galera/etc/my.cnf
  sed -i "s|^.*wsrep_node_name.*=.*|wsrep_node_name = $wsrep_node_name|" ~/galera/etc/my.cnf
  sed "s|^wsrep_cluster_name.*=.*|wsrep_cluster_name = $wsrep_cluster_name|" $etcdir/my.cnf
  sed "s|^wsrep_sst_method.*=.*|wsrep_sst_method = $wsrep_sst_method|" $etcdir/my.cnf
  sed "s|^wsrep_slave_threads.*=.*|wsrep_slave_threads = $wsrep_slave_threads|" $etcdir/my.cnf

  read -p "Do you want to secure your Galera cluster (y/N): " x
  if [[ "$x" == ["yY"] ]]
  then
    read -p "Enter a new MySQL root password: " x
    cat > "/tmp/secure.sql" << EOF
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test; DELETE FROM mysql.db WHERE DB='test' OR DB='test\\_%';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' IDENTIFIED BY '$x' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' IDENTIFIED BY '$x' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF
  fi

}

# main

gen_scripts
