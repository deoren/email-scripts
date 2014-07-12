#!/bin/bash

# $Id$
# $HeadURL$

# Purpose: Removes emails older than X days in various "refuse" folders

DEBUG_ON=1

# Dovecot calls these 'mailboxes', so I used the same terminology here.
mailboxes_to_prune=(
    Trash

    Rss2Email\*

# Disabled because we're not using them yet and I haven't given users enough
# of a heads up that we're pruning these now.
#    Spam
#    Junk
)

cutoff_date="60days"


if [[ "${DEBUG_ON}" -ne 0 ]]; then

    echo -e "\n#################################################################"
    echo "Pruning email in these folders older than ${cutoff_date}:"

    # Intentionally adding a leading space here to trigger the regex for the
    # first item in the (collapsed) array
    echo " ${mailboxes_to_prune[@]}" | sed 's/ /\n* /g'
    echo -e "#################################################################\n"
fi

for mailbox in "${mailboxes_to_prune[@]}"
do

    if [[ "${DEBUG_ON}" -ne 0 ]]; then

        doveadm -vD expunge -A mailbox ${mailbox} before ${cutoff_date}
    else
        doveadm expunge -A mailbox ${mailbox} before ${cutoff_date}
    fi
done
