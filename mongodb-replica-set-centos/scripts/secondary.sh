#!/bin/bash

replSetName=$1
zabbixServer=$2



disk_format() {
	cd /tmp
	yum install wget -y
	for ((j=1;j<=3;j++))
	do
		wget https://raw.githubusercontent.com/JolokiaCorporation/azure-quickstart-templates/master/mongodb-sharding-centos/scripts/vm-disk-utils-0.1.sh
		if [[ -f /tmp/vm-disk-utils-0.1.sh ]]; then
			bash /tmp/vm-disk-utils-0.1.sh -b /var/lib/mongo -s
			if [[ $? -eq 0 ]]; then
				sed -i 's/disk1//' /etc/fstab
				umount /var/lib/mongo/disk1
				mount /dev/md0 /var/lib/mongo
			fi
			break
		else
			echo "download vm-disk-utils-0.1.sh failed. try again."
			continue
		fi
	done

}


install_mongo4() {
#create repo
cat > /etc/yum.repos.d/mongodb-org-4.4.repo <<EOF
[mongodb-org-4.4]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/\$releasever/mongodb-org/4.4/x86_64/
gpgcheck=0
enabled=1
EOF

	#install
	yum install -y mongodb-org

	#ignore update
	sed -i '$a exclude=mongodb-org,mongodb-org-server,mongodb-org-shell,mongodb-org-mongos,mongodb-org-tools' /etc/yum.conf

	#disable selinux
	sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/sysconfig/selinux
	sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
	setenforce 0

	#kernel settings
	if [[ -f /sys/kernel/mm/transparent_hugepage/enabled ]];then
		echo never > /sys/kernel/mm/transparent_hugepage/enabled
	fi
	if [[ -f /sys/kernel/mm/transparent_hugepage/defrag ]];then
		echo never > /sys/kernel/mm/transparent_hugepage/defrag
	fi

	#configure
	sed -i 's/\(bindIp\)/#\1/' /etc/mongod.conf

	#set keyfile
	echo "vfr4CDE1" > /etc/mongokeyfile
	chown mongod:mongod /etc/mongokeyfile
	chmod 600 /etc/mongokeyfile
	sed -i 's/^#security/security/' /etc/mongod.conf
	sed -i '/^security/akeyFile: /etc/mongokeyfile' /etc/mongod.conf
	sed -i 's/^keyFile/  keyFile/' /etc/mongod.conf

}


install_zabbix() {
	#install zabbix agent
	cd /tmp
	yum install -y gcc wget > /dev/null
	wget http://jaist.dl.sourceforge.net/project/zabbix/ZABBIX%20Latest%20Stable/2.2.5/zabbix-2.2.5.tar.gz > /dev/null
	tar zxvf zabbix-2.2.5.tar.gz
	cd zabbix-2.2.5
	groupadd zabbix
	useradd zabbix -g zabbix -s /sbin/nologin
	mkdir -p /usr/local/zabbix
	./configure --prefix=/usr/local/zabbix --enable-agent
	make install > /dev/null
	cp misc/init.d/fedora/core/zabbix_agentd /etc/init.d/
	sed -i 's/BASEDIR=\/usr\/local/BASEDIR=\/usr\/local\/zabbix/g' /etc/init.d/zabbix_agentd
	sed -i '$azabbix-agent    10050/tcp\nzabbix-agent    10050/udp' /etc/services
	sed -i '/^LogFile/s/tmp/var\/log/' /usr/local/zabbix/etc/zabbix_agentd.conf
	hostName=`hostname`
	sed -i "s/^Hostname=Zabbix server/Hostname=$hostName/" /usr/local/zabbix/etc/zabbix_agentd.conf
	if [[ $zabbixServer =~ ([0-9]{1,3}.){3}[0-9]{1,3} ]];then
		sed -i "s/^Server=127.0.0.1/Server=$zabbixServer/" /usr/local/zabbix/etc/zabbix_agentd.conf
		sed -i "s/^ServerActive=127.0.0.1/ServerActive=$zabbixServer/" /usr/local/zabbix/etc/zabbix_agentd.conf
		sed -i "s/^Server=127.0.0.1/Server=$zabbixServer/" /usr/local/zabbix/etc/zabbix_agent.conf
	fi
	touch /var/log/zabbix_agentd.log
	chown zabbix:zabbix /var/log/zabbix_agentd.log

	#start zabbix agent
	chkconfig --add zabbix_agentd
	chkconfig zabbix_agentd on
	/etc/init.d/zabbix_agentd start

}

