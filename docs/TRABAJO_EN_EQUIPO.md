# Compartir el proyecto sin mezclar escenas

## Antes de cambiar de rama o hacer Pull

1. Guarda las escenas y cierra Godot.
2. En GitHub Desktop revisa Changes: guarda los cambios que quieras conservar en
   un commit o mediante Stash. No uses Discard All para resolver dependencias.
3. Cambia de rama y haz Fetch/Pull. Comprueba que todos usáis el mismo commit.
4. Abre el mismo `project.godot` y deja terminar la importación.
5. Para comparar el juego usa F5. F6 ejecuta la escena que cada persona tenga abierta.

## Al compartir cambios

- Usa la misma versión de Godot: esta revisión se prueba con 4.7.2.
- Incluye las escenas, scripts, `.gd.uid`, imágenes originales y sus `.import`.
  La carpeta generada `.godot/` debe permanecer fuera de Git.
- Incluye todas las dependencias nuevas de un minijuego en el mismo commit.
- Para campos de texto que se usan como rutas (por ejemplo, `@export_file` y
  `change_scene_to_file`), guarda rutas `res://...`; reserva los UID para
  referencias de recursos serializadas por Godot.
- Evita editar a la vez la misma escena que otro compañero.
- Mantén el clon de trabajo fuera de una carpeta sincronizada por OneDrive para
  que Git gestione las versiones sin copias adicionales del sincronizador.
- No dupliques una escena copiando su texto con el mismo UID. Si necesitas una
  variante, créala desde Godot y verifica que tenga un identificador propio.

## Cuando hay un conflicto

- Un archivo `.gd.uid` debe contener una sola linea `uid://...`.
- En escenas y archivos UID, no elijas Accept Both a ciegas: puede duplicar nodos
  o dejar dos identificadores. Conserva el identificador que referencian las
  escenas y revisa el cambio completo.
- Busca `<<<<<<<`, `=======` y `>>>>>>>` antes del commit, tambien en `.uid`.
- Abre y ejecuta las escenas afectadas antes de subir el merge.

## Comprobacion rapida

En la terminal, desde la carpeta del proyecto, ejecuta:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/check_project.ps1
```

Primero añade a Git los archivos nuevos que quieras compartir. La comprobación
revisa el contenido local de los archivos registrados: conflictos, UID invalidos
o duplicados, referencias ausentes y diferencias de mayusculas en rutas.
No compila GDScript: ademas hay que importar y ejecutar el proyecto en Godot.

Si tienes Godot en PATH, tambien puedes ejecutar las pruebas de carga:

```powershell
godot --headless --editor --import --path .
godot --headless --path . --script res://tools/test_scenes.gd
```

La segunda prueba carga seis escenas y verifica los UID y destinos de las puertas.

Si persiste una discrepancia, con Godot cerrado renombra `.godot` a
`.godot-backup` y vuelve a abrir el proyecto para reimportarlo. No compartas esa
copia de cache. Esto se hace despues de corregir los archivos fuente; borrar la
cache por si solo no arregla UID duplicados ni conflictos guardados en Git.

## Correccion aplicada

Se eliminaron `cuarto1-MSI.tscn`, `cuarto2-MSI.tscn` y `puerta-MSI.tscn`.
Se conservaron las escenas originales y sus rutas de navegacion. Se resolvieron
los conflictos de `main.gd.uid`, `greenhouse.gd.uid` y `power_station.gd.uid`.

## Minijuegos incluidos en esta rama

Abre una de estas escenas y pulsa F6:

- `game/challenges/electrical_repair/electrical_repair.tscn`: cables, salida unica
  en el borde opuesto, obstaculos y minimo de 10 piezas.
- `game/challenges/solar_cleaning/solar_cleaning.tscn`: seis paneles, limpieza
  manteniendo clic izquierdo y objetivo del 90% por panel.

Se incluyen todos sus scripts, UID, escenas reutilizables y pruebas de PABLO.
F5 sigue arrancando la escena principal del juego. Los minijuegos se ejecutan
por separado; todavia no se conectan automaticamente a las estaciones.
