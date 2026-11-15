param([string]$ProjectRoot = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $ProjectRoot).Path
$paths = @(git -C $root ls-files --cached --deduplicate)
if ($LASTEXITCODE -ne 0) { throw 'No se pudo leer el repositorio Git.' }
$known = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$ids = @{}
$errors = [Collections.Generic.List[string]]::new()
$texts = @{}
foreach ($path in $paths) {
    $full = Join-Path $root $path
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { continue }
    [void]$known.Add($path)
    if ($path -notmatch '\.(tscn|tres|gd|uid|godot|import)$') { continue }
    $content = [IO.File]::ReadAllText($full)
    $texts[$path] = $content
    if ($content -match '(?m)^(<<<<<<<|=======|>>>>>>>)') { $errors.Add("Conflicto sin resolver: $path") }
    $uid = ''
    if ($path.EndsWith('.uid')) {
        if ($content.Trim() -notmatch '^uid://[a-z0-9]+$') { $errors.Add("UID invalido: $path") }
        else { $uid = $content.Trim() }
    } elseif ($path -match '\.(tscn|tres)$') {
        $match = [regex]::Match($content, '^\[gd_(?:scene|resource)[^\r\n]*\buid="([^"]+)"')
        if ($match.Success) { $uid = $match.Groups[1].Value }
    } elseif ($path.EndsWith('.import')) {
        $match = [regex]::Match($content, '(?m)^uid="([^"]+)"')
        if ($match.Success) { $uid = $match.Groups[1].Value }
    }
    if ($uid) {
        if ($ids.ContainsKey($uid)) { $errors.Add("UID duplicado: $path y $($ids[$uid])") }
        else { $ids[$uid] = $path }
    }
}
foreach ($path in $texts.Keys) {
    foreach ($match in [regex]::Matches($texts[$path], 'res://[^"\s]+')) {
        $target = $match.Value.Substring(6)
        if ($target.StartsWith('.godot/')) { continue }
        if (-not $known.Contains($target)) { $errors.Add("Ruta ausente en Git o mayusculas distintas: $path -> $target") }
    }
    foreach ($match in [regex]::Matches($texts[$path], 'uid://[a-z0-9]+')) {
        if (-not $ids.ContainsKey($match.Value)) { $errors.Add("UID sin recurso registrado: $path -> $($match.Value)") }
    }
}
if ($errors.Count -gt 0) {
    $errors | Sort-Object -Unique | ForEach-Object { Write-Output $_ }
    exit 1
}
Write-Output "OK: $($known.Count) archivos registrados; sin conflictos, UID duplicados ni referencias ausentes."
