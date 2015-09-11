# Copy files/folders from one location to another
Import-Module $env:PicassoTools -DisableNameChecking

function Start-Module($colour) {
    $from = $colour.from
    if ([string]::IsNullOrWhiteSpace($from)) {
        throw 'No from path specified.'
    }
    
    if (!(Test-Path $from)) {
        throw "From path specified doesn't exist: '$from'."
    }

    $to = $colour.to
    if ([string]::IsNullOrWhiteSpace($to)) {
        throw 'No to path specified.'
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