##########################################################################
# Picassio is a provisioning/deployment script which uses a single linear
# JSON file to determine what commands to execute.
#
# Copyright (c) 2015, Matthew Kelly (Badgerati)
# Company: Cadaeic Studios
# License: MIT (see LICENSE for details)
#
# Example (still in dev, only works for sql and backups):
#
# {
#    "paint": [
#        {
#            "type": "ps-sql",
#            "timeout": 60,
#            "server": "192.130.1.90\INSTANCE",
#            "backup": {
#                "type": "restore",
#                "location": "C:\\path\\to\\backup.bac",
#                "database": "DatabaseName",
#                "sqlpath": "C:\\path\\to\\put\\mdf_and_ldf"
#            },
#            "sql": {
#                "query": "SELECT * FROM [Example]",
#                "file": "C:\\path\\to\\script.sql"
#            }
#        }
#    ]
# }
#########################################################################

# Run specific SQL commands, or general functions using SQL Servers PowerShell module
Import-Module $env:PicassioTools -DisableNameChecking -ErrorAction Stop

function Start-Module($colour, $variables, $credentials)
{
    Test-Module $colour $variables $credentials
    Start-SqlPs $colour.sqlpsPath

    $server = Replace-Variables $colour.server $variables
    $timeout = Replace-Variables $colour.timeout $variables

    if ([string]::IsNullOrWhiteSpace($timeout))
    {
        Write-Message 'No timeout value specified, using default of 60 seconds.'
        $timeout = 60
    }

    Write-Information "Using database server $server"

    # Snapshot

    # Backup
    $backup = $colour.backup
    if ($backup -ne $null)
    {
        $backupType = (Replace-Variables $backup.type $variables).ToLower().Trim()
        $backupLocation = Replace-Variables $backup.location $variables
        $backupDatabase = Replace-Variables $backup.database $variables

        switch ($backupType)
        {
            'restore'
                {
                    $backupSqlPath = Replace-Variables $backup.sqlpath $variables
                    if (!(Test-Path $backupSqlPath))
                    {
                        throw "Backup SQL path does not exist: '$backupSqlPath'."
                    }

                    Restore-Backup $backupLocation $backupDatabase $backupSqlPath $server $timeout
                }

            'create'
                {
                    Create-Backup $backupLocation $backupDatabase $server $timeout
                }
        }
    }

    # SQL
    $sql = $colour.sql
    if ($sql -ne $null)
    {
        $query = Replace-Variables $sql.query $variables
        $file = Replace-Variables $sql.file $variables

        Run-Sql $query $file $server $timeout
    }
}

function Test-Module($colour, $variables, $credentials)
{
    Test-SqlPs

    # General server/timeout
    $backup = $colour.backup
    $snapshot = $colour.snapshot
    $sql = $colour.sql

    if (($backup -ne $null -and ($snapshot -ne $null -or $sql -ne $null)) -or ($snapshot -ne $null -and $sql -ne $null))
    {
        throw 'You can on specify one of either backup, snapshot or sql for mssql.'
    }

    $server = Replace-Variables $colour.server $variables
    if ([string]::IsNullOrWhiteSpace($server))
    {
        throw 'No database server specified.'
    }

    $timeout = Replace-Variables $colour.timeout $variables
    if (![string]::IsNullOrWhiteSpace($timeout) -and ($timeout -notmatch "^[0-9]+$"))
    {
        throw "Invalid value for timeout: '$timeout'. Should be an integer value."
    }

    # Snapshot
    if ($snapshot -ne $null)
    {

    }

    # Backup
    if ($backup -ne $null)
    {
        $backupType = Replace-Variables $backup.type $variables
        if ([string]::IsNullOrWhiteSpace($backupType))
        {
            throw 'No backup type specified.'
        }

        $backupType = $backupType.ToLower().Trim()
        if ($backupType -ne 'create' -and $backupType -ne 'restore')
        {
            throw "Invalid backup type parameter supplied: '$backupType'."
        }

        $backupLocation = Replace-Variables $backup.location $variables
        if ([string]::IsNullOrWhiteSpace($backupLocation))
        {
            throw 'No backup location specified.'
        }

        $backupDatabase = Replace-Variables $backup.database $variables
        if ([string]::IsNullOrWhiteSpace($backupDatabase))
        {
            throw 'No backup database name specified.'
        }

        if ($backupType -eq 'restore')
        {
            $backupSqlPath = Replace-Variables $backup.sqlpath $variables
            if ([string]::IsNullOrWhiteSpace($backupSqlPath))
            {
                throw 'No backup SQL path specified.'
            }
        }
    }

    # SQL
    if ($sql -ne $null)
    {
        $query = Replace-Variables $sql.query $variables
        $file = Replace-Variables $sql.file $variables

        if ([string]::IsNullOrWhiteSpace($query) -and [string]::IsNullOrWhiteSpace($file))
        {
            throw 'Either a SQL query or file path need to be supplied.'
        }
        elseif (![string]::IsNullOrWhiteSpace($query) -and ![string]::IsNullOrWhiteSpace($file))
        {
            throw 'Only one of either a SQL query or file path can be supplied.'
        }
    }
}


