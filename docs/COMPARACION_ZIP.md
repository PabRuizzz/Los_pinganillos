# ZIP del compañero y proyecto local

Fuente: `Los_pinganillos 2.zip`, recibido el 14 de noviembre de 2026.
Comparación con la carpeta de trabajo local en `main` (`008f6f3`), no con la
versión más reciente del servidor ni con las carpetas de otros compañeros.

## Qué contiene el ZIP

- 96 archivos de proyecto, excluyendo `.git`, `.godot`, `__MACOSX`, `.DS_Store`
  y archivos auxiliares `._*` de macOS.
- Los 96 coinciden con sus equivalentes de la carpeta local al normalizar
  saltos de línea y espacios/saltos finales en archivos de texto. Los recursos
  binarios se compararon por hash. No hay escenarios o sistemas diferentes
  entre esos archivos comunes.
- Misma escena inicial: `main.tscn -> mars_base.tscn -> cuarto1.tscn`.
- Mismos sistemas Resources, SimulationTime, StationCost, TaskExecution y Events.
- Mismos tres archivos UID con marcadores de conflicto y mismas tres copias MSI
  con identificadores duplicados. El ZIP no corrige esos defectos.
- Incluye su propia caché `.godot` y metadatos Git/macOS. No se incorporan a la
  rama: no son una fuente fiable para compartir el estado del juego.

## Diferencia respecto de la carpeta local

La carpeta local contiene además cinco archivos de minijuegos sin registrar en
Git que no están en el ZIP:

- `game/challenges/electrical_repair/Cell.tscn`
- `game/challenges/electrical_repair/PipePiece.tscn`
- `game/challenges/solar_cleaning/SolarPanel.gd`
- `game/challenges/solar_cleaning/SolarPanel.gd.uid`
- `game/challenges/solar_cleaning/solar_cleaning.tscn`

Esos archivos sueltos no constituyen minijuegos completos y referencian recursos
ausentes. También hay tres `.DS_Store` locales, sin efecto en la lógica.
Que el ZIP funcione en otro equipo puede depender de su caché, de la escena que
ejecuta o de la versión del editor. No se verificó el equipo del compañero.

## Rama creada: feature/zip-base-minijuegos

Se copió el contenido fuente del ZIP y se mantuvieron sus escenarios originales,
assets y sistemas. Sobre esa base se aplicaron estos cambios:

- Minijuegos completos de reparación eléctrica y limpieza solar, incluyendo
  escenas, scripts, UID, cámaras, piezas/casillas reutilizables y documentación.
- Resolución de los tres `.uid` y eliminación de las escenas `-MSI`.
- Exclusión de metadatos del ZIP y eliminación de `.DS_Store` registrados.
- Ventana inicial de 1280×720; resolución de diseño conservada en 2560×1440.
- Herramientas de comprobación y guía para el equipo.

Respecto a `fix/godot-uids-escenas` (`ce17502`), los escenarios originales,
sistemas y minijuegos son equivalentes. Esta rama documenta la base del ZIP y
elimina además los tres `.DS_Store` registrados.

## Cómo abrirla

Abre el `project.godot` de esta rama. F5 inicia el juego original. Para probar
cada minijuego, abre su escena y pulsa F6:

- `game/challenges/electrical_repair/electrical_repair.tscn`
- `game/challenges/solar_cleaning/solar_cleaning.tscn`

Los minijuegos están disponibles como escenas independientes; no se conectan
automáticamente a las estaciones del mapa.
