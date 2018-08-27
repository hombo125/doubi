#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
cat << "EOF"
 _      __     ______   _      __  
| | /| / /__ _/ / / /  (_)__  / /__
| |/ |/ / _ `/ / / /__/ / _ \/  '_/
|__/|__/\_,_/_/_/____/_/_//_/_/\_\ 
                                  
EOF
echo "Proxy node server installation script for CentOS 7 x64"
[ $(id -u) != "0" ] && { echo "${CFAILURE}Error: You must be root to run this script${CEND}"; exit 1; }
echo "Press Y for continue the installation process, or press any key else to exit."
read is_install
if [[ ${is_install} != "y" && ${is_install} != "Y" ]]; then
    echo -e "Installation has been canceled..."
    exit 0
fi
echo "Updatin exsit package..."
yum clean all && rm -rf /var/cache/yum && yum update -y
echo "Install necessary package..."
yum install epel-release -y && yum makecache
yum install python-pip git net-tools htop ntp -y
yum -y groupinstall "Development Tools"
echo "Disabling firewalld..."
systemctl stop firewalld && systemctl disable firewalld
echo "Setting system timezone..."
timedatectl set-timezone Asia/Taipei && systemctl stop ntpd.service && ntpdate us.pool.ntp.org
echo "Installing libsodium..."
wget https://github.com/jedisct1/libsodium/releases/download/1.0.16/libsodium-1.0.16.tar.gz
tar xf libsodium-1.0.16.tar.gz && cd libsodium-1.0.16
./configure && make -j2 && make install
echo /usr/local/lib > /etc/ld.so.conf.d/usr_local_lib.conf
ldconfig
cd ../ && rm -rf libsodium*
echo "Installing Shadowsocksr server from GitHub..."
mkdir /soft
cd /soft
git clone -b manyuser https://github.com/esdeathlove/shadowsocks.git
cd /soft/shadowsocks
pip install --upgrade pip
pip install -r requirements.txt
echo "Generating config file..."
cp apiconfig.py userapiconfig.py
cp config.json user-config.json
#Choose the connection method
while :; do echo
	echo -e "Please select the way your node server connection method:"
	echo -e "\t1. WebAPI"
	echo -e "\t2. Remote Database"
	read -p "Please input a number:(Default 2 press Enter) " connection_method
	[ -z "${connection_method}" ] && connection_method=2
	if [[ ! "${connection_method}" =~ ^[1-2]$ ]]; then
		echo "Bad answer! Please only input number 1~2"
	else
		break
	fi			
done
while :; do echo
	echo -n "Do you want to enable multi user in single port feature?(Y/N)"
	read is_mu
	if [[ ${is_mu} != "y" && ${is_mu} != "Y" && ${is_mu} != "N" && ${is_mu} != "n" ]]; then
		echo -n "Bad answer! Please only input number Y or N"
	else
		break
	fi
done
do_mu(){
	echo -n "Please enter MU_SUFFIX:"
	read mu_suffix
	echo -n "Please enter MU_REGEX:"
	read mu_regex
	echo "Writting MU config..."
	sed -i -e "s/MU_SUFFIX = 'zhaoj.in'/MU_SUFFIX = '${mu_suffix}'/g" -e "s/MU_REGEX = 'zhaoj.in'/MU_REGEX = '${mu_regex}'/g" userapiconfig.py
}
do_modwebapi(){
	echo -n "Please enter WebAPI url:"
	read webapi_url
	echo -n "Please enter WebAPI token:"
	read webapi_token
	echo -n "Server node ID:"
	read node_id
	if [[ ${is_mu} == "y" || ${is_mu} == "Y" ]]; then
		do_mu
	fi
	echo "Writting connection config..."
	sed -i -e "s/NODE_ID = 1/NODE_ID = ${node_id}/g" -e "s%WEBAPI_URL = 'https://zhaoj.in'%WEBAPI_URL = '${webapi_url}'%g" -e "s/WEBAPI_TOKEN = 'glzjin'/WEBAPI_TOKEN = '${webapi_token}'/g" userapiconfig.py
}
do_glzjinmod(){
	sed -i -e "s/'modwebapi'/'glzjinmod'/g" userapiconfig.py
	echo -n "Please enter DB server's IP address:"
	read db_ip
	echo -n "DB name:"
	read db_name
	echo -n "DB username:"
	read db_user
	echo -n "DB password:"
	read db_password
	echo -n "Server node ID:"
	read node_id
	if [[ ${is_mu} == "y" || ${is_mu} == "Y" ]]; then
		do_mu
	fi
	echo "Writting connection config..."
	sed -i -e "s/NODE_ID = 1/NODE_ID = ${node_id}/g" -e "s/MYSQL_HOST = '127.0.0.1'/MYSQL_HOST = '${db_ip}'/g" -e "s/MYSQL_USER = 'ss'/MYSQL_USER = '${db_user}'/g" -e "s/MYSQL_PASS = 'ss'/MYSQL_PASS = '${db_password}'/g" -e "s/MYSQL_DB = 'shadowsocks'/MYSQL_DB = '${db_name}'/g" userapiconfig.py
}
#Do the configuration
if [ "${connection_method}" == "1" ]; then
	do_modwebapi
elif [ "${connection_method}" == "2" ]; then
	do_glzjinmod
fi
echo "Running system optimization and enable Google BBR..."
rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm
yum remove kernel-headers -y
yum --enablerepo=elrepo-kernel install kernel-ml kernel-ml-headers -y
grub2-set-default 0
echo "tcp_bbr" >> /etc/modules-load.d/modules.conf
cat >> /etc/security/limits.conf << EOF
* soft nofile 51200
* hard nofile 51200
EOF
ulimit -n 51200
cat >> /etc/sysctl.conf << EOF
fs.file-max = 51200
net.core.default_qdisc = fq
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.netdev_max_backlog = 250000
net.core.somaxconn = 4096
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.ip_local_port_range = 10000 65000
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mtu_probing = 1
EOF
sysctl -p
echo "System require a reboot to complete the installation process, press Y to continue, or press any key else to exit this script."
read is_reboot
if [[ ${is_reboot} == "y" || ${is_reboot} == "Y" ]]; then
    reboot
else
    echo -e "Reboot has been canceled..."
    exit 0
fi
