# sentinel:skip-file - rebuilds portable launchers and atlas metadata from repo-local copies.
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$base = $PSScriptRoot
$organized = Join-Path $base "Organized"
$manifestPath = Join-Path $base "library-manifest.json"

if (-not (Test-Path $manifestPath)) {
  throw "Missing library-manifest.json. Run rebuild-library.ps1 first."
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

function Safe-Name {
  param([string]$Value)

  return ($Value -replace '[<>:"/\\|?*]', " - ").Trim()
}

function Escape-Html {
  param([string]$Value)

  return [System.Net.WebUtility]::HtmlEncode($Value)
}

function Get-GroupUrl {
  param(
    [string]$Category,
    [string]$Group
  )

  return "library.html?category=$([uri]::EscapeDataString($Category))&search=$([uri]::EscapeDataString($Group))"
}

function New-LauncherFile {
  param(
    [string]$FolderPath,
    [string]$FileName,
    [string]$TargetRelativePath
  )

  $stem = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
  $launcherPath = Join-Path $FolderPath ($stem + ".html")
  $counter = 2

  while (Test-Path $launcherPath) {
    $launcherPath = Join-Path $FolderPath ("{0} -- {1}.html" -f $stem, $counter)
    $counter += 1
  }

  $targetAbsolutePath = Join-Path $base ($TargetRelativePath -replace "/", "\")
  $folderUri = New-Object System.Uri(([System.IO.Path]::GetFullPath($FolderPath).TrimEnd("\") + "\"))
  $targetUri = New-Object System.Uri([System.IO.Path]::GetFullPath($targetAbsolutePath))
  $relativeTarget = [System.Uri]::UnescapeDataString($folderUri.MakeRelativeUri($targetUri).ToString())
  $href = [uri]::EscapeUriString($relativeTarget)
  $hrefJson = $href | ConvertTo-Json -Compress

  $body = @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="refresh" content="0; url=$href">
  <title>Redirecting...</title>
  <script>
    location.replace($hrefJson);
  </script>
</head>
<body>
  <p>Redirecting to <a href="$href">$([System.Net.WebUtility]::HtmlEncode($relativeTarget))</a>.</p>
</body>
</html>
"@

  Write-Utf8NoBom -Path $launcherPath -Content $body
  return $launcherPath
}

if (Test-Path $organized) {
  Remove-Item -Path $organized -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $organized | Out-Null

$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
$items = @($manifest.items)

$inventory = foreach ($item in $items) {
  $category = [string]$item.category
  $group = [string]$item.group
  $groupFolder = Join-Path $organized (Join-Path (Safe-Name $category) (Safe-Name $group))
  New-Item -ItemType Directory -Force -Path $groupFolder | Out-Null

  $copyPath = [string]$item.copyPath
  $absoluteCopyPath = Join-Path $base ($copyPath -replace "/", "\")
  if (-not (Test-Path $absoluteCopyPath)) { continue }

  $file = Get-Item $absoluteCopyPath
  $launcherPath = New-LauncherFile -FolderPath $groupFolder -FileName ([string]$item.copyName) -TargetRelativePath $copyPath

  [pscustomobject]@{
    name = $item.name
    category = $category
    group = $group
    kind = $item.kind
    sourceRoot = $item.sourceRoot
    originalPath = $copyPath
    launchUrl = $copyPath
    folderUrl = Get-GroupUrl $category $group
    organizedFolder = Get-RelativeRepoPath $groupFolder
    shortcutPath = Get-RelativeRepoPath $launcherPath
    lastWriteIso = $file.LastWriteTime.ToString("o")
    lastWriteEpoch = [int64]([DateTimeOffset]$file.LastWriteTime).ToUnixTimeMilliseconds()
    sizeBytes = [int64]$file.Length
    sizeLabel = ("{0:N1} KB" -f ($file.Length / 1KB))
  }
}

$payload = [pscustomobject]@{
  generatedAt = (Get-Date).ToString("o")
  items = @($inventory | Sort-Object category, group, name, originalPath)
}

$json = $payload | ConvertTo-Json -Depth 6
Write-Utf8NoBom -Path (Join-Path $base "inventory.json") -Content $json
Write-Utf8NoBom -Path (Join-Path $base "inventory.js") -Content ("window.LIVING_META_INVENTORY = " + $json + ";")

Write-Output "Rebuilt portable atlas launchers at $organized"
$inventory | Group-Object category | Sort-Object Name | ForEach-Object { "{0}: {1}" -f $_.Name, $_.Count }
