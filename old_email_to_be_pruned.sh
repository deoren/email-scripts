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

echo -e "\n#################################################################"
echo -e "Emails older than ${cutoff_date} in these folders:"

# Intentionally adding a leading space here to trigger the regex for the
# first item in the (collapsed) array
echo " ${mailboxes_to_prune[@]}" | sed 's/ /\n  * /g'
echo -e "#################################################################\n"

for mailbox in "${mailboxes_to_prune[@]}"
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
