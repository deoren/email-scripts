#!/bin/bash

# $Id$
# $HeadURL$

# Purpose:  Prune email using per-user settings in addition to whatever the
#           the default pruning script already handles


#
# Variables
#

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


#
# Build array from query results
#

while read row
do 
    query_results+=("${row}")
done < <(mysql --defaults-file=${mysql_client_conf_file} -e "${mysql_query}")

#echo "\${query_results[0]} is: ${query_results[0]}"
#echo "\${query_results[1]} is: ${query_results[1]}"

for mailbox_settings in "${query_results[@]}"
do

    # FIXME: This can be done a lot more efficiently
    account=$(echo $mailbox_settings | awk '{print $1}')
    mailbox=$(echo $mailbox_settings | awk '{print $2}')
    max_days=$(echo $mailbox_settings | awk '{print $3}')

    #echo "${account}"
    #echo "${mailbox}"
    #echo "${max_days}"

    echo "${account} - ${mailbox}: $(doveadm -v search -u ${account} mailbox ${mailbox} before ${max_days}days | wc -l)"
done
