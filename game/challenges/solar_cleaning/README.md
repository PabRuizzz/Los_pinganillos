# Limpieza de paneles solares

Abre `solar_cleaning.tscn` y pulsa **F6**. Es independiente de las otras escenas,
sin autoloads. Incluye las imágenes proporcionadas, copiadas a
`game/challenges/solar_cleaning/assets/`: panel solar limpio y textura de polvo marciano.

- Seis paneles en dos filas de tres, separados por espacios sin superficie limpiable.
- Cada panel tiene 20×20 casillas de igual área: polvo semitransparente = sucio; imagen azul visible = limpio.
- Mantén clic izquierdo y mueve el círculo para limpiar. Pasar sin pulsar no limpia.
- El contacto círculo-rectángulo cambia la casilla completa a limpia. El porcentaje
  es discreto por casillas, no una máscara de píxeles: cada casilla representa 0,25%.
- Debes limpiar el 100% **de cada panel** (400 de 400 casillas en cada uno).
- No hay temporizador. Suelta el botón o pulsa Escape para detener el agua.
- Perder el foco también detiene el agua.

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
y `Cells`, con 400 instancias de `SolarCell.tscn`. Hay 2400 casillas persistentes
en total, visibles en el editor 2D. `SolarPanel.gd` guarda los estados y cuenta
las casillas; `SolarCell.gd` representa cada estado y su hitbox. Las colisiones
respetan las posiciones, rotaciones y escalas de las instancias de panel.

### Añadir imágenes sin modificar la lógica

- Imagen del panel completo: abre `SolarPanel.tscn`, selecciona `Artwork` y
  asigna `Texture`. Al limpiar, las casillas transparentes revelan esa imagen.
- Suciedad: ajusta `Dust Texture` y `Dust Opacity` en SolarPanel (0,58 por defecto: 42% de transparencia). Cada
  `DirtyArtwork` recibe un AtlasTexture con su recorte de la textura; así forma
  una capa continua. Una casilla limpia oculta su recorte, revelando Artwork.
- `Show Grid` en SolarCell permite mostrar los límites para depurar.
- El nodo Frame usa un StyleBoxFlat editable para el borde metálico y la sombra.
  Readout muestra el porcentaje del panel y cambia de color al alcanzar el 100%.
- Cursor de agua/pistola: asigna una textura al Sprite2D `World/WaterSpray/Artwork`.
  Su imagen es independiente del radio de colisión, editable en `WaterSpray → Radius`.
- Mantén `Mouse Filter = Ignore` en los TextureRect para no interceptar la entrada.
- Para cambiar un solo panel, activa **Editable Children / Hijos editables** en
  su instancia y asigna una textura propia. Mueve los paneles desde `World/Panels`.
- No renombres los nodos utilizados por los scripts. La rejilla permanece en
  20×20; modifica los assets del nodo base para cambiar su apariencia común.

### Cámara

`Camera2D` encuadra automáticamente los seis paneles al iniciar o redimensionar.
Para controlarla manualmente, desactiva **Auto Frame Panels** y ajusta Position
y Zoom. La interfaz permanece fija en `Interface`, un CanvasLayer independiente.
El círculo y la limpieza siguen las coordenadas del ratón con cualquier zoom.

Backdrop/Background usa martian_dust.png; Shade oscurece el fondo para que
los paneles destaquen. La opacidad de la suciedad es independiente de ese fondo.
Las imágenes y los nodos siguen siendo editables desde el Inspector.

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

La prueba básica verifica 400 casillas por panel, la transparencia y desaparición
de la suciedad, el límite exacto de 399/400 casillas en los seis paneles,
una única victoria, reinicio e interacción con desplazamiento y zoom de cámara.
