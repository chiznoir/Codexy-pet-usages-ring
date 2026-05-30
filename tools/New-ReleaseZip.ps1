param(
  [string]$OutputDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) "dist")
)

$ErrorActionPreference = "Stop"

$root = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
. (Join-Path $PSScriptRoot "ReleaseManifest.ps1")
$versionFile = Join-Path $root "VERSION"
$version = if (Test-Path -LiteralPath $versionFile) {
  (Get-Content -Raw -LiteralPath $versionFile).Trim()
} else {
  "0.1.0"
}
$name = "Codexy-pet-usages-ring-$version"
$staging = Join-Path $env:TEMP $name
$zipPath = Join-Path $OutputDirectory "$name.zip"

function Get-ProjectRelativePath {
  param([string]$Path)
  $fullPath = [System.IO.Path]::GetFullPath($Path)
  $rootWithSeparator = $root.TrimEnd("\") + "\"
  if ($fullPath.StartsWith($rootWithSeparator, [StringComparison]::OrdinalIgnoreCase)) {
    return (($fullPath.Substring($rootWithSeparator.Length)) -replace '\\', '/')
  }
  return ((Split-Path -Leaf $fullPath) -replace '\\', '/')
}

function Test-ProjectPathExcluded {
  param([string]$Path)
  $relativePath = Get-ProjectRelativePath -Path $Path
  return (Test-CodexPetReleasePathExcluded -RelativePath $relativePath)
}

function Copy-ReleaseItem {
  param([string]$Name)
  $source = Join-Path $root $Name
  if (-not (Test-Path -LiteralPath $source)) { return }
  if (Test-ProjectPathExcluded -Path $source) { return }
  if ((Get-Item -LiteralPath $source).PSIsContainer) {
    Get-ChildItem -LiteralPath $source -Recurse -File -Force |
      Where-Object { -not (Test-ProjectPathExcluded -Path $_.FullName) } |
      ForEach-Object {
        $relativePath = Get-ProjectRelativePath -Path $_.FullName
        $destination = Join-Path $staging ($relativePath -replace '/', '\')
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
        Copy-Item -LiteralPath $_.FullName -Destination $destination -Force
      }
  } else {
    Copy-Item -LiteralPath $source -Destination (Join-Path $staging $Name) -Force
  }
}

if (Test-Path -LiteralPath $staging) {
  Remove-Item -LiteralPath $staging -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $staging | Out-Null
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

foreach ($item in $script:CodexPetReleaseItems) {
  Copy-ReleaseItem -Name $item
}

if (Test-Path -LiteralPath $zipPath) {
  Remove-Item -LiteralPath $zipPath -Force
}
Compress-Archive -Path (Join-Path $staging "*") -DestinationPath $zipPath -Force
Remove-Item -LiteralPath $staging -Recurse -Force

Write-Output "Release zip: $zipPath"
