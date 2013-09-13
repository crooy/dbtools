FROM ubuntu:12.04
MAINTAINER developers of Withlocals "developers@withlocals.com"

# first setup the correct apt-get sources
RUN echo deb http://archive.ubuntu.com/ubuntu/ precise main universe > /etc/apt/sources.list.d/precise.list
RUN apt-get update
RUN apt-get -y upgrade
RUN apt-get -y install software-properties-common python-software-properties
RUN apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xcbcb082a1bb943db
RUN add-apt-repository 'deb http://mirror.1000mbps.com/mariadb/repo/5.5/ubuntu precise main'
RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive  apt-get -y upgrade

# install galera and maria
RUN DEBIAN_FRONTEND=noninteractive apt-get -y autoremove
RUN DEBIAN_FRONTEND=noninteractive apt-get -y autoclean
RUN DEBIAN_FRONTEND=noninteractive apt-get install --force-yes -y mariadb-galera-server galera rsync libssl0.9.8 psmisc libaio1 rsync netcat netcat-traditional wget

ADD etc/my.cnf /etc/mysql/my.cnf
ADD bootstrap-galera.sh /usr/local/sbin/bootstrap-galera.sh
ADD start.sh /usr/local/sbin/start.sh

#setup supervisord
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install supervisor
RUN mkdir -p /var/log/supervisor
ADD supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 3306:3306
EXPOSE 4567:4567
EXPOSE 4444:4444
EXPOSE 4568:4568

ENTRYPOINT start.sh
