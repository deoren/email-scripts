#!/bin/bash

# $Id$
# $HeadURL$

# Purpose: Display emails older than X days in the Trash

# Dovecot calls these 'mailboxes', so I used the same terminology here.
mailboxes=(
    Trash
    Spam
    Junk
)

cutoff_date="60days"

echo -e "\n#################################################################"
echo "Emails in Trash/Junk/Spam folders older than ${cutoff_date}"
echo -e "#################################################################\n"

for mailbox in "${mailboxes[@]}"
do
    for account in $(

        doveadm -v search -A mailbox ${mailbox} before ${cutoff_date} \
            | cut -f 1 -d ' ' \
            | sort \
            | uniq
    )
        do echo "${account} - ${mailbox}: $(doveadm -v search -u ${account} mailbox ${mailbox} before ${cutoff_date} | wc -l)"
    done
done
