# Uninstall Picassio
$picassioPath = Join-Path $env:chocolateyPackageFolder 'tools/src'

Write-Host 'Removing Picassio from environment Path.'
if (($env:Path.Contains($picassioPath)))
{
    $current = (Get-EnvironmentVariable -Name 'PATH' -Scope 'Machine')
    $current = $current.Replace($picassioPath, [string]::Empty)
    Set-EnvironmentVariable -Name 'PATH' -Value $current -Scope 'Machine'
    $env:PATH = $current
}

Write-Host 'Removing environment variables.'
Uninstall-ChocolateyEnvironmentVariable -VariableName 'PicassioModules' -VariableType 'Machine'
Uninstall-ChocolateyEnvironmentVariable -VariableName 'PicassioExtensions' -VariableType 'Machine'
Uninstall-ChocolateyEnvironmentVariable -VariableName 'PicassioTools' -VariableType 'Machine'

refreshenv
