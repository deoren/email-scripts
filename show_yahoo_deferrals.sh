#!/bin/bash

# $Id$
# $HeadURL$

# Purpose:
#
#    Display email "conversations" with Yahoo that result in temporary deferrals

# FIXME: Add check for dependencies and warn if not present

#
# Variables
#

# build global array of queue ids
declare -a queue_ids
declare -a affected_aliases
declare -a log_files


log_files=(

    /var/log/mail/mail.log.1
    /var/log/mail.log

)

#
# Functions
#

gather_queue_ids() {

    for queue_id in $(

            cat "${log_files[@]}" | \
            grep '\[GL' | \
            grep -Eo ': [A-Z0-9]+: ' | \
            sed -r 's/\s|://g' | \
            sort | \
            uniq
    )
    do
        queue_ids+=("${queue_id}")
    done
}

#
# Main
#

# collect queue ids
gather_queue_ids

# Print out conversations and collect email addresses

for log_file in "${log_files[@]}"
do
    for queue_id in "${queue_ids[@]}"
    do
        # Print out conversation for selected queue id
        line="$(grep $queue_id ${log_file})"
        echo -e "\n$line" | ccze -A

        # Gather what looks like an email address
        possible_address=$(echo -e "\n$line" | grep -Eo 'orig_to=<[[:print:]]+>' | sed -e 's/orig_to=<//' -e 's/>//')

        # Make sure it has an @ symbol in the string
        if [[ $possible_address =~ "@" ]]
        then
           # Gather email addresses
            affected_aliases+=($possible_address)
        fi

    done
done

# Remove duplicate aliases
readarray -t sorted < <(for a in "${affected_aliases[@]}"; do echo "$a"; done | sort | uniq)
affected_aliases=("${sorted[@]}")

# Print out recipient aliases which result in a forward to Yahoo address
echo -e "\nAffected aliases:\n"
for alias in "${affected_aliases[@]}"
do
    echo $alias | ccze -A
done
