#!/bin/bash

# $Id$
# $HeadURL$

# Purpose: Display emails older than X days in the Trash

# Dovecot calls these 'mailboxes', so I used the same terminology here.
mailboxes_to_prune=(
    Trash
    Spam
    Junk
    Rss2Email\*
)

cutoff_date="60days"

#
# Functions
#

get_accounts_with_old_mail () {

    doveadm -v search -A mailbox ${mailbox} before ${cutoff_date} \
        | cut -f 1 -d ' ' \
        | sort \
        | uniq

}

print_mailbox_match_count () {

    account=$1
    mailbox=$2

    msg_match_count=$(doveadm -v search -u ${account} mailbox ${mailbox} before ${cutoff_date} | wc -l)

    echo -e "\n${account} [${mailbox}]: ${msg_match_count}"

}

print_mailbox_match_subject_lines () {

    account=$1
    mailbox=$2

    doveadm search -u ${account} mailbox ${mailbox} before ${cutoff_date} | 
    while read guid uid
    do 
        doveadm fetch -u ${account} hdr mailbox-guid $guid uid $uid | grep -i 'Subject: '
    done

}

#
# Main code body
#

echo -e "\n#################################################################"
echo -e "Emails older than ${cutoff_date} in these folders:"

# Intentionally adding a leading space here to trigger the regex for the
# first item in the (collapsed) array
echo " ${mailboxes_to_prune[@]}" | sed 's/ /\n  * /g'
echo -e "#################################################################\n"

for mailbox in "${mailboxes_to_prune[@]}"
do

    for account in $(get_accounts_with_old_mail)
        do 
            print_mailbox_match_count "${account}" "${mailbox}"
            echo "---------------------------------------------------"
            print_mailbox_match_subject_lines "${account}" "${mailbox}"
    done
done
