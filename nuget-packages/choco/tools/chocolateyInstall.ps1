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
$picassioPath = Join-Path $env:chocolateyPackageFolder 'tools/src'
Push-Location $picassioPath

try
{
    $main = $pwd
    $tools = "$main\Tools"
    $modules = "$main\Modules"
    $extensions = "$main\Extensions"

    if (!(Test-Path $extensions))
    {
        Write-Host "Creating '$extensions' directory."
        New-Item -ItemType Directory -Force -Path $extensions | Out-Null
    }

    Write-Host 'Updating environment Path.'
    Install-ChocolateyPath -PathToInstall $main -PathType 'Machine'

    Write-Host 'Creating environment variables.'
    Install-ChocolateyEnvironmentVariable -VariableName 'PicassioModules' -VariableValue $modules -VariableType 'Machine'
    Install-ChocolateyEnvironmentVariable -VariableName 'PicassioExtensions' -VariableValue $extensions -VariableType 'Machine'

    $tools = "$tools\PicassioTools.psm1"
    Install-ChocolateyEnvironmentVariable -VariableName 'PicassioTools' -VariableValue $tools -VariableType 'Machine'

    refreshenv
}
finally
{
    Pop-Location
}
