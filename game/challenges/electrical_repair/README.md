# Minijuego de reparación eléctrica

Abre `electrical_repair.tscn` y pulsa **F6** (ejecutar escena actual).
La escena no utiliza autoloads ni otras escenas del juego. Sus imágenes están en assets/.
La escena principal del proyecto sigue siendo la misma.

## Controles

- Mantén el botón izquierdo para arrastrar una pieza.
- Suelta en una casilla vacía para moverla o sobre una pieza para intercambiarlas.
- Suelta fuera del tablero, pulsa Escape o cambia de aplicación para cancelar el arrastre.
- Conecta el terminal de inicio verde con la única salida ámbar, siempre situada en
  el borde opuesto: norte–sur, sur–norte, este–oeste u oeste–este.
  La posición dentro de cada borde es aleatoria; no tienen que estar alineados.
- Debe haber al menos **10 piezas conectadas** a la red del inicio para ganar.
- Cada tablero contiene **dos grupos de 2–5 casillas bloqueadas**, adyacentes por
  sus lados y representadas por placas elevadas sin símbolos. No admiten piezas; al soltar sobre ellas el cable vuelve a su origen.
- El tinte verde de los cables muestra la red que recibe corriente del inicio.
- No hay temporizador, límite de movimientos ni rotación de piezas.
- `Ver hitboxes` muestra las casillas en cian y las piezas en rosa.

## Trabajo visual de frontend en el editor 2D

Abre `electrical_repair.tscn` en **2D**. La interfaz ya es un árbol de nodos
guardado, no se crea por código. `Board` está directamente bajo la raíz Node2D.
Dentro de `Interface/HUD/Content` puedes mover los Labels y los botones,
cambiar fuentes, colores y temas, o añadir decoración.
Esas posiciones se conservan al jugar. `Content` es el lienzo de diseño que se
escala automáticamente; mueve sus hijos para cambiar la composición.
No renombres los nodos que utiliza el manager.

`Board.tscn` contiene `Cells` con las 64 casillas, `PreviewPieces` con muestras
de los 11 cables y `Pieces`, donde se colocan los cables de la partida.
Las muestras solo se muestran en el editor y se ocultan al jugar.
La cuadrícula mantiene sus posiciones uniformes al generar cada partida;
para desplazarla completa mueve `Board`, no casillas individuales.

### Cámara

Selecciona `Camera2D` en el árbol de la escena. Por defecto, **Auto Frame Board**
está activado: `PuzzleCamera.gd` centra el tablero y adapta el zoom al tamaño del
viewport al iniciar y al redimensionar. El HUD utiliza la misma escala de diseño
para que queden visibles el título, la salida y los botones.

Para encuadrar manualmente, desactiva **Auto Frame Board** en el Inspector.
Después cambia **Transform → Position** y **Zoom**, o arrastra la cámara en 2D.
En modo manual esos valores se conservan. Mantén Enabled activado.

En `project.godot` la resolución de diseño sigue siendo 2560×1440, pero la ventana
inicial es 1280×720 mediante Window Width/Height Override. Esto afecta al tamaño
inicial de la ventana de todo el proyecto y evita abrir una ventana de 2560×1440
que pueda quedar recortada. El modo de escalado sigue siendo `canvas_items`.
El porcentaje mostrado en la vista 2D del editor es su zoom de edición, no el zoom
de Camera2D ni el tamaño de la ventana al jugar.

La interfaz está en `Interface` (CanvasLayer), por lo que permanece fija aunque
muevas la cámara. El fondo está en `Backdrop`, detrás del tablero. Las hitboxes
y el arrastre convierten las coordenadas del ratón según la vista de la cámara.

Para añadir imágenes a los cables:

1. Abre una escena de `pieces/`, por ejemplo `Horizontal.tscn` o `Cross.tscn`.
2. Selecciona su hijo `Artwork` (TextureRect).
3. Arrastra la imagen al campo **Texture** del Inspector y guarda la escena.
4. Abre la escena principal y pulsa **F6**: las piezas generadas usan esa escena
   y su imagen. Las muestras del tablero también comparten esa apariencia.

Las variantes heredan de `PipePiece.tscn`; edita esa base para cambios visuales
comunes. Puedes cambiar tamaño y offsets de `Artwork` sin alterar la hitbox del
Control raíz. Su Mouse Filter debe seguir en Ignore para permitir el arrastre.
Sin textura se dibujan líneas; con textura las líneas se ocultan automáticamente.
Las imágenes se tiñen de verde al recibir corriente. Conserva las conexiones
asignadas a cada variante para que el dibujo y la lógica coincidan.

`Cell.tscn` también incluye un `Artwork` para personalizar el fondo común de las
casillas. Usa transparencia si quieres conservar visibles las marcas de bloqueo.
En una instancia, activa **Editable Children / Hijos editables** si necesitas
seleccionar sus nodos internos, o abre directamente su escena de origen.

## Arquitectura

