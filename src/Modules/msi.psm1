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
#            "type": "msi",
#            "ensure": "install",
#            "msis": [
#               {
#                   "path": "C:\\path\\to\\some\\installer.msi",
#                   "displayName": "Full Software Name"
#               }
#            ]
#        },
#        {
#            "type": "msi",
#            "ensure": "uninstall",
#            "msis": [
#               {
#                   "path": "C:\\path\\to\\some\\installer.msi",
#                   "displayName": "Full Software Name"
#               }
#            ]
#        }
#    ]
# }
#########################################################################

# MSI module to (un)install msi software installers
Import-Module $env:PicassioTools -DisableNameChecking -ErrorAction Stop

function Start-Module($colour, $variables, $credentials)
{
    Test-Module $colour $variables $credentials

    $ensure = (Replace-Variables $colour.ensure $variables).ToLower().Trim()
    $msis = $colour.msis

    foreach ($msi in $msis)
    {
        $path = (Replace-Variables $msi.path $variables).Trim()
        $displayName = Replace-Variables $msi.displayName $variables

        $isInstalled = $true
        if (![string]::IsNullOrWhiteSpace($displayName))
        {
            $softwarePath = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
            $isInstalled = (Get-ItemProperty $softwarePath | Where-Object { $_.DisplayName -ilike "$displayName*" } | Measure-Object).Count -gt 0
        }

        switch ($ensure)
        {
            'install'
                {

                }

            'uninstall'
                {

                }
        }
    }
}

function Test-Module($colour, $variables, $credentials)
{
    # Get ensured operation for installing/uninstalling
    $ensure = Replace-Variables $colour.ensure $variables
    $ensures = @('install', 'uninstall')
    if ([string]::IsNullOrWhiteSpace($ensure) -or $ensures -inotcontains ($ensure.Trim()))
    {
        throw ("Invalid ensure found: '$ensure'. Can be only: {0}." -f ($ensures -join ', '))
    }

    # Check that MSIs were actually passed
    $msis = $colour.msis
    if ($msis -eq $null -or $msis.Length -eq 0)
    {
        throw 'No MSI paths were supplied.'
    }

    # Check the paths
    foreach ($msi in $msis)
    {
        $path = Replace-Variables $msi.path $variables
        if ([string]::IsNullOrWhiteSpace($path))
        {
            throw 'No path passed to MSI installer.'
        }

        if (!(Test-Path $path) -and $variables['__initial_validation__'] -eq $false)
        {
            throw "Path to MSI installer does not exist: '$path'."
        }
    }
}
