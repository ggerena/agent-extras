[CmdletBinding()]
param(
    [switch]$CheckOnly,
    [switch]$IncludeBuzz,
    [string]$BuzzRepo = (Join-Path $env:USERPROFILE "Code\buzz"),
    [string]$BuzzComposeProject = "buzz",
    [string]$GrokRepairScript = (Join-Path $env:USERPROFILE ".agents\skills\revisa-grok\scripts\asegura-grok.ps1"),
    [string]$GrokAuditScript = (Join-Path $env:USERPROFILE ".agents\skills\revisa-grok\scripts\revisa-grok.ps1")
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

function Require-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "No se encontro el comando requerido: $Name"
    }
}

function Invoke-Checked {
    param(
        [string]$Command,
        [string[]]$Arguments = @()
    )
    $previousEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $Command @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "$Command termino con codigo $LASTEXITCODE"
        }
    }
    finally {
        $ErrorActionPreference = $previousEap
    }
}

function Compare-SemVer {
    param([string]$Left, [string]$Right)
    try {
        $leftVersion = [System.Management.Automation.SemanticVersion]::Parse($Left)
        $rightVersion = [System.Management.Automation.SemanticVersion]::Parse($Right)
        return $leftVersion.CompareTo($rightVersion)
    }
    catch {
        return ([version]$Left).CompareTo([version]$Right)
    }
}

function Get-NpmGlobalVersion {
    param([string]$Package)
    $raw = (& npm list -g $Package --depth=0 --json 2>$null | Out-String)
    if (-not $raw.Trim()) { return $null }
    $data = $raw | ConvertFrom-Json
    if (-not $data.dependencies) { return $null }
    $property = $data.dependencies.PSObject.Properties[$Package]
    if ($property) { return [string]$property.Value.version }
    return $null
}

function Get-OpenCodeMajorVersion {
    $raw = [string]((& opencode --version) | Select-Object -First 1)
    if ($LASTEXITCODE -ne 0 -or $raw -notmatch '(?:^|\s)v?(\d+)\.\d+\.\d+') {
        throw "No se pudo consultar la version de OpenCode"
    }
    return [int]$Matches[1]
}

function Update-NpmPackage {
    param([string]$Package)
    $installed = Get-NpmGlobalVersion $Package
    $latest = [string]((& npm view $Package version) | Select-Object -First 1)
    if ($LASTEXITCODE -ne 0 -or -not $latest) {
        throw "No se pudo consultar la version de $Package"
    }
    $needsUpdate = -not $installed -or (Compare-SemVer $installed $latest) -lt 0
    Write-Output "npm ${Package}: instalado=$installed, latest=$latest, actualizar=$needsUpdate"
    if ($needsUpdate -and -not $CheckOnly) {
        Invoke-Checked npm @("install", "-g", "$Package@latest")
    }
}

function Get-BuzzDesktopVersion {
    $paths = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $entry = Get-ItemProperty $paths -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -eq "Buzz" } |
        Select-Object -First 1
    return [string]$entry.DisplayVersion
}

function Update-BuzzDesktop {
    $release = (& gh release view --repo block/buzz --json tagName,assets | Out-String) | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) { throw "No se pudo consultar el release de Buzz" }
    $latest = ([string]$release.tagName) -replace '^desktop-v', ''
    $installed = Get-BuzzDesktopVersion
    $needsUpdate = -not $installed -or (Compare-SemVer $installed $latest) -lt 0
    Write-Output "Buzz Desktop: instalado=$installed, latest=$latest, actualizar=$needsUpdate"
    if (-not $needsUpdate -or $CheckOnly) { return }

    $asset = $release.assets |
        Where-Object { $_.name -match '^Buzz_.+_x64-setup.*\.exe$' } |
        Select-Object -First 1
    if (-not $asset -or -not $asset.digest) {
        throw "El release no contiene un instalador x64 con digest"
    }
    $installer = Join-Path $env:TEMP $asset.name
    if (-not (Test-Path -LiteralPath $installer)) {
        Invoke-Checked gh @("release", "download", $release.tagName, "--repo", "block/buzz", "--pattern", $asset.name, "--dir", $env:TEMP)
    }
    $actualDigest = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant()
    $expectedDigest = ([string]$asset.digest) -replace '^sha256:', ''
    if ($actualDigest -ne $expectedDigest) {
        throw "El SHA-256 del instalador de Buzz no coincide con el release oficial"
    }
    $process = Start-Process -FilePath $installer -ArgumentList "/S" -Wait -PassThru -WindowStyle Hidden
    if ($process.ExitCode -ne 0) { throw "El instalador de Buzz termino con codigo $($process.ExitCode)" }
}

