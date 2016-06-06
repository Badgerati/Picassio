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
#			"type": "copy",
#			"from": "C:\\path\\to\\folder",
#			"to": "C:\\path\\to\\other\\folder",
#			"excludeFiles": [ "*.html", "*.js" ],
#			"includeFolders": [ "src" ]
#		}
#	]
# }
#########################################################################

# Copy files/folders from one location to another
Import-Module $env:PicassioTools -DisableNameChecking -ErrorAction Stop

function Start-Module($colour, $variables, $credentials)
{
    Test-Module $colour $variables $credentials

    $from = (Replace-Variables $colour.from $variables).Trim()
    $to = (Replace-Variables $colour.to $variables).Trim()

    if (!(Test-Path $from))
    {
        throw "From path specified doesn't exist: '$from'."
    }

    $excludeFiles = $colour.excludeFiles
    $excludeFolders = $colour.excludeFolders

    if ($excludeFolders -ne $null -and $excludeFolders.Length -gt 0)
    {
        [Regex]$excludeFoldersRegex = (($excludeFolders | ForEach-Object {[Regex]::Escape((Replace-Variables $_ $variables))}) -join '|')
    }

    if ($excludeFiles -ne $null)
    {
        for ($i = 0; $i -lt $excludeFiles.Length; $i++)
        {
            $excludeFiles[$i] = Replace-Variables $excludeFiles[$i] $variables
        }
    }

    $includeFiles = $colour.includeFiles
    $includeFolders = $colour.includeFolders

    if ($includeFolders -ne $null -and $includeFolders.Length -gt 0)
    {
        [Regex]$includeFoldersRegex = (($includeFolders | ForEach-Object {[Regex]::Escape((Replace-Variables $_ $variables))}) -join '|')
    }

    if ($includeFiles -ne $null)
    {
        for ($i = 0; $i -lt $includeFiles.Length; $i++)
        {
            $includeFiles[$i] = Replace-Variables $includeFiles[$i] $variables
        }
    }

    Write-Message "Copying files/folders from '$from' to '$to'."

    Get-ChildItem -Path $from -Recurse -Force -Exclude $excludeFiles -Include $includeFiles |
        Where-Object { $excludeFoldersRegex -eq $null -or $_.FullName.Replace($from, [String]::Empty) -notmatch $excludeFoldersRegex } |
        Where-Object { $includeFoldersRegex -eq $null -or $_.FullName.Replace($from, [String]::Empty) -match $includeFoldersRegex } |
        Copy-Item -Destination {
            if ($_.PSIsContainer)
            {
                $path = Join-Path $to $_.Parent.FullName.Substring($from.Length)
                $temp = $path
            }
            else
            {
                $path = Join-Path $to $_.FullName.Substring($from.Length)
                $temp = Split-Path -Parent $path
            }

            if (!(Test-Path $temp))
            {
                New-Item -ItemType Directory -Force -Path $temp | Out-Null
            }

            $path
        } -Force -Exclude $excludeFiles -Include $includeFiles

    if (!$?)
    {
        throw 'Failed to copy files/folders.'
    }

    Write-Message 'Files/folders copied successfully.'
}

function Test-Module($colour, $variables, $credentials)
{
    $from = Replace-Variables $colour.from $variables
    if ([string]::IsNullOrWhiteSpace($from))
    {
        throw 'No from path specified.'
    }

    $to = Replace-Variables $colour.to $variables
    if ([string]::IsNullOrWhiteSpace($to))
    {
        throw 'No to path specified.'
    }
}
