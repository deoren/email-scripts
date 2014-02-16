#!/bin/bash

# $Id$
# $HeadURL$

# Purpose: Lists relevant log entries regarding Yahoo Mail server 
#          "554 Message not allowed" rejections

# TODO: Fold into a larger script?


#
# LOGS
#

# NOTE: You may need to change this depending on your distro.
current_mail_log="/var/log/mail.log"

# This will need to be adjusted to where old mail logs are kept. By default 
# they're placed in /var/log on Ubuntu systems
previous_mail_log="/var/log/mail/mail.log.1"


#
# Functions
#

# Builds a conversation list of emails rejected by Yahoo mail servers. This 
# function should be generalized at some point to work for _any_ mail server.
get_554_rejection_smtp_ids() {

    # This blends '554 Message not allowed' email conversations together as 
    # found in the original log
    #grep -E "$(grep 'said: 554' mail.log.1 | grep -Eo '\]: [[:alnum:]]+' | cut -c 4-)" mail.log.1

    # FIXME: This is probably far too specific
    cat ${current_mail_log} ${previous_mail_log} \
        | grep 'said: 554' \
        | grep -Eo '\]: [[:alnum:]]+' \
        | cut -c 4-

}


#
# Gather email conversations that ended with a 554 rejection
# and print them out
#

echo -e "\n\n-----------------"
echo "Email attempts that ended with 554 rejections"
echo "-----------------"

rejection_554_email_ids=($(get_554_rejection_smtp_ids))

for smtp_id in "${rejection_554_email_ids[@]}"
do 
    cat ${current_mail_log} ${previous_mail_log} | grep -E $smtp_id 
    echo -e "\n" 
done
