##########################################################################
# Picassio is a provisioning/deployment script which uses a single linear
# JSON file to determine what commands to execute.
#
# Copyright (c) 2015, Matthew Kelly (Badgerati)
# Company: Cadaeic Studios
# License: MIT (see LICENSE for details)
#########################################################################

# Copy files/folders from one location to another
Import-Module $env:PicassioTools -DisableNameChecking

function Start-Module($colour) {
	Test-Module $colour

    $from = $colour.from.Trim()
    $to = $colour.to.Trim()

	if (!(Test-Path $from)) {
        throw "From path specified doesn't exist: '$from'."
    }

    $excludeFiles = $colour.excludeFiles
    $excludeFolders = $colour.excludeFolders

    if ($excludeFolders -ne $null -and $excludeFolders.Length -gt 0) {
        [Regex]$excludeFoldersRegex = (($excludeFolders | ForEach-Object {[Regex]::Escape($_)}) –Join '|')
    }

    $includeFiles = $colour.includeFiles
    $includeFolders = $colour.includeFolders
    
    if ($includeFolders -ne $null -and $includeFolders.Length -gt 0) {
        [Regex]$includeFoldersRegex = (($includeFolders | ForEach-Object {[Regex]::Escape($_)}) –Join '|')
    }

    Write-Message "Copying files/folders from '$from' to '$to'."

    Get-ChildItem -Path $from -Recurse -Force -Exclude $excludeFiles -Include $includeFiles |
        Where-Object { $excludeFoldersRegex -eq $null -or $_.FullName.Replace($from, [String]::Empty) -notmatch $excludeFoldersRegex } |
        Where-Object { $includeFoldersRegex -eq $null -or $_.FullName.Replace($from, [String]::Empty) -match $includeFoldersRegex } |
        Copy-Item -Destination {
            if ($_.PSIsContainer) {
                $path = Join-Path $to $_.Parent.FullName.Substring($from.Length)
                $temp = $path
            }
            else {
                $path = Join-Path $to $_.FullName.Substring($from.Length)
                $temp = Split-Path -Parent $path
            }
			
            if (!(Test-Path $temp)) {
                New-Item -ItemType Directory -Force -Path $temp | Out-Null
            }
            
            $path
        } -Force -Exclude $excludeFiles -Include $includeFiles
    
    if (!$?) {
        throw 'Failed to copy files/folders.'
    }

    Write-Message 'Files/folders copied successfully.'
}

function Test-Module($colour) {
    $from = $colour.from
    if ([string]::IsNullOrWhiteSpace($from)) {
        throw 'No from path specified.'
    }
	
    $to = $colour.to
    if ([string]::IsNullOrWhiteSpace($to)) {
        throw 'No to path specified.'
    }
}