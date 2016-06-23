##########################################################################
# Picassio is a provisioning/deployment script which uses a single linear
# JSON file to determine what commands to execute.
#
# Copyright (c) 2015, Matthew Kelly (Badgerati)
# Company: Cadaeic Studios
# License: MIT (see LICENSE for details)
#########################################################################
param (
    [string]$palette,
    [string]$username,
    [string]$password,
    [switch]$help = $false,
    [switch]$version = $false,
    [switch]$install = $false,
    [switch]$uninstall = $false,
    [switch]$reinstall = $false,
    [switch]$paint = $false,
    [switch]$erase = $false,
    [switch]$validate = $false,
    [switch]$voice = $false,
    [switch]$force = $false
)

$modulePath = '.\Tools\PicassioTools.psm1'
if (!(Test-Path $modulePath))
{
    $modulePath = $env:PicassioTools

    if ([String]::IsNullOrWhiteSpace($modulePath) -or !(Test-Path $modulePath))
    {
        throw 'Cannot find Picassio tools module.'
    }
}

Import-Module $modulePath -DisableNameChecking -ErrorAction Stop


# Ensures that the palette file passed is valid
function Test-File($palette)
{
    Write-Message 'Validating palette file.'

    # Ensure file is passed
    if ([string]::IsNullOrWhiteSpace($palette))
    {
        throw 'Palette file supplied cannot be empty.'
    }

    # Ensure file is of valid json format
    try
    {
        $json = $palette | ConvertFrom-Json
    }
    catch [exception]
    {
        throw $_.Exception
    }

    # Ensure that there's a paint section
    $paint = $json.paint
    if ($paint -eq $null -or $paint.Count -eq 0)
    {
        throw 'No paint array section found within palette.'
    }

    # Ensure all paint sections have a type
    $list = [array]($paint | Where-Object { [string]::IsNullOrWhiteSpace($_.type) })
    if ($list.Length -ne 0)
    {
        throw 'All paint colours need a type parameter.'
    }

    # Ensure all modules for paint exist
    $variables = @{}
    Test-Section $paint 'paint'

    # Ensure that if there's an erase section, it too is valid
    $erase = $json.erase
    if ($erase -ne $null -and $erase.Count -gt 0)
    {
        $list = [array]($erase | Where-Object { [string]::IsNullOrWhiteSpace($_.type) })
        if ($list.Length -ne 0)
        {
            throw 'All erase colours need a type parameter.'
        }

        # Ensure all modules for erase exist
        $variables = @{}
        Test-Section $erase 'erase'
    }

    Write-Message 'Palette file is valid.'

    # Return config as json
    return $json
}

function Test-Section($section, $name)
{
    ForEach ($colour in $section)
    {
        $type = $colour.type.ToLower()

        try
        {
            switch ($type)
            {
                'credentials'
                    {
                        # No need to test anything
                    }

                'extension'
                    {
                        $extensionName = $colour.extension
                        if ([String]::IsNullOrWhiteSpace($extensionName))
                        {
                            throw "$name colour extension type does not have an extension key."
                        }

                        $extension = "$env:PicassioExtensions\$extensionName.psm1"

                        if (!(Test-Path $extension))
                        {
                            throw "Unrecognised extension found: '$extensionName' in $name section."
                        }

                        Import-Module $extension -DisableNameChecking -ErrorAction Stop

                        if (!(Get-Command 'Start-Extension' -CommandType Function -ErrorAction SilentlyContinue))
                        {
                            throw "Extension module for '$extensionName' does not have a Start-Extension function."
                        }

                        if (!(Get-Command 'Test-Extension' -CommandType Function -ErrorAction SilentlyContinue))
                        {
                            throw "Extension module for '$extensionName' does not have a Test-Extension function."
                        }

                        Test-Extension $colour $variables $credentials
                        Remove-Module $extensionName -ErrorAction Stop
                    }

                default
                    {
                        $module = "$env:PicassioModules\$type.psm1"

                        if (!(Test-Path $module))
                        {
                            throw "Unrecognised colour type found: '$type' in $name section."
                        }

                        Import-Module $module -DisableNameChecking -ErrorAction Stop

                        if (!(Get-Command 'Start-Module' -CommandType Function -ErrorAction SilentlyContinue))
                        {
                            throw "Module for '$type' does not have a Start-Module function."
                        }

                        if (!(Get-Command 'Test-Module' -CommandType Function -ErrorAction SilentlyContinue))
                        {
                            throw "Module for '$type' does not have a Test-Module function."
                        }

                        Test-Module $colour $variables $credentials
                        Remove-Module $type -ErrorAction Stop
                    }
            }
        }
        catch [exception]
        {
            if ($type -eq 'extension')
            {
                Write-Information "Validation of $extensionName extension failed in $name section."
            }
            else
            {
                Write-Information "Validation of $type failed in $name section."
            }

            throw
        }
    }

    Import-Module $modulePath -DisableNameChecking
}

