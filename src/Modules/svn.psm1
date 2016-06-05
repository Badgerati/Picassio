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
#            "type": "svn",
#            "url": "https://url.to.some.svn",
#            "path": "C:\\path\\to\\local\\svn",
#            "name": "LocalName",
#            "revision": "12345"
#        }
#    ]
# }
#########################################################################

# Checkout a remote repository using svn into the supplied local path
Import-Module $env:PicassioTools -DisableNameChecking -ErrorAction Stop

function Start-Module($colour, $variables, $credentials) {
    Test-Module $colour $variables $credentials

    if (!(Test-Software svn.exe 'svn')) {
        Write-Errors 'SVN is not installed'
        Install-AdhocSoftware 'svn' 'SVN'
    }

    $url = (Replace-Variables $colour.remote $variables).Trim()
    $path = (Replace-Variables $colour.localpath $variables).Trim()

    if (!(Test-Path $path)) {
        New-Item -ItemType Directory -Force -Path $path | Out-Null
    }

    $name = (Replace-Variables $colour.localname $variables).Trim()
    $revision = Replace-Variables $colour.revision $variables
    if ($revision -ne $null) {
        $revision = $revision.Trim()
    }

    # Delete existing directory
    Push-Location $path

    try {
        if ((Test-Path $name)) {
            Backup-Directory $name
        }

        # checkout
        Write-Message "Checking out SVN repository from '$url' to '$path'."
        Run-Command 'svn.exe' "checkout $url $name"

        # reset to revision
        if (![string]::IsNullOrWhiteSpace($revision)) {
            Write-Message "Resetting local repository to revision $revision."
            Push-Location $name

            try {
                Run-Command 'svn.exe' "up -r $revision"
            }
            finally {
                Pop-Location
            }
        }

        Write-Message 'SVN checkout was successful.'
    }
    finally {
        Pop-Location
    }
}

function Test-Module($colour, $variables, $credentials) {
    $url = Replace-Variables $colour.remote $variables
    if ([string]::IsNullOrWhiteSpace($url)) {
        throw 'No remote SVN repository passed.'
    }

    $path = Replace-Variables $colour.localpath $variables
    if ([string]::IsNullOrWhiteSpace($path)) {
        throw 'No local SVN repository path specified.'
    }

    $name = Replace-Variables $colour.localname $variables
    if ([string]::IsNullOrWhiteSpace($name)) {
        throw 'No local name supplied for local repository.'
    }
}
