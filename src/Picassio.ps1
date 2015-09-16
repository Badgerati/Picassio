param (
    [string]$config,
    [switch]$help = $false,
    [switch]$version = $false,
	[switch]$install = $false,
	[switch]$uninstall = $false,
	[switch]$reinstall = $false,
	[switch]$draw = $false,
	[switch]$erase = $false
)

$modulePath = $env:PicassioTools
if ([String]::IsNullOrWhiteSpace($modulePath)) {
	$modulePath = '.\Tools\PicassioTools.psm1'

	if (!(Test-Path $modulePath)) {
		throw 'Cannot find Picassio tools module.'
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

    # Ensure that there's a palette and paint section
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

					$extension = "$env:PicassioExtensions\$extensionName.psm1"

					if (!(Test-Path $extension)) {
						throw "Unrecognised extension found: '$extensionName'."
					}

					Import-Module $extension -DisableNameChecking -ErrorAction SilentlyContinue
				
					if (!(Get-Command 'Start-Extension' -CommandType Function -ErrorAction SilentlyContinue)) {
						throw "Extension module for '$extensionName' does not have a Start-Extension function."
					}
					
					if (!(Get-Command 'Validate-Extension' -CommandType Function -ErrorAction SilentlyContinue)) {
						throw "Extension module for '$extensionName' does not have a Validate-Extension function."
					}

					Validate-Extension $colour
					Remove-Module $extensionName
				}

			default
				{
					$module = "$env:PicassioModules\$type.psm1"

					if (!(Test-Path $module)) {
						throw "Unrecognised colour type found: '$type'."
					}

					Import-Module $module -DisableNameChecking -ErrorAction SilentlyContinue
				
					if (!(Get-Command 'Start-Module' -CommandType Function -ErrorAction SilentlyContinue)) {
						throw "Module for '$type' does not have a Start-Module function."
					}
					
					if (!(Get-Command 'Validate-Module' -CommandType Function -ErrorAction SilentlyContinue)) {
						throw "Module for '$type' does not have a Validate-Module function."
					}

					Validate-Module $colour
					Remove-Module $type
				}
		}
	}
	
	Import-Module $modulePath -DisableNameChecking
    Write-Message 'Configuration file is valid.'

    # Return config as json
    return $json
}

# Installs Picassio
function Install-Picassio() {
	if (!(Test-Path .\Picassio.ps1)) {
		Write-Error 'Installation should only be called from where the Picassio scripts actually reside.'
		return
	}

	Write-Information 'Installing Picassio.'

	$main = 'C:\Picassio'
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

	Write-Message 'Copying Picassio scripts.'
	Copy-Item -Path .\Picassio.ps1 -Destination $main -Force | Out-Null
	Copy-Item -Path .\Tools\PicassioTools.psm1 -Destination $tools -Force | Out-Null

	Write-Message 'Copying core modules.'
	Copy-Item -Path .\Modules\* -Destination $modules -Force -Recurse | Out-Null

	Write-Message 'Updating environment Path.'
	if (!($env:Path.Contains($main))) {
		$current = Get-EnvironmentVariable 'Path'

		if ($current.EndsWith(';')) {
			$current += "$main"
		}
		else {
			$current += ";$main"
		}

		Set-EnvironmentVariable 'Path' $current
		$env:Path = $current
	}
	
	Write-Message 'Creating environment variables.'
	if ($env:PicassioModules -ne $modules) {
		$env:PicassioModules = $modules
		Set-EnvironmentVariable 'PicassioModules' $env:PicassioModules
	}
	
	if ($env:PicassioExtensions -ne $extensions) {
		$env:PicassioExtensions = $extensions
		Set-EnvironmentVariable 'PicassioExtensions' $env:PicassioExtensions
	}

	$toolsFile = "$tools\PicassioTools.psm1"

	if ($env:PicassioTools -ne $toolsFile) {
		$env:PicassioTools = $toolsFile
		Set-EnvironmentVariable 'PicassioTools' $env:PicassioTools
	}

	Write-Information 'Picassio has been installed successfully.'
}

