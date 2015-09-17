# Clones the remote repository into the supplied local path
Import-Module $env:PicassioTools -DisableNameChecking

function Start-Module($colour) {
	Validate-Module $colour

    if (!(Test-Software git.exe 'git')) {
        Write-Errors 'Git is not installed'
        Install-AdhocSoftware 'git.install' 'Git'
    }

    $url = $colour.remote.Trim()
    if (!($url -match '(\\|\/)(?<repo>[a-zA-Z]+)\.git')) {
        throw "Remote git repository of '$url' is not valid."
    }

    $directory = $matches['repo']
    
    $path = $colour.localpath.Trim()
    if (!(Test-Path $path)) {
        New-Item -ItemType Directory -Force -Path $path | Out-Null
    }

    $branch = $colour.branchname
    if ([string]::IsNullOrWhiteSpace($branch)) {
        $branch = 'master'
    }
	else {
		$branch = $branch.Trim()
	}

    $commit = $colour.commit
	if ($commit -ne $null) {
		$commit = $commit.Trim()
	}

    $name = $colour.localname
	if ($name -ne $null) {
		$name = $name.Trim()
	}

    # delete directory if exists
    Push-Location $path
    if ((Test-Path $directory)) {
        Backup-Directory $directory
    }
    elseif (![string]::IsNullOrWhiteSpace($name) -and (Test-Path $name)) {
        Backup-Directory $name
    }

    # clone
    Write-Message "Cloning git repository from '$url' to '$path'."
    git.exe clone $url

    if (!$?) {
        Pop-Location
        throw 'Failed to clone git repository.'
    }

    # rename
    if (![string]::IsNullOrWhiteSpace($name)) {
        Rename-Item $directory $name | Out-Null
        Write-Message "Local directory renamed from '$directory' to '$name'."
        $directory = $name
    }

    # checkout
    Write-Message "Checking out the '$branch' branch."
    Push-Location $directory
    git.exe checkout $branch

    if (!$?) {
        Pop-Location
        Pop-Location
        throw "Failed to checkout the '$branch' branch."
    }

    # reset
    if (![string]::IsNullOrWhiteSpace($commit)) {
        Write-Message "Resetting local repository to the $commit commit."
        git.exe reset --hard $commit
    
        if (!$?) {
            Pop-Location
            Pop-Location
            throw "Failed to reset repository to $commit commit."
        }
    }

    Pop-Location
    Pop-Location
    Write-Message 'Git clone was successful.'
}

function Validate-Module($colour) {
    $url = $colour.remote

	if ($url -eq $null) {
		$url = [string]::Empty
	}

	$url = $url.Trim()

    if (!($url -match '(\\|\/)(?<repo>[a-zA-Z]+)\.git')) {
        throw "Remote git repository of '$url' is not valid."
    }
	    
    $path = $colour.localpath

	if ($path -ne $null) {
		$path = $path.Trim()
	}

    if ([string]::IsNullOrWhiteSpace($path)) {
        throw 'No local git repository path specified.'
    }
}