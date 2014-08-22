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
#   http://notes.sagredo.eu/node/124

#############################################################################
# FIXME:
#############################################################################
#   How do I want to define email older than X that should be removed?
#
# * Email received more than X days and moved to trash 
#       (eligible immediately)
#
#       doveadm -v search -A mailbox ${mailbox} before ${cutoff_date}days
#
#
# * Email placed in the Trash and left there for X days 
#       (eligible after X days sitting in Trash)
#
#
#       doveadm -v search -A mailbox ${mailbox} savedbefore ${cutoff_date}days
#
#############################################################################

# Turn this off if testing other portions of the code (reporting for example)
EMAIL_PRUNING_ENABLED=0

# Verbose output. Useful to verify that the script works as a whole. Recommended
# to disable if not actively testing/verifying script functionality.
DISPLAY_PRUNING_OUTPUT=1


#
# NOTE:
#
#   Disabling both of these makes calling the reporting fucntions useless.
#   However, enabling the 'DISPLAY_MAILBOX_REMOVAL_COUNT' option and not the 
#   other probably won't be all that useful either.
#

# Displays the subject lines of emails that are about to be removed
DISPLAY_EMAIL_SUBJECT_LINES=0

# Displays the account, mailbox and number of emails that are about to be 
# removed from it
DISPLAY_MAILBOX_REMOVAL_COUNT=1




#######################################################################
# Settings for all accounts
#######################################################################

# Dovecot calls these 'mailboxes', so I used the same terminology here.
default_mailboxes_to_prune=(
    Trash
    Spam
    Junk
)

default_mailboxes_to_report=(
    Trash
    Spam
    Junk
)

# Measured in days (Example: "30")
default_cutoff_date="60"

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

    doveadm -v search -A mailbox ${mailbox} before ${cutoff_date}days \
        | cut -f 1 -d ' ' \
        | sort \
        | uniq

}

print_mailbox_match_count () {

    account=$1
    mailbox=$2
    cutoff_date=$3

    msg_match_count=$(doveadm -v search -u ${account} mailbox ${mailbox} before ${cutoff_date}days | wc -l)

    echo -e "\n${account} [${mailbox}] (${cutoff_date} days): ${msg_match_count}"

}

print_mailbox_match_subject_lines () {

    account=$1
    mailbox=$2
    cutoff_date=$3

    doveadm search -u ${account} mailbox ${mailbox} before ${cutoff_date}days | 
    while read guid uid
    do 
        doveadm fetch -u ${account} hdr mailbox-guid $guid uid $uid | grep -i 'Subject: '
    done

}


report_default_mailboxes() {

    echo -e "\n#################################################################"
    echo -e "Processing default mailbox expiration settings ..."
    echo -e "#################################################################\n"

    for mailbox in "${default_mailboxes_to_report[@]}"
    do
        for account in $(get_accounts_with_old_mail "${default_cutoff_date}")
            do 
                if [[ "${DISPLAY_MAILBOX_REMOVAL_COUNT}" -eq 1 ]]; then
                    print_mailbox_match_count "${account}" "${mailbox}" "${default_cutoff_date}"
                fi
                if [[ "${DISPLAY_EMAIL_SUBJECT_LINES}" -eq 1 ]]; then
                    echo "---------------------------------------------------"
                    print_mailbox_match_subject_lines "${account}" "${mailbox}" "${default_cutoff_date}"
                fi
        done
    done

}

report_custom_mailboxes() {

    echo -e "\n#################################################################"
    echo -e "Processing custom per-user/per-mailbox expiration settings ..."
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

        if [[ "${DISPLAY_MAILBOX_REMOVAL_COUNT}" -eq 1 ]]; then
            print_mailbox_match_count "${account}" "${mailbox}" "${max_days}"
        fi

        if [[ "${DISPLAY_EMAIL_SUBJECT_LINES}" -eq 1 ]]; then
            echo "---------------------------------------------------"
            print_mailbox_match_subject_lines "${account}" "${mailbox}" "${max_days}"
        fi

    done

}

prune_default_mailboxes() {

    if [[ "${DEBUG_ON}" -ne 0 ]]; then
        echo -e "\n#################################################################"
        echo -e "Pruning emails that meet default mailbox expiration settings ..."
        echo -e "#################################################################\n"
    fi

    for mailbox in "${default_mailboxes_to_prune[@]}"
    do

        if [[ "${DISPLAY_PRUNING_OUTPUT}" -eq 1 ]]; then

            doveadm -vD expunge -A mailbox ${mailbox} before ${default_cutoff_date}days
        else
            doveadm expunge -A mailbox ${mailbox} before ${default_cutoff_date}days
        fi
    done

}

prune_custom_mailboxes() {

    if [[ "${DEBUG_ON}" -ne 0 ]]; then
        echo -e "\n#################################################################"
        echo -e "Pruning emails that meet custom mailbox expiration settings ..."
        echo -e "#################################################################\n"
    fi

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

        if [[ "${DISPLAY_PRUNING_OUTPUT}" -eq 1 ]]; then

            doveadm -vD expunge -u ${account} mailbox ${mailbox} before ${max_days}days
        else
            doveadm expunge -u ${account} mailbox ${mailbox} before ${max_days}days
        fi
    done

}


# Generate a list of content to be pruned for all accounts
report_default_mailboxes


# Prune all accounts
if [[ "${EMAIL_PRUNING_ENABLED}" -eq 1 ]]; then
    # Only prune if we're not actively testing new changes
    prune_default_mailboxes
fi


# Generate a list of content to be pruned for per-user settings
report_custom_mailboxes


# Prune email using per-user settings in addition to whatever the
# the default pruning script already handles
if [[ "${EMAIL_PRUNING_ENABLED}" -eq 1 ]]; then
    # Only prune if we're not actively testing new changes
    prune_custom_mailboxes
fi

