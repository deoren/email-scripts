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


# Turn this off if testing other portions of the code (reporting for example)
EMAIL_PRUNING_ENABLED=1

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
DISPLAY_EMAIL_SUBJECT_LINES=1

# Displays the account, mailbox and number of emails that are about to be 
# removed from it
DISPLAY_MAILBOX_REMOVAL_COUNT=1




#######################################################################
# Settings for all accounts
#######################################################################

default_expiration_settings_query='
SELECT
    mailbox_default_expiration_settings.imap_mailbox_name,
    mailbox_default_expiration_settings.imap_search_key,
    mailbox_default_expiration_settings.date_specification_interval
FROM
    mailbox_default_expiration_settings;
'

#######################################################################
# Per-user settings
#######################################################################



custom_expiration_settings_query='
SELECT
    virtual_users.email, 
    mailbox_custom_expiration_settings.imap_mailbox_name,
    mailbox_custom_expiration_settings.imap_search_key,
    mailbox_custom_expiration_settings.date_specification_interval
FROM
    mailbox_custom_expiration_settings, 
    virtual_users 
WHERE
    virtual_users.id = mailbox_custom_expiration_settings.user_id;
'

mysql_client_conf_file="/root/.my-mailserver_expiration_settings.cf"


get_accounts_with_old_mail () {

    imap_search_key=$1
    date_specification_interval=$2

    doveadm -v search -A mailbox ${mailbox} ${imap_search_key} ${date_specification_interval} \
        | cut -f 1 -d ' ' \
        | sort \
        | uniq

}

print_mailbox_match_count () {

    account=$1
    mailbox=$2
    imap_search_key=$3
    date_specification_interval=$4


    msg_match_count=$(doveadm -v search -u ${account} mailbox ${mailbox} ${imap_search_key} ${date_specification_interval} | wc -l)

    echo -e "\n${account} [${mailbox}] {search_key: $imap_search_key} (${date_specification_interval}): ${msg_match_count}"

}

print_mailbox_match_subject_lines () {

    account=$1
    mailbox=$2
    imap_search_key=$3
    date_specification_interval=$4


    doveadm search -u ${account} mailbox ${mailbox} ${imap_search_key} ${date_specification_interval} | 
    while read guid uid
    do 
        doveadm fetch -u ${account} hdr mailbox-guid $guid uid $uid | grep -Ei '^Subject: '
    done

}


process_default_mailboxes() {

    local -a query_results

    echo -e "\n#################################################################"
    echo -e "Processing default mailbox expiration settings ..."
    echo -e "#################################################################\n"

    #
    # Build array from query results
    #

    # http://stackoverflow.com/questions/13843896/store-query-in-array-in-bash
    while read row
    do 
        query_results+=("${row}")
    done < <(mysql --defaults-file=${mysql_client_conf_file} -e "${default_expiration_settings_query}")

    for mailbox_settings in "${query_results[@]}"
    do
        # FIXME: This can be done a lot more efficiently
        mailbox=$(echo $mailbox_settings | awk '{print $1}')
        imap_search_key=$(echo $mailbox_settings | awk '{print $2}')
        date_specification_interval=$(echo $mailbox_settings | awk '{print $3}')

        for account in $(get_accounts_with_old_mail "${imap_search_key}" "${date_specification_interval}")
        do
            if [[ "${DISPLAY_MAILBOX_REMOVAL_COUNT}" -eq 1 ]]; then
                print_mailbox_match_count "${account}" "${mailbox}" "${imap_search_key}" "${date_specification_interval}"
            fi

            if [[ "${DISPLAY_EMAIL_SUBJECT_LINES}" -eq 1 ]]; then
                echo "---------------------------------------------------"
                print_mailbox_match_subject_lines "${account}" "${mailbox}" "${imap_search_key}" "${date_specification_interval}"
            fi

            # Only prune if we're not actively testing new changes
            if [[ "${EMAIL_PRUNING_ENABLED}" -eq 1 ]]; then

                if [[ "${DISPLAY_PRUNING_OUTPUT}" -eq 1 ]]; then

                    doveadm -vD expunge -u ${account} -d mailbox ${mailbox} ${imap_search_key} ${date_specification_interval}
                else
                    doveadm expunge -u ${account} -d mailbox ${mailbox} ${imap_search_key} ${date_specification_interval}
                fi
            fi

        done

    done

}

process_custom_mailboxes() {

    local -a query_results

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
    done < <(mysql --defaults-file=${mysql_client_conf_file} -e "${custom_expiration_settings_query}")

    for mailbox_settings in "${query_results[@]}"
    do

        # FIXME: This can be done a lot more efficiently
        account=$(echo $mailbox_settings | awk '{print $1}')
        mailbox=$(echo $mailbox_settings | awk '{print $2}')
        imap_search_key=$(echo $mailbox_settings | awk '{print $3}')
        date_specification_interval=$(echo $mailbox_settings | awk '{print $4}')

        if [[ "${DISPLAY_MAILBOX_REMOVAL_COUNT}" -eq 1 ]]; then
            print_mailbox_match_count "${account}" "${mailbox}" "${imap_search_key}" "${date_specification_interval}"
        fi

        if [[ "${DISPLAY_EMAIL_SUBJECT_LINES}" -eq 1 ]]; then
            echo "---------------------------------------------------"
            print_mailbox_match_subject_lines "${account}" "${mailbox}" "${imap_search_key}" "${date_specification_interval}"
        fi

        # Only prune if we're not actively testing new changes
        if [[ "${EMAIL_PRUNING_ENABLED}" -eq 1 ]]; then

            if [[ "${DISPLAY_PRUNING_OUTPUT}" -eq 1 ]]; then

                doveadm -vD expunge -u ${account} mailbox ${mailbox} ${imap_search_key} ${date_specification_interval}
            else
                doveadm expunge -u ${account} mailbox ${mailbox} ${imap_search_key} ${date_specification_interval}
            fi
        fi

    done

}


# Prune from all accounts
process_default_mailboxes


# Prune email using per-user settings in addition to whatever the
# the default pruning script already handles
process_custom_mailboxes
