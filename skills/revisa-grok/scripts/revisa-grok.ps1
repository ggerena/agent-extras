[CmdletBinding()]
param(
    [switch]$Json
)

$ErrorActionPreference = "Stop"

function Read-TomlBool {
    param(
        [string]$Path,
        [string]$Section,
        [string]$Key
    )

    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    $currentSection = ""
    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith("#")) {
            continue
        }
        if ($trimmed -match '^\[([^\]]+)\]$') {
            $currentSection = $Matches[1]
            continue
        }
        if ($currentSection -eq $Section -and $trimmed -match ('^' + [regex]::Escape($Key) + '\s*=\s*(true|false)\s*(?:#.*)?$')) {
            return [pscustomobject]@{
                Found = $true
                Value = ($Matches[1] -eq "true")
                Path = $Path
            }
        }
    }

    return $null
}

function Resolve-TomlBool {
    param(
        [array]$Layers,
        [string]$Section,
        [string]$Key
    )

    foreach ($layer in $Layers) {
        $setting = Read-TomlBool -Path $layer.Path -Section $Section -Key $Key
        if ($null -ne $setting) {
            return [pscustomobject]@{
                Found = $true
                Value = $setting.Value
                Path = $setting.Path
                Layer = $layer.Name
            }
        }
    }

    return [pscustomobject]@{
        Found = $false
        Value = $null
        Path = $null
        Layer = $null
    }
}

function Resolve-EffectiveBool {
    param(
        [array]$Layers,
        [string]$Section,
        [string]$Key,
        [string]$EnvironmentName
    )

    if ($EnvironmentName) {
        $raw = [Environment]::GetEnvironmentVariable($EnvironmentName, "Process")
        if ([string]::IsNullOrWhiteSpace($raw)) {
            $raw = [Environment]::GetEnvironmentVariable($EnvironmentName, "User")
        }
        if ($raw -match '^(?i:true|1|yes|on)$') {
            return [pscustomobject]@{ Found = $true; Value = $true; Path = $null; Layer = "environment" }
        }
        if ($raw -match '^(?i:false|0|no|off)$') {
            return [pscustomobject]@{ Found = $true; Value = $false; Path = $null; Layer = "environment" }
        }
    }

    return Resolve-TomlBool -Layers $Layers -Section $Section -Key $Key
}

function Parse-LogTimestamp {
    param([object]$Value)

    if ($null -eq $Value) {
        return $null
    }
    try {
        return ([datetimeoffset]::Parse([string]$Value)).UtcDateTime
    }
    catch {
        return $null
    }
}

$grokHome = Join-Path $HOME ".grok"
$programDataGrok = if ($env:ProgramData) { Join-Path $env:ProgramData "grok" } else { $null }

# Highest precedence first after environment variables, following Grok's general documented precedence.
$layers = @(
    [pscustomobject]@{ Name = "user-config"; Path = Join-Path $grokHome "config.toml" },
    [pscustomobject]@{ Name = "user-managed"; Path = Join-Path $grokHome "managed_config.toml" },
    [pscustomobject]@{ Name = "system-managed"; Path = if ($programDataGrok) { Join-Path $programDataGrok "managed_config.toml" } else { $null } },
    [pscustomobject]@{ Name = "user-requirements"; Path = Join-Path $grokHome "requirements.toml" },
    [pscustomobject]@{ Name = "system-requirements"; Path = if ($programDataGrok) { Join-Path $programDataGrok "requirements.toml" } else { $null } }
)

$codebaseGuard = Resolve-TomlBool -Layers $layers -Section "harness" -Key "disable_codebase_upload"
$traceGuard = Resolve-EffectiveBool -Layers $layers -Section "telemetry" -Key "trace_upload" -EnvironmentName "GROK_TELEMETRY_TRACE_UPLOAD"
$telemetryGuard = Resolve-EffectiveBool -Layers $layers -Section "features" -Key "telemetry" -EnvironmentName "GROK_TELEMETRY_ENABLED"
$mixpanelGuard = Resolve-EffectiveBool -Layers $layers -Section "telemetry" -Key "mixpanel_enabled" -EnvironmentName "GROK_TELEMETRY_MIXPANEL_ENABLED"
$otelGuard = Resolve-EffectiveBool -Layers $layers -Section "telemetry" -Key "otel_enabled" -EnvironmentName "GROK_EXTERNAL_OTEL"
$feedbackGuard = Resolve-EffectiveBool -Layers $layers -Section "features" -Key "feedback" -EnvironmentName "GROK_FEEDBACK_ENABLED"

$alerts = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()
$notes = [System.Collections.Generic.List[string]]::new()

