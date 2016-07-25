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

# Install Picassio
.\Picassio -install