# Installs Picassio
function Install-Picassio()
{
    if (!(Test-Path .\Picassio.ps1))
    {
        Write-Errors 'Installation should only be called from where the Picassio scripts actually reside.'
        return
    }

    Write-Information 'Installing Picassio.'

    $main = 'C:\Picassio'
    $tools = "$main\Tools"
    $modules = "$main\Modules"
    $extensions = "$main\Extensions"

    if (!(Test-Path $main))
    {
        Write-Message "Creating '$main' directory."
        New-Item -ItemType Directory -Force -Path $main | Out-Null
    }

    if (!(Test-Path $tools))
    {
        Write-Message "Creating '$tools' directory."
        New-Item -ItemType Directory -Force -Path $tools | Out-Null
    }

    if (!(Test-Path $modules))
    {
        Write-Message "Creating '$modules' directory."
        New-Item -ItemType Directory -Force -Path $modules | Out-Null
    }

    if (!(Test-Path $extensions))
    {
        Write-Message "Creating '$extensions' directory."
        New-Item -ItemType Directory -Force -Path $extensions | Out-Null
    }

    Write-Message 'Copying Picassio scripts.'
    Copy-Item -Path .\Picassio.ps1 -Destination $main -Force | Out-Null
    Copy-Item -Path .\Tools\PicassioTools.psm1 -Destination $tools -Force | Out-Null

    Write-Message 'Copying core modules.'
    Copy-Item -Path .\Modules\* -Destination $modules -Force -Recurse | Out-Null

    if ((Test-Path '.\Extensions'))
    {
        Write-Message 'Copying saved extensions.'
        Copy-Item -Path .\Extensions\* -Destination $extensions -Force -Recurse | Out-Null
    }

    Write-Message 'Updating environment Path.'
    if (!($env:Path.Contains($main)))
    {
        $current = Get-EnvironmentVariable 'Path'

        if ($current.EndsWith(';'))
        {
            $current += "$main"
        }
        else
        {
            $current += ";$main"
        }

        Set-EnvironmentVariable 'Path' $current
        Reset-Path
    }

    Write-Message 'Creating environment variables.'
    if ($env:PicassioModules -ne $modules)
    {
        $env:PicassioModules = $modules
        Set-EnvironmentVariable 'PicassioModules' $env:PicassioModules
    }

    if ($env:PicassioExtensions -ne $extensions)
    {
        $env:PicassioExtensions = $extensions
        Set-EnvironmentVariable 'PicassioExtensions' $env:PicassioExtensions
    }

    $toolsFile = "$tools\PicassioTools.psm1"

    if ($env:PicassioTools -ne $toolsFile)
    {
        $env:PicassioTools = $toolsFile
        Set-EnvironmentVariable 'PicassioTools' $env:PicassioTools
    }

    Write-Information 'Picassio has been installed successfully.'
    Write-Message 'Your prompt may need to be restarted.'
}

# Uninstalls Picassio
function Uninstall-Picassio()
{
    if (!(Test-PicassioInstalled))
    {
        Write-Errors 'Picassio has not been installed. Please install Picassio with ".\Picassio.ps1 -install".'
        return
    }

    Write-Information 'Uninstalling Picassio.'

    $main = 'C:\Picassio'

    if ((Test-Path $main))
    {
        Write-Message "Deleting '$main' directory."
        Remove-Item -Path $main -Force -Recurse | Out-Null
    }

    Write-Message 'Removing Picassio from environment Path.'
    if (($env:Path.Contains($main)))
    {
        $current = Get-EnvironmentVariable 'Path'
        $current = $current.Replace($main, [string]::Empty)
        Set-EnvironmentVariable 'Path' $current
        $env:Path = $current
    }

    Write-Message 'Removing environment variables.'
    if (![String]::IsNullOrWhiteSpace($env:PicassioModules))
    {
        Remove-Item env:\PicassioModules
        Set-EnvironmentVariable 'PicassioModules' $null
    }

    if (![String]::IsNullOrWhiteSpace($env:PicassioExtensions))
    {
        Remove-Item env:\PicassioExtensions
        Set-EnvironmentVariable 'PicassioExtensions' $null
    }

    if (![String]::IsNullOrWhiteSpace($env:PicassioTools))
    {
        Remove-Item env:\PicassioTools
        Set-EnvironmentVariable 'PicassioTools' $null
    }

    Write-Information 'Picassio has been uninstalled successfully.'
}