if (-not $codebaseGuard.Found -or $codebaseGuard.Value -ne $true) {
    $alerts.Add("Falta disable_codebase_upload=true en la capa efectiva de configuracion.")
}
if (-not $traceGuard.Found -or $traceGuard.Value -ne $false) {
    $alerts.Add("Falta trace_upload=false en la capa efectiva de configuracion.")
}
if (-not $telemetryGuard.Found -or $telemetryGuard.Value -ne $false) {
    $alerts.Add("Falta telemetry=false en la capa efectiva de configuracion.")
}
if (-not $mixpanelGuard.Found -or $mixpanelGuard.Value -ne $false) {
    $alerts.Add("Falta mixpanel_enabled=false en la capa efectiva de configuracion.")
}
if (-not $otelGuard.Found -or $otelGuard.Value -ne $false) {
    $alerts.Add("Falta otel_enabled=false en la capa efectiva de configuracion.")
}
if (-not $feedbackGuard.Found -or $feedbackGuard.Value -ne $false) {
    $alerts.Add("Falta feedback=false en la capa efectiva de configuracion.")
}

$guardFiles = @($codebaseGuard.Path, $traceGuard.Path, $telemetryGuard.Path, $mixpanelGuard.Path, $otelGuard.Path, $feedbackGuard.Path) |
    Where-Object { $_ } |
    Sort-Object -Unique
$protectedSinceUtc = $null
if ($guardFiles.Count -gt 0) {
    $guardWriteTimes = @($guardFiles | ForEach-Object { (Get-Item -LiteralPath $_).LastWriteTimeUtc })
    $protectedSinceUtc = ($guardWriteTimes | Sort-Object -Descending | Select-Object -First 1)
}

$grokCommand = Get-Command grok -ErrorAction SilentlyContinue
$grokVersion = $null
$inspectOk = $false
if ($grokCommand) {
    try {
        $grokVersion = ((& $grokCommand.Source version 2>$null) | Select-Object -First 1)
        & $grokCommand.Source inspect --json *> $null
        $inspectOk = ($LASTEXITCODE -eq 0)
    }
    catch {
        $inspectOk = $false
    }
    if (-not $inspectOk) {
        $alerts.Add("Grok no pudo validar la configuracion con inspect --json.")
    }
}
else {
    $warnings.Add("No se encontro el ejecutable de Grok en PATH.")
}

$queuePath = Join-Path $grokHome "upload_queue"
$queueFiles = @()
if (Test-Path -LiteralPath $queuePath) {
    $queueFiles = @(Get-ChildItem -LiteralPath $queuePath -File -Recurse -Force -ErrorAction SilentlyContinue)
}
$queueBytes = 0
if ($queueFiles.Count -gt 0) {
    $measuredBytes = ($queueFiles | Measure-Object Length -Sum).Sum
    if ($null -ne $measuredBytes) {
        $queueBytes = [int64]$measuredBytes
    }
    $alerts.Add("La cola local contiene $($queueFiles.Count) archivo(s) y $queueBytes byte(s).")
}

$decisions = [System.Collections.Generic.List[object]]::new()
$repoEvents = [System.Collections.Generic.List[object]]::new()
$logPath = Join-Path $grokHome "logs\unified.jsonl"
if (Test-Path -LiteralPath $logPath) {
    foreach ($line in Get-Content -LiteralPath $logPath) {
        try {
            $row = $line | ConvertFrom-Json
        }
        catch {
            continue
        }

        if ($row.msg -eq "trace.upload.decision") {
            $decisions.Add([pscustomobject]@{
                TimestampUtc = Parse-LogTimestamp $row.ts
                Enabled = [bool]$row.ctx.uploads_enabled
                Reason = [string]$row.ctx.upload_reason
                RemoteTraceEnabled = $row.ctx.in_remote_trace_upload_enabled
            })
        }
        elseif ($row.msg -in @("repo_state.upload.start", "repo_state.upload.enqueued")) {
            $repoEvents.Add([pscustomobject]@{
                TimestampUtc = Parse-LogTimestamp $row.ts
                Message = [string]$row.msg
            })
        }
    }
}
else {
    $warnings.Add("No existe unified.jsonl; no se puede revisar el historial de decisiones.")
}

$latestDecision = $null
if ($decisions.Count -gt 0) {
    $latestDecision = $decisions |
        Where-Object { $null -ne $_.TimestampUtc } |
        Sort-Object TimestampUtc |
        Select-Object -Last 1

    if ($latestDecision -and $latestDecision.Enabled) {
        $alerts.Add("La decision de subida mas reciente tiene uploads_enabled=true.")
    }
}
elseif (Test-Path -LiteralPath $logPath) {
    $warnings.Add("El registro no contiene decisiones trace.upload.decision.")
}

$historicEnabled = @($decisions | Where-Object { $_.Enabled })
$lastHistoricEnabledUtc = $null
if ($historicEnabled.Count -gt 0) {
    $lastHistoricEnabledUtc = $historicEnabled |
        Where-Object { $null -ne $_.TimestampUtc } |
        Sort-Object TimestampUtc |
        Select-Object -Last 1 -ExpandProperty TimestampUtc
    $warnings.Add("Hay $($historicEnabled.Count) decision(es) historicas con subidas habilitadas; esto indica exposicion posible, no entrega completa probada.")
}

