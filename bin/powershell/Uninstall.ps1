param(
  [string]$InstallDir = "$env:LOCALAPPDATA\CodexyPetUsagesRing",
  [switch]$RemoveFiles
)

$ErrorActionPreference = "Stop"

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
  throw "Codexy pet usages ring can only run on Windows."
}

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$targetRoot = [System.IO.Path]::GetFullPath($InstallDir)
$runtimeStateScript = Join-Path $projectRoot "bin\powershell\RuntimeState.ps1"
if (-not (Test-Path -LiteralPath $runtimeStateScript)) {
  throw "Missing runtime state helper: $runtimeStateScript"
}
. $runtimeStateScript

function Test-ShortcutTargetsInstallDir {
  param(
    [string]$ShortcutPath,
    [string]$InstallRoot
  )
  if (-not (Test-Path -LiteralPath $ShortcutPath)) { return $false }
  try {
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($ShortcutPath)
    $root = [System.IO.Path]::GetFullPath($InstallRoot).TrimEnd("\")
    if (-not [string]::IsNullOrWhiteSpace($shortcut.WorkingDirectory)) {
      $workingDirectory = [System.IO.Path]::GetFullPath($shortcut.WorkingDirectory).TrimEnd("\")
      if ($workingDirectory -eq $root) { return $true }
    }
    foreach ($scriptName in @("Start.ps1", "Settings.ps1")) {
      $scriptPath = Join-Path $root "bin\powershell\$scriptName"
      if (Test-CodexPetPathInCommandLine -CommandLine $shortcut.Arguments -Path $scriptPath) {
        return $true
      }
    }
  } catch {
    return $false
  }
  return $false
}

$stopScript = Join-Path $projectRoot "bin\powershell\Stop.ps1"
if (Test-Path -LiteralPath $stopScript) {
  & $stopScript -InstallDir $targetRoot -Quiet
} else {
  Get-CodexPetRuntimeProcesses -ProjectRoots @($targetRoot) |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

$startup = [Environment]::GetFolderPath("Startup")
$startupShortcuts = @(
  (Join-Path $startup "Codexy pet usages ring.lnk"),
  (Join-Path $startup "Codex Pet Limit Rings.lnk")
)
foreach ($startupShortcut in $startupShortcuts) {
  if (Test-ShortcutTargetsInstallDir -ShortcutPath $startupShortcut -InstallRoot $targetRoot) {
    Remove-Item -LiteralPath $startupShortcut -Force
    Write-Output "Removed startup shortcut: $startupShortcut"
  }
}

$programs = [Environment]::GetFolderPath("Programs")
$programFolders = @(
  (Join-Path $programs "Codexy pet usages ring"),
  (Join-Path $programs "Codex Pet Limit Rings")
)
foreach ($programFolder in $programFolders) {
  $programShortcuts = @(
    (Join-Path $programFolder "Start Codexy pet usages ring.lnk"),
    (Join-Path $programFolder "Settings Codexy pet usages ring.lnk"),
    (Join-Path $programFolder "Start Codex Pet Limit Rings.lnk"),
    (Join-Path $programFolder "Settings Codex Pet Limit Rings.lnk")
  )
  foreach ($shortcutPath in $programShortcuts) {
    if (Test-ShortcutTargetsInstallDir -ShortcutPath $shortcutPath -InstallRoot $targetRoot) {
      Remove-Item -LiteralPath $shortcutPath -Force
      Write-Output "Removed Start Menu shortcut: $shortcutPath"
    }
  }
  if ((Test-Path -LiteralPath $programFolder) -and -not (Get-ChildItem -LiteralPath $programFolder -Force)) {
    Remove-Item -LiteralPath $programFolder -Force
  }
}

if ($RemoveFiles) {
  if (Test-Path -LiteralPath $targetRoot) {
    if (-not (Test-CodexPetInstallMarker -ProjectRoot $targetRoot)) {
      throw "Refusing to remove '$targetRoot' because the install marker is missing or invalid. Run Install.ps1 once to mark this install, or remove the directory manually after verifying the path."
    }
    $driveRoot = [System.IO.Path]::GetPathRoot($targetRoot).TrimEnd("\")
    if ($targetRoot.TrimEnd("\") -eq $driveRoot) {
      throw "Refusing to remove a drive root: $targetRoot"
    }
    Set-Location -LiteralPath ([System.IO.Path]::GetTempPath())
    Remove-Item -LiteralPath $targetRoot -Recurse -Force
    Write-Output "Removed install directory: $targetRoot"
  }
}

Write-Output "Uninstalled Codexy pet usages ring."
