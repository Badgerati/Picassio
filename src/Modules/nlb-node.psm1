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
#	"paint": [
#		{
#			"type": "nlb-node",
#           "ensure": "stop",
#           "drain": true,
#           "timeout": 30,
#           "nodes": [
#               "NODE_NAME_1"
#           ]
#		},
#		{
#			"type": "nlb-node",
#           "ensure": "start",
#           "nodes": [
#               "NODE_NAME_1"
#           ]
#		},
#		{
#			"type": "nlb-node",
#           "ensure": "add",
#           "cluster": "NODE_CLUSTER_NAME",
#           "interface": "vlan-3",
#           "nodes": [
#               "NODE_NAME_1"
#           ]
#		}
#	]
# }
#########################################################################

# Adds, removes, starts, stops nodes on Network Load Balancer
Import-Module $env:PicassioTools -DisableNameChecking -ErrorAction Stop
Import-Module NetworkLoadBalancingClusters -ErrorAction Stop

function Start-Module($colour, $variables, $credentials)
{
    Test-Module $colour $variables $credentials

    $ensure = (Replace-Variables $colour.ensure $variables).Trim().ToLower()
    $nodes = $colour.nodes
    $drain = Replace-Variables $colour.drain $variables

    $timeout = Replace-Variables $colour.timeout $variables
    if ([string]::IsNullOrWhiteSpace($timeout))
    {
        $timeout = 30
    }

    ForEach ($node in $nodes)
    {
        $node = (Replace-Variables $node $variables).Trim()

        Write-Message "Attempting to $ensure the $node node."

        switch ($ensure)
        {
            'add'
                {
                    $cluster = (Replace-Variables $colour.cluster $variables).Trim()
                    $interface = (Replace-Variables $colour.interface $variables).Trim()
                    Get-NlbCluster $cluster | Add-NlbClusterNode -NewNodeName $node -NewNodeInterface $interface -Force
                }

            'remove'
                {
                    Remove-NlbClusterNode $node -Force
                }

            'start'
                {
                    Start-NlbClusterNode $node
                }

            'stop'
                {
                    if ($drain -eq $true)
                    {
                        Stop-NlbClusterNode $node -Drain -Timeout $timeout
                    }
                    else
                    {
                        Stop-NlbClusterNode $node
                    }
                }

            'suspend'
                {
                    Suspend-NlbClusterNode $node
                }

            'resume'
                {
                    Resume-NlbClusterNode $node
                }
        }

        if (!$?)
        {
            throw "Failed to $ensure the $node node."
        }

        Write-Message "$ensure of $node node successful."
    }
}

function Test-Module($colour, $variables, $credentials)
{
    $ensure = Replace-Variables $colour.ensure $variables
    $ensures = @('stop', 'start', 'add', 'remove', 'resume', 'suspend')
    if ([string]::IsNullOrWhiteSpace($ensure) -or $ensures -inotcontains ($ensure.Trim()))
    {
        throw ("Invalid ensure found: '$ensure'. Can be only: {0}." -f ($ensures -join ', '))
    }

    $nodes = $colour.nodes
    if ($nodes -eq $null -or $nodes.Length -eq 0)
    {
        throw 'No nodes to load balance specified.'
    }

    ForEach ($node in $nodes)
    {
        $node = Replace-Variables $node $variables

        if ([string]::IsNullOrWhiteSpace($node))
        {
            throw 'Cannot pass an empty node name for load balancing.'
        }
    }

    if ($ensure -ieq 'add')
    {
        $cluster = Replace-Variables $colour.cluster $variables
        if ([string]::IsNullOrWhiteSpace($cluster))
        {
            throw 'No cluster name specified when adding new node to load balance.'
        }

        $interface = Replace-Variables $colour.interface $variables
        if ([string]::IsNullOrWhiteSpace($interface))
        {
            throw 'No interface type specified when adding new node to load balance.'
        }
    }
}