###################
# SQL POWERSHELL
###################
function Test-SqlPs()
{
    $sqlpsreg = 'HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.SqlServer.Management.PowerShell.sqlps'
    if (Get-ChildItem $sqlpsreg -ErrorAction SilentlyContinue)
    {
        throw 'SQL Server Powershell is not installed.'
    }

    return $true
}

function Start-SqlPs($sqlpsPath)
{
    # Based off work by Michiel Wories
    if ((Test-SqlPs) -and [String]::IsNullOrWhiteSpace($sqlpsPath))
    {
        $sqlpsPath = "C:\Program Files (x86)\Microsoft SQL Server\100\Tools\Binn\"
    }

    if (!(Test-Path $sqlpsPath))
    {
        throw "Path to sqlps does not exist: '$sqlpsPath'."
    }

    # Preload the assemblies. Note that most assemblies will be loaded when the provider
    # is used. if you work only within the provider this may not be needed. It will reduce
    # the shell's footprint if you leave these out.
    $assemblylist =
        "Microsoft.SqlServer.Smo",
        "Microsoft.SqlServer.Dmf ",
        "Microsoft.SqlServer.SqlWmiManagement ",
        "Microsoft.SqlServer.ConnectionInfo ",
        "Microsoft.SqlServer.SmoExtended ",
        "Microsoft.SqlServer.Management.RegisteredServers ",
        "Microsoft.SqlServer.Management.Sdk.Sfc ",
        "Microsoft.SqlServer.SqlEnum ",
        "Microsoft.SqlServer.RegSvrEnum ",
        "Microsoft.SqlServer.WmiEnum ",
        "Microsoft.SqlServer.ServiceBrokerEnum ",
        "Microsoft.SqlServer.ConnectionInfoExtended ",
        "Microsoft.SqlServer.Management.Collector ",
        "Microsoft.SqlServer.Management.CollectorEnum"

    foreach ($asm in $assemblylist)
    {
        $asm = [Reflection.Assembly]::LoadWithPartialName($asm)
    }

    # Set variables that the provider expects (mandatory for the SQL provider)
    Set-Variable -scope Global -name SqlServerMaximumChildItems -Value 0
    Set-Variable -scope Global -name SqlServerConnectionTimeout -Value 30
    Set-Variable -scope Global -name SqlServerIncludeSystemObjects -Value $false
    Set-Variable -scope Global -name SqlServerMaximumTabCompletion -Value 1000

    try
    {
        # Load the snapins, type data, format data
        Push-Location $sqlpsPath

        Add-PSSnapin SqlServerCmdletSnapin100
        Add-PSSnapin SqlServerProviderSnapin100
        Update-TypeData -PrependPath SQLProvider.Types.ps1xml
        update-FormatData -prependpath SQLProvider.Format.ps1xml

        Write-Information 'SQL Server Powershell extensions are loaded.'
    }
    finally
    {
        Pop-Location
    }
}


###################
# SNAPSHOTS
###################
function Create-Shapshot($snapshotName, $snapshotLocation, $databaseName, $server, $timeoutSeconds)
{
    Write-Message "Creating snapshot of [$databaseName]"

    $query = "
        USE [$databaseName];
        SELECT FILE_NAME(1);"

    $result = Run-Sql -query $query -server $server
    if (!$?)
    {
        throw 'Failed to retrieve database name for snapshot.'
    }

    $filename = $result[0]
    $query = "
        CREATE DATABASE $snapshotName ON (
            Name = $filename,
            FILENAME = '$snapshotLocation'
        ) AS SNAPSHOT OF [$databaseName];"

    $result = Run-Sql -query $query -server $server -timeoutSeconds $timeoutSeconds
    if (!$?)
    {
        throw 'Failed to create snapshot for database.'
    }

    Write-Host 'Snapshot created.'
}

