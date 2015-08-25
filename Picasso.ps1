param (
    [string]$config,
    [switch]$help = $false,
    [switch]$version = $false
)


# Writes a general message to the console
function Write-Message($message) {
    Write-Host $message -ForegroundColor Cyan
}

function Write-Error($message) {
    Write-Host $message -ForegroundColor Red
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

# Wipes a given directory
function Remove-Directory($directory) {
    Write-Message "Wiping directory: '$directory'."
    Remove-Item -Recurse -Force $directory | Out-Null
    Write-Message 'Directory wiped.'
}

# Ensures that the configuration file passed is valid
function Validate-File($config) {
    Write-Message 'Validating configuration file.'

    # Ensure file is passed
    if ([string]::IsNullOrWhiteSpace($config)) {
        Write-Error 'Configuration file supplied cannot be empty.'
        return
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
        Write-Error 'No palette section found.'
        return
    }
    
    if ($json.palette.paint -eq $null -or $json.palette.paint.Count -eq 0) {
        Write-Error 'No paint array section found within palette.'
        return
    }
    
    # Ensure all paint sections have a type
    $list = [array]($json.palette.paint | Where-Object { [string]::IsNullOrWhiteSpace($_.type) })

    if ($list.Length -ne 0) {
        Write-Error 'All paint colours need a type parameter.'
        return
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

# Resets the PATH for the current session
function Reset-Path() {
    Write-Message 'Updating PATH'
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
    Write-Message 'PATH updated'
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

    Reset-Path
}

# Checkout a remote repository using svn into the supplied local path
function Checkout-Svn($colour) {
    if (!(Test-Software svn.exe)) {
        Write-Error 'SVN is not installed'
        return
    }

    $url = $colour.remote
    if ([string]::IsNullOrWhiteSpace($url)) {
        Write-Error 'No remote SVN repository passed.'
        return
    }

    $path = $colour.localpath
    if ([string]::IsNullOrWhiteSpace($path)) {
        Write-Error 'No local SVN repository path specified.'
        return
    }

    if (!(Test-Path $path)) {
        New-Item -ItemType Directory -Force -Path $path | Out-Null
    }

    $name = $colour.localname
    if ([string]::IsNullOrWhiteSpace($name)) {
        Write-Error 'No local name supplied for local repository.'
        return
    }

    $revision = $colour.revision
    
    # Delete existing directory
    Push-Location $path
    if ((Test-Path $name)) {
        Remove-Directory $name
    }

    # checkout
    Write-Message "Checking out SVN repository from '$url' to '$path'."
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
        Write-Error 'Git is not installed'
        return
    }

    $url = $colour.remote
    if (!($url -match '(\\|\/)(?<repo>[a-zA-Z]+)\.git')) {
        Write-Error "Remote git repository of '$url' is not valid."
        return
    }

    $directory = $matches['repo']
    
    $path = $colour.localpath
    if ([string]::IsNullOrWhiteSpace($path)) {
        Write-Error 'No local git repository path specified.'
        return
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
        Remove-Directory $directory
    }
    elseif (![string]::IsNullOrWhiteSpace($name) -and (Test-Path $name)) {
        Remove-Directory $name
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

# Uses Chocolatey to install, upgrade or uninstall the speicified software
function Install-Software($colour) {
    $name = $colour.name
    if ([string]::IsNullOrWhiteSpace($name)) {
        Write-Error 'No name supplied for software colour.'
        return
    }

    $operation = ($colour.ensure.Substring(0, $colour.ensure.Length - 2)).ToLower()
    if ([string]::IsNullOrWhiteSpace($operation)) {
        Write-Error 'No ensure operation supplied for software colour.'
        return
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
    
    Reset-Path
    Write-Message "$operation on $name application successful."
}

# Use MSBuild to build a project or solution
function Use-MSBuild($colour) {
    $path = $colour.path
    if (!(Test-Path $path)) {
        Write-Error 'Path to MSBuild.exe does not exist.'
        return
    }

    $project = $colour.project
    if (!(Test-Path $project)) {
        Write-Error 'Path to project for building does not exist.'
        return
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
        Write-Error 'No command passed to run via Command Prompt.'
        return
    }

    Write-Message 'Running command via Command Prompt.'
    cmd.exe /C $command

    if (!$?) {
        throw "Failed to run command: '$command'."
    }

    Write-Message 'Command ran successfully.'
}

# Installs a service onto the system
function Install-Service($colour) {
    $name = $colour.name
    if ([string]::IsNullOrWhiteSpace($name)) {
        Write-Error 'No service name supplied.'
        return
    }

    $service = (Get-WmiObject -Class Win32_Service -Filter "Name='$name'")

    $ensure = $colour.ensure
    if ([string]::IsNullOrWhiteSpace($ensure)) {
        Write-Error 'No ensure parameter supplied for service.'
        return
    }

    $ensure = $ensure.ToLower()
    if ($ensure -ne 'installed' -and $ensure -ne 'uninstalled') {
        Write-Error "Invalid ensure parameter supplied for service: '$ensure'."
        return
    }

    if ($service -eq $null -and $ensure -eq 'uninstalled') {
        Write-Message "Service '$name' already $ensure."
        return
    }

    $state = $colour.state
    if ([string]::IsNullOrWhiteSpace($state)) {
        Write-Error 'No state parameter supplied for service.'
        return
    }

    $state = $state.ToLower()
    if ($state -ne 'started' -and $state -ne 'stopped') {
        Write-Error "Invalid state parameter supplied for service: '$state'."
        return
    }

    $path = $colour.path
    if ([string]::IsNullOrWhiteSpace($path) -and $service -eq $null -and $ensure -eq 'installed') {
        Write-Error 'No path passed to install service.'
        return
    }
    
    if ($service -ne $null -and $ensure -eq 'installed') {
        Write-Message "Ensuring service '$name' is $state."
        if ($state -eq 'started') {
            Start-Service $name
        }
        else {
            Stop-Service $name
        }
        Write-Message "Service $state."
    }
    elseif ($service -ne $null -and $ensure -eq 'uninstalled') {
        Write-Message "Ensuring service '$name' is $ensure."
        $service.delete()
        Write-Message "Service $ensure."
    }
    else {
        Write-Message "Ensuring service '$name' is $ensure."
        New-Service -Name $name -BinaryPathName $path -StartupType Automatic
        Write-Message "Service $ensure."

        Write-Message "Ensuring service '$name' is $state."
        if ($state -eq 'started') {
            Start-Service $name
        }
        else {
            Stop-Service $name
        }
        Write-Message "Service $state."
    }
}

# Writes the help manual to the console
function Write-Help() {
    Write-Host 'Help Manual' -ForegroundColor Green
    Write-Host ''
    Write-Host 'The following is a list of possible colour types:'
    Write-Host "`t- software"
    Write-Host "`t- git"
    Write-Host "`t- svn"
    Write-Host "`t- msbuild"
    Write-Host "`t- cmd"
    Write-Host "`t- service"
}



# Ensure we're running against the correct version of PowerShell
$currentVersion = [decimal]([string](Get-Host | Select-Object Version).Version)
if ($currentVersion -lt 3) {
    Write-Error "Picasso requires PowerShell 3.0 or greater, your version is $currentVersion"
    return
}


# Check switches first
if ($version) {
    Write-Host 'Picasso v0.2.0a' -ForegroundColor Green
    return
}

if ($help) {
    Write-Help
    return
}


# Main Picasso logic
if ([string]::IsNullOrWhiteSpace($config)) {
    Write-Error 'No configuration file supplied.'
    Write-Help
    return
}

if (!(Test-Path $config)) {
    Write-Error 'Passed configuration file does not exist.'
    return
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

        'service'
            {
                Install-Service $colour
            }

        default
            {
                Write-Error "Unrecognised colour type found: $type"
                return
            }
    }

    Write-Host ([string]::Empty)
}