function Test-DockerReady {
    $previousEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        docker info *> $null
        return ($LASTEXITCODE -eq 0)
    }
    finally {
        $ErrorActionPreference = $previousEap
    }
}

function Ensure-Docker {
    if (Test-DockerReady) { return }
    if ($CheckOnly) { throw "Docker Desktop no esta iniciado" }
    $candidates = @(
        "C:\Program Files\Docker\Docker\Docker Desktop.exe",
        (Join-Path $env:LOCALAPPDATA "Docker\Docker Desktop.exe")
    )
    $executable = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $executable) { throw "No se encontro Docker Desktop" }
    Start-Process -FilePath $executable -WindowStyle Hidden
    $deadline = (Get-Date).AddSeconds(120)
    do {
        Start-Sleep -Seconds 3
        if (Test-DockerReady) { return }
    } while ((Get-Date) -lt $deadline)
    throw "Docker Desktop no quedo listo dentro de 120 segundos"
}

function Update-BuzzRelay {
    if (-not (Test-Path -LiteralPath $BuzzRepo)) { throw "No existe el repositorio Buzz: $BuzzRepo" }
    $compose = Join-Path $BuzzRepo "deploy\compose\compose.yml"
    if (-not (Test-Path -LiteralPath $compose)) { throw "No existe el compose de Buzz" }

    $dirty = @(& git -C $BuzzRepo status --porcelain)
    Invoke-Checked git @("-C", $BuzzRepo, "fetch", "origin", "main", "--quiet")
    $local = [string]((& git -C $BuzzRepo rev-parse HEAD) | Select-Object -First 1)
    $remote = [string]((& git -C $BuzzRepo rev-parse origin/main) | Select-Object -First 1)
    Write-Output "Buzz repo: local=$local, remote=$remote, limpio=$($dirty.Count -eq 0)"
    if ($local -ne $remote -and $dirty.Count -gt 0) {
        throw "Buzz tiene cambios locales; no se hara pull ni se descartara nada"
    }
    if ($local -ne $remote -and -not $CheckOnly) {
        Invoke-Checked git @("-C", $BuzzRepo, "pull", "--ff-only", "origin", "main")
    }
    if ($CheckOnly) { return }

    Ensure-Docker
    Push-Location $BuzzRepo
    try {
        Invoke-Checked docker @("compose", "-p", $BuzzComposeProject, "-f", $compose, "pull", "relay")
        Invoke-Checked docker @("compose", "-p", $BuzzComposeProject, "-f", $compose, "up", "-d")
        $deadline = (Get-Date).AddSeconds(90)
        $previousEap = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            do {
                $health = [string]((& docker inspect "${BuzzComposeProject}-relay-1" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}') | Select-Object -First 1)
                if ($health -eq "healthy") { break }
                Start-Sleep -Seconds 2
            } while ((Get-Date) -lt $deadline)
        }
        finally {
            $ErrorActionPreference = $previousEap
        }
        if ($health -ne "healthy") { throw "El relay de Buzz no alcanzo estado healthy" }
    }
    finally {
        Pop-Location
    }
}

function Get-WingetTable {
    param([string[]]$Arguments)
    $previousEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $lines = @(& winget @Arguments)
    }
    finally {
        $ErrorActionPreference = $previousEap
    }

    $headerIndex = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^Name\s+Id\s+Version') {
            $headerIndex = $i
            break
        }
    }
    if ($headerIndex -lt 0) { return @() }

    $header = $lines[$headerIndex]
    $columnNames = @("Name", "Id", "Version", "Available", "Source")
    $columns = @()
    foreach ($columnName in $columnNames) {
        $start = $header.IndexOf($columnName)
        if ($start -ge 0) {
            $columns += [pscustomobject]@{ Name = $columnName; Start = $start }
        }
    }
    $columns = @($columns | Sort-Object Start)
    $rows = @()
    for ($i = $headerIndex + 2; $i -lt $lines.Count; $i++) {
        $line = [string]$lines[$i]
        if (-not $line.Trim()) { continue }
        if ($line -match 'upgrades available') { continue }
        $row = [ordered]@{}
        for ($c = 0; $c -lt $columns.Count; $c++) {
            $start = $columns[$c].Start
            if ($start -ge $line.Length) {
                $row[$columns[$c].Name] = ""
                continue
            }
            $length = if ($c -lt $columns.Count - 1) {
                $columns[$c + 1].Start - $start
            }
            else {
                $line.Length - $start
            }
            $take = [Math]::Min($length, $line.Length - $start)
            $row[$columns[$c].Name] = $line.Substring($start, $take).Trim()
        }
        $rows += [pscustomobject]$row
    }
    return $rows
}

