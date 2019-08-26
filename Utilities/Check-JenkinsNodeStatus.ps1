##############################################################################################
# Check-JenkinsNodeStatus.ps1
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the Apache License.
<#
.Synopsis
    This script tests used to get the health status of all jenkins' nodes.
.Description
    Used only if all parameter exists.
    Pass the username and token by parameter to generate Certification Information. https://octopus.com/blog/jenkins-rest-api
    Print the name of the node status and count the total.
#>
###############################################################################################

Param(
    [String] $jenkinsurl,
    [String] $username,
    [String] $token
)

$node_name = @()
$node_active = @()
$node_offline_reason = @()
$all_info = @()
$online = 0
$offline = 0
$flag = 0

if (!$jenkinsurl -or !$username -or !$token) {
    Write-Host "ERROR: Parameter jenkinsurl or username or token not exist" -ForegroundColor "Red"
} else {
    $pair = "$($username):$($token)"
    $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
    $basicAuthValue = "Basic $encodedCreds"
    $headers = @{
        Authorization = $basicAuthValue
    }

    Invoke-WebRequest -Uri $jenkinsurl'/computer/api/xml' -Headers $headers -OutFile "$pwd\get_node_info.xml"
    [xml]$getxml = Get-Content "$pwd\get_node_info.xml"

    Write-Host "`n===== Test result information =====`n"
    "{0,-32} {1,-5} {2,-80} {3,-60}" -f "displayName", "active", "offlineCauseReason", "labels"
    "{0,-32} {1,-5} {2,-80} {3,-60}" -f "-----------", "------", "------------------", "------"

    $rename_offline_column = @{Expression="offline"; Label="active"}
    $rename_label_column = @{Expression="description"; Label="labels"}
    foreach ($item in $getxml.computerSet.computer) {
        $node_name = $getxml.computerSet.computer[$flag].displayName
        $node_offline = $getxml.computerSet.computer[$flag].offline
        $node_offline_reason = $getxml.computerSet.computer[$flag].offlineCauseReason -Split "\n"
        $assignedLabel = ""

        for ($i = 0; $i -lt $getxml.computerSet.computer[$flag].assignedLabel.name.count; $i++) {
            if ($getxml.computerSet.computer[$flag].assignedLabel.name.count -eq "1") {
                $node_label = $getxml.computerSet.computer[$flag].assignedLabel.name
            } else {
                $node_label = $getxml.computerSet.computer[$flag].assignedLabel.name[$i]
            }
            $assignedLabel += "$node_label"
            if ($i -lt ($getxml.computerSet.computer[$flag].assignedLabel.name.count)-1) {
                $assignedLabel += ","
            }
        }

        if ($node_offline -eq "true") {
            $node_active = "false"
            $getxml.computerSet.computer[$flag].offline = $node_active
            $getxml.computerSet.computer[$flag].offlineCauseReason = $node_offline_reason[0]
            "{0,-32} {1,-5} {2,-80} {3,-60}" -f $node_name, $node_active, $node_offline_reason[0], $assignedLabel | Write-Host -ForegroundColor "Red"
            $offline++
        } else {
            $node_active = "true"
            $getxml.computerSet.computer[$flag].offline = $node_active
            "{0,-32} {1,-5} {2,-80} {3,-60}" -f $node_name, $node_active, "", $assignedLabel | Write-Host -ForegroundColor "Green"
            $online++
        }
        $getxml.computerSet.computer[$flag].description = $assignedLabel
        $all_info += $item
        $flag++
    }
    Write-Host "`nAll node Count: $($getxml.computerSet.computer.Count)"
    Write-Host "Count of offline: $offline`nCount of online: $online`noutput.html full url: '$pwd\output.html'"

    "All node Count: $($getxml.computerSet.computer.Count)" | Out-File "$pwd\output.xml"
    "Count of offline: $offline" | Out-File "$pwd\output.xml" -Append
    "Count of online: $online" | Out-File "$pwd\output.xml" -Append
    "output.html full url: '$pwd\output.html'$n" | Out-File "$pwd\output.xml" -Append

    $header = @"
<style>
Body{background-color:white;font-family:Arial;font-size:10pt;}
Table{border-width: 1px; border-style: solid; border-color: black; border-collapse: collapse;}
TH{border-width: 1px; padding: 2px; border-style: solid; border-color: black; background-color: #cccccc;}
TD{border-width: 1px; padding: 5px; border-style: solid; border-color: black; background-color: white;}
</style>
"@
    $get_output_file = Get-Content "$pwd\output.xml"
    $fileLine = @()
    Foreach ($line in $get_output_file) {
        $myObject = New-Object -TypeName PSObject
        Add-Member -InputObject $myObject -Type NoteProperty -Name HealthCheck -Value $line
        $fileLine += $myObject
    }
    $all_info | ConvertTo-Html -Property displayName, $rename_offline_column, offlineCauseReason, $rename_label_column -Head $header | Out-File "$pwd\output.html"
    $fileLine | ConvertTo-Html -Property @{Expression="HealthCheck"; Label="===== Test result information =====" } | Out-File "$pwd\output.html" -Append

    rm "$pwd\get_node_info.xml", "$pwd\output.xml"
}