# Re-installs Picassio by uninstalling then re-installing
function Reinstall-Picassio()
{
    if (!(Test-Path .\Picassio.ps1))
    {
        Write-Errors 'Re-installation should only be called from where the Picassio scripts actually reside.'
        return
    }

    Write-Information 'Re-installing Picassio.'

    if (Test-PicassioInstalled)
    {
        Uninstall-Picassio
    }
    else
    {
        Write-Message 'Picassio has not been installed. Skipping uninstall step.'
    }

    Install-Picassio

    Write-Information 'Picassio has been re-installed successfully.'
}

# Runs the palette, determining the section to be executed
function Run-Palette($paint, $erase)
{
    if ($paint) { Run-Paint }
    elseif ($erase) { Run-Erase }
}

# Runs the paint section
function Run-Paint()
{
    if ($json -ne $null)
    {
        Write-Information "Painting the current machine: $env:COMPUTERNAME"
        Speak-Text 'Painting the current machine' $speech
        Run-Section $json.paint
    }
}

# Runs the erase section
function Run-Erase()
{
    if ($json -ne $null)
    {
        Write-Information "Erasing the current machine: $env:COMPUTERNAME"
        Speak-Text 'Erasing the current machine' $speech
        Run-Section $json.erase
    }
}

# Runs the steps defined in the passed section
function Run-Section($section)
{
    if ($section -eq $null -or $section.Count -eq 0)
    {
        throw 'There is no section present.'
    }

    # Setup variables
    $variables = @{}
    if ($speech -ne $null)
    {
        $variables['__speech__'] = $speech
    }

    # Loop through each colour within the config file
    ForEach ($colour in $section)
    {
        Write-NewLine

        $type = $colour.type.ToLower()

        if ($type -ieq 'extension')
        {
            Write-Header ("{0} (ext)" -f $colour.extension)
        }
        else
        {
            Write-Header $type
        }

        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        $description = $colour.description
        if (![String]::IsNullOrWhiteSpace($description))
        {
            Write-Information "[$description]"
            Speak-Text $description $speech
        }

        switch ($type)
        {
            'credentials'
                {
                    if ($credentials -eq $null)
                    {
                        $message = $colour.message
                        if ([string]::IsNullOrWhiteSpace($message))
                        {
                            $message = 'Your credentials are required for use via Picassio.'
                        }

                        $credentials = (Get-Credential -Message $message)

                        if ($credentials -eq $null -or [string]::IsNullOrWhiteSpace($credentials.Username))
                        {
                            throw 'No credentials have been supplied.'
                        }

                        Write-Information ("Credentials set for {0}." -f $credentials.Username)
                    }
                }

            'extension'
                {
                    $extensionName = $colour.extension
                    $extension = "$env:PicassioExtensions\$extensionName.psm1"
                    Import-Module $extension -DisableNameChecking -ErrorAction Stop
                    Start-Extension $colour $variables $credentials
                    Remove-Module $extensionName -ErrorAction Stop
                }

            default
                {
                    $module = "$env:PicassioModules\$type.psm1"
                    Import-Module $module -DisableNameChecking -ErrorAction Stop
                    Start-Module $colour $variables $credentials
                    Remove-Module $type -ErrorAction Stop
                }
        }

        # Report import the picassio tools module
        Import-Module $modulePath -DisableNameChecking -ErrorAction Stop
        Reset-Path

        Write-Stamp ('Time taken: {0}' -f $stopwatch.Elapsed)
        Write-NewLine
    }

    Write-Header ([string]::Empty)
}