function Get-WingetPackages {
    param(
        [Parameter(Mandatory = $true)][string]$Id
    )
    return @(Get-WingetTable @(
            "list",
            "--id", $Id,
            "--exact",
            "--accept-source-agreements",
            "--disable-interactivity"
        ) | Where-Object { $_.Id -eq $Id })
}

function Invoke-WingetUpgrade {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [string]$Version,
        [string]$Source
    )
    $arguments = @(
        "upgrade",
        "--id", $Id,
        "--exact",
        "--silent",
        "--accept-package-agreements",
        "--accept-source-agreements",
        "--disable-interactivity"
    )
    if ($Version) { $arguments += @("--version", $Version) }
    if ($Source) { $arguments += @("--source", $Source) }

    $previousEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & winget @arguments
        $code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousEap
    }
    # 0 = ok; -1978335189 = no hay upgrade aplicable
    if ($code -eq 0 -or $code -eq -1978335189) { return }
    throw "winget upgrade $Id termino con codigo $code"
}

function Update-DesktopApps {
    Write-Output "=== Actualizar desktops ==="
    $previousEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & winget source update --disable-interactivity *> $null
    }
    finally {
        $ErrorActionPreference = $previousEap
    }

    $targets = @(
        [pscustomobject]@{ Name = "ChatGPT Desktop"; Id = "9PLM9XGG6VKS"; Source = "msstore" },
        [pscustomobject]@{ Name = "Claude Desktop"; Id = "Anthropic.Claude"; Source = "winget" },
        [pscustomobject]@{ Name = "OpenCode Desktop"; Id = "SST.OpenCodeDesktop"; Source = "winget" }
    )

    foreach ($target in $targets) {
        $packages = @(Get-WingetPackages -Id $target.Id)
        if ($packages.Count -eq 0) {
            Write-Output "$($target.Name): no instalado"
            continue
        }

        $upgradable = @($packages | Where-Object { $_.Available -and ((Compare-SemVer $_.Version $_.Available) -lt 0) })
        foreach ($package in $packages) {
            $available = if ($package.Available) { $package.Available } else { $package.Version }
            $needsUpdate = [bool]($package.Available) -and ((Compare-SemVer $package.Version $package.Available) -lt 0)
            Write-Output "$($target.Name): instalado=$($package.Version) ($($package.Name)), latest=$available, actualizar=$needsUpdate"
        }
        if ($upgradable.Count -eq 0 -or $CheckOnly) { continue }

        $latest = ($upgradable | Sort-Object { $_.Available } -Descending | Select-Object -First 1).Available
        try {
            Invoke-WingetUpgrade -Id $target.Id -Version $latest -Source $target.Source
        }
        catch {
            Write-Output "$($target.Name): no se pudo actualizar con la app abierta. $($_.Exception.Message)"
        }
    }
}

function Get-DesktopVersionSummary {
    $lines = @()
    $map = @(
        [pscustomobject]@{ Name = "ChatGPT Desktop"; Id = "9PLM9XGG6VKS" },
        [pscustomobject]@{ Name = "Claude Desktop"; Id = "Anthropic.Claude" },
        [pscustomobject]@{ Name = "OpenCode Desktop"; Id = "SST.OpenCodeDesktop" }
    )
    foreach ($item in $map) {
        $packages = @(Get-WingetPackages -Id $item.Id)
        if ($packages.Count -eq 0) {
            $lines += "$($item.Name): no instalado"
            continue
        }
        foreach ($package in $packages) {
            $lines += "$($item.Name): $($package.Version) ($($package.Name))"
        }
    }
    return $lines
}

