$ErrorActionPreference = "Stop"

$base = "C:\Living metas"
$organized = Join-Path $base "Organized"

if (Test-Path $organized) {
  Remove-Item -Path $organized -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $organized | Out-Null

$roots = @(
  "C:\Projects\Finrenone",
  "C:\Projects\Tricuspid_TEER_LivingMeta",
  "C:\Projects\PFA_AF_LivingMeta",
  "C:\Projects\esc-acs-living-meta",
  "C:\HTML apps\living-meta",
  "C:\Projects\LivingMeta_Watchman_Amulet",
  "C:\Projects\living-meta-engine"
)

$items = New-Object System.Collections.Generic.List[object]

foreach ($root in $roots) {
  if (-not (Test-Path $root)) { continue }
  Get-ChildItem -Path $root -Recurse -File -Include *.html -ErrorAction SilentlyContinue | ForEach-Object {
    $items.Add([pscustomobject]@{
      FullName = $_.FullName
      Name = $_.Name
      SourceRoot = $root
      LastWriteTime = $_.LastWriteTime
      Length = $_.Length
    })
  }
}

Get-ChildItem -Path "C:\Projects\HTML-Misc" -File -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -in @("teer.html", "teer (3).html") } |
  ForEach-Object {
    $items.Add([pscustomobject]@{
      FullName = $_.FullName
      Name = $_.Name
      SourceRoot = "C:\Projects\HTML-Misc"
      LastWriteTime = $_.LastWriteTime
      Length = $_.Length
    })
  }

if (Test-Path "C:\Living metas\FINERENONE_REVIEW.html") {
  $legacy = Get-Item "C:\Living metas\FINERENONE_REVIEW.html"
  $items.Add([pscustomobject]@{
    FullName = $legacy.FullName
    Name = $legacy.Name
    SourceRoot = "C:\Living metas"
    LastWriteTime = $legacy.LastWriteTime
    Length = $legacy.Length
  })
}

$items = $items | Sort-Object FullName -Unique

function Get-Category($path, $name, $sourceRoot) {
  if ($sourceRoot -eq "C:\Living metas") { return "Legacy" }
  if ($path -match "\\e156-submission\\") { return "Submission" }
  if ($name -match "(?i)\.bak\.html$|backup|pre_hr_rr_backup") { return "Backup" }
  if ($path -match "\\vnext\\" -or $path -match "\\.superpowers\\" -or $sourceRoot -eq "C:\Projects\HTML-Misc") { return "Scratch" }
  return "Current"
}

function Get-Group($path, $name, $sourceRoot, $category) {
  switch -Regex ($sourceRoot) {
    "^C:\\Projects\\Finrenone$" {
      if ($category -eq "Submission") { return "Finrenone E156 Submission" }
      if ($category -eq "Backup") { return "Finrenone Backups" }
      if ($category -eq "Scratch") { return "Finrenone Experiments" }
      if ($path -match "\\livingmeta\\") { return "Finrenone LivingMeta Copies" }
      if ($name -match "^(TrialRadar|MetaExtract|META_DASHBOARD|AutoGRADE|AutoManuscript)\.html$") { return "Finrenone Support" }
      return "Finrenone Reviews"
    }
    "^C:\\Projects\\Tricuspid_TEER_LivingMeta$" {
      if ($name -eq "dashboard.html") { return "TEER Support" }
      return "Tricuspid TEER Living Meta"
    }
    "^C:\\Projects\\PFA_AF_LivingMeta$" { return "PFA AF Living Meta" }
    "^C:\\Projects\\esc-acs-living-meta$" {
      if ($name -match "runner") { return "ESC ACS Support" }
      return "ESC ACS Living Meta"
    }
    "^C:\\HTML apps\\living-meta$" {
      if ($category -eq "Submission") { return "Living Meta App E156 Submission" }
      if ($path -match "\\dist-single\\") { return "Living Meta Standalone App" }
      return "Living Meta App"
    }
    "^C:\\Projects\\LivingMeta_Watchman_Amulet$" { return "Watchman and Amulet" }
    "^C:\\Projects\\living-meta-engine$" {
      if ($category -eq "Submission") { return "Living Meta Engine E156 Submission" }
      return "Living Meta Engine"
    }
    "^C:\\Projects\\HTML-Misc$" { return "TEER Scratch" }
    "^C:\\Living metas$" { return "Legacy Root Copies" }
    default { return "Misc Living Meta" }
  }
}

