# Reparación de tuberías
Abre frozen_pipe.tscn y pulsa F6. Es independiente: termina al reparar las dos tuberías y NO inicia el bombeo. Cada partida pide dos piezas distintas, elegidas entre los 4 repuestos de FACIL o los 5 de NORMAL. Arrastra con ratón o toque; después mantén pulsados los tres tornillos de cada tubería. El progreso incompleto retrocede al soltar.

## Nodos y frontend
- FrozenPipe.gd configura dificultad, centra Content y emite completed una sola vez.
- RepairPhase.gd gestiona selección aleatoria, arrastre, acoplamiento y tornillos.
- Pipe1 y Pipe2 son instancias persistentes de PipeSlot.tscn. Puedes moverlas en 2D; Gap define el área de recepción.
- SparePiece.tscn y Screw.tscn son reutilizables. Asigna texturas a Artwork desde el Inspector y oculta Placeholder y Symbol cuando tengas arte. Conserva sus nombres y los nodos de interacción.
- En PipeSlot, asigna arte a PipeLeft/Artwork y PipeRight/Artwork. Gap/Symbol identifica el repuesto requerido; puedes sustituir esa presentación por iconos según requirements.
- Las piezas instaladas conservan el tamaño del Control. Las hitboxes usan el rectángulo de cada Control y las coordenadas del canvas, por lo que siguen funcionando al mover nodos o escalar Content.
- Cambia difficulty en el nodo raíz. Conecta completed desde el juego principal para decidir qué ocurre al finalizar.

No hay mensaje educativo final. El bombeo está separado en ../water_pumping/water_pumping.tscn, con scripts propios y sin dependencias de esta escena.
