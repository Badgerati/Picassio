# Tools for which to utilise in Picassio modules and extensions

# Writes the help manual to the console
function Write-Help() {
    Write-Host 'Help Manual' -ForegroundColor Green
    Write-Host ''

	if (!(Test-PicassioInstalled)) {
		Write-Host 'To install Picassio use: ".\Picassio.ps1 -install"' -ForegroundColor Yellow
		Write-Host ''
	}

    Write-Host 'The following is a list of possible colour types:'
    Write-Host "`t- software"
    Write-Host "`t- git"
    Write-Host "`t- svn"
    Write-Host "`t- msbuild"
    Write-Host "`t- command"
    Write-Host "`t- service"
    Write-Host "`t- copy"
    Write-Host "`t- vagrant"
    Write-Host "`t- hosts"
    Write-Host "`t- echo"
	Write-Host ''
}

# Writes the current version of Picassio to the console
function Write-Version() {
    Write-Host 'Picassio v0.8.0a' -ForegroundColor Green
}

# Wipes a given directory
function Remove-Directory($directory) {
    Write-Message "Removing directory: '$directory'."
    Remove-Item -Recurse -Force $directory | Out-Null
    Write-Message 'Directory removed successfully.'
}

# Backs up a directory, appending the current date/time
function Backup-Directory($directory) {
    Write-Message "Backing-up directory: '$directory'"
    $newDir = $directory + '_' + ([DateTime]::Now.ToString('yyyy-MM-dd_HH-mm-ss'))
    Rename-Item $directory $newDir -Force
    Write-Message "Directory '$directory' renamed to '$newDir'"
}

# Returns whether Picassio has been installed or not
function Test-PicassioInstalled() {
	return !([String]::IsNullOrWhiteSpace($env:PicassioTools) -or [String]::IsNullOrWhiteSpace($env:PicassioModules) -or [String]::IsNullOrWhiteSpace($env:PicassioModules))
}

# Writes a general message to the console (cyan)
function Write-Message($message) {
    Write-Host $message -ForegroundColor Cyan
}

# Overrides Write-Error, with one which just outputs text to the console (red)
function Write-Error($message) {
    Write-Host $message -ForegroundColor Red
}

# Write informative text to the console (green)
function Write-Information($message) {
	Write-Host $message -ForegroundColor Green
}

# Write a stamp message to the console (magenta)
function Write-Stamp($message) {
	Write-Host $message -ForegroundColor Magenta
}

# Writes a header to the console in uppercase (magenta)
function Write-Header($message) {
	if ($message -eq $null) {
		$message = [string]::Empty
	}

	$count = 65
	$message = $message.ToUpper()

	if ($message.Length -gt $count) {
		Write-Host "$message>" -ForegroundColor Magenta
	}
	else {
		$length = $count - $message.Length
		$padding = ('=' * $length)
		Write-Host "$message$padding>" -ForegroundColor Magenta
	}
}

# Resets the PATH for the current session
function Reset-Path() {
    $env:Path = (Get-EnvironmentVariable 'Path') + ';' + (Get-EnvironmentVariable 'Path' 'User')
    Write-Message 'Path updated.'
}

# Check to see if a piece of software is installed
function Test-Software($command, $name = $null) {
    try {
        # attempt to see if it's install via chocolatey
        if (![String]::IsNullOrWhiteSpace($name)) {
            try {
                $result = (choco.exe list -lo | Where-Object { $_ -ilike "*$name*" } | Select-Object -First 1)
            }
            catch [exception] {
				$result = $null
			}

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

# Installs software via Chocolatey on an adhoc basis
function Install-AdhocSoftware($packageName, $name) {
    if (!(Test-Software choco.exe)) {
        Install-Chocolatey
    }

    Write-Message "Installing $name."
    choco.exe install $packageName -y

    if (!$?) {
        throw "Failed to install $name."
    }
    
    Write-Message "Installation of $name successful."
}

# Install Chocolatey - if already installed, will just update
function Install-Chocolatey() {
    if (Test-Software choco.exe) {
        Write-Message 'Chocolatey is already installed.'
        return
    }
    
    Write-Message 'Installing Chocolately.'
    Set-ExecutionPolicy Unrestricted
    Invoke-Expression ((New-Object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
    Write-Message 'Chocolately installed.'

    Reset-Path
}

# Check to see if we have a paint colour of the passed type
function Test-ColourType($json, $type) {
    $list = [array]($json.palette.paint | Where-Object { $_.type.ToLower() -eq $type.ToLower() })
    return ($list.Length -ne 0)
}

# Return an environment variable
function Get-EnvironmentVariable($name, $level = 'Machine') {
	$value = [Environment]::GetEnvironmentVariable($name, $level)

	if (!$?) {
		throw
	}

	return $value
}

# Sets an environment variable
function Set-EnvironmentVariable($name, $value, $level = 'Machine') {
	[Environment]::SetEnvironmentVariable($name, $value, $level)

	if (!$?) {
		throw
	}
}