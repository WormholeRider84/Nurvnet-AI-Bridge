param(
    [string]$InstallDir = $env:NURVNET_INSTALL_DIR
)

$ErrorActionPreference = 'Stop'
$Repository = 'WormholeRider84/Nurvnet-AI-Bridge'
$Asset = 'Nurvnet-AI-Bridge.zip'
$ManagerUrl = 'https://github.com/router-for-me/Cli-Proxy-API-Management-Center/releases/download/v1.21.4/management.html'
$ManagerSha256 = '1d885552cc2d12b98613f31f2bc326e321c81dcbb792afb1e0b0066ecb74028e'

function New-HexSecret {
    $bytes = New-Object byte[] 32
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    return ($bytes | ForEach-Object { $_.ToString('x2') }) -join ''
}

function Read-EnvFile([string]$Path) {
    $values = @{}
    Get-Content $Path | ForEach-Object {
        if ($_ -match '^([^#=]+)=(.*)$') { $values[$matches[1].Trim()] = $matches[2].Trim() }
    }
    return $values
}

function Wait-Url([string]$Name, [string]$Url, [int]$Attempts) {
    for ($i = 0; $i -lt $Attempts; $i++) {
        try {
            Invoke-WebRequest -UseBasicParsing -Uri $Url -TimeoutSec 3 | Out-Null
            Write-Host "$Name is ready."
            return
        } catch {
            Start-Sleep -Seconds 2
        }
    }
    docker compose logs --tail=100
    throw "$Name did not become ready."
}

$localRoot = $PSScriptRoot
if (-not $localRoot -or -not (Test-Path (Join-Path $localRoot 'compose.yaml'))) {
    if (-not $InstallDir) { $InstallDir = Join-Path $env:LOCALAPPDATA 'Nurvnet-AI-Bridge' }
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("nurvnet-ai-bridge-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Force -Path $tempRoot, $InstallDir | Out-Null
    try {
        $releaseUrl = "https://github.com/$Repository/releases/latest/download"
        $archive = Join-Path $tempRoot $Asset
        $checksumFile = "$archive.sha256"
        Write-Host 'Downloading Nurvnet-AI-Bridge...'
        Invoke-WebRequest -UseBasicParsing -Uri "$releaseUrl/$Asset" -OutFile $archive
        Invoke-WebRequest -UseBasicParsing -Uri "$releaseUrl/$Asset.sha256" -OutFile $checksumFile
        $expected = ((Get-Content $checksumFile -First 1) -split '\s+')[0].ToLowerInvariant()
        $actual = (Get-FileHash -Algorithm SHA256 $archive).Hash.ToLowerInvariant()
        if ($actual -ne $expected) { throw 'Release checksum verification failed.' }

        $expanded = Join-Path $tempRoot 'expanded'
        Expand-Archive -Path $archive -DestinationPath $expanded -Force
        $source = Get-ChildItem -Directory $expanded | Select-Object -First 1
        if (-not $source) { throw 'Release archive has an unexpected layout.' }
        Get-ChildItem -Force $source.FullName | Copy-Item -Destination $InstallDir -Recurse -Force
    } finally {
        if (Test-Path $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
    }
    $root = $InstallDir
} else {
    $root = $localRoot
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw 'Docker Desktop is required: https://docs.docker.com/desktop/setup/install/windows-install/'
}
docker compose version | Out-Null
docker info | Out-Null

$runtimeDir = Join-Path $root '.runtime'
$configDir = Join-Path $root 'config'
$directories = @(
    $runtimeDir,
    (Join-Path $root 'data/open-webui'),
    (Join-Path $root 'data/cliproxyapi/auths'),
    (Join-Path $root 'data/cliproxyapi/logs'),
    (Join-Path $root 'data/cliproxyapi/static')
)
New-Item -ItemType Directory -Force -Path $directories | Out-Null

$envFile = Join-Path $root '.env'
if (-not (Test-Path $envFile)) { Copy-Item (Join-Path $root '.env.example') $envFile }
$settings = Read-EnvFile $envFile
$webuiPort = if ($settings.WEBUI_PORT) { $settings.WEBUI_PORT } else { '3000' }
$proxyPort = if ($settings.CLIPROXY_PORT) { $settings.CLIPROXY_PORT } else { '8317' }

$secretsFile = Join-Path $runtimeDir 'secrets.env'
if (-not (Test-Path $secretsFile)) {
    @(
        "CLIPROXY_API_KEY=$(New-HexSecret)"
        "CLIPROXY_MANAGEMENT_KEY=$(New-HexSecret)"
        "WEBUI_SECRET_KEY=$(New-HexSecret)"
    ) | Set-Content -Encoding ascii $secretsFile
}
$secrets = Read-EnvFile $secretsFile

$managerFile = Join-Path $root 'data/cliproxyapi/static/management.html'
$managerValid = (Test-Path $managerFile) -and ((Get-FileHash -Algorithm SHA256 $managerFile).Hash.ToLowerInvariant() -eq $ManagerSha256)
if (-not $managerValid) {
    $managerTemp = "$managerFile.tmp"
    Invoke-WebRequest -UseBasicParsing -Uri $ManagerUrl -OutFile $managerTemp
    if ((Get-FileHash -Algorithm SHA256 $managerTemp).Hash.ToLowerInvariant() -ne $ManagerSha256) {
        Remove-Item -LiteralPath $managerTemp -Force
        throw 'Management center checksum verification failed.'
    }
    Move-Item -LiteralPath $managerTemp -Destination $managerFile -Force
}

$proxyConfig = Join-Path $configDir 'cliproxyapi.yaml'
if (-not (Test-Path $proxyConfig)) {
    $template = Get-Content -Raw (Join-Path $configDir 'cliproxyapi.example.yaml')
    $template = $template.Replace('__CLIPROXY_API_KEY__', $secrets.CLIPROXY_API_KEY)
    $template = $template.Replace('__CLIPROXY_MANAGEMENT_KEY__', $secrets.CLIPROXY_MANAGEMENT_KEY)
    $template | Set-Content -Encoding utf8 $proxyConfig
}

$webuiConfig = Join-Path $runtimeDir 'open-webui.env'
if (-not (Test-Path $webuiConfig)) {
    $template = Get-Content -Raw (Join-Path $configDir 'open-webui.env.example')
    $template = $template.Replace('__WEBUI_URL__', "http://localhost:$webuiPort")
    $template = $template.Replace('__WEBUI_SECRET_KEY__', $secrets.WEBUI_SECRET_KEY)
    $template = $template.Replace('__CLIPROXY_API_KEY__', $secrets.CLIPROXY_API_KEY)
    $template | Set-Content -Encoding ascii $webuiConfig
}

Push-Location $root
try {
    docker compose pull
    docker compose up -d
    Wait-Url 'CLIProxyAPI' "http://localhost:$proxyPort/healthz" 60
    Wait-Url 'Open WebUI' "http://localhost:$webuiPort/health" 180
} finally {
    Pop-Location
}

$workspaceUrl = "http://localhost:$webuiPort"
$setupUrl = "http://localhost:$proxyPort/management.html#/ai-providers"
Write-Host ''
Write-Host 'Nurvnet-AI-Bridge is ready.'
Write-Host "Workspace: $workspaceUrl"
Write-Host "Provider setup: $setupUrl"
Write-Host "Management key: $($secrets.CLIPROXY_MANAGEMENT_KEY)"
Start-Process $workspaceUrl
Start-Process $setupUrl
