# Fugas de aire
Abre air_leaks.tscn y pulsa F6. Mueve el ratón o arrastra el dedo por los paneles. El pitido acelera y el indicador pasa de azul a rojo al acercarte a una fuga sin reparar. Pulsa sobre ella y arrastra uno de los tres parches de la bandeja hasta la fuga descubierta. Si lo sueltas fuera, sobre una fuga oculta o sobre una reparada, vuelve suavemente a su posición inicial sin consumirse. Los clics vacíos no penalizan. Finaliza al reparar tres fugas y emite completed una vez.

## Estructura
- AirLeaks (Control): AirLeaks.gd configura dificultad, posiciones, selección, contador y final.
- Content/Habitat: seis instancias persistentes de WallPanel.tscn, tres de Leak.tscn y Detector.
- Leak.gd: estados HIDDEN, FOUND y REPAIRED; solo FOUND admite parche.
- Detector.gd: distancia a la fuga sin reparar más cercana, color y pitido generado sin archivos externos.
- Content: Reading, Counter, Patch1…3 y Reaction son interfaz editable. ReactionTimer limpia los mensajes breves.

FACIL: radio de clic 40, alcance de señal 500. NORMAL: radio 24, alcance 260. Las unidades son locales al hábitat, independientes del escalado de ventana. Las posiciones usan seis regiones barajadas con variación de ±10; distancia mínima garantizada 180, superior al requisito de 160.

## Frontend
Todos los nodos existen en el editor 2D. Mueve Content/Habitat y los controles de interfaz desde el editor. La posición de las fugas cambia al iniciar, y la de Detector sigue al puntero; sus visuales pueden editarse en sus nodos hijos.

Asigna texturas en WallPanel/Artwork, Leak/Visual/Artwork y Detector/Artwork. Oculta los Placeholder o Symbol cuando incorpores arte. Visual de Leak se oculta durante HIDDEN para no revelar su posición. Para arte diferente según estado, amplía Leak._refresh manteniendo la lógica de discover y patch. Los controles decorativos deben conservar Mouse Filter = Ignore para no bloquear la exploración. Habitat recibe la entrada local, incluyendo el escalado de Content; los tres parches parten de una bandeja fuera de la zona de exploración.

Detector/Beep admite un AudioStream desde el Inspector. Si está vacío genera un tono corto automáticamente. Ajusta volume_db allí; Indicator controla la pista de color. No requiere cámara ni escenas externas. Conecta completed desde el proyecto principal para decidir la siguiente acción.

Prueba mínima: ejecutar tests/smoke.gd mediante Godot --headless --path . --script res://game/challenges/air_leaks/tests/smoke.gd.

## Parches arrastrables
Patch.tscn es una escena reutilizable con hitbox Control, Placeholder, Artwork y Symbol. Asigna la textura a Artwork y oculta Placeholder/Symbol cuando tengas arte. Sus tres instancias son persistentes y pueden moverse desde el editor. Patch.gd gestiona el movimiento, retorno y bloqueo tras usarlo; AirLeaks.gd valida que el punto donde se suelta coincida con una fuga FOUND. Funciona con ratón y toque.
