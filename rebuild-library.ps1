$ErrorActionPreference = "Stop"

$base = "C:\Living metas"
$library = Join-Path $base "Library"
$inventoryPath = Join-Path $base "inventory.json"

if (-not (Test-Path $inventoryPath)) {
  throw "Missing inventory.json. Run rebuild-organized.ps1 first."
}

if (Test-Path $library) {
  Remove-Item -Path $library -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $library | Out-Null

$inventory = Get-Content $inventoryPath -Raw | ConvertFrom-Json
$items = @($inventory.items)

function Safe-Name($value) {
  return ($value -replace '[<>:"/\\|?*]', " - ").Trim()
}

$manifest = foreach ($item in $items) {
  $source = [string]$item.originalPath
  if (-not (Test-Path $source)) { continue }

  $categoryFolder = Join-Path $library (Safe-Name ([string]$item.category))
  $groupFolder = Join-Path $categoryFolder (Safe-Name ([string]$item.group))
  New-Item -ItemType Directory -Force -Path $groupFolder | Out-Null

  $stem = [System.IO.Path]::GetFileNameWithoutExtension([string]$item.name)
  $ext = [System.IO.Path]::GetExtension([string]$item.name)
  $copyStem = if ([string]$item.category -eq "Submission" -or [string]$item.category -eq "Backup" -or [string]$item.category -eq "Scratch") {
    $relative = $source.Replace([string]$item.sourceRoot, "").TrimStart("\")
    $parts = $relative.Split("\")
    if ($parts.Count -gt 1) { ($parts[0..($parts.Count - 2)] + $stem) -join " -- " } else { $stem }
  } else {
    $stem
  }
  $copyName = (Safe-Name $copyStem) + $ext
  $copyPath = Join-Path $groupFolder $copyName

  if (Test-Path $copyPath) {
    $hash = [System.IO.Path]::GetFileNameWithoutExtension([string]$item.shortcutPath)
    $copyName = (Safe-Name ($copyStem + " -- " + $hash)) + $ext
    $copyPath = Join-Path $groupFolder $copyName
  }

  Copy-Item -Path $source -Destination $copyPath -Force

  [pscustomobject]@{
    name = $item.name
    category = $item.category
    group = $item.group
    kind = $item.kind
    sourceRoot = $item.sourceRoot
    originalPath = $source
    copyPath = $copyPath
    copyName = $copyName
    lastWriteIso = $item.lastWriteIso
    sizeBytes = $item.sizeBytes
    sizeLabel = $item.sizeLabel
  }
}

$payload = [pscustomobject]@{
  generatedAt = (Get-Date).ToString("o")
  items = @($manifest | Sort-Object category, group, copyName)
}

$manifestJson = $payload | ConvertTo-Json -Depth 6
Set-Content -Path (Join-Path $base "library-manifest.json") -Value $manifestJson -Encoding UTF8
$manifestJs = "window.LIVING_META_LIBRARY = " + $manifestJson + ";"
Set-Content -Path (Join-Path $base "library.js") -Value $manifestJs -Encoding UTF8

Write-Output "Rebuilt library at $library"
$manifest | Group-Object category | Sort-Object Name | ForEach-Object { "{0}: {1}" -f $_.Name, $_.Count }
