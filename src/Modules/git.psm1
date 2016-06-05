##########################################################################
# Picassio is a provisioning/deployment script which uses a single linear
# JSON file to determine what commands to execute.
#
# Copyright (c) 2015, Matthew Kelly (Badgerati)
# Company: Cadaeic Studios
# License: MIT (see LICENSE for details)
#
# Example:
#
# {
#    "paint": [
#        {
#            "type": "git",
#            "remote": "https://path//to/some/branch.git"
#            "branchname": "master",
#            "localpath": "C:\\path\\to\\place",
#            "localname": "NewBranch"
#        }
#    ]
# }
#########################################################################

# Clones the remote repository into the supplied local path
Import-Module $env:PicassioTools -DisableNameChecking -ErrorAction Stop

function Start-Module($colour, $variables, $credentials) {
    Test-Module $colour $variables $credentials

    if (!(Test-Software git.exe 'git')) {
        Write-Errors 'Git is not installed'
        Install-AdhocSoftware 'git.install' 'Git'
    }

    $url = (Replace-Variables $colour.remote $variables).Trim()
    if (!($url -match '(\\|\/)(?<repo>[a-zA-Z]+)\.git')) {
        throw "Remote git repository of '$url' is not valid."
    }

    $directory = $matches['repo']

    $path = (Replace-Variables $colour.localpath $variables).Trim()
    if (!(Test-Path $path)) {
        New-Item -ItemType Directory -Force -Path $path | Out-Null
    }

    $branch = Replace-Variables $colour.branchname $variables
    if ([string]::IsNullOrWhiteSpace($branch)) {
        $branch = 'master'
    }
    else {
        $branch = $branch.Trim()
    }

    $commit = Replace-Variables $colour.commit $variables
    if ($commit -ne $null) {
        $commit = $commit.Trim()
    }

    $name = Replace-Variables $colour.localname $variables
    if ($name -ne $null) {
        $name = $name.Trim()
    }

    # delete directory if exists
    Push-Location $path

    try {
        if ((Test-Path $directory)) {
            Backup-Directory $directory
        }
        elseif (![string]::IsNullOrWhiteSpace($name) -and (Test-Path $name)) {
            Backup-Directory $name
        }

        # clone
        Write-Message "Cloning git repository from '$url' to '$path'."
        Run-Command 'git.exe' "clone $url"

        # rename
        if (![string]::IsNullOrWhiteSpace($name)) {
            Rename-Item $directory $name | Out-Null
            if (!$?) {
                throw "Rename of directory from '$directory' to '$name' failed."
            }

            Write-Message "Local directory renamed from '$directory' to '$name'."
            $directory = $name
        }

        # checkout
        Write-Message "Checking out the '$branch' branch."
        Push-Location $directory

        try {
            Run-Command 'git.exe' "checkout $branch"

            # reset
            if (![string]::IsNullOrWhiteSpace($commit)) {
                Write-Message "Resetting local repository to the $commit commit."
                Run-Command 'git.exe' "reset --hard $commit"
            }

            Write-Message 'Git clone was successful.'
        }
        finally {
            Pop-Location
        }
    }
    finally {
        Pop-Location
    }
}

function Test-Module($colour, $variables, $credentials) {
    $url = Replace-Variables $colour.remote $variables
    if ($url -eq $null) {
        $url = [string]::Empty
    }

    $url = $url.Trim()

    if (!($url -match '(\\|\/)(?<repo>[a-zA-Z]+)\.git')) {
        throw "Remote git repository of '$url' is not valid."
    }

    $path = Replace-Variables $colour.localpath $variables
    if ($path -ne $null) {
        $path = $path.Trim()
    }

    if ([string]::IsNullOrWhiteSpace($path)) {
        throw 'No local git repository path specified.'
    }
}
