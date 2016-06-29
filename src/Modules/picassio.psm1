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
#           "type": "picassio",
#           "ensure": "paint",
#           "palettes": [
#               "C:\\path\\to\\picassio.palette"
#           ]
#        }
#    ]
# }
#########################################################################

# Paints/Erases a machine using a passed Picassio script
Import-Module $env:PicassioTools -DisableNameChecking -ErrorAction Stop

function Start-Module($colour, $variables, $credentials)
{
    Test-Module $colour $variables $credentials

    $ensure = (Replace-Variables $colour.ensure $variables).ToLower().Trim()

    $palettes = $colour.palettes
    ForEach ($palette in $palettes)
    {
        $palette = Replace-Variables $palette $variables

        if (!(Test-Path $palette))
        {
            throw "Palette does not exist: '$palette'."
        }
    }

    ForEach ($palette in $palettes)
    {
        Write-Host ([string]::Empty)
        $palette = Replace-Variables $palette $variables

        switch ($ensure)
        {
            'paint'
                {
                    Write-Message "Painting current machine."

                    powershell.exe /C "picassio -palette `"$palette`" -paint"
                    if (!$?)
                    {
                        throw "Painting palette '$palette' failed."
                    }

                    Write-Message 'Painting successful.'
                }

            'erase'
                {
                    Write-Message "Erasing current machine."

                    powershell.exe /C "picassio -palette `"$palette`" -erase"
                    if (!$?)
                    {
                        throw "Erasing palette '$palette' failed."
                    }

                    Write-Message 'Erasing successful.'
                }
        }
    }
}

function Test-Module($colour, $variables, $credentials)
{
    # check we have a valid palettes
    $palettes = $colour.palettes
    if ($palettes -eq $null -or $palettes.Length -eq 0)
    {
        throw 'No palettes have been supplied.'
    }

    ForEach ($palette in $palettes)
    {
        $palette = Replace-Variables $palette $variables

        if ([string]::IsNullOrEmpty($palette))
        {
            throw 'No palette path has been supplied.'
        }
    }

    # check we have a valid ensure property
    $ensure = (Replace-Variables $colour.ensure $variables)
    $ensures = @('paint', 'erase')
    if ([string]::IsNullOrWhiteSpace($ensure) -or $ensures -inotcontains ($ensure.Trim()))
    {
        throw ("Invalid ensure found: '$ensure'. Can be only: {0}." -f ($ensures -join ', '))
    }
}
