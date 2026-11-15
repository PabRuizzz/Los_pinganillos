# Bombeo de agua

Abre `water_pumping.tscn` y pulsa **F6**. Pulsa Espacio, Enter o **BOMBEAR** cuando la aguja llegue a la ventana verde y aparezca **LISTO**. El visor muestra el nivel real de agua. Los aciertos producen un pulso cian en una tubería y los fallos iluminan brevemente el botón. Al llenar el depósito se muestra **Circulación restablecida** y la raíz emite `completed` una vez.

## Frontend

- `Content/Artwork` usa `assets/water_processor_console.png`, la versión del fondo generada con ImageGen. El prompt está en la misma carpeta.
- `Content/PumpPhase` contiene la consola y sus controles editables desde el editor 2D. `Tank/Water` se llena de izquierda a derecha. `Bar/Green` y `Bar/Marker` indican la ventana y la aguja. Conserva sus nombres al cambiar su arte.
- `Content/PipePulse` delimita el tramo de cristal animado en la tubería derecha. Mueve ese nodo si sustituyes la ilustración. `Glow` se recorta al recorrerlo.
- Ajusta el estilo en los recursos de la escena y la dificultad en el Inspector de la raíz. `PumpPhase.gd` controla el ritmo, el nivel y la realimentación visual. `WaterPumping.gd` encuadra la consola y emite la señal de finalización.
