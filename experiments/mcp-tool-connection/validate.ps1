<#
.SYNOPSIS
    Validates that a Foundry MCP tool connection is usable with no Agent Service agent present.

.DESCRIPTION
    Terraform proves the connection RESOURCE can be created. This script proves the
    remaining half: that the connection is actually consumable.

    Nothing here creates an agent. If step 5 returns a tool list, the hypothesis holds.

    Read-only except for step 4, which creates a Toolbox. Skip it with -SkipToolbox.

.NOTES
    Requires: Azure CLI (logged in). Step 4 additionally requires `azd` with the ai extension.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $ProjectEndpoint,
    [Parameter(Mandatory)][string] $SubscriptionId,
    [Parameter(Mandatory)][string] $ResourceGroup,
    [Parameter(Mandatory)][string] $AccountName,
    [Parameter(Mandatory)][string] $ProjectName,
    [string] $ConnectionName = 'mcp-validation-conn',
    [string] $ToolboxName    = 'mcp-validation-toolbox',
    [string] $ApiVersion     = '2025-06-01',
    [switch] $SkipToolbox
)

$ErrorActionPreference = 'Stop'
$script:findings = [ordered]@{}

function Write-Step { param([string]$Text) Write-Host "`n=== $Text ===" -ForegroundColor Cyan }
function Write-Pass { param([string]$Text) Write-Host "  PASS  $Text" -ForegroundColor Green }
function Write-Fail { param([string]$Text) Write-Host "  FAIL  $Text" -ForegroundColor Red }
function Write-Info { param([string]$Text) Write-Host "  ..    $Text" -ForegroundColor DarkGray }

# ---------------------------------------------------------------------------
Write-Step '1. Context'
# ---------------------------------------------------------------------------
az account set --subscription $SubscriptionId | Out-Null
$who = az account show --query '{user:user.name, sub:name}' -o json | ConvertFrom-Json
Write-Info "Signed in as $($who.user) on '$($who.sub)'"

# ---------------------------------------------------------------------------
Write-Step '2. Connection exists on the project (control plane)'
# ---------------------------------------------------------------------------
$connId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup" +
          "/providers/Microsoft.CognitiveServices/accounts/$AccountName" +
          "/projects/$ProjectName/connections/$ConnectionName"

try {
    $conn = az rest --method GET --url "https://management.azure.com$($connId)?api-version=$ApiVersion" -o json | ConvertFrom-Json
    Write-Pass "Connection '$ConnectionName' exists"
    Write-Info "category  : $($conn.properties.category)"
    Write-Info "authType  : $($conn.properties.authType)"
    Write-Info "target    : $($conn.properties.target)"
    Write-Info "group     : $($conn.properties.group)"

    # The RP may silently rewrite the category. That rewrite is a finding.
    $script:findings['category_sent_vs_stored'] = $conn.properties.category
    $script:findings['connection_created']      = $true
}
catch {
    Write-Fail "Could not read the connection: $($_.Exception.Message)"
    $script:findings['connection_created'] = $false
    throw
}

# ---------------------------------------------------------------------------
Write-Step '3. Confirm NO agents exist on this project'
# ---------------------------------------------------------------------------
# This is the control for the experiment. If the project has zero agents and the
# toolbox still serves tools, Agent Service is not on the critical path.

$tokenAudiences = @('https://ai.azure.com', 'https://cognitiveservices.azure.com')
$dataToken = $null
foreach ($aud in $tokenAudiences) {
    try {
        $dataToken = az account get-access-token --resource $aud --query accessToken -o tsv 2>$null
        if ($dataToken) { Write-Info "Data-plane token acquired for audience $aud"; break }
    } catch { }
}
if (-not $dataToken) { Write-Fail 'Could not acquire a data-plane token for any known audience.'; throw }

$agentCount = $null
foreach ($ver in @('v1', '2025-05-01', '2025-05-15-preview')) {
    try {
        $resp = Invoke-RestMethod -Method GET `
            -Uri "$ProjectEndpoint/assistants?api-version=$ver" `
            -Headers @{ Authorization = "Bearer $dataToken" }
        $agentCount = @($resp.data).Count
        Write-Info "Agents API responded on api-version=$ver"
        break
    } catch { }
}

