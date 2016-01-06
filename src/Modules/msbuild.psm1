##########################################################################
# Picassio is a provisioning/deployment script which uses a single linear
# JSON file to determine what commands to execute.
#
# Copyright (c) 2015, Matthew Kelly (Badgerati)
# Company: Cadaeic Studios
# License: MIT (see LICENSE for details)
#########################################################################

# Use MSBuild to build a project or solution
Import-Module $env:PicassioTools -DisableNameChecking

function Start-Module($colour, $variables) {
	Test-Module $colour $variables

    $path = Replace-Variables $colour.path $variables
	if ([String]::IsNullOrWhiteSpace($path)) {
		Write-Message 'No path supplied, using default.'
		$path = 'C:\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe'
	}
	else {
		$path = $path.Trim()
	}
	
	$projects = $colour.projects
	$clean = Replace-Variables $colour.clean $variables
	$_args = Replace-Variables $colour.arguments $variables
	if ($_args -eq $null) {
		$_args = ""
	}

	ForEach ($project in $projects) {
		$project = (Replace-Variables $project $variables).Trim()

		if (!(Test-Path $project)) {
			throw "Path to project for building does not exist: '$project'"
		}

		Push-Location (Split-Path $project -Parent)
		$file = (Split-Path $project -Leaf)

		Write-SubHeader "$file"
		Write-Information "Arguments: '$_args'."
		
		$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

		if (![string]::IsNullOrWhiteSpace($clean) -and $clean -eq $true) {
			Write-Host 'Cleaning...'
			Build-Project $path "/p:Configuration=Debug /t:Clean $project"
			Build-Project $path "/p:Configuration=Release /t:Clean $project"
		}

		Write-Host 'Building...'
		Build-Project $path "$_args $project"
		Pop-Location

		Write-Stamp ('Time taken: {0}' -f $stopwatch.Elapsed)
		Write-Message "Project built successfully."
		Write-Host ([string]::Empty)
	}
}

function Test-Module($colour, $variables) {
    $path = Replace-Variables $colour.path $variables
	if ([String]::IsNullOrWhiteSpace($path)) {
		$path = 'C:\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe'
	}

    if (!(Test-Path $path)) {
        throw "Path to MSBuild.exe does not exist: '$path'"
    }

	$clean = Replace-Variables $colour.clean $variables
	if (![string]::IsNullOrWhiteSpace($clean) -and $clean -ne $true -and $clean -ne $false) {
		throw "Invalid value for clean: '$clean'. Should be either true or false."
	}

	$projects = $colour.projects
	if ($projects -eq $null -or $projects.Length -eq 0) {
		throw 'No projects have been supplied for MSBuild.'
	}
	
	ForEach ($project in $projects) {
		if ([string]::IsNullOrWhiteSpace($project)) {
			throw 'No path specified to build project.'
		}
	}
}


function Build-Project($command, $_args) {
	$output = Run-Command $command $_args
	
	if ($output -ne $null) {
		Pop-Location
		$output | ForEach-Object { Write-Errors $_ }
		throw 'Project failed to build'
	}
}