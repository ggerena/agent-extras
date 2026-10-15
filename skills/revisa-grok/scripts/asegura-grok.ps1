[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function Set-TomlBoolean {
    param(
        [string]$Content,
        [string]$Section,
        [string]$Key,
        [bool]$Value
    )

    $literal = if ($Value) { "true" } else { "false" }
    $sectionPattern = '(?ms)^\[' + [regex]::Escape($Section) + '\][ \t]*\r?\n(?<body>.*?)(?=^\[|\z)'
    $match = [regex]::Match($Content, $sectionPattern)
    if ($match.Success) {
        $body = $match.Groups['body'].Value
        $keyPattern = '(?m)^[ \t]*' + [regex]::Escape($Key) + '[ \t]*=[^\r\n]*(?=\r?$)'
        if ([regex]::IsMatch($body, $keyPattern)) {
            $newBody = [regex]::Replace($body, $keyPattern, "$Key = $literal", 1)
        }
        else {
            $newBody = "$Key = $literal`r`n$body"
        }
        return $Content.Substring(0, $match.Groups['body'].Index) + $newBody + $Content.Substring($match.Groups['body'].Index + $match.Groups['body'].Length)
    }

    $separator = if (-not $Content) { "" } elseif ($Content.EndsWith("`n")) { "`r`n" } else { "`r`n`r`n" }
    return "$Content$separator[$Section]`r`n$Key = $literal`r`n"
}

$configPath = Join-Path (Join-Path $HOME ".grok") "config.toml"
$configDirectory = Split-Path -Parent $configPath
if (-not (Test-Path -LiteralPath $configDirectory)) {
    New-Item -ItemType Directory -Path $configDirectory | Out-Null
}

$original = if (Test-Path -LiteralPath $configPath) { [IO.File]::ReadAllText($configPath) } else { "" }
$updated = $original

# La variante plural era usada por builds antiguos y ahora genera una advertencia.
$updated = [regex]::Replace($updated, '(?m)^[ \t]*trace_uploads[ \t]*=.*(?:\r?\n|$)', '')
$settings = @(
    @{ Section = "harness"; Key = "disable_codebase_upload"; Value = $true },
    @{ Section = "features"; Key = "telemetry"; Value = $false },
    @{ Section = "features"; Key = "feedback"; Value = $false },
    @{ Section = "telemetry"; Key = "trace_upload"; Value = $false },
    @{ Section = "telemetry"; Key = "mixpanel_enabled"; Value = $false },
    @{ Section = "telemetry"; Key = "otel_enabled"; Value = $false },
    @{ Section = "telemetry"; Key = "otel_log_user_prompts"; Value = $false },
    @{ Section = "telemetry"; Key = "otel_log_tool_details"; Value = $false }
)
foreach ($setting in $settings) {
    $updated = Set-TomlBoolean -Content $updated -Section $setting.Section -Key $setting.Key -Value $setting.Value
}

if ($updated -ne $original) {
    if (Test-Path -LiteralPath $configPath) {
        $backupPath = "$configPath.bak-$((Get-Date).ToString('yyyyMMdd-HHmmss'))"
        Copy-Item -LiteralPath $configPath -Destination $backupPath
        Write-Output "Respaldo creado: $backupPath"
    }
    [IO.File]::WriteAllText($configPath, $updated, [Text.UTF8Encoding]::new($false))
    Write-Output "Bloqueos locales de Grok restaurados en $configPath"
}
else {
    Write-Output "Los bloqueos locales de Grok ya estaban correctos."
}

# Las variables documentadas tienen precedencia sobre config.toml.
$environmentLocks = [ordered]@{
    GROK_TELEMETRY_ENABLED = "0"
    GROK_TELEMETRY_TRACE_UPLOAD = "0"
    GROK_TELEMETRY_MIXPANEL_ENABLED = "0"
    GROK_EXTERNAL_OTEL = "0"
    GROK_FEEDBACK_ENABLED = "0"
}
foreach ($entry in $environmentLocks.GetEnumerator()) {
    [Environment]::SetEnvironmentVariable($entry.Key, $entry.Value, "User")
    Set-Item -Path "Env:$($entry.Key)" -Value $entry.Value
}

$grok = Get-Command grok -ErrorAction SilentlyContinue
if (-not $grok) { throw "No se encontro Grok en PATH." }
& $grok.Source inspect --json *> $null
if ($LASTEXITCODE -ne 0) { throw "Grok rechazo la configuracion corregida." }

Write-Output "Telemetria, trazas, Mixpanel, feedback y OTEL externo quedaron bloqueados para futuras sesiones."
exit 0
