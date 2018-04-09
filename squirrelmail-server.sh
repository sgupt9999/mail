#!/bin/bash
# Setting up a squirrelmail server on Centos/RHEL with postfix and dovecot

# User inputs
SERVERIP=35.164.117.47
NETWORK="172.31.21.38/16"
HOSTNAME="mail.mylabserver.com"
DOMAIN="mylabserver.com"

# firewalld should be up and running. this is just to add the mail service to an already running service
FIREWALL="yes"
#FIREWALL="no"

# End of user inputs

PACKAGES="postfix dovecot squirrelmail"

if [[ $EUID != "0" ]]
then
	echo "ERROR. Need to be user to run this script"
	exit 1
fi


hostnamectl set-hostname $HOSTNAME
echo "$SERVERIP $HOSTNAME" >> /etc/hosts

#yum -y -q -e0 update

# Install epel repo
yum install -y -q -e0 https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

yum remove -y -q -e0 sendmail postfix dovecot php-mbstring squirrelmail > /dev/null 2>&1
rm -rf /var/spool/postfix
rm -rf /etc/pki/docvecot
rm -rf /var/lib/dovecot

if yum list installed httpd
then
	echo "Apache already installed"
else
	echo "Installing Apache..................."
	yum install -y -q -e0 httpd
	echo "Done"
fi


# squirrelmail needs php-mbstring which not be included in the repolist
rm -rf /tmp/tmp.rpm
wget -O /tmp/tmp.rpm https://rpmfind.net/linux/centos/7.4.1708/updates/x86_64/Packages/php-mbstring-5.4.16-43.el7_4.1.x86_64.rpm 
yum install -y -q -e0 /tmp/tmp.rpm 

echo "Installing $PACKAGES........"
yum install -y -q -e0 $PACKAGES
echo "Done"

# Update the postfix config file
line_number=`grep -n ^#myhostname /etc/postfix/main.cf | head -n 1 | cut -d":" -f1`
sed -i "${line_number}imyhostname = $HOSTNAME" /etc/postfix/main.cf
line_number=`grep -n ^#mydomain /etc/postfix/main.cf | head -n 1 | cut -d":" -f1`
sed -i "${line_number}imydomain = $DOMAIN" /etc/postfix/main.cf
line_number=`grep -n ^#myorigin /etc/postfix/main.cf | head -n 1 | cut -d":" -f1`
sed -i "${line_number}imyorigin = \$mydomain" /etc/postfix/main.cf
sed -i "s/^inet_interfaces.*/inet_interfaces = all/" /etc/postfix/main.cf
sed -i "s/^#inet_protocols = all/inet_protocols = all/" /etc/postfix/main.cf
sed -i "0,/^mydestination/s/\(mydestination.*\)/& , \$mydomain/" /etc/postfix/main.cf
line_number=`grep -n ^"#mynetworks " /etc/postfix/main.cf | head -n 1 | cut -d":" -f1`
sed -i "${line_number}imynetworks = $NETWORK 127.0.0.0/8" /etc/postfix/main.cf
line_number=`grep -n ^#home_mailbox /etc/postfix/main.cf | head -n 1 | cut -d":" -f1`
sed -i "${line_number}ihome_mailbox = Maildir\/" /etc/postfix/main.cf
# End of postfix config file


# Update the dovecot config file
sed -i "s/^#protocols/protocols/" /etc/dovecot/dovecot.conf

sed -i "s%^#mail_location.*%mail_location = maildir:~/Maildir%" /etc/dovecot/conf.d/10-mail.conf

sed -i "s/^#disable_plaintext_auth/disable_plaintext_auth/" /etc/dovecot/conf.d/10-auth.conf
sed -i "s/^auth_mechanisms.*/& login/" /etc/dovecot/conf.d/10-auth.conf

line_number=`grep -n "unix_listener auth-userdb" /etc/dovecot/conf.d/10-master.conf | head -n 1 | cut -d":" -f1`
line_number=`expr $line_number + 1`
sed -i "${line_number}i	group = postfix" /etc/dovecot/conf.d/10-master.conf
sed -i "${line_number}i	user = postfix" /etc/dovecot/conf.d/10-master.conf
sed -i "${line_number}i	mode = 0600" /etc/dovecot/conf.d/10-master.conf
# End of dovecot config file setting


# Update the Apache config file
if [ -f /etc/httpd/conf/httpd.conf_backup ]
then
	cp -f /etc/httpd/conf/httpd.conf_backup /etc/httpd/conf/httpd.conf
else
	cp -f /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf_backup
fi

echo >> /etc/httpd/conf/httpd.conf
echo "<Directory /usr/share/squirrelmail>" >> /etc/httpd/conf/httpd.conf
echo "	Options Indexes FollowSymLinks" >> /etc/httpd/conf/httpd.conf
echo "	RewriteEngine On" >> /etc/httpd/conf/httpd.conf
echo "	AllowOverride All" >> /etc/httpd/conf/httpd.conf
echo "	DirectoryIndex index.php" >> /etc/httpd/conf/httpd.conf
echo "	Order allow,deny" >> /etc/httpd/conf/httpd.conf
echo "	Allow from all" >> /etc/httpd/conf/httpd.conf
echo "</Directory>" >> /etc/httpd/conf/httpd.conf
# End of Apache configuration


# Update the Squirrelmail config file
sed -i "s/\$domain.*/\$domain\t\t\t= '$DOMAIN';/" /usr/share/squirrelmail/config/config.php
sed -i "s/^\$useSendmail.*/\$useSendmail\t\t= false;/" /usr/share/squirrelmail/config/config.php
# End of Squirrelmail config file

if [[ $FIREWALL == "yes" ]]
then
	firewall-cmd --permanent --add-service smtp
	firewall-cmd --permanent --add-service pop3
	firewall-cmd --permanent --add-service http
	firewall-cmd --reload
fi

systemctl start dovecot
systemctl enable dovecot
systemctl start postfix
systemctl enable postfix
systemctl restart httpd
systemctl enable httpd


# create new users for testing
useradd user100
echo "redhat" | passwd --stdin user100
useradd user200
echo "redhat" | passwd --stdin user200




