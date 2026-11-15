# Bombeo independiente
Abre water_pumping.tscn y pulsa F6. Pulsa ESPACIO/ENTER o BOMBEAR cuando el centro de la línea blanca móvil esté dentro de la zona verde de la barra inferior. Acierto: sube agua; fallo: baja ligeramente. El nivel disminuye 3 puntos porcentuales por segundo mientras juegas y se detiene al ganar. Puedes ajustar drain_per_second en PumpPhase desde el Inspector. Al llenar el depósito, el nodo raíz emite completed una vez.

WaterPumping.gd configura FACIL/NORMAL, adapta Content a la ventana y gestiona el final. PumpPhase.gd controla exclusivamente el ritmo, la zona válida y el nivel del depósito. No carga ni inicia el juego de tuberías.

## Frontend
Todos los nodos son persistentes y visibles en 2D. Mueve Tank, Bar y PumpButton desde el editor. Asigna imágenes en Tank/Artwork. Tank/Water se llena de izquierda a derecha; la barra lateral de flujo se ha eliminado. Puedes añadir TextureRect con mouse_filter Ignore bajo Bar/Green y Bar/Marker; conserva estos nodos porque representan la zona y la línea móvil. La línea mide 8 x 64 y sobresale a ambos lados de la barra para que sea visible. Su posición y el ancho de Green se actualizan según la dificultad: 16% de la barra en FACIL y 10% en NORMAL (la mitad que antes). Conserva Tank/Water y Tank/Percent para mostrar el nivel, y Hint para resultados de cada pulsación.

Solo placeholders; no assets externos ni mensaje «Sabías que».
