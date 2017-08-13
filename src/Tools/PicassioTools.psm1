##########################################################################
# Picassio is a provisioning/deployment script which uses a single linear
# JSON file to determine what commands to execute.
#
# Copyright (c) 2015, Matthew Kelly (Badgerati)
# Company: Cadaeic Studios
# License: MIT (see LICENSE for details)
#########################################################################

# Tools for which to utilise in Picassio modules and extensions

# Returns the current version of Picassio
function Get-Version()
{
    return '$version$'
}

# Returns the current version of PowerShell
function Get-PowerShellVersion()
{
    try
    {
        return [decimal]([string](Get-Host | Select-Object Version).Version)
    }
    catch
    {
        return [decimal]((Get-Host).Version.Major)
    }
}

# Checks to see if the user has administrator priviledges
function Test-AdminUser()
{
    try
    {
        $principal = New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())

        if ($principal -eq $null)
        {
            return $false
        }

        return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch [exception]
    {
        Write-Host 'Error checking user administrator priviledges'
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }
}

# Writes the help manual to the console
function Write-Help()
{
    Write-Host 'Help Manual' -ForegroundColor Green
    Write-Host ([string]::Empty)

    if (!(Test-PicassioInstalled))
    {
        Write-Host 'To install Picassio use: ".\Picassio.ps1 -install"' -ForegroundColor Yellow
        Write-Host ([string]::Empty)
    }

    Write-Host 'The following is a list of possible commands:'
    Write-Host " -help`t`t Displays the help page"
    Write-Host " -voice`t`t Enables voice over for some textual output"
    Write-Host " -validate`t Validates the palette"
    Write-Host " -install`t Installs/Updates Picassio, extensions are kept intact"
    Write-Host " -uninstall`t Uninstalls Picassio"
    Write-Host " -reinstall`t Uninstalls and then re-installs Picassio"
    Write-Host " -version`t Displays the current version of Picassio"
    Write-Host " -palette`t Specifies the picassio palette file to use (Default: picassio.palette)"
    Write-Host " -paint`t`t Runs the palette file's paint section"
    Write-Host " -erase`t`t Runs the palette file's erase section, if one is present"
    Write-Host " -username`t [Optional] Your username to use for initial credentials"
    Write-Host " -password`t [Optional] Your password, this can be left blank"
    Write-Host " -force`t`t Forces Picassio to run, regardless of the user having administrator priviledges"
    Write-Host ([string]::Empty)
}

# Writes the current version of Picassio to the console
function Write-Version()
{
    $version = Get-Version
    $psVersion = Get-PowerShellVersion
    Write-Host "Picassio v$version (PS $psVersion)" -ForegroundColor Green
}

# Wipes a given directory
function Remove-Directory($directory)
{
    Write-Message "Removing directory: '$directory'."

    Remove-Item -Recurse -Force $directory | Out-Null
    if (!$?)
    {
        throw 'Failed to remove directory.'
    }

    Write-Message 'Directory removed successfully.'
}

# Backs up a directory, appending the current date/time
function Backup-Directory($directory)
{
    Write-Message "Backing-up directory: '$directory'"
    $newDir = $directory + '_' + ([DateTime]::Now.ToString('yyyy-MM-dd_HH-mm-ss'))

    Rename-Item $directory $newDir -Force | Out-Null
    if (!$?)
    {
        throw 'Failed to backup directory.'
    }

    Write-Message "Directory '$directory' renamed to '$newDir'"
}

# Returns whether Picassio has been installed or not
function Test-PicassioInstalled()
{
    return !([String]::IsNullOrWhiteSpace($env:PicassioTools) -or [String]::IsNullOrWhiteSpace($env:PicassioModules) -or [String]::IsNullOrWhiteSpace($env:PicassioExtensions))
}

# Writes a general message to the console (cyan)
function Write-Message([string]$message, $speech = $null)
{
    Write-Host $message -ForegroundColor Cyan
    Speak-Text $message $speech
}

# Writes a new line to the console
function Write-NewLine()
{
    Write-Host ([string]::Empty)
}

# Writes error text to the console (red)
function Write-Errors([string]$message, $speech = $null, [switch]$tag)
{
    if ($tag)
    {
        $message = "[ERROR] $message"
    }

    Write-Host $message -ForegroundColor Red
    Speak-Text $message $speech
}

# Writes the exception to the console (red)
function Write-Exception($exception)
{
    Write-Host $exception.GetType().FullName -ForegroundColor Red
    Write-Host $exception.Message -ForegroundColor Red
}

