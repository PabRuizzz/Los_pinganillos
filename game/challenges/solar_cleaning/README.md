# Limpieza de paneles solares

Abre `solar_cleaning.tscn` y pulsa **F6**. Es independiente de las otras escenas,
sin assets externos ni autoloads. La imagen de referencia no se ha integrado:
este prototipo muestra únicamente rejillas y colores de estado.

- Seis paneles en dos filas de tres, separados por espacios sin superficie limpiable.
- Cada panel tiene 10×10 casillas de igual área: marrón = sucio, azul = limpio.
- Mantén clic izquierdo y mueve el círculo para limpiar. Pasar sin pulsar no limpia.
- El contacto círculo-rectángulo cambia la casilla completa a limpia. El porcentaje
  es discreto por casillas, no una máscara de píxeles: cada casilla representa 1%.
- Debes limpiar al menos el 90% **de cada panel** (90 de 100 casillas en cada uno).
- No hay temporizador. Suelta el botón o pulsa Escape para detener el agua.
- Perder el foco también detiene el agua. Pulsa **R** para reiniciar.

## Nodos y lógica

La raíz es Node2D y contiene estos nodos editables:

```text
SolarCleaning
├── Camera2D
├── Backdrop/Background
├── World
│   ├── Panels/Panel1 ... Panel6
│   └── WaterSpray/Artwork
└── Interface (CanvasLayer)
    └── HUD/Content
        ├── Instructions
        └── Status
```

`SolarPanel.tscn` es la plantilla de un panel; contiene `Artwork` (TextureRect)
y `Cells`, con 100 instancias de `SolarCell.tscn`. Hay 600 casillas persistentes
en total, visibles en el editor 2D. `SolarPanel.gd` guarda los estados y cuenta
las casillas; `SolarCell.gd` representa cada estado y su hitbox. Las colisiones
respetan las posiciones, rotaciones y escalas de las instancias de panel.

### Añadir imágenes sin modificar la lógica

- Imagen del panel completo: abre `SolarPanel.tscn`, selecciona `Artwork` y
  asigna `Texture`. Al limpiar, las casillas transparentes revelan esa imagen.
- Texturas por casilla: abre `SolarCell.tscn`, asigna imágenes a `DirtyArtwork`
  y/o `CleanArtwork`. Son compartidas por todas sus instancias. Los colores
  marrón/azul siguen siendo la representación provisional si no hay imagen.
- Cursor de agua/pistola: asigna una textura al Sprite2D `World/WaterSpray/Artwork`.
  Su imagen es independiente del radio de colisión, editable en `WaterSpray → Radius`.
- Mantén `Mouse Filter = Ignore` en los TextureRect para no interceptar la entrada.
- Para cambiar un solo panel, activa **Editable Children / Hijos editables** en
  su instancia y asigna una textura propia. Mueve los paneles desde `World/Panels`.
- No renombres los nodos utilizados por los scripts. La rejilla permanece en
  10×10; modifica los assets del nodo base para cambiar su apariencia común.

### Cámara

`Camera2D` encuadra automáticamente los seis paneles al iniciar o redimensionar.
Para controlarla manualmente, desactiva **Auto Frame Panels** y ajusta Position
y Zoom. La interfaz permanece fija en `Interface`, un CanvasLayer independiente.
El círculo y la limpieza siguen las coordenadas del ratón con cualquier zoom.

Los textos son indicadores de prueba, sin diseño visual final. No se modifica
la escena principal del proyecto ni se integra todavía la imagen de referencia.

Para integrarlo, conecta `cleaning_completed` o `cleaning_progress_changed(ratio)`.
Esta última señal informa el porcentaje total (0–1); completar requiere que los
seis paneles cumplan el umbral individual. `reset()` reinicia la partida.
Como escena Node2D con cámara, puede ejecutarse directamente o aislarse en un
SubViewport. Si comparte viewport con otro juego, el anfitrión debe gestionar
qué cámara está activa.

## Pruebas

```sh
godot --headless --path . --script res://game/challenges/solar_cleaning/tests/test_cleaning.gd
```

Se prueban estados, contacto circular, clic mantenido/liberado, movimientos
rápidos, umbral exacto 89%/90%, reinicio, foco, cambio de tamaño, zoom y movimiento
de cámara, HUD fijo, paneles transformados y conservación de texturas.
