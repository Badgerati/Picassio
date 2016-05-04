##########################################################################
# Picassio is a provisioning/deployment script which uses a single linear
# JSON file to determine what commands to execute.
#
# Copyright (c) 2015, Matthew Kelly (Badgerati)
# Company: Cadaeic Studios
# License: MIT (see LICENSE for details)
#########################################################################
param (
	[string]$palette,
	[switch]$help = $false,
	[switch]$version = $false,
	[switch]$install = $false,
	[switch]$uninstall = $false,
	[switch]$reinstall = $false,
	[switch]$paint = $false,
	[switch]$erase = $false,
	[switch]$validate = $false
)

$modulePath = $env:PicassioTools
if ([String]::IsNullOrWhiteSpace($modulePath)) {
	$modulePath = '.\Tools\PicassioTools.psm1'

	if (!(Test-Path $modulePath)) {
		throw 'Cannot find Picassio tools module.'
	}
}

Import-Module $modulePath -DisableNameChecking



# Ensures that the palette file passed is valid
function Test-File($palette) {
    Write-Message 'Validating palette file.'

    # Ensure file is passed
    if ([string]::IsNullOrWhiteSpace($palette)) {
        throw 'Palette file supplied cannot be empty.'
    }

    # Ensure file is of valid json format
    try {
        $json = $palette | ConvertFrom-Json
    }
    catch [exception] {
        throw $_.Exception
    }
	
    # Ensure that there's a paint section
	$paint = $json.paint
    if ($paint -eq $null -or $paint.Count -eq 0) {
        throw 'No paint array section found within palette.'
    }
    
    # Ensure all paint sections have a type
    $list = [array]($paint | Where-Object { [string]::IsNullOrWhiteSpace($_.type) })
    if ($list.Length -ne 0) {
        throw 'All paint colours need a type parameter.'
    }

	# Ensure all modules for paint exist
	$variables = @{}
	Test-Section $paint 'paint'
	
	# Ensure that if there's an erase section, it too is valid
	$erase = $json.erase
	if ($erase -ne $null -and $erase.Count -gt 0) {
		$list = [array]($erase | Where-Object { [string]::IsNullOrWhiteSpace($_.type) })
		if ($list.Length -ne 0) {
			throw 'All erase colours need a type parameter.'
		}
		
		# Ensure all modules for erase exist
		$variables = @{}
		Test-Section $erase 'erase'
	}
    	
    Write-Message 'Palette file is valid.'

    # Return config as json
    return $json
}

function Test-Section($section, $name) {
	ForEach ($colour in $section) {
		$type = $colour.type.ToLower()

		switch ($type) {
			'extension'
				{
					$extensionName = $colour.extension
					if ([String]::IsNullOrWhiteSpace($extensionName)) {
						throw "$name colour extension type does not have an extension key."
					}

					$extension = "$env:PicassioExtensions\$extensionName.psm1"

					if (!(Test-Path $extension)) {
						throw "Unrecognised extension found: '$extensionName' in $name section."
					}

					Import-Module $extension -DisableNameChecking -ErrorAction SilentlyContinue
				
					if (!(Get-Command 'Start-Extension' -CommandType Function -ErrorAction SilentlyContinue)) {
						throw "Extension module for '$extensionName' does not have a Start-Extension function."
					}
					
					if (!(Get-Command 'Test-Extension' -CommandType Function -ErrorAction SilentlyContinue)) {
						throw "Extension module for '$extensionName' does not have a Test-Extension function."
					}

					Test-Extension $colour $variables
					Remove-Module $extensionName
				}

			default
				{
					$module = "$env:PicassioModules\$type.psm1"

					if (!(Test-Path $module)) {
						throw "Unrecognised colour type found: '$type' in $name section."
					}

					Import-Module $module -DisableNameChecking -ErrorAction SilentlyContinue
				
					if (!(Get-Command 'Start-Module' -CommandType Function -ErrorAction SilentlyContinue)) {
						throw "Module for '$type' does not have a Start-Module function."
					}
					
					if (!(Get-Command 'Test-Module' -CommandType Function -ErrorAction SilentlyContinue)) {
						throw "Module for '$type' does not have a Test-Module function."
					}

					Test-Module $colour $variables
					Remove-Module $type
				}
		}
	}
	
	Import-Module $modulePath -DisableNameChecking
}