# Write informative text to the console (green)
function Write-Information([string]$message, $speech = $null)
{
    Write-Host $message -ForegroundColor Green
    Speak-Text $message $speech
}

# Write a stamp message to the console (magenta)
function Write-Stamp([string]$message, $speech = $null)
{
    Write-Host $message -ForegroundColor Magenta
    Speak-Text $message $speech
}

# Writes a warning to the console (yellow)
function Write-Warnings([string]$message, $speech = $null, [switch]$tag)
{
    if ($tag)
    {
        $message = "[WARNING] $message"
    }

    Write-Host $message -ForegroundColor Yellow
    Speak-Text $message $speech
}

# Writes a header to the console in uppercase (magenta)
function Write-Header([string]$message)
{
    if ($message -eq $null)
    {
        $message = [string]::Empty
    }

    $count = 65
    $message = $message.ToUpper()

    if ($message.Length -gt $count)
    {
        Write-Host "$message>" -ForegroundColor Magenta
    }
    else
    {
        $length = $count - $message.Length
        $padding = ('=' * $length)
        Write-Host "=$message$padding>" -ForegroundColor Magenta
    }
}

# Writes a sub-header to the console in uppercase (dark yellow)
function Write-SubHeader([string]$message)
{
    if ($message -eq $null)
    {
        $message = [string]::Empty
    }

    $count = 65
    $message = $message.ToUpper()

    if ($message.Length -gt $count)
    {
        Write-Host "$message>" -ForegroundColor DarkYellow
    }
    else
    {
        $length = $count - $message.Length
        $padding = ('-' * $length)
        Write-Host "-$message$padding>" -ForegroundColor DarkYellow
    }
}

# Speaks the passed text using the passed speech object
function Speak-Text([string]$text, $speech)
{
    if ($speech -eq $null -or [string]::IsNullOrWhiteSpace($text))
    {
        return
    }

    try
    {
        $speech.SpeakAsync($text) | Out-Null
    }
    catch { }
}

# Read input for the user, to check if they are sure about something (asks y/n)
function Read-AreYouSure()
{
    $valid = @('y', 'n')
    $value = Read-Host -Prompt "Are you sure you wish to continue? y/n"

    if ([string]::IsNullOrWhiteSpace($value) -or $valid -inotcontains $value)
    {
        return Read-AreYouSure
    }

    return $value -ieq 'y'
}


# Resets the PATH for the current session
function Reset-Path($showMessage = $true)
{
    $env:Path = (Get-EnvironmentVariable 'Path') + ';' + (Get-EnvironmentVariable 'Path' 'User')

    if ($showMessage)
    {
        Write-Message 'Path updated.'
    }
}

# Check to see if a piece of software is installed
function Test-Software($command, $name = $null)
{
    try
    {
        # attempt to see if it's install via chocolatey
        if (![String]::IsNullOrWhiteSpace($name))
        {
            try
            {
                $result = (choco.exe list -lo | Where-Object { $_ -ilike "*$name*" } | Measure-Object).Count
            }
            catch [exception]
            {
                $result = 0
            }

            if ($result -ne 0)
            {
                return $true
            }
        }

        # attempt to call the program, see if we get a response back
        $output = powershell.exe /C "$command" | Out-Null
        if ($LASTEXITCODE -ne 0)
        {
            return $false
        }

        return $true
    }
    catch [exception] { }

    return $false
}

# Tests to see if a URL is valid
function Test-Url($url)
{
    if ([string]::IsNullOrWhiteSpace($url))
    {
        return $false
    }

    try
    {
        $request = [System.Net.WebRequest]::Create($url)
        $response = $request.GetResponse()
        return $response.StatusCode -eq 200
    }
    catch [exception]
    {
        return $false
    }
    finally
    {
        if ($response -ne $null)
        {
            $response.Close()
        }
    }
}

