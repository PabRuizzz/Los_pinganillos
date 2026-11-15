# Descarga las fotografias oficiales de NASA del catalogo de muestras marcianas
# a assets/science/rock_samples/. Ejecutar desde la raiz del proyecto (Windows):
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/download_rock_sample_images.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$dest = Join-Path $root "assets/science/rock_samples"
New-Item -ItemType Directory -Force -Path $dest | Out-Null
$fail = $false
$images = @(
    @("montdenier.jpg", "https://images-assets.nasa.gov/image/PIA24832/PIA24832~orig.jpg"),
    @("hazeltop.jpg", "https://images-assets.nasa.gov/image/PIA24929/PIA24929~orig.jpg"),
    @("atmo_mountain.jpg", "https://images-assets.nasa.gov/image/PIA25588/PIA25588~orig.jpg"),
    @("otis_peak.jpg", "https://images-assets.nasa.gov/image/PIA25962/PIA25962~orig.jpg"),
    @("comet_geyser.jpg", "https://images-assets.nasa.gov/image/PIA26313/PIA26313~orig.jpg"),
    @("sapphire_canyon.jpg", "https://images-assets.nasa.gov/image/PIA26370/PIA26370~orig.jpg"),
    @("silver_mountain.png", "https://assets.science.nasa.gov/dynamicimage/assets/science/psd/solar-system/mars/images/mars-rock-samples/Mars_Perseverance_FRF_1401_0791327312_691ECM_N0660000FHAZ02008_01_095J.png"),
    @("green_gardens.jpg", "https://images-assets.nasa.gov/image/PIA26529/PIA26529~orig.jpg"),
    @("hottah.jpg", "https://images-assets.nasa.gov/image/PIA16156/PIA16156~orig.jpg"),
    @("berry_bowl.jpg", "https://images-assets.nasa.gov/image/PIA05634/PIA05634~orig.jpg"),
    @("garden_city.jpg", "https://images-assets.nasa.gov/image/PIA19161/PIA19161~large.jpg"),
    @("kodiak.jpg", "https://images-assets.nasa.gov/image/PIA24802/PIA24802~large.jpg")
)
foreach ($img in $images) {
    $path = Join-Path $dest $img[0]
    if ((Test-Path $path) -and ((Get-Item $path).Length -gt 0)) { Write-Host "ya existe  $($img[0])"; continue }
    try { Invoke-WebRequest -Uri $img[1] -OutFile $path -UseBasicParsing; Write-Host "descargada $($img[0])" }
    catch { Write-Host "ERROR      $($img[0]) <- $($img[1])"; Remove-Item -ErrorAction SilentlyContinue $path; $fail = $true }
}
if ($fail) { Write-Host "Algunas descargas fallaron."; exit 1 }
Write-Host "Listo: 12 imagenes en $dest. Abre Godot para importarlas."
