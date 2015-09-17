# Use MSBuild to build a project or solution
Import-Module $env:PicassioTools -DisableNameChecking

function Start-Module($colour) {
	Validate-Module $colour

    $path = $colour.path
	if ([String]::IsNullOrWhiteSpace($path)) {
		Write-Message 'No path supplied, using default.'
		$path = 'C:\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe'
	}
	else {
		$path = $path.Trim()
	}

	$projects = $colour.projects
	$args = $colour.arguments

	ForEach ($project in $projects) {
		$project = $project.Trim()

		if (!(Test-Path $project)) {
			throw "Path to project for building does not exist: '$project'"
		}

		Push-Location (Split-Path $project -Parent)
		$file = (Split-Path $project -Leaf)
		$command = "$path $args $project"

		Write-Message "Building project: '$file'."
		(cmd.exe /C $command) | Out-Null

		if (!$?) {
			Pop-Location
			throw "Failed to build project '$file'."
		}

		Pop-Location
		Write-Message "Project '$file' built successfully."
	}
}

function Validate-Module($colour) {
    $path = $colour.path
	if ([String]::IsNullOrWhiteSpace($path)) {
		$path = 'C:\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe'
	}

    if (!(Test-Path $path)) {
        throw "Path to MSBuild.exe does not exist: '$path'"
    }

	$projects = $colour.projects
	if ($projects -eq $null -or $projects.Length -eq 0) {
		throw 'No projects have been supplied for MSBuild.'
	}
	
	ForEach ($project in $projects) {
		if ([string]::IsNullOrWhiteSpace($project)) {
			throw 'No from path specified to build project.'
		}
	}
}