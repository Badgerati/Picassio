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
#			"type": "svn",
#			"url": "https://url.to.some.svn",
#			"path": "C:\\path\\to\\local\\svn",
#			"name": "LocalName",
#			"revision": "12345"
#		}
#	]
# }
#########################################################################

# Checkout a remote repository using svn into the supplied local path
Import-Module $env:PicassioTools -DisableNameChecking

function Start-Module($colour, $variables) {
	Test-Module $colour $variables

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
    if ((Test-Path $name)) {
        Backup-Directory $name
    }

    # checkout
    Write-Message "Checking out SVN repository from '$url' to '$path'."
    svn.exe checkout $url $name

    if (!$?) {
        Pop-Location
        throw 'Failed to checkout SVN repository.'
    }

    # reset to revision
    if (![string]::IsNullOrWhiteSpace($revision)) {
        Write-Message "Resetting local repository to revision $revision."
        Push-Location $name
        svn.exe up -r $revision

        if (!$?) {
            Pop-Location
            Pop-Location
            throw "Failed to reset repository to revision $revision."
        }
    }

    Pop-Location
    Pop-Location
    Write-Message 'SVN checkout was successful.'
}

function Test-Module($colour, $variables) {
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