# Installs software via Chocolatey on an adhoc basis
function Install-AdhocSoftware($packageName, $name, $installer = 'choco')
{
    Write-Message "Installing $name."

    if ([string]::IsNullOrWhiteSpace($packageName))
    {
        throw 'Package name for installing adhoc software cannot be empty.'
    }

    switch ($installer)
    {
        'choco'
            {
                if (!(Test-Software 'choco -v'))
                {
                    Write-Warnings 'Chocolatey is not installed'
                    Install-Chocolatey
                }

                Run-Command 'choco.exe' "install $packageName -y"
            }

        'npm'
            {
                if (!(Test-Software 'node.exe -v' 'nodejs'))
                {
                    Write-Warnings 'node.js is not installed'
                    Install-AdhocSoftware 'nodejs.install' 'node.js'
                }

                Run-Command 'npm' "install -g $packageName" $false $true
            }

        default
            {
                throw "Invalid installer type found for adhoc software: '$installer'."
            }
    }

    # Was the install successful
    if (!$?)
    {
        throw "Failed to install $name."
    }

    Reset-Path $false
    Write-Message "Installation of $name successful."
}

# Install Chocolatey - if already installed, will just update
function Install-Chocolatey()
{
    if (Test-Software 'choco -v')
    {
        Write-Message 'Chocolatey is already installed.'
        return
    }

    Write-Message 'Installing Chocolately.'

    $policies = @('Unrestricted', 'ByPass')
    if ($policies -inotcontains (Get-ExecutionPolicy))
    {
        Set-ExecutionPolicy Bypass -Force
    }

    Run-Command "Invoke-Expression ((New-Object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))" $null $true $true
    Write-Message 'Chocolately installed.'

    Reset-Path
}

# Check to see if we have a paint colour of the passed type
function Test-ColourType($json, $type)
{
    $list = [array]($json.palette.paint | Where-Object { $_.type.ToLower() -eq $type.ToLower() })
    return ($list.Length -ne 0)
}

# Return an environment variable
function Get-EnvironmentVariable($name, $level = 'Machine')
{
    $value = [Environment]::GetEnvironmentVariable($name, $level)

    if (!$?)
    {
        throw "Failed to get environment variable '$name' from '$level' level."
    }

    return $value
}

# Sets an environment variable
function Set-EnvironmentVariable($name, $value, $level = 'Machine')
{
    [Environment]::SetEnvironmentVariable($name, $value, $level)

    if (!$?)
    {
        throw "Failed to set environment variable '$name' at '$level' level."
    }
}

# Tests whether the current shell is open in a 32-bit host
function Test-Win32()
{
    return [IntPtr]::Size -eq 4;
}

# Tests whether the current shell is open in a 64-bit host
function Test-Win64()
{
    return [IntPtr]::Size -eq 8;
}

# Runs the passed command and arguments. If fails displays the last 200 lines of output
function Run-Command([string]$command, [string]$_args, [bool]$fullOutput = $false, [bool]$isPowershell = $false, [bool]$ignoreFailure = $false)
{
    Write-Information "Running command: '$command $_args'"

    if ($ignoreFailure)
    {
        Write-Warnings 'Failures are being suppressed' -tag
    }

    if ($isPowershell)
    {
        $output = powershell.exe /C "`"$command`" $_args"

        if (!$? -and !$ignoreFailure)
        {
            if ($output -ne $null)
            {
                if (!$fullOutput)
                {
                    $output = ($output | Select-Object -Last 200)
                }

                $output | ForEach-Object { Write-Errors $_ }
            }

            throw "Command '$command' failed to complete."
        }
    }
    else
    {
        $output = cmd.exe /C "`"$command`" $_args"
        $code = $LASTEXITCODE

        if ($code -ne 0 -and !$ignoreFailure)
        {
            if ($output -ne $null)
            {
                if (!$fullOutput)
                {
                    $output = ($output | Select-Object -Last 200)
                }

                $output | ForEach-Object { Write-Errors $_ }
            }

            throw "Command '$command' failed to complete. Exit code: $code"
        }
    }
}

# Returns the regex for variables
function Get-VariableRegex()
{
    return '(?<var>[a-zA-Z0-9_]+)'
}

# Replaces a passed value with variable substitutes
function Replace-Variables($value, $variables)
{
    if ($variables -eq $null -or $variables.Count -eq 0 -or [string]::IsNullOrWhiteSpace($value))
    {
        return $value
    }

    $varregex = Get-VariableRegex
    $pattern = "#\($varregex\)"
    $varnames = ($value | Select-String -Pattern $pattern -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups['var'].Value })

    if ($varnames -eq $null -or $varnames.Count -eq 0)
    {
        return $value
    }

    ForEach ($varname in $varnames)
    {
        if (!$variables.ContainsKey($varname))
        {
            continue
        }

        $val = $variables[$varname]
        $var = "#\($varname\)"
        $value = ($value -replace $var, $val)
    }

    return $value
}
