#!/usr/bin/python

"""
Parse mail log and mail CSV attachment listing any rejection warnings found
"""

# $Id$
# $HeadURL$

import datetime
import os.path
import re

from email.MIMEMultipart import MIMEMultipart
from email.MIMEText import MIMEText
import smtplib

import sys
import uuid


# -----------------------------------------
# Refererences:
# -----------------------------------------
# http://stackoverflow.com/questions/3362600/how-to-send-email-attachments-with-python
# https://developers.google.com/edu/python/regular-expressions
# http://docs.python.org/2/library/re.html
# http://www.tutorialspoint.com/python/python_reg_expressions.htm
# http://docs.python.org/2/library/email-examples.html
# http://stackoverflow.com/questions/842059/is-there-a-portable-way-to-get-the-current-username-in-python
# http://docs.python.org/2/library/uuid.html

date = datetime.date.today()
current_user = os.path.basename(os.path.expanduser('~'))

############################################
# USER CONFIGURABLE VARIABLES (ok to touch)
############################################

DEBUG_ON = True

# I use a local postfix server in a VM for testing
SEND_MAIL_WHILE_DEBUG_ON = True

if DEBUG_ON:
    email_server = "localhost"
    email_sender = current_user
    email_subject = "Rejection warnings - %s" % date

    # Specify recipients, separated by commas 
    # NOTE: Make sure to include a trailing comma
    email_recipients = "root,"

else:
    email_server = "localhost"
    email_sender = "logbucket@example.com"
    email_subject = "Rejection warnings - %s" % date

    # Make sure this has a trailing comma
    email_recipients = "logbucket@example.com,"


if DEBUG_ON:
    # A copy of the real log that I downloaded to test with
    input_file="/mnt/hgfs/dev/whyaskwhy.org/systems/mail/var/log/mail.log"
else:
    # The previous day's log. This script runs after log rotation completes
    input_file="/var/log/mail.log.1"

output_file="/tmp/rejection_warnings_%s.tmp" % uuid.uuid4()

############################################
# CORE VARIABLES (Handle with care)
############################################

test_string="Jul 26 06:38:36 mail postfix/smtpd[21459]: NOQUEUE: reject_warning: RCPT from unknown[95.9.49.216]: 450 4.7.1 Client host rejected: cannot find your hostname, [95.9.49.216]; from=<moneybagslv@appliedps.com> to=<moneybags@example.com> proto=ESMTP helo=<95.9.49.216.static.ttnet.com.tr>"

# Using re.X option
regex="""

    # Descriptions here are based off of our "test_string" value

    # Matches 'Jul 25 18:30:00' and also places it into capture group 1
    ^([\w]+\s\d+\s\d{2}:\d{2}:\d{2})

    # Extends the match up to ' mail postfix/smtpd[20177]'
    \s\w+\s\w+\/\w+\[\d+\]

    # Extends the match up to ': NOQUEUE'
    :\s\w+

    # Extends the match up to ': reject_warning'
    :\s\w+

    # Extends the match up to ': RCPT from unknown[201.240.88.59]' and
    # Adds '201.240.88.59' to capture group 2
    :[\s\w]+\[([\d.]+)\]

    # Extends the match up to
    # ': 450 4.7.1 Client host rejected: cannot find your hostname, [201.240.88.59]; '
    [\s\w.:,\[\]]+;\s

    # Extends the match up to 'from=<qzqbf@grwwyg.net> '
    # Adds 'qzqbf@grwwyg.net' to capture group 3
    from=<([\w@.]+)>\s

    # Extends the match up to 'to=<moneybags@example.com> '
    # Adds 'moneybags@example.com' to capture group 4
    #to=<(\w+@\w+\.\w+)>\s
    to=<([\w@.]+)>\s

    # Extends the match up to 'proto=ESMTP '
    proto=\w+\s

    # Extends the match up to 'helo=<client-201.240.88.59.speedy.net.pe>'
    # Adds 'client-201.240.88.59.speedy.net.pe' to capture group 5
    helo=<(\[?[\w\.-]+\]?)>

    """


class EmailReport(object):
    """A container for email-related settings"""

    def __init__(self):
        self.sender = email_sender
        self.recipients = email_recipients
        self.subject = email_subject
        self.server = email_server

def email_file(email_conf, csv_input_file):
    """Use Python's smtplib to send user an email with CSV attachment"""
    
    if DEBUG_ON:
        print "email_conf settings:"
        print "-" * 15
        print "Subject: %s" % email_conf.subject
        print "From: %s" % email_conf.sender
        print "To: %s " % email_conf.recipients

        print "csv_input_file: %s" % csv_input_file

        if os.path.isfile(csv_input_file):
            print "%s exists" % csv_input_file

    COMMASPACE = ', '

    # Create the container (outer) email message.
    msg = MIMEMultipart()
    msg['Subject'] = email_conf.subject
    msg['From'] = email_conf.sender
    #msg['To'] = COMMASPACE.join(email_conf.recipients)
    msg['To'] = email_conf.recipients
    msg.preamble = email_conf.subject

    try:
        input_fh = open(csv_input_file,'r')
    except:
        print "[!] Error accessing %s" % csv_input_file
        print sys.exc_info()[0]
        return False
    else:
        msg.attach(MIMEText(input_fh.read()))

        if DEBUG_ON:
            print "%s, %s, %s" % (email_conf.sender, email_conf.recipients, msg)

        if not DEBUG_ON or SEND_MAIL_WHILE_DEBUG_ON:
            mailer = smtplib.SMTP(email_conf.server)
            #mailer.set_debuglevel(1)
            mailer.sendmail(email_conf.sender, email_conf.recipients, msg.as_string())
            mailer.quit()

def parse_log(input_file, regex):
    """Examine log file and returns a list of CSV-formatted values"""

    # The Regular Expression pattern we're going to use when examining
    # the log file
    pattern = re.compile(regex, re.X)

    rejection_warnings = []

    report_legend = '"Datestamp","Remote Host","Claimed sender","Recipient","Helo greeting"'

    rejection_warnings.append(report_legend)

    if DEBUG_ON:
        print report_legend

    try:
        input_fh = open(input_file,'r')
    except:
        print "[!] Error accessing %s" % input_file
        print sys.exc_info()[0]
        
        return False
    else:
        for line in input_fh:

            # We're only interested in reject warnings
            # FIXME: Replace this hard-coded value
            if 'reject_warning' in line:

                try:
                    matches = pattern.match(line).groups()
                except:
                    pass
                else:
                    if DEBUG_ON:
                        print "We found:\n\t%s,%s,%s,%s,%s" % matches

                    # Build CSV string, add to list
                    csv_string='"%s","%s","%s","%s","%s"' % matches
                    rejection_warnings.append(csv_string)
        input_fh.close()
        return rejection_warnings




# FIXME: Do we really to write out the file and then read it back in?
def write_file(filename, csv_list):
    """Recieves a list of strings (CSV-formatted) and writes to a file"""
    try:
        output_fh = open(filename,'w')

        for line in csv_list:
            output_fh.write(line + '\n')
    except:
        print "[!] Error accessing %s" % filename
        print sys.exc_info()[0]

        return False
    finally:
        output_fh.close()

def main():

    rejection_warnings = []
    rejection_warnings = parse_log(input_file, regex)

    # Create the CSV input file for the email_file() function
    write_file(output_file, rejection_warnings)

    # Create email object using user configurable settings
    email_settings = EmailReport()

    # Use those settings and provide CSV list to transform to a MIME attachment
    email_file(email_settings, output_file)


if __name__ == "__main__":
    main()
