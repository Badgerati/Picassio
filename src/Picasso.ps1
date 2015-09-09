param (
    [string]$config,
    [switch]$help = $false,
    [switch]$version = $false
)

Import-Module $env:PICASSO_TOOLS -DisableNameChecking

# Ensure we're running against the correct version of PowerShell
$currentVersion = [decimal]([string](Get-Host | Select-Object Version).Version)
if ($currentVersion -lt 3) {
    Write-Error "Picasso requires PowerShell 3.0 or greater, your version is $currentVersion"
    return
}

# Check switches first
if ($version) {
    Write-Version
    return
}
else {
    Write-Version
}

if ($help) {
    Write-Help
    return
}

# Main Picasso logic
if ([string]::IsNullOrWhiteSpace($config)) {
    Write-Message 'No config file supplied, using default.'
    $config = './picasso.json'

    if (!(Test-Path $config)) {
        Write-Error 'Default picasso.json file cannot be found in current directory.'
        return
    }
}
elseif (!(Test-Path $config)) {
    Write-Error "Passed configuration file does not exist: '$config'"
    return
}

$json = Validate-File (Get-Content $config -Raw)

if ((Test-ColourType $json 'software')) {
    Install-Chocolatey
}

$total_stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

ForEach ($colour in $json.palette.paint) {
    Write-Host ([string]::Empty)

    $type = $colour.type.ToLower()
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    $description = $colour.description
    if (![String]::IsNullOrWhiteSpace($description)) {
        Write-Host $description -ForegroundColor Green
    }

    switch ($type) {
        default
            {
				$module = "$env:PICASSO_MODULES\$type.psm1"

				if (!(Test-Path $module)) {
					Write-Host "Unrecognised colour type found: '$type'." -ForegroundColor Red
					return
				}

				Import-Module $module -DisableNameChecking -ErrorAction SilentlyContinue
				
				if (!(Get-Command 'Start-Module' -CommandType Function -ErrorAction SilentlyContinue)) {
					Write-Host "Module for '$type' does not have a Start-Module function." -ForegroundColor Red
					return
				}

				Start-Module $colour
				Remove-Module $type
            }
    }
    
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')

    Write-Host ('Time taken: {0}' -f $stopwatch.Elapsed) -ForegroundColor Magenta
    Write-Host ([string]::Empty)
}

Write-Host ('Total time taken: {0}' -f $total_stopwatch.Elapsed) -ForegroundColor Magenta


# Ensures that the configuration file passed is valid
function Validate-File($config) {
    Write-Message 'Validating configuration file.'

    # Ensure file is passed
    if ([string]::IsNullOrWhiteSpace($config)) {
        throw 'Configuration file supplied cannot be empty.'
    }

    # Ensure file is of valid json format
    try {
        $json = $config | ConvertFrom-Json
    }
    catch [exception] {
        throw $_.Exception
    }

    # Ensure that there's a pallete and paint section
    if ($json.palette -eq $null) {
        throw 'No palette section found.'
    }
    
    if ($json.palette.paint -eq $null -or $json.palette.paint.Count -eq 0) {
        throw 'No paint array section found within palette.'
    }
    
    # Ensure all paint sections have a type
    $list = [array]($json.palette.paint | Where-Object { [string]::IsNullOrWhiteSpace($_.type) })

    if ($list.Length -ne 0) {
        throw 'All paint colours need a type parameter.'
    }
    
    Write-Message 'Configuration file is valid.'

    # Return config as json
    return $json
}