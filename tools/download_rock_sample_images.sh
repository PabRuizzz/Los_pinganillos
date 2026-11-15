#!/usr/bin/env bash
# Descarga las fotografias oficiales de NASA del catalogo de muestras marcianas
# a assets/science/rock_samples/. Ejecutar desde la raiz del proyecto (macOS/Linux):
#   bash tools/download_rock_sample_images.sh
# Luego abrir Godot para que importe las imagenes. Las URL y creditos estan en cada .tres.
set -u
cd "$(dirname "$0")/.."
DEST="assets/science/rock_samples"
mkdir -p "$DEST"
fail=0

download() {
  local file="$1" url="$2"
  if [ -s "$DEST/$file" ]; then echo "ya existe  $file"; return; fi
  if curl -fsSL --retry 2 -o "$DEST/$file.part" "$url"; then mv "$DEST/$file.part" "$DEST/$file"; echo "descargada $file"
  else rm -f "$DEST/$file.part"; echo "ERROR      $file <- $url"; fail=1; fi
}

download "montdenier.jpg" "https://images-assets.nasa.gov/image/PIA24832/PIA24832~orig.jpg"
download "hazeltop.jpg" "https://images-assets.nasa.gov/image/PIA24929/PIA24929~orig.jpg"
download "atmo_mountain.jpg" "https://images-assets.nasa.gov/image/PIA25588/PIA25588~orig.jpg"
download "otis_peak.jpg" "https://images-assets.nasa.gov/image/PIA25962/PIA25962~orig.jpg"
download "comet_geyser.jpg" "https://images-assets.nasa.gov/image/PIA26313/PIA26313~orig.jpg"
download "sapphire_canyon.jpg" "https://images-assets.nasa.gov/image/PIA26370/PIA26370~orig.jpg"
download "silver_mountain.png" "https://assets.science.nasa.gov/dynamicimage/assets/science/psd/solar-system/mars/images/mars-rock-samples/Mars_Perseverance_FRF_1401_0791327312_691ECM_N0660000FHAZ02008_01_095J.png"
download "green_gardens.jpg" "https://images-assets.nasa.gov/image/PIA26529/PIA26529~orig.jpg"
download "hottah.jpg" "https://images-assets.nasa.gov/image/PIA16156/PIA16156~orig.jpg"
download "berry_bowl.jpg" "https://images-assets.nasa.gov/image/PIA05634/PIA05634~orig.jpg"
download "garden_city.jpg" "https://images-assets.nasa.gov/image/PIA19161/PIA19161~large.jpg"
download "kodiak.jpg" "https://images-assets.nasa.gov/image/PIA24802/PIA24802~large.jpg"

if [ "$fail" -ne 0 ]; then echo "Algunas descargas fallaron."; exit 1; fi
echo "Listo: 12 imagenes en $DEST. Abre Godot para importarlas."
