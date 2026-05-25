# sentinel:skip-file - rebuilds portable library metadata from repo-local copies.
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$base = $PSScriptRoot
$library = Join-Path $base "Library"

if (-not (Test-Path $library)) {
  throw "Missing Library directory at $library"
}

function Write-Utf8NoBom {
  param(
    [string]$Path,
    [string]$Content
  )

  $encoding = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function Get-RelativeRepoPath {
  param([string]$AbsolutePath)

  $baseUri = New-Object System.Uri(([System.IO.Path]::GetFullPath($base).TrimEnd("\") + "\"))
  $targetPath = [System.IO.Path]::GetFullPath($AbsolutePath)
  $targetItem = Get-Item -LiteralPath $targetPath
  $targetUri = if ($targetItem.PSIsContainer) {
    New-Object System.Uri(($targetPath.TrimEnd("\") + "\"))
  } else {
    New-Object System.Uri($targetPath)
  }

  return [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($targetUri).ToString())
}

function Get-Kind {
  param(
    [string]$Category,
    [string]$Group,
    [string]$Name
  )

  if ($Category -eq "Submission") { return "Submission" }
  if ($Category -eq "Backup") { return "Backup" }
  if ($Category -eq "Scratch") { return "Scratch" }
  if ($Category -eq "Legacy") { return "Legacy" }
  if ($Group -in @("ESC ACS Support", "Finrenone Support", "TEER Support")) { return "Support" }
  if ($Name -match "^(dashboard|test-runner|r-validation-runner|TrialRadar|MetaExtract|META_DASHBOARD|AutoGRADE|AutoManuscript)\.html$") { return "Support" }
  if ($Name -eq "index.html" -or $Name -match "living-meta-engine|living-meta-complete|living-meta-standalone|LivingMeta|LIVING_META|PFA_AF_LivingMeta|TEER_LIVING_META") { return "App" }
  if ($Name -match "_REVIEW") { return "Review" }
  return "HTML"
}

$items = foreach ($categoryDir in Get-ChildItem -Path $library -Directory | Sort-Object Name) {
  $category = $categoryDir.Name

  foreach ($groupDir in Get-ChildItem -Path $categoryDir.FullName -Directory | Sort-Object Name) {
    $group = $groupDir.Name

    foreach ($file in Get-ChildItem -Path $groupDir.FullName -File -Filter *.html | Sort-Object Name) {
      $relativePath = Get-RelativeRepoPath $file.FullName

      [pscustomobject]@{
        name = $file.Name
        category = $category
        group = $group
        kind = Get-Kind $category $group $file.Name
        sourceRoot = Get-RelativeRepoPath $groupDir.FullName
        originalPath = $relativePath
        copyPath = $relativePath
        copyName = $file.Name
        folderPath = Get-RelativeRepoPath $groupDir.FullName
        lastWriteIso = $file.LastWriteTime.ToString("o")
        sizeBytes = [int64]$file.Length
        sizeLabel = ("{0:N1} KB" -f ($file.Length / 1KB))
      }
    }
  }
}

$payload = [pscustomobject]@{
  generatedAt = (Get-Date).ToString("o")
  items = @($items | Sort-Object category, group, copyName)
}

$json = $payload | ConvertTo-Json -Depth 6
Write-Utf8NoBom -Path (Join-Path $base "library-manifest.json") -Content $json
Write-Utf8NoBom -Path (Join-Path $base "library.js") -Content ("window.LIVING_META_LIBRARY = " + $json + ";")

Write-Output "Rebuilt portable library manifest from $library"
$items | Group-Object category | Sort-Object Name | ForEach-Object { "{0}: {1}" -f $_.Name, $_.Count }
