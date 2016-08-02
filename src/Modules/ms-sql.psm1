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
#            "type": "ms-sql",
#            "connectionString": "server=(local);Databas=Example;Trusted_Connection=True;",
#            "sql": "INSERT INTO [SomeTable] VALUES ('value', 1001)",
#            "notIf": "SELECT TOP 1 * FROM [SomeTable] WHERE SomeValue = 'value'"
#        },
#        {
#            "type": "ms-sql",
#            "connectionString": "server=(local);Databas=Example;Trusted_Connection=True;",
#            "sqlFile": "C:\\path\\to\\some.sql",
#            "notIf": "SELECT TOP 1 * FROM [SomeTable] WHERE SomeValue = 'value'"
#        }
#    ]
# }
#########################################################################

# Execute the passed SQL against the passed connection string
Import-Module $env:PicassioTools -DisableNameChecking -ErrorAction Stop

function Start-Module($colour, $variables, $credentials)
{
    Test-Module $colour $variables $credentials

    $connectionString = (Replace-Variables $colour.connectionString $variables).Trim()
    $sql = Replace-Variables $colour.sql $variables
    $sqlFile = Replace-Variables $colour.sqlFile $variables
    $notIf = Replace-Variables $colour.notIf $variables

    try
    {
        # Attempt connection using connection string
        Write-Information "Opening Connection: $connectionString"
        $conn = [System.Data.SqlClient.SqlConnection] $connectionString
        $conn.Open()

        if (!$?)
        {
            throw "Failed to open connection to database using connection string supplied."
        }

        # Check if the notIf command is present
        if (![string]::IsNullOrWhiteSpace($notIf))
        {
            Write-Message 'Checking database against notIf command.'
            $notIf = "IF EXISTS ($notIf) BEGIN SELECT 1 END ELSE BEGIN SELECT 0 END"
            $sqlCommand = $conn.CreateCommand()
            $sqlCommand.CommandText = $notIf
            $result = $sqlCommand.ExecuteScalar()

            if ($result -eq 1)
            {
                Write-Information 'The notIf command returned true, not running main SQL.'
                return
            }
        }

        Write-Message 'Running SQL command.'
        if ([string]::IsNullOrWhiteSpace($sql))
        {
            $sql = Get-Content $sqlFile -Raw
        }

        $sqlCommand = $conn.CreateCommand()
        $sqlCommand.CommandText = $sql
        $sqlCommand.ExecuteNonQuery()

        if (!$?)
        {
            throw 'Running the SQL command failed.'
        }

        Write-Message 'SQL command ran successfully.'
    }
    finally
    {
        if ($conn -ne $null)
        {
            $conn.Close()
        }
    }
}

function Test-Module($colour, $variables, $credentials)
{
    # Check the connection string
    $connectionString = Replace-Variables $colour.connectionString $variables
    if ([string]::IsNullOrWhiteSpace($connectionString))
    {
        throw 'No connection string passed to connect to database.'
    }

    # Check the SQL/file command
    $sql = Replace-Variables $colour.sql $variables
    $sqlFile = Replace-Variables $colour.sqlFile $variables

    if ([string]::IsNullOrWhiteSpace($sql) -and [string]::IsNullOrWhiteSpace($sqlFile))
    {
        throw 'No SQL or SQL file path passed to execute against the database.'
    }

    if (![string]::IsNullOrWhiteSpace($sql) -and ![string]::IsNullOrWhiteSpace($sqlFile))
    {
        throw 'Cannot pass both SQL and a SQL file path.'
    }

    # Check the SQL file, if passed
    if (![string]::IsNullOrWhiteSpace($sqlFile) -and $variables['__initial_validation__'] -eq $false)
    {
        if (!(Test-Path $sqlFile))
        {
            throw "The SQL file path passed does not exist: '$sqlFile'."
        }

        $sql = Get-Content $sqlFile -Raw
        if ([string]::IsNullOrWhiteSpace($sql))
        {
            throw "There is no SQL within the passed SQL file: '$sqlFile'."
        }
    }
}
