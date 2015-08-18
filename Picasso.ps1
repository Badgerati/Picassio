param (
    [string]$config,
    [switch]$help = $false,
    [switch]$version = $false
)


# Writes a general message to the console
function Write-Message($message) {
    Write-Host $message -ForegroundColor Cyan
}

# Tests to see if a URL is valid
function Test-Url($url) {
    if ([string]::IsNullOrWhiteSpace($url)) {
        return $false
    }

    try {
        $request = [System.Net.WebRequest]::Create($url)
        $response = $request.GetResponse()
        return $response.StatusCode -eq 200
    }
    catch [exception] {
        return $false
    }
    finally {
        if ($response -ne $null) {
            $response.Close()
        }
    }
}

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

# Check to see if we have a paint colour of the passed type
function Test-ColourType($json, $type) {
    $list = [array]($json.palette.paint | Where-Object { $_.type.ToLower() -eq $type.ToLower() })
    return ($list.Length -ne 0)
}

# Check to see if a piece of software is installed
function Test-Software($command) {
    try {
        $value = [string]::Empty
        $value = & $command

        if (![string]::IsNullOrWhiteSpace($value)) {
            return $true
        }
    }
    catch [exception] { }

    return $false
}

# Install Chocolatey - if already installed, will just update
function Install-Chocolatey() {
    if (Test-Software choco.exe) {
        Write-Message 'Chocolatey is already installed'
        return
    }
    
    Write-Message 'Installing Chocolately.'
    Set-ExecutionPolicy Unrestricted
    Invoke-Expression ((New-Object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
    Write-Message 'Chocolately installed.'
}

# Checkout a remote repository using svn into the supplied local path
function Checkout-Svn($colour) {
    if (!(Test-Software svn.exe)) {
        throw 'SVN is not installed'
    }

    $url = $colour.remote
    if ([string]::IsNullOrWhiteSpace($url)) {
        throw 'No remote SVN repository passed.'
    }

    $path = $colour.localpath
    if ([string]::IsNullOrWhiteSpace($path)) {
        throw 'No local SVN repository path specified.'
    }

    if (!(Test-Path $path)) {
        New-Item -ItemType Directory -Force -Path $path | Out-Null
    }

    $name = $colour.localname
    if ([string]::IsNullOrWhiteSpace($name)) {
        throw 'No local name supplied for local repository.'
    }

    $revision = $colour.revision
    
    # clone
    Write-Message "Checking out SVN repository from '$url' to '$path'."
    Push-Location $path
    svn.exe checkout $url $name

    if (!$?) {
        Pop-Location
        throw 'Failed to checkout SVN repository.'
    }

    # reset to revision
    if (![string]::IsNullOrWhiteSpace($revision)) {
        Write-Message "Resetting local repository to revision $revision."
        Push-Location $name
        svn.exe up -r $revision
    
        if (!$?) {
            Pop-Location
            Pop-Location
            throw "Failed to reset repository to revision $revision."
        }
    }

    Pop-Location
    Pop-Location
    Write-Message 'SVN checkout was successful.'
}

# Clones the remote repository into the supplied local path
function Clone-Git($colour) {
    if (!(Test-Software git.exe)) {
        throw 'Git is not installed'
    }

    $url = $colour.remote
    if (!($url -match '(\\|\/)(?<repo>[a-zA-Z]+)\.git')) {
        throw "Remote git repository of '$url' is not valid."
    }

    $directory = $matches['repo']

    $path = $colour.local
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
    
    # clone
    Write-Message "Cloning git repository from '$url' to '$path'."
    Push-Location $path
    git.exe clone $url

    if (!$?) {
        Pop-Location
        throw 'Failed to clone git repository.'
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

# Uses Chocolatey to install, upgrade or uninstall the speicified software
function Install-Software($colour) {
    $name = $colour.name
    if ([string]::IsNullOrWhiteSpace($name)) {
        throw 'No name supplied for software colour.'
    }

    $operation = ($colour.ensure.Substring(0, $colour.ensure.Length - 2)).ToLower()
    if ([string]::IsNullOrWhiteSpace($operation)) {
        throw 'No ensure operation supplied for software colour.'
    }

    if ($operation -eq 'install') {
        $result = (choco.exe list -lo | Where-Object { $_ -like "*$name *" } | Select-Object -First 1)

        if (![string]::IsNullOrEmpty($result)) {
            $operation = 'upgrade'
        }
    }

    if ([string]::IsNullOrWhiteSpace($colour.version) -or $colour.version.ToLower() -eq 'latest' -or $operation -eq 'unistall') {
        $versionTag = [string]::Empty
        $version = [string]::Empty
        $versionStr = 'latest'
    }
    else {
        $versionTag = '--version'
        $version = $colour.version
        $versionStr = $colour.version
    }

    Write-Message "$operation on $name application starting. Version: $versionStr"
    choco.exe $operation $name $versionTag $version -y

    if (!$?) {
        throw "Failed to $operation the $name software."
    }
    
    Write-Message "$operation on $name application successful."
}

# Use MSBuild to build a project or solution
function Use-MSBuild($colour) {
    $path = $colour.path
    if (!(Test-Path $path)) {
        throw 'Path to MSBuild.exe does not exist.'
    }

    $project = $colour.project
    if (!(Test-Path $project)) {
        throw 'Path to project for building does not exist.'
    }

    Push-Location (Split-Path $project -Parent)
    $file = (Split-Path $project -Leaf)

    $args = $colour.arguments
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

# Run a passed command using Command Prompt
function Run-Command($colour) {
    $command = $colour.command
    if ([string]::IsNullOrWhiteSpace($command)) {
        throw 'No command passed to run via Command Prompt.'
    }

    Write-Message 'Running command via Command Prompt.'
    cmd.exe /C $command

    if (!$?) {
        throw "Failed to run command: '$command'."
    }

    Write-Message 'Command ran successfully.'
}



# Check switches first
if ($version) {
    Write-Host 'Picasso v0.1.0a' -ForegroundColor Green
    return
}

if ($help) {
    Write-Host 'Help Manual' -ForegroundColor Green
    Write-Host ''
    Write-Host 'The following is a list of possible colour types:'
    Write-Host "`t- software"
    Write-Host "`t- git"
    Write-Host "`t- svn"
    Write-Host "`t- msbuild"
    Write-Host "`t- cmd"
    return
}


# Main Picasso logic
if ([string]::IsNullOrWhiteSpace($config)) {
    throw 'No configuration file supplied.'
}

if (!(Test-Path $config)) {
    throw 'Passed configuration file does not exist.'
}

$json = Validate-File (Get-Content $config -Raw)

if ((Test-ColourType $json 'software')) {
    Install-Chocolatey
}

ForEach ($colour in $json.palette.paint) {
    $type = $colour.type.ToLower()

    switch ($type) {
        'software'
            {
                Install-Software $colour
            }

        'svn'
            {
                Checkout-Svn $colour
            }

        'git'
            {
                Clone-Git $colour
            }

        'msbuild'
            {
                Use-MSBuild $colour
            }

        'cmd'
            {
                Run-Command $colour
            }

        default
            {
                Write-Error "Unrecognised colour type found: $type"
            }
    }

    Write-Host ([string]::Empty)
}