try
{
    # Ensure we're running against the correct version of PowerShell
    try
    {
        $currentVersion = [decimal]([string](Get-Host | Select-Object Version).Version)
    }
    catch
    {
        $currentVersion = [decimal]((Get-Host).Version.Major)
    }

    if ($currentVersion -lt 3)
    {
        Write-Errors "Picassio requires PowerShell 3.0 or greater, your version is $currentVersion"
        return
    }

    Write-Version
    if ($version)
    {
        return
    }
    elseif ($help)
    {
        Write-Help
        return
    }

    # Check administrator priviledges
    if (!$force -and !(Test-AdminUser))
    {
        Write-Warnings 'You must be running as a user with administrator priviledges for Picassio to fully function.'
        Write-Warnings 'If you believe this to be wrong, you can specify the -force flag. This will force Picassio to run regardless of user priviledges.'
        return
    }

    if ($force)
    {
        Write-Warnings '[WARNING] You are running Picassio with the -force flag. This may lead to unexpected behaviour.'
        if (!(Read-AreYouSure))
        {
            return
        }
    }

    # Check switches
    if ($install)
    {
        Install-Picassio
        return
    }
    elseif ($uninstall)
    {
        Uninstall-Picassio
        return
    }
    elseif ($reinstall)
    {
        Reinstall-Picassio
        return
    }

    # Main Picassio logic
    # Check that picassio is installed on the machine
    if (!(Test-PicassioInstalled))
    {
        Write-Errors 'Picassio has not been installed. Please install Picassio with ".\Picassio.ps1 -install".'
        return
    }

    # Check to see if a palette file was passed, if not we use the default picassio.palette
    if ([string]::IsNullOrWhiteSpace($palette))
    {
        Write-Message "No palette file supplied, using default 'picassio.palette'."
        $palette = './picassio.palette'

        if (!(Test-Path $palette))
        {
            Write-Errors "Default 'picassio.palette' file cannot be found in current directory."
            return
        }
    }
    elseif (!(Test-Path $palette))
    {
        Write-Errors "Passed palette file does not exist: '$palette'."
        return
    }

    # Palette exists, but is the extension correct?
    $extension = [System.IO.Path]::GetExtension($palette)
    if ($extension -ne '.palette')
    {
        Write-Errors "Passed palette file is not a valid '.palette' file, extension passed was: '$extension'"
        return
    }

    # Header for palette
    Write-Header (Split-Path -Leaf $palette)

    # Setup main variables hashtable
    $variables = @{}

    # Setup credentials
    $credentials = $null
    if (![string]::IsNullOrWhiteSpace($username))
    {
        if ($password -eq $null)
        {
            $password = [string]::Empty
        }

        $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
        $credentials = New-Object PSCredential($username, $securePassword)
    }

    # Validate the config file
    $json = Test-File (Get-Content $palette -Raw)

    # If we're only validating, exit the program now
    if ($validate)
    {
        return
    }

    # If paint and erase switches are both false or true, exit program
    if (!$paint -and !$erase)
    {
        Write-Warnings 'Need to specify either the paint or erase flags.'
        return
    }

    if ($paint -and $erase)
    {
        Write-Warnings 'You can only specify either the paint or erase flag, not both.'
        return
    }

    # Start the stopwatch for total time tracking
    $total_stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    # Check to see if the voice-over is enabled. If so, set it up as a variable
    if ($voice)
    {
        try
        {
            Add-Type -AssemblyName 'System.Speech'
            $speech = New-Object System.Speech.Synthesis.SpeechSynthesizer
            $variables['__speech__'] = $speech
            Write-Message 'Voice enabled.'
        }
        catch [exception]
        {
            # Write the exception, but we don't care if we can't enable the voice
            Write-Errors 'Failed to enable voice over.'
            Write-Exception $_.Exception
        }
    }

    # Check to see if we need to erase first, and only if we're painting
    if (![string]::IsNullOrWhiteSpace($json.eraseBeforePaint) -and $json.eraseBeforePaint -eq $true -and $paint)
    {
        Run-Erase
        Write-NewLine
    }

    # Get either the paint or erase section
    Run-Palette $paint $erase

    # Check to see if we need to erase after we're done painting
    if (![string]::IsNullOrWhiteSpace($json.eraseAfterPaint) -and $json.eraseAfterPaint -eq $true -and $paint)
    {
        Write-NewLine
        Run-Erase
        Write-NewLine
    }

    Write-Stamp ('Total time taken: {0}' -f $total_stopwatch.Elapsed)
    Write-Information 'Picassio finished successfully.' $speech
}
catch [exception]
{
    if ($total_stopwatch -ne $null)
    {
        Write-Stamp ('Total time taken: {0}' -f $total_stopwatch.Elapsed)
    }

    Write-Warnings 'Picassio failed to finish.' $speech
    Pop-Location -ErrorAction SilentlyContinue

    # Rollback
    try
    {
        if (![string]::IsNullOrWhiteSpace($json.rollbackOnFail) -and $json.rollbackOnFail -eq $true)
        {
            Write-Information "`nRolling back the palette.`n"
            Run-Palette $erase $paint
        }
    }
    catch [exception]
    {
        Write-Errors 'Failed to rollback the palette. Rollback exception:'
        Write-Exception $_.Exception
        Write-NewLine
        Write-Warnings 'Main failure exception:'
    }

    Speak-Text $_.Exception.Message $speech
    throw
}
finally
{
    if ($speech -ne $null)
    {
        Write-Host 'Dipsosing voice.'
        $speech.Dispose()
    }

    $variables = @{}

    # Remove the picassio tools module
    if (![string]::IsNullOrWhiteSpace($modulePath))
    {
        Remove-Module 'PicassioTools'
    }
}
