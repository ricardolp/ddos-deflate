#!/bin/bash

###################################################
# DDoS-Deflate by Amet13 <admin@amet13.name>      #
# It's fork of DDoS-Deflate by Zaf <zaf@vsnl.com> #
# https://github.com/Amet13/ddos-deflate          #
###################################################

RED='\033[0;31m'
NC='\033[0m'

load_conf()
{
	CONF="/usr/local/ddos-deflate/ddos-deflate.conf"
	if [ -f "$CONF" ]; then
		source $CONF
	else
		printf "${RED}${CONF} not found.${NC}\n"
		exit 1
	fi
}

unbanip()
{
	UNBAN_SCRIPT=`mktemp /tmp/unban.XXXXXXXX`
	TMP_FILE=`mktemp /tmp/unban.XXXXXXXX`
	UNBAN_IP_LIST=`mktemp /tmp/unban.XXXXXXXX`
	echo '#!/bin/sh' > $UNBAN_SCRIPT
	echo "sleep $BAN_PERIOD" >> $UNBAN_SCRIPT
	while read line; do
		echo "$IPT -D INPUT -s $line -j DROP" >> $UNBAN_SCRIPT
		echo $line >> $UNBAN_IP_LIST
	done < $BANNED_IP_LIST
	echo "grep -v --file=$UNBAN_IP_LIST $IGNORE_IP_LIST > $TMP_FILE" >> $UNBAN_SCRIPT
	echo "mv $TMP_FILE $IGNORE_IP_LIST" >> $UNBAN_SCRIPT
	echo "rm -f $UNBAN_SCRIPT" >> $UNBAN_SCRIPT
	echo "rm -f $UNBAN_IP_LIST" >> $UNBAN_SCRIPT
	echo "rm -f $TMP_FILE" >> $UNBAN_SCRIPT
	. $UNBAN_SCRIPT &
}

load_conf

TMP_PREFIX='/tmp/ddos-deflate'
TMP_FILE="mktemp $TMP_PREFIX.XXXXXXXX"
BANNED_IP_MAIL=`$TMP_FILE`
BANNED_IP_LIST=`$TMP_FILE`

echo "Banned the following ip addresses on `date`" > $BANNED_IP_MAIL
echo "From `hostname -f` (`hostname -i`)" >> $BANNED_IP_MAIL
echo >> $BANNED_IP_MAIL

BAD_IP_LIST=`$TMP_FILE`
netstat -ntu | grep ":80" | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -nr > $BAD_IP_LIST
cat $BAD_IP_LIST

IP_BAN_NOW=0
while read line; do
	CURR_LINE_CONN=$(echo $line | cut -d" " -f1)
	CURR_LINE_IP=$(echo $line | cut -d" " -f2)
	if [ $CURR_LINE_CONN -lt $NO_OF_CONNECTIONS ]; then
		break
	fi
	IGNORE_BAN=`grep -c $CURR_LINE_IP $IGNORE_IP_LIST`
	if [ $IGNORE_BAN -ge 1 ]; then
		continue
	fi
	IP_BAN_NOW=1
	echo "$CURR_LINE_IP with $CURR_LINE_CONN connections" >> $BANNED_IP_MAIL
	echo $CURR_LINE_IP >> $BANNED_IP_LIST
	echo $CURR_LINE_IP >> $IGNORE_IP_LIST
	$IPT -I INPUT -s $CURR_LINE_IP -j DROP
done < $BAD_IP_LIST

if [ $IP_BAN_NOW -eq 1 ]; then
	DATE=`date`
	if [ $EMAIL_TO != "" ]; then
		cat $BANNED_IP_MAIL | mail -s "IP addresses banned on $DATE" $EMAIL_TO
	fi
	unbanip
fi

rm -f $TMP_PREFIX.*