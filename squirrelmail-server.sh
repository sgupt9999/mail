#!/bin/bash
# Setting up a squirrelmail server on Centos/RHEL with postfix and dovecot

# User inputs

SERVERIP=34.217.178.158
HOSTNAME="mail.mylabserver.com"
# End of user inputs

PACKAGES="postfix dovecot"

if [[ $EUID != "0" ]]
then
	echo "ERROR. Need to be user to run this script"
	exit 1
fi


hostnamectl set-hostname $HOSTNAME
echo "$SERVERIP $HOSTNAME" >> /etc/hosts

rm -rf /var/run/yum.pid
yum -y -q -e0 update

# Only 1 MTA allowed
yum remove -y -q -e0 sendmail

if yum list installed postfix
then
	echo "Removing old copy of postfix........."
	yum remove -y -q -e0 postfix
	rm -rf /var/spool/postfix
fi

if yum list installed dovecot
then
	echo "Removing old copy of dovecot..........."
	yum remove -y -q -e0 dovecot
	rm -rf /etc/pki/docvecot
	rm -rf /var/lib/dovecot
fi

echo "Installing packages........"
yum install -y -q -e0 $PACKAGES
echo "Done"

# Update the postfix config file
line_number=`grep -n ^#myhostname /etc/postfix/main.cf | head -n 1 | cut -d":" -f1`
echo $line_number
sed -i "${line_number}imyhostname = $HOSTNAME" /etc/postfix/main.cf
