#!/bin/bash

# $Id$
# $HeadURL$

# Purpose: 
#   Output a list of email addresses associated with rejected email. By default
#   we are not interested in including addresses that are Greylisted (unless
#   later rejected) or explictly rejected addresses whose senders are given
#   a custom rejection message.

# NOTE: You may need to change this depending on your distro.
current_mail_log="/var/log/mail.log"

# NOTE: You'll probably want to change this to /var/log/mail.log.1
previous_mail_log="/var/log/mail/mail.log.1"
exclude_entries_regex="Greylist|Account terminated|postgrey|Invalid account"

echo -e "\n#################################################################"
echo "Rejected emails addresses (non-greylisted and explicit rejection)"
echo "#################################################################"

echo -e "\nREJECTION ENTRIES (ADDRESSES):\n"

cat ${current_mail_log} ${previous_mail_log} \
    | grep 'reject:' \
    | grep -vE "${exclude_entries_regex}" \
    | grep -Eo 'to=<[[:graph:]]++>' \
    | sed  's/to=</   * /' \
    | sed 's/>//' \
    | sort \
    | uniq

# NOTE: This might not be a good idea if you're sending this output to a
#        mail hosting service like Yahoo or Gmail as the log entries will
#        likely trigger high SPAM scores.
echo -e "\nREJECTION ENTRIES (FULL):\n"

cat ${current_mail_log} ${previous_mail_log} \
    | grep 'reject:' \
    | grep -vE "${exclude_entries_regex}" \
    | grep -E 'to=<[[:graph:]]++>' \
