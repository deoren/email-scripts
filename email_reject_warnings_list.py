#!/usr/bin/python

"""
Parse mail log and mail CSV attachment listing any rejection warnings found
"""

# $Id$
# $HeadURL$

import datetime
import os.path
import re
import sys

from email.MIMEMultipart import MIMEMultipart
from email.MIMEBase import MIMEBase
from email.MIMEText import MIMEText
from email.Utils import COMMASPACE, formatdate
from email import Encoders

import os
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
# http://stackoverflow.com/questions/398237/how-to-use-the-csv-mime-type
# http://stackoverflow.com/a/3363254

date = datetime.date.today()
current_user = os.path.basename(os.path.expanduser('~'))

############################################
# USER CONFIGURABLE VARIABLES (ok to touch)
############################################

DEBUG_ON = True

# I use a local postfix server in a VM for testing
SEND_MAIL_WHILE_DEBUG_ON = True

if DEBUG_ON:
    # Current production log file
    input_file="/var/log/mail.log"
else:
    # The previous day's production log file. This script runs after log 
    # rotation completes
    input_file="/var/log/mail.log.1"

output_file="/tmp/rejection_warnings_%s.csv" % uuid.uuid4()


if DEBUG_ON:
    email_server = "localhost"
    email_sender = current_user
    email_recipients = ['root']

else:
    email_server = "localhost"
    email_sender = "logbucket@example.com"
    email_recipients = ['logbucket@example.com']

email_subject = "Rejection warnings - %s" % date
email_body = """
Attached is a report of all reject_warning entries in CSV format
for the %s log file
""" % input_file

############################################
# CORE VARIABLES (Handle with care)
############################################

test_string1="Jul 26 06:38:36 mail postfix/smtpd[21459]: NOQUEUE: reject_warning: RCPT from unknown[95.9.49.216]: 450 4.7.1 Client host rejected: cannot find your hostname, [95.9.49.216]; from=<moneybagslv@appliedps.com> to=<moneybags@example.com> proto=ESMTP helo=<95.9.49.216.static.ttnet.com.tr>"
test_string2="Aug  2 15:08:40 mail postfix/smtpd[16867]: NOQUEUE: reject_warning: RCPT from 190-82-114-19.static.tie.cl[190.82.114.19]: 554 5.7.1 Service unavailable; Client host [190.82.114.19] blocked using b.barracudacentral.org; http://www.barracudanetworks.com/reputation/?pr=1&ip=190.82.114.19; from=<misc2qhfbt@999tetra.com> to=<misc2@example.com> proto=ESMTP helo=<190-82-114-19.static.tie.cl>"

regexes = []

# * Using re.X option
# * Meant to match against 'Client host rejected: cannot find your hostname'
#   reject_warning entries
regexes.append("""

    # Descriptions here are based off of our "test_string1" value

    # Matches 'Jul 25 18:30:00' and also places it into capture group 1
    ^([\w]+\s{1,2}\d+\s\d{2}:\d{2}:\d{2})

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
    # ': 450 4.7.1 Client host rejected: cannot find your hostname,' and
    # Adds 'Client host rejected: cannot find your hostname' to capture group 3
    [:\s\d.]+([\w\s]+:\s[\w\s]+),

    # Extends the match up to ' [95.9.49.216]; '
    [\[\]\d.;\s]+

    # Extends the match up to 'from=<qzqbf@grwwyg.net> '
    # Adds 'qzqbf@grwwyg.net' to capture group 3
    from=<([\w@.]+)>\s

    # Extends the match up to 'to=<moneybags@example.com> '
    # Adds 'moneybags@example.com' to capture group 5
    #to=<(\w+@\w+\.\w+)>\s
    to=<([\w@.]+)>\s

    # Extends the match up to 'proto=ESMTP '
    proto=\w+\s

    # Extends the match up to 'helo=<client-201.240.88.59.speedy.net.pe>'
    # Adds 'client-201.240.88.59.speedy.net.pe' to capture group 6
    helo=<(\[?[\w\.-]+\]?)>

    """)

