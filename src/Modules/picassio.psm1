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
#            "type": "picassio",
#            "ensure": "paint",
#            "palette": "C:\\path\\to\\palette.picassio"
#        }
#    ]
# }
#########################################################################

# Paints/Erases a machine using a passed Picassio script
Import-Module $env:PicassioTools -DisableNameChecking -ErrorAction Stop

function Start-Module($colour, $variables, $credentials)
{
    Test-Module $colour $variables $credentials

    $palette = (Replace-Variables $colour.palette $variables)
    if (!(Test-Path $palette))
    {
        throw "Palette does not exist '$palette'."
    }

    $ensure = (Replace-Variables $colour.ensure $variables).ToLower().Trim()

    switch ($ensure)
    {
        'paint'
            {
                Write-Message "Painting current machine."

                powershell.exe /C "picassio -palette `"$palette`" -paint"
                if (!$?)
                {
                    throw 'Painting palette failed.'
                }

                Write-Message 'Painting successfully.'
            }

        'erase'
            {
                Write-Message "Erasing current machine."

                powershell.exe /C "picassio -palette `"$palette`" -erase"
                if (!$?)
                {
                    throw 'Erasing palette failed.'
                }

                Write-Message 'Erasing successfully.'
            }
    }
}

function Test-Module($colour, $variables, $credentials)
{
    # check we have a valid palette path
    $palette = (Replace-Variables $colour.palette $variables)
    if ([string]::IsNullOrEmpty($palette))
    {
        throw 'No palette path has been supplied.'
    }

    # check we have a valid ensure property
    $ensure = (Replace-Variables $colour.ensure $variables)
    if ([string]::IsNullOrWhiteSpace($ensure))
    {
        throw 'No ensure parameter supplied for picassio.'
    }

    $ensure = $ensure.ToLower().Trim()
    if ($ensure -ne 'paint' -and $ensure -ne 'erase')
    {
        throw "Invalid ensure supplied for picassio: '$ensure'."
    }
}
