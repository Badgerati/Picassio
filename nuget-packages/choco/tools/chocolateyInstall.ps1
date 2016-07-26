$ErrorActionPreference = 'Stop';

$packageName= 'Picassio'
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$url        = 'https://github.com/Badgerati/Picassio/releases/download/v$version$/$version$-Binaries.zip'

$packageArgs = @{
  packageName   = $packageName
  unzipLocation = $toolsDir
  url           = $url
}

# Download Picassio
Install-ChocolateyZipPackage @packageArgs

Write-Host $pwd -ForegroundColor Cyan

# Install Picassio
$picassioPath = Join-Path $env:chocolateyPackageFolder 'tools/src'
Push-Location $picassioPath

try
{
    .\Picassio.ps1 -install
    refreshenv
}
finally
{
    Pop-Location
}