# * Using re.X option
# * Meant to match against Barracuda reject_warning entries
regexes.append("""

    # Descriptions here are based off of our "test_string2" value

    # Matches 'Aug  2 15:08:40' and also places it into capture group 1
    ^([\w]+\s{1,2}\d+\s\d{2}:\d{2}:\d{2})

    # Extends the match up to ' mail postfix/smtpd[16867]'
    \s\w+\s\w+\/\w+\[\d+\]

    # Extends the match up to ': NOQUEUE reject_warning: RCPT from '
    :\s\w+:\sreject_warning:\sRCPT\sfrom\s

    # Extends the match up to 
    # '190-82-114-19.static.tie.cl[190.82.114.19]: 554 5.7.1 '
    # Adds '' to capture group 2
    [-.\w:]+\[([\d.]+)\]:\s\d{3}\s\d\.\d\.\d\s

    # Extends the match up to 'Service unavailable; '
    [.\w\s\[\]]+;\s

    # Extends the match up to 
    # 'Client host [190.82.114.19] blocked using b.barracudacentral.org; http://www.barracudanetworks.com/reputation/?pr=1&ip=190.82.114.19; '
    # Adds the entire line to capture group 3
    ([.\w\s\[\]]+;.+http[.:\w\s\/\/\&\?\=]+);\s

    # Extends the match up to 'from=<misc2qhfbt@999tetra.com> '
    # Adds 'misc2qhfbt@999tetra.com' to capture group 4
    from=<([\w@.]+)>\s

    # Extends the match up to 'to=<misc2@example.com> '
    # Adds 'misc2@example.com' to capture group 5
    to=<([\w@.]+)>\s

    # Extends the match up to 'proto=ESMTP '
    proto=\w+\s

    # Extends the match up to 'helo=<190-82-114-19.static.tie.cl>'
    # Adds '190-82-114-19.static.tie.cl' to capture group 6
    helo=<(\[?[\w\.-]+\]?)>

    """)

class EmailReport(object):
    """A container for email-related settings"""

    def __init__(self):
        self.sender = email_sender
        self.recipients = email_recipients
        self.subject = email_subject
        self.server = email_server
        self.body = email_body


def send_email(email_conf, csv_input_file):
    """Use Python's smtplib to send user an email with CSV attachment"""

    # Based off of code here: http://stackoverflow.com/a/3363254

    assert type(email_conf.recipients)==list

    if DEBUG_ON:
        print "email_conf settings:"
        print "-" * 15
        print "Subject: %s" % email_conf.subject
        print "From: %s" % email_conf.sender
        print "To: %s " % email_conf.recipients

        print "csv_input_file: %s" % csv_input_file

        if os.path.isfile(csv_input_file):
            print "%s exists" % csv_input_file

    # Create the container (outer) email message.
    msg = MIMEMultipart()
    msg['Subject'] = email_conf.subject
    msg['From'] = email_conf.sender
    msg['To'] = COMMASPACE.join(email_conf.recipients)
    #msg['To'] = email_conf.recipients
    msg['Date'] = formatdate(localtime=True)

    msg.attach( MIMEText(email_conf.body) )

    try:
        input_fh = open(csv_input_file,'r')
    except:
        print "[!] Error accessing %s" % csv_input_file
        print sys.exc_info()[0]
        return False
    else:
        part = MIMEBase('text', "csv")
        part.set_payload( input_fh.read() )
        Encoders.encode_base64(part)
        part.add_header('Content-Disposition', 'attachment; filename="%s"' % os.path.basename(csv_input_file))
        msg.attach(part)

        if DEBUG_ON:
            print "%s, %s, %s" % (email_conf.sender, email_conf.recipients, msg)

        if not DEBUG_ON or SEND_MAIL_WHILE_DEBUG_ON:
            mailer = smtplib.SMTP(email_conf.server)
            #mailer.set_debuglevel(1)
            mailer.sendmail(email_conf.sender, email_conf.recipients, msg.as_string())
            mailer.quit()

def parse_log(input_file, regexes):
    """Examine log file and returns a list of CSV-formatted values"""

    rejection_warnings = []

    report_legend = '"Datestamp","Remote Host","Reason","Claimed sender","Recipient","Helo greeting"'

    if DEBUG_ON:
        print report_legend

    rejection_warnings.append(report_legend)

    try:
        input_fh = open(input_file,'r')
    except:
        print "[!] Error accessing %s" % input_file
        print sys.exc_info()[0]

        sys.exit()
    else:
        for line in input_fh:

            # We're only interested in reject warnings
            # FIXME: Replace this hard-coded value
            if 'reject_warning' in line:

                for regex in regexes:
                    
                    # The Regular Expression pattern we're going to use when examining
                    # the log file
                    pattern = re.compile(regex, re.X)

                    try:
                        matches = pattern.match(line).groups()
                    except:
                        pass
                    else:
                        if DEBUG_ON:
                            print "We found:\n\t%s,%s,%s,%s,%s,%s" % matches

                        # Build CSV string, add to list
                        csv_string='"%s","%s","%s","%s","%s","%s"' % matches
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
    rejection_warnings = parse_log(input_file, regexes)

    # If there are rejection warnings ...
    if len(rejection_warnings) != 0:

        # Create the CSV input file for the email_file() function
        write_file(output_file, rejection_warnings)

        # Create email object using user configurable settings
        email_settings = EmailReport()

        # Use those settings and provide CSV list to transform to a MIME attachment
        send_email(email_settings, output_file)

    else:
        sys.exit()


if __name__ == "__main__":
    main()
