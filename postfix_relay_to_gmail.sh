#!/bin/bash
#####################################################################################
# This script will configure postfix as a relay through gmail
# A gmail account and password is required and also the security on the google account
# has to be downgraded to give access to less secure apps
#####################################################################################
# Start of user inputs

# End of user inputs
#####################################################################################

source ./common_fn

INSTALLPACKAGES="postfix cyrus-sasl-plain mailx"
GOOGLECREDSFILE="/etc/postfix/sasl_passwd"
LOG_FILE="/tmp/postfix_gmal_relay.log"

rm -rf $LOG_FILE
exec 5>$LOG_FILE

check_euid

MESSAGE="This script will configure postfix to relay via gmail. Make sure the security on the google account has been downgraded"
print_msg_header


if yum list installed postfix >&5 2>&5
then
	systemctl -q is-active postfix && {
	systemctl stop postfix
	systemctl -q disable postfix
	}

	MESSAGE="Removing old copy of postfix"
	print_msg_start
	yum remove -y $INSTALLPACKAGES >&5 2>&5
	rm -rf /etc/postfix
	rm -rf /var/spool/postfix
	rm -rf /var/lib/postfixA
	rm -rf /etc/postfix/sasl_passwd
	print_msg_done
fi

MESSAGE="Installing $INSTALLPACKAGES"
print_msg_start
yum install -y $INSTALLPACKAGES >&5 2>&5
print_msg_done

systemctl start postfix
systemctl -q enable postfix

# Edit the postfix config file
sed -i "s/^inet_protocols.*/inet_protocols = ipv4/" /etc/postfix/main.cf
echo "relayhost = [smtp.gmail.com]:587" >> /etc/postfix/main.cf
echo "smtp_use_tls = yes" >> /etc/postfix/main.cf
echo "smtp_sasl_auth_enable = yes" >> /etc/postfix/main.cf
echo "smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd" >> /etc/postfix/main.cf
echo "smtp_tls_CAfile = /etc/ssl/certs/ca-bundle.crt" >> /etc/postfix/main.cf
echo "smtp_sasl_security_options = noanonymous" >> /etc/postfix/main.cf
echo "smtp_sasl_tls_security_options = noanonymous" >> /etc/postfix/main.cfa

rm -rf $GOOGLECREDSFILE
MESSAGE="Need google credentials to complete configuration"
print_msg_start
echo
echo "Please enter the google username"
read GOOGLEUSERNAME
echo "Please enter the google password"
read GOOGLEPASSWORD
echo "Please enter an email address to send an email to"
read TESTEMAIL
echo
print_msg_done

echo "[smtp.gmail.com]:587 $GOOGLEUSERNAME:$GOOGLEPASSWORD" > $GOOGLECREDSFILE
postmap $GOOGLECREDSFILE
chown root:postfix $GOOGLECREDSFILE
chmod 0640 $GOOGLECREDSFILE

systemctl restart postfix

MESSAGE="Testing the config - echo 'This is a test' | mail -s 'test message' $TESTEMAIL"
print_msg_start
echo 'This is a test' | mail -s 'test message' $TESTEMAIL
print_msg_done

MESSAGE="postfix config completed"
print_msg_header
