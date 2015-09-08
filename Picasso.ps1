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

# Backs up a directory, appending the current date/time
function Backup-Directory($directory) {
    Write-Message "Backing up directory: '$directory'"
    $newDir = $directory + '_' + ([DateTime]::Now.ToString('yyyy-MM-dd_HH-mm-ss'))
    Rename-Item $directory $newDir -Force
    Write-Message "Directory '$directory' renamed to '$newDir'"
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
function Test-Software($command, $name = $null) {
    try {
        # attempt to see if it's install via chocolatey
        if (![String]::IsNullOrWhiteSpace($name)) {
            try {
                $result = (choco.exe list -lo | Where-Object { $_ -ilike "*$name*" } | Select-Object -First 1)
            }
            catch [exception] { }

            if (![string]::IsNullOrWhiteSpace($result)) {
                return $true
            }
        }

        # attempt to call the program, see if we get a response back
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
function Colour-CheckoutSvn($colour) {
    if (!(Test-Software svn.exe 'svn')) {
        Write-Error 'SVN is not installed'
        Install-AdhocSoftware 'svn' 'SVN'
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
    
    # Delete existing directory
    Push-Location $path
    if ((Test-Path $name)) {
        Backup-Directory $name
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
function Colour-CloneGit($colour) {
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

# Installs software via Chocolatey on an adhoc basis
function Install-AdhocSoftware($packageName, $name) {
    if (!(Test-Software choco.exe)) {
        Install-Chocolatey
    }

    Write-Message "Installing $name"
    choco.exe install $packageName -y

    if (!$?) {
        throw "Failed to install $name."
    }
    
    Write-Message "Installation of $name successful."
}

# Uses Chocolatey to install, upgrade or uninstall the speicified softwares
function Colour-InstallSoftware($colour) {
    # Get list of software names
    $names = $colour.names
    if ($names -eq $null -or $names.Length -eq 0) {
        throw 'No names supplied for software colour.'
    }
    
    # Get ensured operation for installing/uninstalling
    $operation = $colour.ensure
    if ([string]::IsNullOrWhiteSpace($operation)) {
        throw 'No ensure operation supplied for software colour.'
    }

    $operation = $operation.ToLower()

    if ($operation.EndsWith('ed')) {
        $operation = $operation.Substring(0, $colour.ensure.Length - 2)
    }

    # Gte list of versions (or single version for all names)
    $versions = $colour.versions
    if ($versions -ne $null -and $versions.Length -gt 1 -and $versions.Length -ne $names.Length) {
        throw 'Incorrect number of versions specified. Expected an equal amount to the amount of names speicified.'
    }
    
    for ($i = 0; $i -lt $names.Length; $i++) {
        $name = $names[$i]
        $this_operation = $operation

        # Work out what version we're trying to install
        if ($versions -eq $null -or $versions.Length -eq 0) {
            $version = 'latest'
        }
        elseif ($versions.Length -eq 1) {
            $version = $versions[0]
        }
        else {
            $version = $versions[$i]
        }

        if ($this_operation -eq 'install') {
            $result = (choco.exe list -lo | Where-Object { $_ -ilike "*$name*" } | Select-Object -First 1)

            if (![string]::IsNullOrWhiteSpace($result)) {
                $this_operation = 'upgrade'
            }
        }

        if ([string]::IsNullOrWhiteSpace($version) -or $version.ToLower() -eq 'latest' -or $this_operation -eq 'uninstall') {
            $versionTag = [string]::Empty
            $version = [string]::Empty
            $versionStr = 'latest'
        }
        else {
            $versionTag = '--version'
            $versionStr = $version
        }

        Write-Message "$this_operation on $name application starting. Version: $versionStr"
        choco.exe $this_operation $name $versionTag $version -y

        if (!$?) {
            throw "Failed to $this_operation the $name software."
        }
    
        Write-Message "$this_operation on $name application successful."

        Reset-Path

        if ($i -ne ($names.Length - 1)) {
            Write-Host ([string]::Empty)
        }
    }
}

# Use MSBuild to build a project or solution
function Colour-UseMSBuild($colour) {
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

# Run a passed command using Command Prompt/PowerShell
function Colour-RunCommand($colour) {
    $command = $colour.command
    if ([string]::IsNullOrWhiteSpace($command)) {
        Write-Error 'No command passed to run via Command Prompt.'
        return
    }

    $prompt = $colour.prompt
    if ([string]::IsNullOrWhiteSpace($prompt)) {
        Write-Message 'No prompt type passed, defaulting to Command Prompt.'
        $prompt = 'cmd'
    }

    # determine which prompt in which to run the command
    switch ($prompt.ToLower()) {
        'cmd'
            {
                Write-Message 'Running command via Command Prompt.'
                cmd.exe /C $command
            }

        'powershell'
            {
                Write-Message 'Running command via PowerShell.'
                powershell.exe /C $command
            }

        default
            {
                throw "unrecognised prompt for command colour: '$prompt'."
            }
    }
    
    if (!$?) {
        throw "Failed to run command: '$command'."
    }

    Write-Message 'Command ran successfully.'
}

# Installs a service onto the system
function Colour-InstallService($colour) {
    $name = $colour.name
    if ([string]::IsNullOrWhiteSpace($name)) {
        throw 'No service name supplied.'
    }

    # attempt to retrieve the service
    $service = (Get-WmiObject -Class Win32_Service -Filter "Name='$name'")

    $ensure = $colour.ensure
    if ([string]::IsNullOrWhiteSpace($ensure)) {
        throw 'No ensure parameter supplied for service.'
    }

    # check we have a valid ensure property
    $ensure = $ensure.ToLower()
    if ($ensure -ne 'installed' -and $ensure -ne 'uninstalled') {
        throw "Invalid ensure parameter supplied for service: '$ensure'."
    }

    # check if service is alredy uninstalled
    if ($service -eq $null -and $ensure -eq 'uninstalled') {
        Write-Message "Service '$name' already $ensure."
        return
    }

    $state = $colour.state
    if ([string]::IsNullOrWhiteSpace($state)) {
        throw 'No state parameter supplied for service.'
    }

    # check we have a valid state property
    $state = $state.ToLower()
    if ($state -ne 'started' -and $state -ne 'stopped' -and $ensure -eq 'installed') {
        throw "Invalid state parameter supplied for service: '$state'."
    }

    $path = $colour.path
    if ([string]::IsNullOrWhiteSpace($path) -and $service -eq $null -and $ensure -eq 'installed') {
        throw 'No path passed to install service.'
    }
    
    if ($service -ne $null -and $ensure -eq 'installed') {
        Write-Message "Ensuring service '$name' is $state."

        if ($state -eq 'started') {
            Restart-Service $name
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

# Copy files/folders from one location to another
function Colour-CopyFiles($colour) {
    $from = $colour.from
    if ([string]::IsNullOrWhiteSpace($from)) {
        throw 'No from path specified.'
    }
    
    if (!(Test-Path $from)) {
        throw "From path specified doesn't exist: '$from'."
    }

    $to = $colour.to
    if ([string]::IsNullOrWhiteSpace($to)) {
        throw 'No to path specified.'
    }

    $excludeFiles = $colour.excludeFiles
    $excludeFolders = $colour.excludeFolders

    if ($excludeFolders -ne $null -and $excludeFolders.Length -gt 0) {
        [Regex]$excludeFoldersRegex = (($excludeFolders | ForEach-Object {[Regex]::Escape($_)}) –Join '|')
    }

    $includeFiles = $colour.includeFiles
    $includeFolders = $colour.includeFolders
    
    if ($includeFolders -ne $null -and $includeFolders.Length -gt 0) {
        [Regex]$includeFoldersRegex = (($includeFolders | ForEach-Object {[Regex]::Escape($_)}) –Join '|')
    }

    Write-Message "Copying files/folders from '$from' to '$to'."

    Get-ChildItem -Path $from -Recurse -Force -Exclude $excludeFiles -Include $includeFiles |
        Where-Object { $excludeFoldersRegex -eq $null -or $_.FullName.Replace($from, [String]::Empty) -notmatch $excludeFoldersRegex } |
        Where-Object { $includeFoldersRegex -eq $null -or $_.FullName.Replace($from, [String]::Empty) -match $includeFoldersRegex } |
        Copy-Item -Destination {
            if ($_.PSIsContainer) {
                $path = Join-Path $to $_.Parent.FullName.Substring($from.Length)
                $temp = $path
            }
            else {
                $path = Join-Path $to $_.FullName.Substring($from.Length)
                $temp = Split-Path -Parent $path
            }
            
            if (!(Test-Path $temp)) {
                New-Item -ItemType Directory -Force -Path $temp | Out-Null
            }
            
            $path
        } -Force -Exclude $excludeFiles -Include $includeFiles
    
    if (!$?) {
        throw 'Failed to copy files/folders.'
    }

    Write-Message 'Files/folders copied successfully.'
}

# Calls vagrant from a specified path where a Vagrantfile can be found
function Colour-Vagrant($colour) {
    if (!(Test-Software vagrant.exe 'vagrant')) {
        Write-Error 'Vagrant is not installed'
        Install-AdhocSoftware 'vagrant' 'Vagrant'
    }

    $path = $colour.path
    if ([string]::IsNullOrWhiteSpace($path)) {
        throw 'No path specified to parent directory where the Vagrantfile is located.'
    }
    
    if (!(Test-Path $path)) {
        throw "Path specified doesn't exist: '$path'."
    }

    $command = $colour.command
    if ([string]::IsNullOrWhiteSpace($command)) {
        throw 'No command specified for which to call vagrant.'
    }

    Push-Location $path
    vagrant.exe $command
    
    if (!$?) {
        Pop-Location
        throw 'Failed to call vagrant.'
    }

    Pop-Location
    Write-Message "vagrant $command, successful."
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
    Write-Host "`t- command"
    Write-Host "`t- service"
    Write-Host "`t- copy"
}

# Writes the current version of Picasso to the console
function Write-Version() {
    Write-Host 'Picasso v0.2.3a' -ForegroundColor Green
}



##################################
#          Main Script           #
##################################

# Ensure we're running against the correct version of PowerShell
$currentVersion = [decimal]([string](Get-Host | Select-Object Version).Version)
if ($currentVersion -lt 3) {
    Write-Error "Picasso requires PowerShell 3.0 or greater, your version is $currentVersion"
    return
}


# Check switches first
if ($version) {
    Write-Version
    return
}
else {
    Write-Version
}

if ($help) {
    Write-Help
    return
}


# Main Picasso logic
if ([string]::IsNullOrWhiteSpace($config)) {
    Write-Message 'No config file supplied, using default.'
    $config = './picasso.json'

    if (!(Test-Path $config)) {
        Write-Error 'Default picasso.json file cannot be found in current directory.'
        return
    }
}

if (!(Test-Path $config)) {
    Write-Error "Passed configuration file does not exist: '$config'"
    return
}

$json = Validate-File (Get-Content $config -Raw)

if ((Test-ColourType $json 'software')) {
    Install-Chocolatey
}

$total_stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

ForEach ($colour in $json.palette.paint) {
    Write-Host ([string]::Empty)
    $type = $colour.type.ToLower()
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    $description = $colour.description
    if (![String]::IsNullOrWhiteSpace($description)) {
        Write-Host $description -ForegroundColor Green
    }

    switch ($type) {
        'software'
            {
                Colour-InstallSoftware $colour
            }

        'svn'
            {
                Colour-CheckoutSvn $colour
            }

        'git'
            {
                Colour-CloneGit $colour
            }

        'msbuild'
            {
                Colour-UseMSBuild $colour
            }

        'command'
            {
                Colour-RunCommand $colour
            }

        'service'
            {
                Colour-InstallService $colour
            }

        'copy'
            {
                Colour-CopyFiles $colour
            }

        'vagrant'
            {
                Colour-Vagrant $colour
            }

        default
            {
                Write-Error "Unrecognised colour type found: $type"
                return
            }
    }
    
    Reset-Path

    Write-Host ('Time taken: {0}' -f $stopwatch.Elapsed) -ForegroundColor Magenta
    Write-Host ([string]::Empty)
}

Write-Host ('Total time taken: {0}' -f $total_stopwatch.Elapsed) -ForegroundColor Magenta