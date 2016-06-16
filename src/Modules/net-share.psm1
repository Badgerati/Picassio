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
#    "paint": [
#        {
#           "type": "net-share",
#           "ensure": "exists",
#           "name": "share.folder.name",
#           "path": "C:\\path\\to\\folder\\to\\share",
#           "remark": "Some Description",
#           "grants": {
#               "Everyone": "FULL"
#           }
#        },
#        {
#           "type": "net-share",
#           "ensure": "removed",
#           "name": "share.folder.name"
#        }
#    ]
# }
#########################################################################

# Shares a supplied path, with given permissions
Import-Module $env:PicassioTools -DisableNameChecking -ErrorAction Stop
Import-Module WebAdministration -ErrorAction Stop
sleep 2

function Start-Module($colour, $variables, $credentials)
{
    Test-Module $colour $variables $credentials

    $ensure = (Replace-Variables $colour.ensure $variables).ToLower().Trim()
    $name = (Replace-Variables $colour.name $variables).ToLower().Trim()

    Write-Message "`nEnsuring $name share $ensure."

    switch ($ensure)
    {
        'exists'
            {
                $path = (Replace-Variables $colour.path $variables).Trim()

                if (!(Test-Path $path))
                {
                    throw "Path for sharing does not exist: '$path'."
                }

                Write-Information "Sharing path: '$path'."

                $remark = $colour.remark
                if ([string]::IsNullOrWhiteSpace($remark))
                {
                    $remark = 'Created via Picassio.'
                }

                $grants = $colour.grants
                $keys = $grants.psobject.properties.name
                $grantsArgs = [string]::Empty

                ForEach ($key in $keys)
                {
                    # Grab the grant we're dealing with currently
                    $key = (Replace-Variables $key $variables).Trim()

                    # What permission access are we granting
                    $permission = (Replace-Variables $grants.$key $variables).ToUpper().Trim()

                    $grantsArgs += "/grant:`"$key,$permission`" "
                }

                try
                {
                    Run-Command 'net' "share $name /delete /y"
                }
                catch
                {
                    Write-Warnings "Failed to delete share $name before creating it. There's a high chance this error has occurred either due to permissions, or because the share just doesn't exist yet."
                }

                Run-Command 'net' "share $name=$path $grantsArgs /remark:$remark"
            }

        'removed'
            {
                Run-Command 'net' "share $name /delete /y"
            }
    }

    Write-Message "The $name share $ensure."
}

function Test-Module($colour, $variables, $credentials)
{
    # Check the ensures value
    $ensure = Replace-Variables $colour.ensure $variables
    $ensures = @('exists', 'removed')
    if ([string]::IsNullOrWhiteSpace($ensure) -or $ensures -inotcontains ($ensure.Trim()))
    {
        throw ("Invalid ensure found: '$ensure'. Can be only: {0}." -f ($ensures -join ', '))
    }

    # Check we actually have a share name
    $name = Replace-Variables $colour.name $variables
    if ([string]::IsNullOrWhiteSpace($name))
    {
        throw 'Share name cannot be empty.'
    }

    # If creating share, then check path and grants
    if ($ensure -ieq 'exists')
    {
        # Check path to folder for sharing was supplied
        $path = Replace-Variables $colour.path $variables
        if ([string]::IsNullOrWhiteSpace($path))
        {
            throw 'No path to a folder to share passed.'
        }

        # Check we have grants values
        $grants = $colour.grants
        if ($grants -eq $null)
        {
            throw 'No grants have been supplied.'
        }

        # Grab the names of the grants, ensure we have valid values
        $keys = $grants.psobject.properties.name
        if ($keys -eq $null -or $keys.Length -eq 0)
        {
            throw 'No grant names have been supplied.'
        }

        $grantValues = @('read', 'change', 'full')
        if (($keys | Where-Object { $grantValues -inotcontains (Replace-Variables $_ $variables) } | Measure-Object).Count -gt 0)
        {
            throw 'Invalid or empty grant permission values found.'
        }
    }
}