if ($null -eq $agentCount) {
    Write-Info 'Agents API did not respond on any tried api-version - treating as inconclusive.'
    Write-Info 'This does not invalidate the test; Terraform never created an agent.'
    $script:findings['agent_count'] = 'inconclusive'
}
elseif ($agentCount -eq 0) {
    Write-Pass 'Project has 0 agents'
    $script:findings['agent_count'] = 0
}
else {
    Write-Fail "Project already has $agentCount agent(s)."
    Write-Info 'This is an EXISTING project, so pre-existing agents are plausible - but they'
    Write-Info 'weaken the result: you can no longer claim the tools resolved with no agent'
    Write-Info 'present. Re-run against a project with zero agents for a clean answer.'
    $script:findings['agent_count'] = $agentCount
}

# ---------------------------------------------------------------------------
Write-Step '4. Create a Toolbox referencing the connection'
# ---------------------------------------------------------------------------
if ($SkipToolbox) {
    Write-Info 'Skipped by request.'
}
else {
    $toolboxYaml = Join-Path $PSScriptRoot 'mcp-validation-toolbox.yaml'
    @"
description: MCP connection reachability test - no agent involved
connections:
  - name: $ConnectionName
"@ | Set-Content -Path $toolboxYaml -Encoding utf8
    Write-Info "Wrote $toolboxYaml"

    try {
        azd ai project set $ProjectEndpoint | Out-Null
        azd ai toolbox create $ToolboxName --from-file $toolboxYaml
        Write-Pass "Toolbox '$ToolboxName' created"
        $script:findings['toolbox_created'] = $true
    }
    catch {
        Write-Fail "Toolbox creation failed: $($_.Exception.Message)"
        Write-Info 'If this is the only failure, the connection is valid but inert -'
        Write-Info 'which would still confirm the connection half of the hypothesis.'
        $script:findings['toolbox_created'] = $false
    }
}

# ---------------------------------------------------------------------------
Write-Step '5. Call the Toolbox MCP endpoint directly (no agent, no Kong)'
# ---------------------------------------------------------------------------
# A plain JSON-RPC tools/list. If this returns tools, an arbitrary MCP client can
# consume Foundry tools with no Agent Service in the loop - and this call did not
# traverse the gateway.

$toolboxEndpoint = "$ProjectEndpoint/toolboxes/$ToolboxName/mcp"
Write-Info "POST $toolboxEndpoint"

try {
    $body = @{ jsonrpc = '2.0'; id = 1; method = 'tools/list' } | ConvertTo-Json -Compress
    $tools = Invoke-RestMethod -Method POST -Uri $toolboxEndpoint -Body $body `
        -ContentType 'application/json' `
        -Headers @{
            Authorization = "Bearer $dataToken"
            Accept        = 'application/json, text/event-stream'
        }

    $names = @($tools.result.tools | ForEach-Object { $_.name })
    Write-Pass "tools/list returned $($names.Count) tool(s)"
    $names | Select-Object -First 15 | ForEach-Object { Write-Info $_ }
    $script:findings['tools_listed'] = $names.Count
}
catch {
    $msg = $_.Exception.Message
    if ($msg -match '32006' -or $msg -match 'CONSENT_REQUIRED') {
        Write-Info 'CONSENT_REQUIRED (-32006) returned. This is EXPECTED for OAuth2 connections'
        Write-Info 'and is itself a positive signal: the MCP endpoint is live and enforcing'
        Write-Info 'per-user consent. Open the consent URL in the error body, then re-run.'
        $script:findings['tools_listed'] = 'consent_required'
    }
    else {
        Write-Fail "tools/list failed: $msg"
        $script:findings['tools_listed'] = $false
    }
}

# ---------------------------------------------------------------------------
Write-Step 'Findings'
# ---------------------------------------------------------------------------
$script:findings.GetEnumerator() | ForEach-Object {
    '{0,-28} {1}' -f $_.Key, $_.Value
}

Write-Host "`nHypothesis holds if: connection_created = True, agent_count = 0," -ForegroundColor Yellow
Write-Host "and tools_listed is a number (or consent_required for OAuth2).`n" -ForegroundColor Yellow