configure_tls() {
cat > /etc/mongod.pem <<EOF
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEA35kpki5roVWq5GBRzV818zg/i6xbPW2HxAwZTNGBQ4rG9nME
jqnPaJB3wB5fgGiyVZPzPGB+YTYT4Cc+Kr40AgqRj11R5tba07CV3ziRR0IBHzHS
kSgqS9Xob8MlICXVEey/ukC5qM2CIo2FNQooi25v93fIYFIQxDX/U9sdVs3EPjap
U/kBYGwWchFjrJbtUw078I8Wvs54vLkhZooI3DJKYkw7OLhyvru58e+PgKpZ3UAT
F/Jvp0d3pEfmeLfIadvg0+o9B13SXSFA0aDTKGDH/7TmBEkcmi14xbF7HroBQ6oJ
/0AUdcShvyy2ENDKrqNYwommDG7FvwhrCY/adQIDAQABAoIBAQCgzenTs4a8NHv+
Wjb6V+rYzC8HKCFGACuPlpPrZxBrnraQLw+r+fur25oDlNRh6Om4GfroBQ1epCGP
JynSW4/Tl/4u+JIaTZJ6g5iFPI1ejd14rcAdnKEugNv05Icio5KknXsVW88p0wIw
D08pYfDetcHYW1DD1MEyGxNRH1fuQBzYb4rrWY/qR5dOcnod2G/BNNjAHd9PaIb4
pXQOlCAfXjAnkE6t/krnQIdEMuKqWQVlJ1bMYaDk6rsHty82V7oEIMjmHcuA98Up
zKqe0UeAbV49jzeb+EFjFUhDx/Li7bd4qzJOo1CKFOwNSG9n6wsWP6xL3yw4CSIU
7BzUdpOBAoGBAPn72wJHniqpF0l+EX2QAdN9TrtROHgm1xMx69VsKmqxHKoPGzg9
vg9MWc+xRL2xnsjLKxjJ2QWXzIEjDBHHQLbBZJ2lYq/2JNmm8o5OVfqhFDW9Yv/i
pZ0HdhzHV4z1UwwlSmMnkh+0Ry9u6/RZHxxv3469efAaK525qvD1ckW5AoGBAOT6
vw2wXQl9vNxNb867hH5PTI89KkH3whbdfVcqtp3d7BENg1HxU4xIoLY8cNEVyZXn
XT1J3D+BuAOMioHdVgsN2M68NpciG5YLXGgwtiklLcVSTXBQhkp6Uy7teAdC+H0G
X5eUqsRMfIW/GPNWm6fZxDAoPS7mhdgk6+H4X9idAoGAUJU1Zii7/biAPzqaXMV9
MTWlmZB3CZRLpG5lPWkey0HIobE47wpIKBpOoTrdk+Cb9NI5VEZM5Ran38DydRCr
9b2lt4PGqj5IZrkAW4s5AA/IugIQ1bez90iedGx19oRmfvXOYuQwoHO2tr2k5iGM
e9g8UoEVu6ZUBQYC6qXUblECgYBQFzB6TkTMjBFiESfZbJd0QrJpq6A7QLi/nKs5
sPP9FeF7OXnEUJ/DgqfL9ioTyAYhi7J+PHZwNCQ0AZV0xQFSjn5WGVkS1dhGTCT/
QIKGs71ltlrlvRSrukucL217RL57pJ4M+/AbBxHLCkNk4ddCB5Zqrbhwzirkpk1n
VaPYtQKBgGuuLWE8cTk2MdPFXgNxzxaoqi9QbAWAg7JbArG927J59I10iz8nL8x9
Fino9MNrhl6yg0Y+5EOQQljUSRXRnvrj15+xxHPfkx5COP0ogPRjMu0TKJ0V1gRa
jyNTo2K/I0lkoYb99VVYG668ZggXFbNgtcqetvlwc4ua+i04ePRY
-----END RSA PRIVATE KEY-----
-----BEGIN CERTIFICATE-----
MIIDTDCCAjQCCQD6XFmoQlJqUjANBgkqhkiG9w0BAQsFADBoMQswCQYDVQQGEwJV
UzETMBEGA1UECAwKQ2FsaWZvcm5pYTETMBEGA1UEBwwKU2FudGEgQ3J1ejENMAsG
A1UECgwEU2VsZjEMMAoGA1UECwwDT3BzMRIwEAYDVQQDDAlsb2NhbGhvc3QwHhcN
MTgwMzA1MjM0NjU3WhcNMjgwMzAyMjM0NjU3WjBoMQswCQYDVQQGEwJVUzETMBEG
A1UECAwKQ2FsaWZvcm5pYTETMBEGA1UEBwwKU2FudGEgQ3J1ejENMAsGA1UECgwE
U2VsZjEMMAoGA1UECwwDT3BzMRIwEAYDVQQDDAlsb2NhbGhvc3QwggEiMA0GCSqG
SIb3DQEBAQUAA4IBDwAwggEKAoIBAQDfmSmSLmuhVarkYFHNXzXzOD+LrFs9bYfE
DBlM0YFDisb2cwSOqc9okHfAHl+AaLJVk/M8YH5hNhPgJz4qvjQCCpGPXVHm1trT
sJXfOJFHQgEfMdKRKCpL1ehvwyUgJdUR7L+6QLmozYIijYU1CiiLbm/3d8hgUhDE
Nf9T2x1WzcQ+NqlT+QFgbBZyEWOslu1TDTvwjxa+zni8uSFmigjcMkpiTDs4uHK+
u7nx74+AqlndQBMX8m+nR3ekR+Z4t8hp2+DT6j0HXdJdIUDRoNMoYMf/tOYESRya
LXjFsXseugFDqgn/QBR1xKG/LLYQ0Mquo1jCiaYMbsW/CGsJj9p1AgMBAAEwDQYJ
KoZIhvcNAQELBQADggEBAK/MXW0VjAP0VZWz9yXH22kTg5FRyu88g7A9MJrqqd8y
wrbOVC/JKIfRvXQPLVBeravmR4OoC0wWSHt2BTJ6tNa/34eeVN/OL0/7wbAfqU4y
WGRiYPYOWS+8BHW4++M7UJE+iVltWIXQ/rMgDynB4+/tMm41rdNupvjLMM/ExNN/
gPNEpfvX2eeuihX2Jnnr1g9yl/sYKHc7v5GAPBtUzPlxGXAyjKd+pLhJSl1fruP6
MlItEv1ZkZj5G+3jJDFPshdGFxCAOpOUCL6qNzuN6DtCF18BhHfHT8fpbJTsLrkU
VAfh0dacQSKnaUIICvgFqAhJEslEzkzNU0eaeRt2Woc=
-----END CERTIFICATE-----
EOF

    sed -i '/^# network inter.*/d' /etc/mongod.conf
	sed -i '/^net/d' /etc/mongod.conf
	sed -i '/^  port/d' /etc/mongod.conf
	sed -i '/^  #bindIp.*/d' /etc/mongod.conf
    echo "# network inferfaces" >> /etc/mongod.conf
	echo "net:" >> /etc/mongod.conf
	echo "  port: 27017" >> /etc/mongod.conf
	echo "  tls:" >> /etc/mongod.conf
	echo "    mode: preferTLS" >> /etc/mongod.conf
	echo "    certificateFile: /etc/mongod.pem" >> /etc/mongod.conf

}

