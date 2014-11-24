#!/bin/bash

# $Id$
# $HeadURL$

# Purpose:
#
#    Display email "conversations" with Yahoo that result in temporary deferrals

# FIXME: Add check for dependencies and warn if not present

#
# Variables - User configurable
#

USE_REDMINE_SYNTAX=1
DEBUG_ON=0


#
# Variables - Script dependent
#

# Set to newlines only so spaces won't trigger a new array entry and so loops
# will only consider items separated by newlines to be the next in the loop
IFS=$'\n'


declare -a affected_aliases
declare -a log_files


log_files=(

    /var/log/mail/mail.log.1
    /var/log/mail.log

)

#
# Functions
#

# Pass in the log file to gather queue ids from
gather_queue_ids() {

    for queue_id in $(

            cat $1 | \
            grep '\[GL' | \
            grep -Eo ': [A-Z0-9]+: ' | \
            sed -r 's/\s|://g' | \
            sort | \
            uniq
    )
    do
        # Only return string (for inclusion in array) if it is non-empty and non-null
        if [ ! -z "$queue_id" -a "$queue_id" != " " ]; then

            echo ${queue_id}
        fi
    done
}

#
# Main
#

# Print out conversations and collect email addresses

if [[ "${USE_REDMINE_SYNTAX}" -eq 1 ]]; then
    echo -e "\nh4. Temporary Yahoo deferrals\n"
else
    echo -e "\nTemporary Yahoo deferrals:\n"
fi

for log_file in "${log_files[@]}"
do

    if [[ "${USE_REDMINE_SYNTAX}" -eq 1 ]]; then
        echo -e "\nh5. @$log_file@\n"
    else
        echo -e "\n$log_file:\n"
    fi

    # collect queue ids
    queue_ids=($(gather_queue_ids $log_file))

    # Print out conversation for selected queue id
    for queue_id in "${queue_ids[@]}"
    do

        if [[ "${DEBUG_ON}" -eq 1 ]]; then
            echo "\$queue_id is $queue_id"
        fi

        if [[ "${USE_REDMINE_SYNTAX}" -eq 1 ]]; then
            echo -e "\n<pre>"
        fi

        # Start and end of email transaction based on queue id
        conversation=($(grep $queue_id ${log_file}))

        for line in "${conversation[@]}"
        do
            echo $line | ccze -A

            # Gather what looks like an email address
            possible_address=$(echo $line | grep -Eo 'orig_to=<[[:print:]]+>' | sed -e 's/orig_to=<//g' -e 's/>//g')

            # Make sure it has an @ symbol in the string
            if [[ $possible_address =~ "@" ]]
            then
               # Gather email addresses
                affected_aliases+=($possible_address)
            fi
        done

        if [[ "${USE_REDMINE_SYNTAX}" -eq 1 ]]; then
            echo "</pre>"
        fi

    done
done


# Remove duplicate aliases
readarray -t sorted < <(for a in "${affected_aliases[@]}"; do echo "$a"; done | sort | uniq)
affected_aliases=("${sorted[@]}")

# Print out recipient aliases which result in a forward to Yahoo address
if [[ "${USE_REDMINE_SYNTAX}" -eq 1 ]]; then
    echo -e "\nh5. Affected aliases\n"
else
    echo -e "\nAffected aliases:\n"
fi

for alias in "${affected_aliases[@]}"
do
    echo "* $alias" | ccze -A
done
