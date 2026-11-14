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

`solar_cleaning.tscn` contiene seis instancias de `SolarPanel.tscn`, visibles en el
editor 2D. `SolarPanel.gd` guarda los estados, cuenta las casillas y comprueba el
contacto círculo-rectángulo. `WaterSpray.gd` dibuja el círculo; su `radius` se puede
editar en el Inspector. `SolarCleaning.gd` controla la entrada, interpola los
movimientos rápidos, adapta la escala y verifica el objetivo.

`Stage/Panels` es un agrupador en el origen: mueve las instancias de los paneles
dentro de él para cambiar su distribución. Los textos son indicadores de prueba,
sin diseño visual final. La escena principal del proyecto no se modifica.

Para integrarlo, conecta `cleaning_completed` o `cleaning_progress_changed(ratio)`.
Esta última señal informa el porcentaje total (0–1); completar requiere que los
seis paneles cumplan el umbral individual. `reset()` reinicia la partida.

## Pruebas

```sh
godot --headless --path . --script res://game/challenges/solar_cleaning/tests/test_cleaning.gd
```