function Get-Kind($path, $name, $sourceRoot, $category) {
  if ($category -eq "Submission") { return "Submission" }
  if ($category -eq "Backup") { return "Backup" }
  if ($category -eq "Scratch") { return "Scratch" }
  if ($category -eq "Legacy") { return "Legacy" }
  if ($name -match "^(dashboard|test-runner|r-validation-runner|TrialRadar|MetaExtract|META_DASHBOARD|AutoGRADE|AutoManuscript)\.html$") { return "Support" }
  if ($name -eq "index.html" -or $name -match "living-meta-engine|living-meta-complete|living-meta-standalone|LivingMeta|LIVING_META") { return "App" }
  if ($name -match "_REVIEW") { return "Review" }
  return "HTML"
}

function Safe-Name($value) {
  return ($value -replace '[<>:"/\\|?*]', " - ").Trim()
}

$inventory = foreach ($item in $items) {
  $category = Get-Category $item.FullName $item.Name $item.SourceRoot
  $group = Get-Group $item.FullName $item.Name $item.SourceRoot $category
  $kind = Get-Kind $item.FullName $item.Name $item.SourceRoot $category
  $folder = Join-Path $organized (Join-Path (Safe-Name $category) (Safe-Name $group))
  New-Item -ItemType Directory -Force -Path $folder | Out-Null

  $fileUrl = ([uri]$item.FullName).AbsoluteUri
  $folderUrl = ([uri](Split-Path -Parent $item.FullName)).AbsoluteUri
  $relativeBits = $item.FullName.Replace($item.SourceRoot, "").TrimStart("\").Split("\")
  $baseName = [System.IO.Path]::GetFileNameWithoutExtension($item.Name)
  $uniqueStem = if ($relativeBits.Count -gt 1) { ($relativeBits[0..($relativeBits.Count - 2)] + $baseName) -join " -- " } else { $baseName }
  $shortcutName = Safe-Name $uniqueStem
  $shortcutPath = Join-Path $folder ($shortcutName + ".url")
  $shortcutBody = "[InternetShortcut]`r`nURL=$fileUrl`r`n"
  Set-Content -Path $shortcutPath -Value $shortcutBody -Encoding ASCII

  [pscustomobject]@{
    name = $item.Name
    category = $category
    group = $group
    kind = $kind
    sourceRoot = $item.SourceRoot
    originalPath = $item.FullName
    launchUrl = $fileUrl
    folderUrl = $folderUrl
    organizedFolder = $folder
    shortcutPath = $shortcutPath
    lastWriteIso = $item.LastWriteTime.ToString("o")
    lastWriteEpoch = [int64]([DateTimeOffset]$item.LastWriteTime).ToUnixTimeMilliseconds()
    sizeBytes = [int64]$item.Length
    sizeLabel = ("{0:N1} KB" -f ($item.Length / 1KB))
  }
}

$payload = [pscustomobject]@{
  generatedAt = (Get-Date).ToString("o")
  items = @($inventory | Sort-Object category, group, name, originalPath)
}

$json = $payload | ConvertTo-Json -Depth 6
Set-Content -Path (Join-Path $base "inventory.json") -Value $json -Encoding UTF8
Set-Content -Path (Join-Path $base "inventory.js") -Value ("window.LIVING_META_INVENTORY = " + $json + ";") -Encoding UTF8

Write-Output "Rebuilt organizer at $organized"
$inventory | Group-Object category | Sort-Object Name | ForEach-Object { "{0}: {1}" -f $_.Name, $_.Count }
