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
#            "type": "chef-client",
#            "path": "C:\\path\\to\\cookbook",
#            "cookbook": "dev",
#            "arguments": "--force-formatter",
#            "runList": [
#               "web",
#               "sql"
#            ]
#        },
#        {
#            "type": "chef-client",
#            "path": "C:\\path\\to\\recipes",
#            "arguments": "--force-formatter",
#            "recipes": [
#                "web.rb",
#                "sql.rb"
#            ]
#        }
#    ]
# }
#########################################################################

# Run a cookbook using the chef-client tool
Import-Module $env:PicassioTools -DisableNameChecking -ErrorAction Stop

function Start-Module($colour, $variables, $credentials)
{
    Test-Module $colour $variables $credentials

    if (!(Test-Software 'chef-client --version' 'chef-client'))
    {
        Write-Warnings 'Chef is not installed'
        Install-AdhocSoftware 'chef-client' 'Chef'
    }

    $path = (Replace-Variables $colour.path $variables).Trim()
    $cookbook = Replace-Variables $colour.cookbook $variables
    $runList = $colour.runList
    $recipes = $colour.recipes

    $_args = Replace-Variables $colour.arguments $variables
    if ([string]::IsNullOrWhiteSpace($_args))
    {
        $_args = [string]::Empty
    }

    Push-Location $path

    try
    {
        if ([string]::IsNullOrWhiteSpace($cookbook))
        {
            ForEach ($recipe in $recipes)
            {
                Write-Message "Running Chef for recipe: $recipe"
                Run-Command 'chef-client' "--local-mode $recipe $_args"
            }
        }
        else
        {
            if ($runList -eq $null -or $runList.Length -eq 0)
            {
                Write-Message "Running Chef for $cookbook cookbook on default recipe."
                Run-Command 'chef-client' "--local-mode --runlist 'recipe[$cookbook]' $_args"
            }
            else
            {
                ForEach ($recipe in $runList)
                {
                    Write-Message "Running Chef for $cookbook cookbook on $recipe recipe."
                    Run-Command 'chef-client' ("--local-mode --runlist 'recipe[{0}::{1}]' {2}" -f $cookbook, $recipe, $_args)
                }
            }
        }
    }
    finally
    {
        Pop-Location
    }

    Write-Message 'Chef ran successfully.'
}

function Test-Module($colour, $variables, $credentials)
{
    # Check the path
    $path = Replace-Variables $colour.path $variables
    if ([string]::IsNullOrWhiteSpace($path))
    {
        throw 'No path passed to cookbooks/recipes.'
    }

    if (!(Test-Path $path) -and $variables['__initial_validation__'] -eq $false)
    {
        throw "Path to cookbooks/recipes does not exist: '$path'."
    }

    # Check the cookbook and runlist
    $cookbook = Replace-Variables $colour.cookbook $variables
    if (![string]::IsNullOrWhiteSpace($cookbook))
    {
        $runList = $colour.runList
        if ($runList -ne $null -and $runList.Length -gt 0)
        {
            ForEach ($item in $runList)
            {
                $item = Replace-Variables $item $variables

                if ([string]::IsNullOrWhiteSpace($item))
                {
                    throw 'Cannot pass an empty recipe name for cookbook in runList.'
                }
            }
        }
    }

    # Check the recipes
    if ([string]::IsNullOrWhiteSpace($cookbook))
    {
        $recipes = $colour.recipes
        if ($recipes -eq $null -or $recipes.Length -eq 0)
        {
            throw 'No recipes supplied to run.'
        }

        ForEach ($recipe in $recipes)
        {
            $recipe = Replace-Variables $recipe $variables

            if ([string]::IsNullOrWhiteSpace($recipe))
            {
                throw 'Cannot pass an empty recipe name.'
            }
        }
    }
}