- `PuzzleManager.gd`: interfaz, partida, movimientos y señales de integración.
- `Board.gd`: cuadrícula equivalente a GridContainer, arrastre e intercambio atómico.
- `Cell.gd`: coordenadas, ocupante, estado de ocupación y hitbox Control de 80×80.
- `PipePiece.gd`: conexiones, dibujo, hitbox Control independiente de 70×70.
- `PuzzleGenerator.gd`: árbol aleatorio, poda de ramas sin destinos y mezcla de su inventario exacto.
- `ConnectionValidator.gd`: BFS pura con comprobación recíproca de conexiones y puertos de destino.

Las conexiones son una máscara de bits: norte 1, este 2, sur 4, oeste 8.
Las 11 variantes de pieza siguen disponibles para futuras ampliaciones. La
generación actual crea una ruta única sin ramificaciones, por lo que utiliza
rectas y curvas; no añade T ni cruces innecesarias.
La solución generada tiene al menos 10 piezas. Los obstáculos se generan antes
que las rutas y la mezcla solo utiliza casillas habilitadas. Los grupos se
mantienen separados para que ningún conjunto conectado supere 5 casillas.
Los terminales son puertos fijos del borde, no piezas adicionales. El jugador
puede mover las piezas que ocupan sus casillas. No se exige cerrar otras ramas:
la victoria requiere una conexión válida desde I hasta cada destino y un mínimo
de 10 piezas en la red conectada al inicio.

Antes de entregar un nivel, `PuzzleGenerator.has_valid_solution()` comprueba que
la solución conecta la entrada con la salida, contiene al menos 10 piezas, no ocupa
obstáculos y utiliza exactamente el mismo inventario (incluidas orientaciones)
que el tablero mezclado. Si falla, se descarta y se genera otro candidato.
Esto permite reconstruir la solución mediante los intercambios libres del juego,
sin rotar piezas ni atravesar casillas bloqueadas.

## Integración futura

Ejecuta `electrical_repair.tscn` como escena independiente o instánciala dentro
del mundo Node2D. También puede aislarse en su propio SubViewport. Su Camera2D
controla la vista del viewport; si se comparte con otras cámaras, el anfitrión
debe gestionar cuál está activa y restaurar la anterior al salir del minijuego.
Conecta `puzzle_completed(moves, seed_value)` para continuar el juego.
También existe `puzzle_started(seed_value, destinations)`.
El minijuego no pausa ni cambia escenas por su cuenta.

Siempre se genera una sola salida; ya no existe `destination_count`.
Configura `puzzle_seed` en -1 para partidas nuevas. Una semilla no negativa permite reproducir una partida;
la semilla determina la partida al abrirla. La interfaz adapta su
escala al tamaño del viewport y centra el lienzo de diseño del HUD. El tablero
se visualiza mediante Camera2D: su encuadre automático se adapta junto al HUD,
o puede ajustarse independientemente desactivando Auto Frame Board.

## Pruebas

Desde la raíz del proyecto, con Godot en PATH:

```sh
godot --headless --path . --script res://game/challenges/electrical_repair/tests/test_puzzle.gd
```

Comprueban 1000 semillas, inventario exacto, todas las variedades de pieza,
conexiones recíprocas, salida única en el borde opuesto, inicio sin resolver, intercambios,
retorno al origen, cancelación, victoria única y reinicio.
También verifican el mínimo de 10 piezas, el tamaño y la separación de los grupos
bloqueados, los intentos de colocar cables sobre obstáculos, las hitboxes y el
arrastre mediante eventos de ratón con tres niveles de zoom y cámara desplazada,
así como la independencia del HUD respecto a la cámara.

Validación ampliada de resolubilidad:

```sh
godot --headless --path . --script res://game/challenges/electrical_repair/tests/test_solvability.gd
```

Comprueba 10.000 semillas, verifica la salida única en el borde opuesto y las
conexiones de la solución y resuelve 200 partidas mediante las operaciones reales
de arrastre/intercambio del tablero y sus señales de victoria. También comprueba
que se rechazan inventarios con piezas de más/de menos y soluciones bloqueadas.

## Assets sci-fi integrados

El atlas aprobado está en `assets/navy_tiles.png`. Los recursos `.tres` son AtlasTexture con recortes del atlas original: no requieren procesamiento ni plugins. Las once escenas de `pieces/` asignan el recorte correspondiente a Artwork; todas mantienen sus conexiones y hitboxes originales. Puedes sustituir cada textura desde el Inspector.

Cell.tscn incluye Artwork para la casilla vacía, Blocked Texture para los bloqueos y Source/Target Texture para los terminales. Terminal es un nodo visual elevado, fuera del borde del tablero, y no intercepta el ratón. El exterior conserva el fondo liso; solo las cajas verde y naranja aparecen fuera del tablero, orientadas hacia su conexión.

La propuesta y su prompt se conservan en `assets/proposals/`. Verificación breve: carga de texturas, solución válida, retorno al soltar fuera y colocación/intercambio de piezas.

La versión activa usa cables gruesos azul oscuro. `south_east.tres` y `south_west.tres` se asignan según sus conexiones reales en la imagen. Las placas bloqueadas no llevan X ni naranja.
