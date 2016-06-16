##########################################################################
# Picassio is a provisioning/deployment script which uses a single linear
# JSON file to determine what commands to execute.
#
# Copyright (c) 2015, Matthew Kelly (Badgerati)
# Company: Cadaeic Studios
# License: MIT (see LICENSE for details)
#
# Example:
#
# {
#	"paint": [
#		{
#			"type": "email",
#           "host": "SMTPSERVER1",
#           "port": 25,
#           "subject": "This is an example email",
#           "body": "Hello, world!",
#           "attachments": [
#               "C:\\path\\to\\some\\file.png"
#           ]
#           "from": "some@email.com",
#           "to": [
#               "other@email.com"
#           ],
#           "cc": [
#               "another@email.com"
#           ],
#           "bcc": [
#               "example@email.com"
#           ],
#			"priority": "Normal",
#			"useSsl": false
#		}
#	]
# }
#########################################################################

# Sends an email to some specified emails
Import-Module $env:PicassioTools -DisableNameChecking -ErrorAction Stop

function Start-Module($colour, $variables, $credentials)
{
    Test-Module $colour $variables $credentials

    $smtpServer = (Replace-Variables $colour.host $variables).Trim()
    $subject = (Replace-Variables $colour.subject $variables).Trim()
    $from = (Replace-Variables $colour.from $variables).Trim()

    $body = Replace-Variables $colour.body $variables
    if ($body -eq $null)
    {
        $body = [string]::Empty
    }

    $port = Replace-Variables $colour.port $variables
    if ([string]::IsNullOrWhiteSpace($port))
    {
        $port = 25
    }

    $priority = Replace-Variables $colour.priority $variables
    if ([string]::IsNullOrWhiteSpace($priority))
    {
        $priority = 'Normal'
    }

    $useSsl = Replace-Variables $colour.useSsl $variables
    if ([string]::IsNullOrWhiteSpace($useSsl))
    {
        $useSsl = $false
    }

    $attachments = $colour.attachments
    $final_attachments = @()
    if ($attachments -ne $null)
    {
        ForEach ($attachment in $attachments)
        {
            $attachment = (Replace-Variables $attachment $variables).Trim()

            if (!(Test-Path $attachment))
            {
                throw "Path to attachment for sending email does not exist: '$attachment'."
            }

            $final_attachments += $attachment
        }
    }

    $to_emails = $colour.to
    $final_to = @()
    if ($to_emails -ne $null)
    {
        ForEach ($to_email in $to_emails)
        {
            $to_email = (Replace-Variables $to_email $variables).Trim()
            $final_to += $to_email
        }
    }

    $cc_emails = $colour.cc
    $final_cc = @()
    if ($cc_emails -ne $null)
    {
        ForEach ($cc_email in $cc_emails)
        {
            $cc_email = (Replace-Variables $cc_email $variables).Trim()
            $final_cc += $cc_email
        }
    }

    $bcc_emails = $colour.bcc
    $final_bcc = @()
    if ($bcc_emails -ne $null)
    {
        ForEach ($bcc_email in $bcc_emails)
        {
            $bcc_email = (Replace-Variables $bcc_email $variables).Trim()
            $final_bcc += $bcc_email
        }
    }

    Write-Message 'Sending Email.'

    if ($useSsl)
    {
        Send-MailMessage -From $from -To $final_to -Cc $final_cc -Bcc $final_bcc -Attachments $final_attachments -Subject $subject -Body $body -SmtpServer $smtpServer -Port $port -Priority $priority -UseSsl
    }
    else
    {
        Send-MailMessage -From $from -To $final_to -Cc $final_cc -Bcc $final_bcc -Attachments $final_attachments -Subject $subject -Body $body -SmtpServer $smtpServer -Port $port -Priority $priority
    }

    if (!$?)
    {
        throw 'Failed to send email.'
    }

    Write-Message 'Sending email was successful.'
}

function Test-Module($colour, $variables, $credentials)
{
    $smtpServer = Replace-Variables $colour.host $variables
    if ([string]::IsNullOrWhiteSpace($smtpServer))
    {
        throw 'No host server specified from which to send the email.'
    }

    $subject = Replace-Variables $colour.subject $variables
    if ([string]::IsNullOrWhiteSpace($subject))
    {
        throw 'No subject for the email specified.'
    }

    $from = Replace-Variables $colour.from $variables
    if ([string]::IsNullOrWhiteSpace($from))
    {
        throw 'No from email address specified.'
    }

    $to_emails = $colour.to
    if ($to_emails -eq $null -or $to_emails.Length -eq 0)
    {
        throw 'No to email addresses specified.'
    }

    ForEach ($to_email in $to_emails)
    {
        $to_email = Replace-Variables $to_email $variables

        if ([string]::IsNullOrWhiteSpace($to_email))
        {
            throw 'Cannot pass an empty to email address.'
        }
    }

    $cc_emails = $colour.cc
    if ($cc_emails -ne $null -and $cc_emails.Length -gt 0)
    {
        ForEach ($cc_email in $cc_emails)
        {
            $cc_email = Replace-Variables $cc_email $variables

            if ([string]::IsNullOrWhiteSpace($cc_email))
            {
                throw 'Cannot pass an empty cc email address.'
            }
        }
    }

    $bcc_emails = $colour.bcc
    if ($bcc_emails -ne $null -and $bcc_emails.Length -gt 0)
    {
        ForEach ($bcc_email in $bcc_emails)
        {
            $bcc_email = Replace-Variables $bcc_email $variables

            if ([string]::IsNullOrWhiteSpace($bcc_email))
            {
                throw 'Cannot pass an empty bcc email address.'
            }
        }
    }

    $priority = Replace-Variables $colour.priority $variables
    $priorities = @('normal', 'high', 'low')
    if (![string]::IsNullOrWhiteSpace($priority) -and $priorities -inotcontains $priority)
    {
        throw ("Invalid priority found: '$priority'. Can be only: {0}." -f ($priorities -join ', '))
    }
}
