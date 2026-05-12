param(
  [string]$CodexHome = "$env:USERPROFILE\.codex",
  [string]$InstallDir = "",
  [int]$PollSeconds = 3,
  [int]$HiddenGraceSeconds = 5,
  [switch]$NoLiveUsage,
  [switch]$ShowTrayIcon,
  [switch]$NoExitWithCodex,
  [string]$CodexAppPath = "",
  [string]$CodexAppId = "",
  [switch]$NoStartCodex,
  [int]$CodexStartWaitSeconds = 8
)

$ErrorActionPreference = "Stop"

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
  throw "Codexy pet usages ring watcher can only run on Windows."
}

function Read-Utf8Text {
  param([string]$Path)
  return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Write-WatcherLog {
  param([string]$Message)
  try {
    $line = "{0:s} {1}" -f (Get-Date), $Message
    Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8
  } catch {
  }
}

function Get-ProjectRoot {
  if (-not [string]::IsNullOrWhiteSpace($InstallDir)) {
    return [System.IO.Path]::GetFullPath($InstallDir)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
}

function Get-WindowsPowerShell {
  $winPs = Get-Command powershell.exe -ErrorAction SilentlyContinue
  if ($winPs) { return $winPs.Source }
  $pwsh = Get-Command pwsh.exe -ErrorAction SilentlyContinue
  if ($pwsh) { return $pwsh.Source }
  throw "PowerShell was not found."
}

function Quote-Argument {
  param([string]$Value)
  if ($Value -match '[\s"]') {
    return '"' + ($Value -replace '"', '\"') + '"'
  }
  return $Value
}

function Test-PetOverlayOpen {
  if (-not (Test-Path -LiteralPath $script:StatePath)) { return $false }
  try {
    $state = Read-Utf8Text -Path $script:StatePath | ConvertFrom-Json
    if ($state.'electron-avatar-overlay-open' -is [bool] -and -not $state.'electron-avatar-overlay-open') {
      return $false
    }
    $bounds = $state.'electron-avatar-overlay-bounds'
    if ($null -eq $bounds) { return $false }
    return ($null -ne $bounds.mascot -or $null -ne $bounds.anchor)
  } catch {
    Write-WatcherLog "Pet overlay state read failed: $($_.Exception.Message)"
    return $false
  }
}

function Get-CompanionProcesses {
  if (-not (Get-Command Get-CodexPetRuntimeProcesses -ErrorAction SilentlyContinue)) { return @() }
  $processes = @(Get-CodexPetRuntimeProcesses -ProjectRoots @($script:ProjectRoot))
  return @($processes | Where-Object { $_.CommandLine -match [regex]::Escape($script:AppScript) })
}

function Stop-Companion {
  $processes = @(Get-CompanionProcesses)
  foreach ($process in $processes) {
    Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
    Write-WatcherLog "Stopped companion helper PID $($process.ProcessId)."
  }
}

function Start-Companion {
  if (@(Get-CompanionProcesses).Count -gt 0) { return }
  $args = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-STA",
    "-File", $script:AppScript,
    "-CodexHome", $CodexHome,
    "-SettingsPath", $script:SettingsPath,
    "-LogDirectory", $script:LogDirectory
  )
  if ($NoLiveUsage) { $args += "-NoLiveUsage" }
  if (-not $ShowTrayIcon) { $args += "-NoTrayIcon" }
  if ($NoExitWithCodex) { $args += "-NoExitWithCodex" }

  $argumentLine = ($args | ForEach-Object { Quote-Argument ([string]$_) }) -join " "
  $process = Start-Process -FilePath $script:PowerShell -ArgumentList $argumentLine -WorkingDirectory $script:ProjectRoot -WindowStyle Hidden -PassThru
  if (Get-Command Set-CodexPetPidFile -ErrorAction SilentlyContinue) {
    Set-CodexPetPidFile -ProjectRoot $script:ProjectRoot -ProcessId $process.Id
  }
  Write-WatcherLog "Started companion helper PID $($process.Id) because /pet is visible."
}

$script:ProjectRoot = Get-ProjectRoot
$script:AppScript = Join-Path $script:ProjectRoot "src\CodexyPetUsagesRing.ps1"
if (-not (Test-Path -LiteralPath $script:AppScript)) {
  throw "Missing app script: $script:AppScript"
}

$runtimeStateScript = Join-Path $script:ProjectRoot "bin\powershell\RuntimeState.ps1"
if (Test-Path -LiteralPath $runtimeStateScript) {
  . $runtimeStateScript
}

$codexDiscoveryScript = Join-Path $script:ProjectRoot "src\CodexAppDiscovery.ps1"
if (Test-Path -LiteralPath $codexDiscoveryScript) {
  . $codexDiscoveryScript
}

$CodexHome = [System.IO.Path]::GetFullPath($CodexHome)
$script:StatePath = Join-Path $CodexHome ".codex-global-state.json"
$script:SettingsPath = Join-Path $script:ProjectRoot "settings.json"
$localAppData = [Environment]::GetFolderPath("LocalApplicationData")
if ([string]::IsNullOrWhiteSpace($localAppData)) { $localAppData = $env:LOCALAPPDATA }
if ([string]::IsNullOrWhiteSpace($localAppData)) { $localAppData = $env:TEMP }
$script:LogDirectory = Join-Path $localAppData "CodexyPetUsagesRing\logs"
New-Item -ItemType Directory -Force -Path $script:LogDirectory | Out-Null
$script:LogFile = Join-Path $script:LogDirectory "codexy-pet-usages-ring.log"
$script:PowerShell = Get-WindowsPowerShell

try {
  [System.Diagnostics.Process]::GetCurrentProcess().PriorityClass = [System.Diagnostics.ProcessPriorityClass]::BelowNormal
} catch {
}

Write-WatcherLog "Starting Codexy pet usages ring watcher."

if (-not $NoStartCodex -and (Get-Command Start-CodexDesktopApp -ErrorAction SilentlyContinue)) {
  $codexStartResult = Start-CodexDesktopApp `
    -CodexAppPath $CodexAppPath `
    -CodexAppId $CodexAppId `
    -WaitSeconds $CodexStartWaitSeconds
  if ($codexStartResult.Running) {
    Write-WatcherLog "Codex Desktop is running for watcher."
  } elseif (-not [string]::IsNullOrWhiteSpace($codexStartResult.Error)) {
    Write-WatcherLog "Codex Desktop auto-start skipped: $($codexStartResult.Error)"
  }
}

$hiddenSince = $null
while ($true) {
  $codexRunning = if (Get-Command Test-CodexDesktopRunning -ErrorAction SilentlyContinue) {
    Test-CodexDesktopRunning
  } else {
    $true
  }

  $petOpen = $codexRunning -and (Test-PetOverlayOpen)
  if ($petOpen) {
    $hiddenSince = $null
    Start-Companion
  } else {
    if ($null -eq $hiddenSince) { $hiddenSince = Get-Date }
    if (((Get-Date) - $hiddenSince).TotalSeconds -ge [Math]::Max(0, $HiddenGraceSeconds)) {
      Stop-Companion
    }
  }

  Start-Sleep -Seconds ([Math]::Max(1, $PollSeconds))
}
