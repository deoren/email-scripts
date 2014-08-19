#!/bin/bash

# $Id$
# $HeadURL$

# Purpose: Removes emails older than X days in various common folders

# References:
#
#   http://stackoverflow.com/questions/13843896/store-query-in-array-in-bash
#   http://stevemorin.blogspot.com/2011/01/multi-line-string-in-bash.html
#   http://wiki2.dovecot.org/Tools/Doveadm/Expunge
#   http://wiki2.dovecot.org/Tools/Doveadm/SearchQuery
#   http://wiki2.dovecot.org/Tools/Doveadm/Search

# Should this script be verbose in its output?
DEBUG_ON=1

#######################################################################
# Settings for all accounts
#######################################################################

# Dovecot calls these 'mailboxes', so I used the same terminology here.
default_mailboxes_to_prune=(
    Trash

    Rss2Email\*

# Disabled because we're not using them yet and I haven't given users enough
# of a heads up that we're pruning these now.
#    Spam
#    Junk
)

default_mailboxes_to_report=(
    Trash
    Spam
    Junk
)

default_cutoff_date="60days"

#######################################################################
# Per-user settings
#######################################################################

mysql_query='
SELECT
    virtual_users.email, 
    mailbox_expiration_settings.imap_mailbox_name, 
    mailbox_expiration_settings.max_days 
FROM
    mailbox_expiration_settings, 
    virtual_users 
WHERE
    virtual_users.id = mailbox_expiration_settings.user_id;
'

mysql_client_conf_file="/root/.my-mailserver_expiration_setting.cf"


declare -a query_results

get_accounts_with_old_mail () {

    cutoff_date=$1

    doveadm -v search -A mailbox ${mailbox} before ${cutoff_date} \
        | cut -f 1 -d ' ' \
        | sort \
        | uniq

}

print_mailbox_match_count () {

    account=$1
    mailbox=$2
    cuteoff_date=$3

    msg_match_count=$(doveadm -v search -u ${account} mailbox ${mailbox} before ${cutoff_date} | wc -l)

    echo -e "\n${account} [${mailbox}]: ${msg_match_count}"

}

print_mailbox_match_subject_lines () {

    account=$1
    mailbox=$2
    cutoff_date=$3

    doveadm search -u ${account} mailbox ${mailbox} before ${cutoff_date} | 
    while read guid uid
    do 
        doveadm fetch -u ${account} hdr mailbox-guid $guid uid $uid | grep -i 'Subject: '
    done

}


report_default_mailboxes() {

    echo -e "\n#################################################################"
    echo -e "Emails older than ${default_cutoff_date} in these folders:"

    # Intentionally adding a leading space here to trigger the regex for the
    # first item in the (collapsed) array
    echo " ${default_mailboxes_to_report[@]}" | sed 's/ /\n  * /g'
    echo -e "#################################################################\n"

    for mailbox in "${default_mailboxes_to_report[@]}"
    do
        for account in $(get_accounts_with_old_mail "${default_cutoff_date}")
            do 
                print_mailbox_match_count "${account}" "${mailbox}" "${default_cutoff_date}"
                echo "---------------------------------------------------"
                print_mailbox_match_subject_lines "${account}" "${mailbox}" "${default_cutoff_date}"
        done
    done

}

report_custom_mailboxes() {

    echo -e "\n#################################################################"
    echo -e "Processing custom/per-use mailbox expiration settings ..."
    echo -e "#################################################################\n"

    #
    # Build array from query results
    #

    # http://stackoverflow.com/questions/13843896/store-query-in-array-in-bash
    while read row
    do 
        query_results+=("${row}")
    done < <(mysql --defaults-file=${mysql_client_conf_file} -e "${mysql_query}")

    for mailbox_settings in "${query_results[@]}"
    do

        # FIXME: This can be done a lot more efficiently
        account=$(echo $mailbox_settings | awk '{print $1}')
        mailbox=$(echo $mailbox_settings | awk '{print $2}')
        max_days=$(echo $mailbox_settings | awk '{print $3}')

        print_mailbox_match_count "${account}" "${mailbox}" "${max_days}"
        echo "---------------------------------------------------"
        print_mailbox_match_subject_lines "${account}" "${mailbox}" "${max_days}"

    done

}

prune_default_mailboxes() {


    if [[ "${DEBUG_ON}" -ne 0 ]]; then

        echo -e "\n#################################################################"
        echo "Pruning email in these folders older than ${default_cutoff_date}:"

        # Intentionally adding a leading space here to trigger the regex for the
        # first item in the (collapsed) array
        echo " ${default_mailboxes_to_prune[@]}" | sed 's/ /\n* /g'
        echo -e "#################################################################\n"
    fi

    for mailbox in "${default_mailboxes_to_prune[@]}"
    do

        if [[ "${DEBUG_ON}" -ne 0 ]]; then

            doveadm -vD expunge -A mailbox ${mailbox} before ${default_cutoff_date}
        else
            doveadm expunge -A mailbox ${mailbox} before ${default_cutoff_date}
        fi
    done

}

prune_custom_mailboxes() {

    #
    # Build array from query results
    #

    # http://stackoverflow.com/questions/13843896/store-query-in-array-in-bash
    while read row
    do 
        query_results+=("${row}")
    done < <(mysql --defaults-file=${mysql_client_conf_file} -e "${mysql_query}")

    for mailbox_settings in "${query_results[@]}"
    do

        # FIXME: This can be done a lot more efficiently
        account=$(echo $mailbox_settings | awk '{print $1}')
        mailbox=$(echo $mailbox_settings | awk '{print $2}')
        max_days=$(echo $mailbox_settings | awk '{print $3}')

        if [[ "${DEBUG_ON}" -ne 0 ]]; then

            doveadm -vD expunge -u ${account} mailbox ${mailbox} before ${max_days}days
        else
            doveadm expunge -u ${account} mailbox ${mailbox} before ${max_days}days
        fi
    done

}


# Generate a list of content to be pruned for all accounts
report_default_mailboxes


# Prune all accounts
prune_default_mailboxes


# Generate a list of content to be pruned for per-user settings
report_custom_mailboxes


# Prune email using per-user settings in addition to whatever the
# the default pruning script already handles
prune_custom_mailboxes