install_mongo4
disk_format
#install_zabbix
#set tls
configure_tls

#start replica set
mongod --dbpath /var/lib/mongo/ --config /etc/mongod.conf --replSet $replSetName --logpath /var/log/mongodb/mongod.log --fork --bind_ip_all


#check if mongod started or not
sleep 15
n=`ps -ef |grep "mongod --dbpath /var/lib/mongo/" |grep -v grep|wc -l`
if [[ $n -eq 1 ]];then
    echo "replica set started successfully"
else
    echo "replica set started failed!"
fi


#set mongod auto start
cat > /etc/init.d/mongod1 <<EOF
#!/bin/bash
#chkconfig: 35 84 15
#description: mongod auto start
. /etc/init.d/functions

Name=mongod1
start() {
if [[ ! -d /var/run/mongodb ]];then
mkdir /var/run/mongodb
chown -R mongod:mongod /var/run/mongodb
fi
mongod --dbpath /var/lib/mongo/ --replSet $replSetName --logpath /var/log/mongodb/mongod.log --fork --config /etc/mongod.conf --bind_ip_all
}
stop() {
pkill mongod
}
restart() {
stop
sleep 15
start
}

case "\$1" in
    start)
	start;;
	stop)
	stop;;
	restart)
	restart;;
	status)
	status \$Name;;
	*)
	echo "Usage: service mongod1 start|stop|restart|status"
esac
EOF
chmod +x /etc/init.d/mongod1
chkconfig mongod1 on