# Uninstalls Picassio
function Uninstall-Picassio() {
	if (!(Test-PicassioInstalled)) {
		Write-Error 'Picassio has not been installed. Please install Picassio with ".\Picassio.ps1 -install".'
		return
	}

	Write-Information 'Uninstalling Picassio.'

	$main = 'C:\Picassio'
	
	if ((Test-Path $main)) {
		Write-Message "Deleting '$main' directory."
		Remove-Item -Path $main -Force -Recurse | Out-Null
	}

	Write-Message 'Removing Picassio from environment Path.'
	if (($env:Path.Contains($main))) {
		$current = Get-EnvironmentVariable 'Path'
		$current = $current.Replace($main, '')
		Set-EnvironmentVariable 'Path' $current
		$env:Path = $current
	}
	
	Write-Message 'Removing environment variables.'
	if (![String]::IsNullOrWhiteSpace($env:PicassioModules)) {
		Remove-Item env:\PicassioModules
		Set-EnvironmentVariable 'PicassioModules' $null
	}
	
	if (![String]::IsNullOrWhiteSpace($env:PicassioExtensions)) {
		Remove-Item env:\PicassioExtensions
		Set-EnvironmentVariable 'PicassioExtensions' $null
	}

	if (![String]::IsNullOrWhiteSpace($env:PicassioTools)) {
		Remove-Item env:\PicassioTools
		Set-EnvironmentVariable 'PicassioTools' $null
	}

	Write-Information 'Picassio has been uninstalled successfully.'
}

# Re-installs Picassio by uninstalling then re-installing
function Reinstall-Picassio() {
	if (!(Test-Path .\Picassio.ps1)) {
		Write-Error 'Re-installation should only be called from where the Picassio scripts actually reside.'
		return
	}

	Write-Information 'Re-installing Picassio.'

	if (Test-PicassioInstalled) {
		Uninstall-Picassio
	}
	else {
		Write-Message 'Picassio has not been installed. Skipping uninstall step.'
	}

	Install-Picassio
	
	Write-Information 'Picassio has been re-installed successfully.'
}




try {
	# Ensure we're running against the correct version of PowerShell
	$currentVersion = [decimal]([string](Get-Host | Select-Object Version).Version)
	if ($currentVersion -lt 3) {
		Write-Error "Picassio requires PowerShell 3.0 or greater, your version is $currentVersion"
		return
	}

	# Check switches first
	Write-Version
	if ($version) {
		return
	}
	elseif ($help) {
		Write-Help
		return
	}
	elseif ($install) {
		Install-Picassio
		return
	}
	elseif ($uninstall) {
		Uninstall-Picassio
		return
	}
	elseif ($reinstall) {
		Reinstall-Picassio
		return
	}

	# Main Picassio logic
	if (!(Test-PicassioInstalled)) {
		Write-Error 'Picassio has not been installed. Please install Picassio with ".\Picassio.ps1 -install".'
		return
	}

	if ([string]::IsNullOrWhiteSpace($config)) {
		Write-Message 'No config file supplied, using default.'
		$config = './Picassio.json'

		if (!(Test-Path $config)) {
			Write-Error 'Default Picassio.json file cannot be found in current directory.'
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
					Write-Header "$extensionName (ext)"
					$extension = "$env:PicassioExtensions\$extensionName.psm1"
					Import-Module $extension -DisableNameChecking -ErrorAction SilentlyContinue
					Start-Extension $colour
					Remove-Module $extensionName
				}

			default
				{
					Write-Header $type
					$module = "$env:PicassioModules\$type.psm1"
					Import-Module $module -DisableNameChecking -ErrorAction SilentlyContinue				
					Start-Module $colour
					Remove-Module $type
				}
		}
    	
		Import-Module $modulePath -DisableNameChecking
		Reset-Path

		Write-Stamp ('Time taken: {0}' -f $stopwatch.Elapsed)
		Write-Host ([string]::Empty)
	}

	Write-Stamp ('Total time taken: {0}' -f $total_stopwatch.Elapsed)
}
finally {
	if (![string]::IsNullOrWhiteSpace($modulePath)) {
		Remove-Module 'PicassioTools'
	}
}