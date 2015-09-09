# Clones the remote repository into the supplied local path
Import-Module $env:PICASSO_TOOLS -DisableNameChecking

function Start-Module($colour) {
    if (!(Test-Software git.exe 'git')) {
        Write-Error 'Git is not installed'
        Install-AdhocSoftware 'git.install' 'Git'
    }

    $url = $colour.remote
    if (!($url -match '(\\|\/)(?<repo>[a-zA-Z]+)\.git')) {
        throw "Remote git repository of '$url' is not valid."
    }

    $directory = $matches['repo']
    
    $path = $colour.localpath
    if ([string]::IsNullOrWhiteSpace($path)) {
        throw 'No local git repository path specified.'
    }

    if (!(Test-Path $path)) {
        New-Item -ItemType Directory -Force -Path $path | Out-Null
    }

    $branch = $colour.branchname
    if ([string]::IsNullOrWhiteSpace($branch)) {
        $branch = 'master'
    }

    $commit = $colour.commit
    $name = $colour.localname

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