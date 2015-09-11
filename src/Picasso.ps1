param (
    [string]$config,
    [switch]$help = $false,
    [switch]$version = $false,
	[switch]$install = $false
)

$modulePath = $env:PicassoTools
if ([String]::IsNullOrWhiteSpace($modulePath)) {
	$modulePath = '.\Tools\PicassoTools.psm1'

	if (!(Test-Path $modulePath)) {
		throw 'Cannot find picasso tools module.'
	}
}

Import-Module $modulePath -DisableNameChecking



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
    
	# Ensure all modules exist
	ForEach ($colour in $json.palette.paint) {
		$type = $colour.type.ToLower()

		switch ($type) {
			'extension'
				{
					$extensionName = $colour.extension
					if ([String]::IsNullOrWhiteSpace($extensionName)) {
						throw "Colour extension type does not have an extension key."
					}

					$extension = "$env:PicassoExtensions\$extensionName.psm1"

					if (!(Test-Path $extension)) {
						throw "Unrecognised extension found: '$extensionName'."
					}

					Import-Module $extension -DisableNameChecking -ErrorAction SilentlyContinue
				
					if (!(Get-Command 'Start-Extension' -CommandType Function -ErrorAction SilentlyContinue)) {
						throw "Extension module for '$extensionName' does not have a Start-Extension function."
					}

					Remove-Module $extensionName
				}

			default
				{
					$module = "$env:PicassoModules\$type.psm1"

					if (!(Test-Path $module)) {
						throw "Unrecognised colour type found: '$type'."
					}

					Import-Module $module -DisableNameChecking -ErrorAction SilentlyContinue
				
					if (!(Get-Command 'Start-Module' -CommandType Function -ErrorAction SilentlyContinue)) {
						throw "Module for '$type' does not have a Start-Module function."
					}

					Remove-Module $type
				}
		}
	}
	
	Import-Module $modulePath -DisableNameChecking
    Write-Message 'Configuration file is valid.'

    # Return config as json
    return $json
}

# Installs Picasso
function Install-Picasso() {
	if (!(Test-Path .\Picasso.ps1)) {
		Write-Error 'Installation should only be called from where the picasso scripts actually reside.'
		return
	}

	Write-Information 'Installing picasso.'

	$main = 'C:\Picasso'
	$tools = "$main\Tools"
	$modules = "$main\Modules"
	$extensions = "$main\Extensions"
	
	if (!(Test-Path $main)) {
		Write-Message "Creating '$main' directory."
		New-Item -ItemType Directory -Force -Path $main | Out-Null
	}
	
	if (!(Test-Path $tools)) {
		Write-Message "Creating '$tools' directory."
		New-Item -ItemType Directory -Force -Path $tools | Out-Null
	}

	if (!(Test-Path $modules)) {
		Write-Message "Creating '$modules' directory."
		New-Item -ItemType Directory -Force -Path $modules | Out-Null
	}

	if (!(Test-Path $extensions)) {
		Write-Message "Creating '$extensions' directory."
		New-Item -ItemType Directory -Force -Path $extensions | Out-Null
	}

	Write-Message 'Copying picasso scripts.'
	Copy-Item -Path .\Picasso.ps1 -Destination $main -Force | Out-Null
	Copy-Item -Path .\Tools\PicassoTools.psm1 -Destination $tools -Force | Out-Null

	Write-Message 'Copying core modules.'
	Copy-Item -Path .\Modules\* -Destination $modules -Force -Recurse | Out-Null

	Write-Message 'Updating environment Path.'
	if (!($env:Path.Contains($main))) {
		if ($env:Path.EndsWith(';')) {
			$env:Path += "$main"
		}
		else {
			$env:Path += ";$main"
		}

		[Environment]::SetEnvironmentVariable('Path', $env:Path, [System.EnvironmentVariableTarget]::Machine)
	}
	
	Write-Message 'Creating environment variables.'
	if ($env:PicassoModules -ne $modules) {
		$env:PicassoModules = $modules
		[Environment]::SetEnvironmentVariable('PicassoModules', $env:PicassoModules, [System.EnvironmentVariableTarget]::Machine)
	}
	
	if ($env:PicassoExtensions -ne $extensions) {
		$env:PicassoExtensions = $extensions
		[Environment]::SetEnvironmentVariable('PicassoExtensions', $env:PicassoExtensions, [System.EnvironmentVariableTarget]::Machine)
	}

	$toolsFile = "$tools\PicassoTools.psm1"

	if ($env:PicassoTools -ne $toolsFile) {
		$env:PicassoTools = $toolsFile
		[Environment]::SetEnvironmentVariable('PicassoTools', $env:PicassoTools, [System.EnvironmentVariableTarget]::Machine)
	}

	Write-Information 'Installation complete.'
}



# Ensure we're running against the correct version of PowerShell
$currentVersion = [decimal]([string](Get-Host | Select-Object Version).Version)
if ($currentVersion -lt 3) {
    Write-Error "Picasso requires PowerShell 3.0 or greater, your version is $currentVersion"
    return
}

# Check switches first
Write-Version
if ($version) {
    return
}

if ($help) {
    Write-Help
    return
}

if ($install) {
	Install-Picasso
	return
}

# Main Picasso logic
if ([String]::IsNullOrWhiteSpace($env:PicassoTools) -or [String]::IsNullOrWhiteSpace($env:PicassoModules) -or [String]::IsNullOrWhiteSpace($env:PicassoModules)) {
	Write-Error 'Picasso has not been installed. Please install picasso with ".\Picasso.ps1 -install".'
	return
}

if ([string]::IsNullOrWhiteSpace($config)) {
    Write-Message 'No config file supplied, using default.'
    $config = './picasso.json'

    if (!(Test-Path $config)) {
        Write-Error 'Default picasso.json file cannot be found in current directory.'
        return
    }
}
elseif (!(Test-Path $config)) {
    Write-Error "Passed configuration file does not exist: '$config'."
    return
}

$json = Validate-File (Get-Content $config -Raw)

$total_stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

ForEach ($colour in $json.palette.paint) {
    Write-Host ([string]::Empty)

    $type = $colour.type.ToLower()
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    $description = $colour.description
    if (![String]::IsNullOrWhiteSpace($description)) {
        Write-Information $description
    }

    switch ($type) {
		'extension'
			{
				$extensionName = $colour.extension
				$extension = "$env:PicassoExtensions\$extensionName.psm1"
				Import-Module $extension -DisableNameChecking -ErrorAction SilentlyContinue
				Start-Extension $colour
				Remove-Module $extensionName
			}

        default
            {
				$module = "$env:PicassoModules\$type.psm1"
				Import-Module $module -DisableNameChecking -ErrorAction SilentlyContinue				
				Start-Module $colour
				Remove-Module $type
            }
    }
    
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
	
	Import-Module $modulePath -DisableNameChecking

    Write-Stamp ('Time taken: {0}' -f $stopwatch.Elapsed)
    Write-Host ([string]::Empty)
}

Write-Stamp ('Total time taken: {0}' -f $total_stopwatch.Elapsed)
