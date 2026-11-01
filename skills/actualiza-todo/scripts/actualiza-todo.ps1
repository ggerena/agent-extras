[CmdletBinding()]
param(
    [switch]$CheckOnly,
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

$requiredCommands = @("codex", "claude", "opencode", "grok", "npm", "winget")
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

Write-Output "=== Verificaciones ==="
if (Test-Path -LiteralPath $GrokAuditScript) {
    & $GrokAuditScript -Json
    if ($LASTEXITCODE -ne 0) { throw "La auditoria de Grok no termino en OK" }
}
else {
    throw "No se encontro la auditoria de Grok: $GrokAuditScript"
}

Write-Output "=== Versiones finales ==="
& codex --version
& claude --version
& opencode --version
& grok --version
Get-DesktopVersionSummary | ForEach-Object { Write-Output $_ }
if ($CheckOnly) {
    Write-Output "Comprobacion integral completada."
}
else {
    Write-Output "Actualizacion integral completada."
}