function Restore-Shapshot($snapshotName, $databaseName, $server, $timeoutSeconds)
{
    Write-Message "Restoring database for [$databaseName]"

    $query = "
        ALTER DATABASE [$databaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        RESTORE DATABASE [$databaseName] FROM DATABASE_SNAPSHOT = '$snapshotName';
        ALTER DATABASE [$databaseName] SET MULTI_USER;"

    $result = Run-Sql -query $query -server $server -timeoutSeconds $timeoutSeconds
    if (!$?)
    {
        throw 'Failed to restore database from snapshot.'
    }

    Write-Host 'Database restored.'
}


###################
# BACKUPS
###################
function Create-Backup($backupLocation, $databaseName, $server, $timeoutSeconds)
{
    Write-Message "Creating backup of [$databaseName]"

    $query = "
        BACKUP DATABASE [$databaseName]
        TO DISK = '$backupLocation' WITH INIT;"

    $result = Run-Sql -query $query -server $server -timeout $timeoutSeconds
    if (!$?)
    {
        throw 'Failed to create backup of the database.'
    }

    Write-Host 'Backup created.'
}

function Restore-Backup($backupLocation, $databaseName, $sqlPath, $server, $timeoutSeconds)
{
    Write-Message "Restoring backup of [$databaseName]"

    $query = "
        DECLARE @FileList TABLE
        (
            LogicalName NVARCHAR(128) NOT NULL,
            PhysicalName NVARCHAR(260) NOT NULL,
            Type CHAR(1) NOT NULL,
            FileGroupName NVARCHAR(120) NULL,
            Size NUMERIC(20, 0) NOT NULL,
            MaxSize NUMERIC(20, 0) NOT NULL,
            FileID BIGINT NULL,
            CreateLSN NUMERIC(25,0) NULL,
            DropLSN NUMERIC(25,0) NULL,
            UniqueID UNIQUEIDENTIFIER NULL,
            ReadOnlyLSN NUMERIC(25,0) NULL ,
            ReadWriteLSN NUMERIC(25,0) NULL,
            BackupSizeInBytes BIGINT NULL,
            SourceBlockSize INT NULL,
            FileGroupID INT NULL,
            LogGroupGUID UNIQUEIDENTIFIER NULL,
            DifferentialBaseLSN NUMERIC(25,0)NULL,
            DifferentialBaseGUID UNIQUEIDENTIFIER NULL,
            IsReadOnly BIT NULL,
            IsPresent BIT NULL,
            TDEThumbprint VARBINARY(32) NULL
        );

        INSERT INTO @FileList
        EXEC(N'RESTORE FILELISTONLY FROM DISK = ''$backupLocation'';');

        DECLARE @logical_data NVARCHAR(128), @logical_log NVARCHAR(128);

        SET @logical_data = (SELECT LogicalName FROM @FileList WHERE Type = 'D' AND FileID = 1);
        SET @logical_log = (SELECT LogicalName FROM @FileList WHERE Type = 'L' AND FileID = 2);

        RESTORE DATABASE [$databaseName]
        FROM DISK = N'$backupLocation'
        WITH REPLACE,
             MOVE @logical_data TO '$sqlPath\$databaseName.mdf',
             MOVE @logical_log TO '$sqlPath\$databaseName.ldf';"

    $result = Run-Sql -query $query -server $server -timeout $timeoutSeconds
    if (!$?)
    {
        throw 'Failed to restore database from backup.'
    }

    Write-Host 'Database restored.'
}


###################
# SQL
###################
function Run-Sql($query, $file, $server, $timeoutSeconds = 60)
{
    if (![string]::IsNullOrWhiteSpace($query))
    {
        Write-Host 'Running SQL query.'
        Write-Information "$query"
        $value = Invoke-Sqlcmd -Query $query -ServerInstance $server -QueryTimeout $timeoutSeconds
    }
    else
    {
        Write-Host 'Running SQL file'

        if (!(Test-Path $file))
        {
            throw "SQL file path does not exist: '$file'."
        }

        Write-Information "File: '$file'"
        $value = Invoke-Sqlcmd -InputFile $file -ServerInstance $server -QueryTimeout $timeoutSeconds
    }

    if (!$?)
    {
        throw 'Failed to run SQL command.'
    }

    return $value
}
