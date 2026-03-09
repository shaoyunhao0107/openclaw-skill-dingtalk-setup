# DingTalk Channel Auto Setup Script
# Usage: .\auto-setup.ps1 -ClientId "xxx" -ClientSecret "xxx"

param(
    [Parameter(Mandatory=$true)]
    [string]$ClientId,
    
    [Parameter(Mandatory=$true)]
    [string]$ClientSecret,
    
    [string]$RobotCode = "",
    [string]$CorpId = "",
    [string]$AgentId = "",
    [string]$ProxyUrl = "http://127.0.0.1:7897",
    [string]$NpmRegistry = "https://registry.npmmirror.com",
    [switch]$UseProxy = $false
)

Write-Host "=== DingTalk Channel Auto Setup ===" -ForegroundColor Cyan

# Set proxy if needed
if ($UseProxy) {
    $env:HTTP_PROXY = $ProxyUrl
    $env:HTTPS_PROXY = $ProxyUrl
    Write-Host "Proxy enabled: $ProxyUrl" -ForegroundColor Yellow
}

# Set npm registry
$env:NPM_CONFIG_REGISTRY = $NpmRegistry
Write-Host "NPM Registry: $NpmRegistry" -ForegroundColor Yellow

# Install plugin
Write-Host "`nInstalling @soimy/dingtalk plugin..." -ForegroundColor Yellow
openclaw plugins install @soimy/dingtalk

if ($LASTEXITCODE -ne 0) {
    Write-Host "Plugin installation failed!" -ForegroundColor Red
    exit 1
}

# Update openclaw.json
Write-Host "`nUpdating configuration..." -ForegroundColor Yellow
$configPath = "$env:USERPROFILE\.openclaw\openclaw.json"

if (-not (Test-Path $configPath)) {
    Write-Host "Config file not found: $configPath" -ForegroundColor Red
    exit 1
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json

# Add plugin to allowlist
if (-not $config.plugins) {
    $config | Add-Member -MemberType NoteProperty -Name "plugins" -Value @{
        enabled = $true
        allow = @("dingtalk")
    }
} else {
    if (-not $config.plugins.allow) {
        $config.plugins | Add-Member -MemberType NoteProperty -Name "allow" -Value @("dingtalk")
    } elseif ($config.plugins.allow -notcontains "dingtalk") {
        $config.plugins.allow += "dingtalk"
    }
    $config.plugins.enabled = $true
}

# Add channel configuration
if (-not $config.channels) {
    $config | Add-Member -MemberType NoteProperty -Name "channels" -Value @()
}

$dingtalkConfig = @{
    id = "dingtalk"
    plugin = "dingtalk"
    enabled = $true
    clientId = $ClientId
    clientSecret = $ClientSecret
    dm = "open"
    group = "open"
}

if ($RobotCode) { $dingtalkConfig.robotCode = $RobotCode }
if ($CorpId) { $dingtalkConfig.corpId = $CorpId }
if ($AgentId) { $dingtalkConfig.agentId = $AgentId }

# Remove existing dingtalk config and add new one
$config.channels = @($config.channels | Where-Object { $_.id -ne "dingtalk" })
$config.channels += $dingtalkConfig

# Save config
$config | ConvertTo-Json -Depth 10 | Set-Content $configPath

Write-Host "Configuration updated successfully!" -ForegroundColor Green

# Restart Gateway
Write-Host "`nRestarting OpenClaw Gateway..." -ForegroundColor Yellow
openclaw gateway restart

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n=== Setup Complete! ===" -ForegroundColor Green
    Write-Host "DingTalk channel is now configured and running." -ForegroundColor Green
    Write-Host "`nTest by sending a message to your DingTalk bot." -ForegroundColor Cyan
} else {
    Write-Host "`nGateway restart failed. Please check logs:" -ForegroundColor Red
    Write-Host "  openclaw logs gateway" -ForegroundColor Yellow
}