$enabledAfterProtection = @()
$repoAfterProtection = @()
if ($protectedSinceUtc) {
    $enabledAfterProtection = @($decisions | Where-Object { $_.Enabled -and $_.TimestampUtc -gt $protectedSinceUtc })
    $repoAfterProtection = @($repoEvents | Where-Object { $_.TimestampUtc -gt $protectedSinceUtc })

    if ($enabledAfterProtection.Count -gt 0) {
        $alerts.Add("Hay $($enabledAfterProtection.Count) decision(es) con subidas habilitadas despues de activar la proteccion local.")
    }
    if ($repoAfterProtection.Count -gt 0) {
        $alerts.Add("Hay $($repoAfterProtection.Count) evento(s) repo_state.upload despues de activar la proteccion local.")
    }
}
else {
    $warnings.Add("No se pudo establecer desde cuando estan activas las protecciones.")
}

$grokProcesses = @(Get-Process -Name grok -ErrorAction SilentlyContinue)
if ($grokProcesses.Count -gt 0) {
    $notes.Add("Grok esta ejecutandose en $($grokProcesses.Count) proceso(s); la auditoria no los cerro.")
}

$status = if ($alerts.Count -gt 0) {
    "ALERTA"
}
elseif (-not $grokCommand -or -not (Test-Path -LiteralPath $logPath)) {
    "INCIERTO"
}
else {
    "OK"
}

$result = [ordered]@{
    status = $status
    checked_at_utc = [datetime]::UtcNow.ToString("o")
    grok_version = $grokVersion
    config_parse_ok = $inspectOk
    protections = [ordered]@{
        disable_codebase_upload = $codebaseGuard.Value
        trace_upload = $traceGuard.Value
        telemetry = $telemetryGuard.Value
        mixpanel_enabled = $mixpanelGuard.Value
        otel_enabled = $otelGuard.Value
        feedback = $feedbackGuard.Value
        protected_since_utc = if ($protectedSinceUtc) { $protectedSinceUtc.ToString("o") } else { $null }
    }
    queue = [ordered]@{
        files = $queueFiles.Count
        bytes = $queueBytes
    }
    log = [ordered]@{
        decisions = $decisions.Count
        latest_uploads_enabled = if ($latestDecision) { $latestDecision.Enabled } else { $null }
        latest_decision_utc = if ($latestDecision) { $latestDecision.TimestampUtc.ToString("o") } else { $null }
        latest_reason = if ($latestDecision) { $latestDecision.Reason } else { $null }
        historic_enabled_count = $historicEnabled.Count
        last_historic_enabled_utc = if ($lastHistoricEnabledUtc) { $lastHistoricEnabledUtc.ToString("o") } else { $null }
        enabled_after_protection = $enabledAfterProtection.Count
        repo_events_after_protection = $repoAfterProtection.Count
    }
    running_processes = $grokProcesses.Count
    alerts = @($alerts)
    warnings = @($warnings)
    notes = @($notes)
    privacy = "No verificable completamente desde archivos locales. /privacy controla por separado los datos de programacion y la skill no cambia esa preferencia remota."
}

if ($Json) {
    [pscustomobject]$result | ConvertTo-Json -Depth 6
}
else {
    Write-Output "=== Revisa Grok ==="
    Write-Output "Estado: $status"
    Write-Output "Version: $grokVersion"
    Write-Output "Configuracion valida: $inspectOk"
    Write-Output "Protecciones: codebase=$($codebaseGuard.Value), trace_upload=$($traceGuard.Value), telemetry=$($telemetryGuard.Value), mixpanel=$($mixpanelGuard.Value), otel=$($otelGuard.Value), feedback=$($feedbackGuard.Value)"
    Write-Output "Cola: $($queueFiles.Count) archivo(s), $queueBytes byte(s)"
    if ($latestDecision) {
        Write-Output "Ultima decision: uploads_enabled=$($latestDecision.Enabled), razon=$($latestDecision.Reason), fecha_utc=$($latestDecision.TimestampUtc.ToString('o'))"
    }
    else {
        Write-Output "Ultima decision: no disponible"
    }
    Write-Output "Historico habilitado: $($historicEnabled.Count) decision(es)"
    Write-Output "Despues de la proteccion: $($enabledAfterProtection.Count) decision(es) habilitada(s), $($repoAfterProtection.Count) evento(s) de repositorio"

    foreach ($item in $alerts) {
        Write-Output "[ALERTA] $item"
    }
    foreach ($item in $warnings) {
        Write-Output "[AVISO] $item"
    }
    foreach ($item in $notes) {
        Write-Output "[INFO] $item"
    }
    Write-Output "[INFO] Privacidad remota: no verificable completamente desde archivos locales."
}

if ($status -eq "ALERTA") {
    exit 1
}
if ($status -eq "INCIERTO") {
    exit 2
}
exit 0
