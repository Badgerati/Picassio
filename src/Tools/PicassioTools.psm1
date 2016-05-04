##########################################################################
# Picassio is a provisioning/deployment script which uses a single linear
# JSON file to determine what commands to execute.
#
# Copyright (c) 2015, Matthew Kelly (Badgerati)
# Company: Cadaeic Studios
# License: MIT (see LICENSE for details)
#########################################################################

# Tools for which to utilise in Picassio modules and extensions

# Writes the help manual to the console
function Write-Help() {
    Write-Host 'Help Manual' -ForegroundColor Green
    Write-Host ''

	if (!(Test-PicassioInstalled)) {
		Write-Host 'To install Picassio use: ".\Picassio.ps1 -install"' -ForegroundColor Yellow
		Write-Host ''
	}

    Write-Host 'The following is a list of possible commands:'
    Write-Host " -help`t`t Displays the help page"
	Write-Host " -validate`t Validates the palette"
    Write-Host " -install`t Installs Picassio to C:\Picassio"
    Write-Host " -uninstall`t Uninstalls Picassio"
    Write-Host " -reinstall`t Uninstalls and then re-installs Picassio"
    Write-Host " -version`t Displays the current version of Picassio"
    Write-Host " -palette`t Specifies the picassio palette file to use"
    Write-Host " -paint`t`t Runs the config file's paint section"
    Write-Host " -erase`t`t Runs the config file's erase section, if one is present"
	Write-Host ''
}

# Writes the current version of Picassio to the console
function Write-Version() {
	$version = Get-Version
    Write-Host "Picassio $version" -ForegroundColor Green
}

# Returns the current version of Picassio
function Get-Version() {
	return 'v0.9.5a'
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

# Writes a new line to the console
function Write-NewLine() {
	Write-Host ([string]::Empty)
}

# Writes error text to the console (red)
function Write-Errors($message) {
    Write-Host $message -ForegroundColor Red
}

# Writes the exception to the console (red)
function Write-Exception($exception) {
	Write-Host $exception.GetType().FullName -ForegroundColor Red
	Write-Host $exception.Message -ForegroundColor Red
}

# Write informative text to the console (green)
function Write-Information($message) {
	Write-Host $message -ForegroundColor Green
}

# Write a stamp message to the console (magenta)
function Write-Stamp($message) {
	Write-Host $message -ForegroundColor Magenta
}

# Writes a warning to the console (yellow)
function Write-Warnings($message) {
	Write-Host $message -ForegroundColor Yellow
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

# Writes a sub-header to the console in uppercase (dark yellow)
function Write-SubHeader($message) {
	if ($message -eq $null) {
		$message = [string]::Empty
	}

	$count = 65
	$message = $message.ToUpper()

	if ($message.Length -gt $count) {
		Write-Host "$message>" -ForegroundColor DarkYellow
	}
	else {
		$length = $count - $message.Length
		$padding = ('-' * $length)
		Write-Host "$message$padding>" -ForegroundColor DarkYellow
	}
}

# Resets the PATH for the current session
function Reset-Path($showMessage = $true) {
    $env:Path = (Get-EnvironmentVariable 'Path') + ';' + (Get-EnvironmentVariable 'Path' 'User')

	if ($showMessage) {
		Write-Message 'Path updated.'
	}
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

# Tests whether the current shell is open in a 32-bit host
function Test-Win32() {
	return [IntPtr]::Size -eq 4;
}

# Tests whether the current shell is open in a 64-bit host
function Test-Win64() {
	return [IntPtr]::Size -eq 8;
}

# Runs the passed command and arguments. If passes returns null, otherwise returns last 100 lines of output
function Run-Command($command, $_args, $fullOutput = $false, $isPowershell = $false) {
	if ($isPowershell) {
		$output = (powershell.exe /C "`"$command`" $_args")

		if (!$?) {
			if ($fullOutput) {
				return $output
			}
			else {
				return ($output | Select-Object -Last 100)
			}
		}
	}
	else {
		$output = (cmd.exe /C "`"$command`" $_args")

		if ($LASTEXITCODE -ne 0) {
			if ($fullOutput) {
				return $output
			}
			else {
				return ($output | Select-Object -Last 100)
			}
		}
	}	
	
	return $null
}

# Returns the regex for variables
function Get-VariableRegex() {
	return '(?<var>[a-zA-Z0-9_]+)'
}

# Replaces a passed value with variable substitutes
function Replace-Variables($value, $variables) {
	if ($variables -eq $null -or $variables.Count -eq 0 -or [string]::IsNullOrWhiteSpace($value)) {
		return $value
	}

	$varregex = Get-VariableRegex
	$pattern = "#\($varregex\)"
	$varnames = ($value | Select-String -Pattern $pattern -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups['var'].Value })

	if ($varnames -eq $null -or $varnames.Count -eq 0) {
		return $value
	}

	ForEach ($varname in $varnames) {
		if (!$variables.ContainsKey($varname)) {
			continue
		}

		$val = $variables[$varname]
		$var = "#\($varname\)"
		$value = ($value -replace $var, $val)
	}

	return $value
}