# Installs Picassio
function Install-Picassio() {
	if (!(Test-Path .\Picassio.ps1)) {
		Write-Errors 'Installation should only be called from where the Picassio scripts actually reside.'
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
		Reset-Path
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
		Write-Errors 'Picassio has not been installed. Please install Picassio with ".\Picassio.ps1 -install".'
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
		Write-Errors 'Re-installation should only be called from where the Picassio scripts actually reside.'
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

# Runs the palette, determining the section to be executed
function Run-Palette($paint, $erase) {
	if ($paint) { Run-Paint }
	elseif ($erase) { Run-Erase }
}

# Runs the paint section
function Run-Paint() {
	if ($json -ne $null) {
		Write-Information "Painting the current machine: $env:COMPUTERNAME"
		Run-Section $json.paint
	}
}

# Runs the erase section
function Run-Erase() {
	if ($json -ne $null) {
		Write-Information "Erasing the current machine: $env:COMPUTERNAME"
		Run-Section $json.erase
	}
}

# Runs the steps defined in the passed section
function Run-Section($section) {
	if ($section -eq $null -or $section.Count -eq 0) {
		throw 'There is no section present.'
	}

	# Setup variables
	$variables = @{}

	# Loop through each colour within the config file
	ForEach ($colour in $section) {
		Write-NewLine

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
					Start-Extension $colour $variables
					Remove-Module $extensionName
				}

			default
				{
					Write-Header $type
					$module = "$env:PicassioModules\$type.psm1"
					Import-Module $module -DisableNameChecking -ErrorAction SilentlyContinue
					Start-Module $colour $variables
					Remove-Module $type
				}
		}
    	
		# Report import the picassio tools module
		Import-Module $modulePath -DisableNameChecking
		Reset-Path

		Write-Stamp ('Time taken: {0}' -f $stopwatch.Elapsed)
		Write-NewLine
	}

	Write-Header ([string]::Empty)
}




try {
	# Ensure we're running against the correct version of PowerShell
	try {
		$currentVersion = [decimal]([string](Get-Host | Select-Object Version).Version)
	}
	catch {
		$currentVersion = [decimal]((Get-Host).Version.Major)
	}

	if ($currentVersion -lt 3) {
		Write-Errors "Picassio requires PowerShell 3.0 or greater, your version is $currentVersion"
		return
	}

	# Check switches
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
	# Check that picassio is installed on the machine
	if (!(Test-PicassioInstalled)) {
		Write-Errors 'Picassio has not been installed. Please install Picassio with ".\Picassio.ps1 -install".'
		return
	}

	# Check to see if a palette file was passed, if not we use the default picassio.palette
	if ([string]::IsNullOrWhiteSpace($palette)) {
		Write-Message "No palette file supplied, using default 'picassio.palette'."
		$palette = './picassio.palette'

		if (!(Test-Path $palette)) {
			Write-Errors "Default 'picassio.palette' file cannot be found in current directory."
			return
		}
	}
	elseif (!(Test-Path $palette)) {
		Write-Errors "Passed palette file does not exist: '$palette'."
		return
	}

	# Palette exists, but is the extension correct?
	$extension = [System.IO.Path]::GetExtension($palette)
	if ($extension -ne '.palette') {
		Write-Errors "Passed palette file is not a valid '.palette' file, extension passed was: '$extension'"
		return
	}

	# Setup main variables hashtable
	$variables = @{}

	# Validate the config file
	$json = Test-File (Get-Content $palette -Raw)

	# If we're only validating, exit the program now
	if ($validate) {
		return
	}

	# If paint and erase switches are both false or true, exit program
	if (!$paint -and !$erase) {
		Write-Warning 'Need to specify either the paint or erase flags.'
		return
	}

	if ($paint -and $erase) {
		Write-Warning 'You can only specify either the paint or erase flag, not both.'
		return
	}
	
	# Start the stopwatch for total time tracking
	$total_stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

	# Check to see if we need to erase first, and only if we're painting
	if (![string]::IsNullOrWhiteSpace($json.eraseBeforePaint) -and $json.eraseBeforePaint -eq $true -and $paint) {
		Run-Erase
		Write-NewLine
	}
	
	# Get either the paint or erase section
	Run-Palette $paint $erase

	Write-Stamp ('Total time taken: {0}' -f $total_stopwatch.Elapsed)
	Write-Information 'Picassio finished successfully.'
}
catch [exception] {
	if ($total_stopwatch -ne $null) {
		Write-Stamp ('Total time taken: {0}' -f $total_stopwatch.Elapsed)
	}

	Write-Warning 'Picassio failed to finish.'
	Pop-Location -ErrorAction SilentlyContinue

	# Rollback
	try {
		if (![string]::IsNullOrWhiteSpace($json.rollbackOnFail) -and $json.rollbackOnFail -eq $true) {
			Write-Information "`nRolling back the palette.`n"
			Run-Palette $erase $paint
		}
	}
	catch [exception] {
		Write-Errors 'Failed to rollback the palette. Rollback exception:'
		Write-Exception $_.Exception
		Write-NewLine
		Write-Notice 'Main failure exception:'
	}

	throw
}
finally {
	$variables = @{}

	# Remove the picassio tools module
	if (![string]::IsNullOrWhiteSpace($modulePath)) {
		Remove-Module 'PicassioTools'
	}
}