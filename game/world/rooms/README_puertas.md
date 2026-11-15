# Puertas y puntos de llegada

El origen de `astronaut.tscn` coincide con el centro de su CollisionShape2D. No desplaces el sprite, la colisión y la cámara cientos de píxeles respecto al personaje: mueve la instancia completa en cada escenario.

En cada puerta configura:
- `Cuarto Destino`: ruta `res://...tscn` de la escena que se abrirá.
- `Nombre Spawn`: nombre único o ruta de un Marker2D en la escena de destino.

Los Marker2D se pueden mover desde el editor 2D. Deben estar sobre suelo transitable y separados del área de la puerta por el tamaño del cuerpo del jugador. El jugador coloca su centro de colisión exactamente en ese marcador.

Invernadero y campamento usan `SpawnFromMars`. Para volver a Marte se usan `spawpoints/greenhousespw` y `spawpoints/campspw` (las puertas admiten también el nombre único). Los cuartos de prueba usan `SpawnTop` y `SpawnBottom`.

La transición se bloquea mientras se cambia de escena para evitar llamadas duplicadas. El jugador consume el marcador antes de reactivar su movimiento. `puerta_2.gd` hereda la misma lógica de `puerta.gd`.

Prueba breve de las rutas existentes, posición y colisiones:
`godot --headless --path . --script res://game/world/rooms/tests/test_door_spawns.gd`

La partida empieza junto a la cama del campamento. La posición inicial es la de la instancia player en campament.tscn. SpawnFromMars se usa al volver desde el exterior.
