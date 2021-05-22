#!/bin/sh

# by Ryan Woodson, KJ4NRK <ryan.woodson@protonmail.com>

# created from the work done by Gordon Gibby, KX4Z found here:
# https://qsl.net/n/nf4rc//2020/ShelterWebServerTechnicalDetails.pdf

clear

# script dependency check
if ! [ $(id -u) = 0 ]; then
   echo "This script must be run as root (or sudo)!"
   exit 1
fi

# prompt for user pi password
stty -echo
printf "\\nEnter a new password for the user pi: "
read pass1
printf "\\nRetype Password: "
read pass2
printf "\\n"
stty echo


while ! [ "$pass1" = "$pass2" ]; do
	unset pass2
	stty -echo
	printf "\\nPasswords do not match.\\n\\nEnter password again: "
	read pass1
	printf "\\nRetype password: "
	read pass2
	printf "\\n"
	stty echo
done;

clear

# prompt for user root password
stty -echo
printf "\\nEnter a new password for the user root: "
read pass3
printf "\\nRetype Password: "
read pass4
printf "\\n"
stty echo

while ! [ "$pass3" = "$pass4" ]; do
	unset pass4
	stty -echo
	printf "\\nPasswords do not match.\\n\\nEnter password again: "
	read pass3
	printf "\\nRetype password: "
	read pass4
	printf "\\n"
	stty echo
done;

clear

# assign pi and root password
echo "pi:$pass1" | chpasswd
echo "root:$pass3" | chpasswd

# prompt for FTP port
printf "\\nEnter the port you would like to use for FTP (8000-8999 recommended except 8080): "
read port1
printf "\\nRetype Port Number: "
read port2
printf "\\n"

while ! [ "$port1" = "$port2" ]; do
	unset port2
	printf "\\nPort numbers do not match.\\n\\nEnter port number again: "
	read port1
	printf "\\nRetype port number: "
	read port2
	printf "\\n"
done;

clear

# assign FTP port
echo 'Port '$port1 >> /etc/ssh/sshd_config

# prompt for ARESHAM FTP user password
stty -echo
printf "\\nEnter a new password for the FTP user ARESHAM: "
read ftppass1
printf "\\nRetype Password: "
read ftppass2
printf "\\n"
stty echo

while ! [ "$ftppass1" = "$ftppass2" ]; do
	unset ftppass2
	stty -echo
	printf "\\nPasswords do not match.\\n\\nEnter Password again: "
	read ftppass1
	printf "\\nRetype password: "
	read ftppass2
	printf "\\n"
	stty echo
done;

clear

# prompt for EOC FTP user password
stty -echo
printf "\\nEnter a new password for the FTP user EOC: "
read ftppass3
printf "\\nRetype password: "
read ftppass4
printf "\\n"
stty echo

while ! [ "$ftppass3" = "$ftppass4" ]; do
	unset ftppass3
	stty -echo
	printf "\\nPasswords do not match.\\n\\nEnter password again: "
	read ftppass3
	printf "\\nRetype password: "
	read ftppass4
	printf "\\n"
	stty echo
done;

clear

# update system and install network/web services
apt update
apt upgrade -y
apt install -y apache2 apache2-doc apache2-utils libapache2-mod-php php php-pear
apt install -y dnsmasq

# configure network interface
echo '#iface eth0 inet manual' >> /etc/network/interfaces
echo 'auto eth0' >> /etc/network/interfaces
echo 'iface eth0 inet static' >> /etc/network/interfaces
echo 'address 10.0.0.1' >> /etc/network/interfaces
echo 'netmask 255.255.255.0' >> /etc/network/interfaces

echo 'interface eth0' >> /etc/dhcpcd.conf
echo 'static ip_address=10.0.0.1/24' >> /etc/dhcpd.conf
echo 'static domain_name_servers=10.0.0.1' >> /etc/dhcpcd.conf

# configure DHCP (dnsmasq)
echo 'interface=eth0' >> /etc/dnsmasq.conf
echo 'dhcp-range=10.0.0.10, 10.0.0.254, 255.255.255.0, 24h' >> /etc/dnsmasq.conf
echo 'dhcp-option=6,10.0.0.1' >> /etc/dnsmasq.conf
echo 'no-hosts' >> /etc/dnsmasq.conf
echo 'addn-hosts=/etc/hosts.dnsmasq' >> /etc/dnsmasq.conf

# create and configure DNS entry to webserver
touch /etc/hosts.dnsmasq
echo '10.0.0.1 hamradioband.com' >> /etc/hosts.dnsmasq
echo '10.0.0.1 www.hamradioband.com' >> /etc/hosts.dnsmasq

# install FTP, create users
apt install -y pure-ftpd
groupadd ftpgroup
useradd ftpuser -g ftpgroup -s /sbin/nologin -d /dev/null

mkdir /home/pi/EOC
chown -R ftpuser:ftpgroup /home/pi/EOC
(echo $ftppass3; echo $ftppass3) | pure-pw useradd EOC -u ftpuser -g ftpgroup -d /home/pi/EOC -m
pure-pw mkdb

mkdir /home/pi/ARESHAM
chown -R ftpuser:ftpgroup /home/pi/ARESHAM
(echo $ftppass1; echo $ftppass1) | pure-pw useradd ARESHAM -u ftpuser -g ftpgroup -d /home/pi/ARESHAM
pure-pw mkdb

ln -s /etc/pure-ftpd/conf/PureDB /etc/pure-ftpd/auth/60puredb

rm -r /var/www/html

mkdir /var/www/html
touch /var/www/html/index.html
echo '<html>' >> /var/www/html/index.html
echo '<head>' >> /var/www/html/index.html
echo '<title>Shelter Web Site</title>' >> /var/www/html/index.html
echo '</head>' >> /var/www/html/index.html
echo '<body>' >> /var/www/html/index.html
echo '<h1>Shelter Web Site</h1>' >> /var/www/html/index.html
echo '<p>Content</p>' >> /var/www/html/index.html
echo '</body>' >> /var/www/html/index.html
echo '</html>' >> /var/www/html/index.html

ln -s /home/pi/ARESHAM /var/www/html
ln -s /home/pi/EOC /var/www/html/EOC

service pure-ftpd restart

# remote access restrictions
echo 'ALL:	192.168.' >> /etc/hosts.allow
echo 'ALL:	10.0.0.' >> /etc/hosts.allow
echo 'sshd:	ALL' >> /etc/hosts.allow

# install and configure firewall
apt install ufw
ufw allow $port1/tcp
ufw allow 8080/tcp
ufw allow 80/tcp
ufw allow ftp
ufw allow dns
ufw allow 67/udp
ufw allow 68/udp
ufw enable

clear

printf "Complete. Please reboot for the new settings to take effect.\\n\\n"