function Test-NvidiaCatalog {
    if (-not $env:NVIDIA_API_KEY) {
        Write-Output "NVIDIA/OpenCode: omitido porque NVIDIA_API_KEY no esta definida"
        return
    }
    $openCodeMajorVersion = Get-OpenCodeMajorVersion
    if ($openCodeMajorVersion -lt 2) {
        Invoke-Checked opencode @("debug", "config") *> $null
    }
    $headers = @{ Authorization = "Bearer $env:NVIDIA_API_KEY" }
    $api = @((Invoke-RestMethod -Uri "https://integrate.api.nvidia.com/v1/models" -Headers $headers -Method Get -TimeoutSec 30).data.id | Sort-Object -Unique)
    $arguments = if ($openCodeMajorVersion -ge 2) { @("models", "--standalone") } else { @("models", "nvidia") }
    $models = @(& opencode @arguments 2>$null)
    if ($LASTEXITCODE -ne 0) { throw "No se pudo consultar el catalogo de OpenCode" }
    $visible = @($models | Where-Object { $_ -match '^nvidia/' } | ForEach-Object { $_ -replace '^nvidia/', '' } | Sort-Object -Unique)
    $difference = @(Compare-Object $api $visible)
    Write-Output "NVIDIA/OpenCode: api=$($api.Count), visible=$($visible.Count), diferencias=$($difference.Count)"
    if ($difference.Count -gt 0) { throw "El catalogo NVIDIA de OpenCode no coincide con la API" }
}

$requiredCommands = @("codex", "claude", "opencode", "grok", "npm", "winget")
if ($IncludeBuzz) { $requiredCommands += @("gh", "git", "docker") }
foreach ($command in $requiredCommands) { Require-Command $command }

Write-Output "=== Actualizar agentes ==="
if ($CheckOnly) {
    Invoke-Checked grok @("update", "--check", "--json")
}
else {
    Invoke-Checked grok @("update", "--stable")
    if (-not (Test-Path -LiteralPath $GrokRepairScript)) {
        throw "No se encontro la reparacion de privacidad de Grok: $GrokRepairScript"
    }
    & $GrokRepairScript
    if ($LASTEXITCODE -ne 0) { throw "No se pudieron restaurar los bloqueos locales de Grok" }
    Invoke-Checked codex @("update")
    Invoke-Checked claude @("update")
}

$openCodeMajorVersion = Get-OpenCodeMajorVersion
$openCodeV2Version = Get-NpmGlobalVersion "@opencode/cli"
$openCodePackage = if ($openCodeMajorVersion -ge 2 -or $openCodeV2Version) { "@opencode/cli" } else { "opencode-ai" }
if ($openCodePackage -eq "opencode-ai") {
    Write-Output "OpenCode V1: se conserva esta version mayor; migrar a V2 requiere opencode upgrade --major."
}
$npmPackages = @(
    $openCodePackage,
    "@agentclientprotocol/claude-agent-acp",
    "@agentclientprotocol/codex-acp"
)
foreach ($package in $npmPackages) { Update-NpmPackage $package }

Update-DesktopApps

if ($IncludeBuzz) {
    Write-Output "=== Actualizar Buzz ==="
    Update-BuzzDesktop
    Update-BuzzRelay
}
else {
    Write-Output "Buzz omitido: Desktop, repositorio y relay conservados. Usar -IncludeBuzz solo por pedido explicito."
}

Write-Output "=== Verificaciones ==="
if (Test-Path -LiteralPath $GrokAuditScript) {
    & $GrokAuditScript -Json
    if ($LASTEXITCODE -ne 0) { throw "La auditoria de Grok no termino en OK" }
}
else {
    throw "No se encontro la auditoria de Grok: $GrokAuditScript"
}
Test-NvidiaCatalog

Write-Output "=== Versiones finales ==="
& codex --version
& claude --version
& opencode --version
& grok --version
if ($IncludeBuzz) { Write-Output "Buzz Desktop: $(Get-BuzzDesktopVersion)" }
Get-DesktopVersionSummary | ForEach-Object { Write-Output $_ }
if ($CheckOnly) {
    Write-Output "Comprobacion integral completada."
}
else {
    Write-Output "Actualizacion integral completada."
}

