# Fugas de aire
Abre air_leaks.tscn y pulsa F6. Mueve el ratón o arrastra el dedo por los paneles. El pitido acelera y el indicador pasa de azul a rojo al acercarte a una fuga sin reparar. Pulsa sobre ella y arrastra uno de los tres parches de la bandeja hasta la fuga descubierta. Si lo sueltas fuera, sobre una fuga oculta o sobre una reparada, vuelve suavemente a su posición inicial sin consumirse. Los clics vacíos no penalizan. Finaliza al reparar tres fugas y emite completed una vez.

## Estructura
- AirLeaks (Control): AirLeaks.gd configura dificultad, posiciones, selección, contador y final.
- Content/Habitat: seis instancias invisibles de WallPanel.tscn bajo Panels, tres de Leak.tscn y Detector.
- Leak.gd: estados HIDDEN, FOUND y REPAIRED; solo FOUND admite parche.
- Detector.gd: distancia a la fuga sin reparar más cercana, color y pitido generado sin archivos externos.
- Content: Reading, Counter, Patch1…3 y Reaction son interfaz editable. ReactionTimer limpia los mensajes breves.

FACIL: radio de clic 40, alcance de señal 500. NORMAL: radio 24, alcance 260. Las unidades son locales al hábitat, independientes del escalado de ventana. Las posiciones usan seis regiones barajadas con variación de ±10; La posición de cada fuga se adapta al tamaño de la zona de búsqueda.

## Frontend
Todos los nodos existen en el editor 2D. Mueve Content/Habitat y los controles de interfaz desde el editor. La posición de las fugas cambia al iniciar, y la de Detector sigue al puntero; sus visuales pueden editarse en sus nodos hijos.

Los PNG activos están por separado en assets/. WallArtwork cubre toda la ventana con la textura de pared. La zona de búsqueda se extiende entre las franjas de la interfaz. Los paneles de Habitat/Panels se mantienen invisibles durante la partida y sus centros determinan las zonas de aparición. Activa temporalmente su visibilidad en el editor para colocarlos y vuelve a ocultarlos al guardar.

Detector/Artwork muestra la pistola. Indicator cambia de color y su hijo Aim marca el punto central que coincide con el cursor. Si cambias la imagen, ajusta Offset para que la pantalla coincida con Indicator. Leak/Visual/Artwork muestra la X al descubrir la fuga y la oculta al sellarla.

Detector/Beep admite un AudioStream desde el Inspector. Si está vacío genera un tono corto automáticamente. Ajusta volume_db allí; Indicator controla la pista de color. No requiere cámara ni escenas externas. Conecta completed desde el proyecto principal para decidir la siguiente acción.

Prueba mínima: ejecutar tests/smoke.gd mediante Godot --headless --path . --script res://game/challenges/air_leaks/tests/smoke.gd.

## Parches arrastrables
Patch.tscn es reutilizable y tiene un Control como hitbox. LoosePlate muestra el parche con orificios. SealedPlate muestra el mismo metal con tornillos instalados. Cambia las texturas en el Inspector. Patch.gd gestiona el arrastre y el retorno. AirLeaks.gd valida que el parche se suelte sobre una fuga descubierta.
