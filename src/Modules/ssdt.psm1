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
#   "paint": [
#       {
#           "type": "ssdt",
#           "action": "publish",
#           "path": "C:\\path\\to\\SqlPackage.exe",
#           "source": "C:\\path\\to\\some\\file.dacpac",
#           "publish": "C:\\path\\to\\some\\publish.xml",
#           "timeout": 60,
#           "backupFirst": false,
#           "dropFirst": false,
#           "blockOnLoss": true,
#           "args": "/p:IgnorePermissions=True"
#       },
#       {
#           "type": "ssdt",
#           "action": "script",
#           "path": "C:\\path\\to\\SqlPackage.exe",
#           "source": "C:\\path\\to\\some\\file.dacpac",
#           "output": "C:\\path\\to\\create\\output.sql",
#           "timeout": 60,
#           "args": "/p:IgnorePermissions=True"
#       }
#   ]
# }
#########################################################################

# Publishes or generates the script via SSDT's SqlPackage tool
Import-Module $env:PicassioTools -DisableNameChecking -ErrorAction Stop

function Start-Module($colour, $variables, $credentials) {
    Test-Module $colour $variables $credentials

    $path = (Replace-Variables $colour.path $variables).Trim().ToLower()
    if ([string]::IsNullOrWhiteSpace($path)) {
        Write-Message 'No path supplied, using default.'
        $path = 'C:\Program Files (x86)\Microsoft SQL Server\110\DAC\bin\SqlPackage.exe'
    }
    else {
        $path = $path.Trim()
    }

    $action = (Replace-Variables $colour.action $variables).Trim().ToLower()
    $source = (Replace-Variables $colour.source $variables).Trim().ToLower()

    $timeout = Replace-Variables $colour.timeout $variables
    if ([string]::IsNullOrWhiteSpace($timeout)) {
        $timeout = 60
    }

    $_args = Replace-Variables $colour.args $variables
    if ([string]::IsNullOrWhiteSpace($_args)) {
        $_args = [string]::Empty
    }

    $final_args = "/sf:$source /a:$action /p:CommandTimeout=$timeout"

    switch ($ensure) {
        'publish'
            {
                $publish = (Replace-Variables $colour.publish $variables).Trim().ToLower()
                $backupFirst = Replace-Variables $colour.backupFirst $variables
                if ([string]::IsNullOrWhiteSpace($backupFirst)) {
                    $backupFirst = $false
                }

                $dropFirst = Replace-Variables $colour.dropFirst $variables
                if ([string]::IsNullOrWhiteSpace($dropFirst)) {
                    $dropFirst = $false
                }

                $blockOnLoss = Replace-Variables $colour.blockOnLoss $variables
                if ([string]::IsNullOrWhiteSpace($blockOnLoss)) {
                    $blockOnLoss = $true
                }

                $final_args = "$final_args /pr:$publish /p:BackupDatabaseBeforeChanges=$backupFirst /p:CreateNewDatabase=$dropFirst /p:BlockOnPossibleDataLoss=$blockOnLoss"
            }

        'script'
            {
                $output = (Replace-Variables $colour.output $variables).Trim().ToLower()
                $final_args = "$final_args /op:$output"
            }
    }

    if (![string]::IsNullOrWhiteSpace($_args)) {
        $final_args = "$final_args $_args"
    }

    Write-Message "Attempting to $action SSDT."

    Run-Command $path $final_args

    Write-Message "$action of SSDT successful."
}

function Test-Module($colour, $variables, $credentials) {
    $action = Replace-Variables $colour.action $variables
    $actions = @('publish', 'script')
    if ([string]::IsNullOrWhiteSpace($action) -or $actions -inotcontains ($action.Trim())) {
        throw ("Invalid action found: '$action'. Can be only: {0}." -f ($actions -join ', '))
    }

    $path = Replace-Variables $colour.path $variables
    if ([string]::IsNullOrWhiteSpace($path)) {
        $path = 'C:\Program Files (x86)\Microsoft SQL Server\110\DAC\bin\SqlPackage.exe'
    }

    if (!(Test-Path ($path.Trim()))) {
        throw "Invalid path to SqlPackage.exe supplied: '$path'."
    }

    $source = Replace-Variables $colour.source $variables
    if ([string]::IsNullOrEmpty($source) -or !(Test-Path ($source.Trim()))) {
        throw "Invalid or empty source path supplied: '$source'."
    }

    switch ($action.Trim().ToLower()) {
        'publish'
            {
                $publish = Replace-Variables $colour.publish $variables
                if ([string]::IsNullOrEmpty($publish) -or !(Test-Path ($publish.Trim()))) {
                    throw "Invalid or empty publish profile path supplied: '$publish'."
                }
            }

        'script'
            {
                $output = Replace-Variables $colour.output $variables
                if ([string]::IsNullOrEmpty($output)) {
                    throw "Empty output path supplied: '$output'."
                }
            }
    }
}
