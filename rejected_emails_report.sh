#!/bin/bash

# $Id$
# $HeadURL$

# Purpose:  Extends on rejected_emails.sh to provide additional reporting
#           options. Very much a WIP.

# TODO: 
#   * Support reading in a conf file to skip using these hardcoded settings
#     Example: /etc/whyaskwhy.org/reject_emails/settings.conf
#
#


#
# LOGS
#

# NOTE: You may need to change this depending on your distro.
current_mail_log="/var/log/mail.log"

# This will need to be adjusted to where old mail logs are kept. By default 
# they're placed in /var/log on Ubuntu systems
previous_mail_log="/var/log/mail/mail.log.1"

#
# FILTERS
#
exclude_entries_regex_full_list="Greylist|Account terminated|postgrey|Invalid account"
exclude_greylist_entries_regex="Greylist|postgrey"


#
# Functions
#

# Build a list of email addresses that this server has rejected. If an 
# argument is passed it should exclude email addresses rejected for the 
# specific reasons listed.
get_list_of_rejected_emails() {

    # If no exclusions are given, then we return a list of EVERY rejected 
    # email address found in the logs. We skip providing the matching lines
    # however.
    if [[ "$#" -eq 0 ]]; then
        cat ${current_mail_log} ${previous_mail_log} \
            | grep 'reject:' \
            | grep -Eo 'to=<[[:graph:]]++>' \
            | sed  's/to=<//' \
            | sed 's/>//' \
            | sort \
            | uniq

    else
        cat ${current_mail_log} ${previous_mail_log} \
            | grep 'reject:' \
            | grep -vE "$1" \
            | grep -Eo 'to=<[[:graph:]]++>' \
            | sed  's/to=<//' \
            | sed 's/>//' \
            | sort \
            | uniq

    fi


}

# Builds a conversation list of emails rejected by a remote mail host. For our 
# testing purposes we're focusing on Yahoo mail servers. This function should 
# be generalized at some point to work for _any_ mail server.
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


#
# Gather email addresses that were rejected
#

rejected_email_addresses_with_all_exclusions=(
    $(get_list_of_rejected_emails "${exclude_entries_regex_full_list}")
)

rejected_email_addresses_with_greylist_exclusions=(
    $(get_list_of_rejected_emails "${exclude_greylist_entries_regex}")
)

rejected_email_addresses_all=($(get_list_of_rejected_emails))



#
# Print them out
#

echo -e "\n\n-----------------"
echo "Rejected emails addresses (Applying all exclusion filters)"
echo "-----------------"

for email_addr in "${rejected_email_addresses_with_all_exclusions[@]}"
do 
    echo "    * ${email_addr}"
done

echo -e "\n\n-----------------"
echo "Rejected emails addresses (Applying only greylist exclusion filters)"
echo "-----------------"

for email_addr in "${rejected_email_addresses_with_greylist_exclusions[@]}"
do 
    echo "    * ${email_addr}"
done

echo -e "\n\n-----------------"
echo "Rejected emails addresses (Applying NO filters)"
echo "-----------------"

for email_addr in "${rejected_email_addresses_all[@]}"
do 
    echo "    * ${email_addr}"
done
