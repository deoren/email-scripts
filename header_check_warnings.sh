#!/bin/bash

# $Id$
# $HeadURL$

# Purpose: 
#   Output a list of all header check warnings that would have resulted in
#   a rejected email if WARNING mode wasn't enabled for the check.

# yes/no
# 
# NOTE: Be aware that some mail hosts flag some entries as SPAM
include_matching_log_entries="yes"

# NOTE: You may need to change this depending on your distro.
current_mail_log="/var/log/mail.log"

# NOTE: You'll probably want to change this to /var/log/mail.log.1
previous_mail_log="/var/log/mail/mail.log.1"

# What trigger an entry in the log to be included here
warning_pattern=" warning: header "

echo -e "\n#################################################################"
echo "Sender email addresses flagged by header checks"
echo "#################################################################"

echo -e "\nHEADER CHECK WARNING ENTRIES (ADDRESSES):\n"

cat ${current_mail_log} ${previous_mail_log} \
    | grep "${warning_pattern}" \
    | grep -Eo 'from=<[[:graph:]]++>' \
    | sed  's/from=</   * /' \
    | sed 's/>//' \
    | sort \
    | uniq

# Convert variable to lowercase, grab first character for comparison
include_log_entries=$(
    echo ${include_matching_log_entries} \
    | tr -s '[:upper:]' '[:lower:]' \
    | tr -s '' \
    | cut -c 1
)

# Only include the matching mail log entries if requested.
if [[ "${include_log_entries}" == "y" ]]
then

    # NOTE: This might not be a good idea if you're sending this output to a
    #        mail hosting service like Yahoo or Gmail as the log entries will
    #        likely trigger high SPAM scores and result in a rejection.
    echo -e "\nHEADER CHECK WARNING ENTRIES (FULL):\n"

    cat ${current_mail_log} ${previous_mail_log} \
        | grep "${warning_pattern}" \
        | grep -E 'from=<[[:graph:]]++>'
fi
