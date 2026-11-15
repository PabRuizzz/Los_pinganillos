# Contención de hongos

Abre greenhouse_fungus.tscn y pulsa F6. Cada partida empieza con una única planta infectada. Enciende la luz UV para identificarla y usa CERRAR en las rutas de contagio para levantar barreras entre las macetas.

Pulsa una planta infectada para abrir ManualTreatment.tscn. Aplica fungicida a cada mancha pulsándola. Al eliminar la última, vuelves automáticamente a la mesa. La maceta tratada queda sana. Cada vecina sana conectada a ella por una ruta abierta queda infectada. Las barreras bloquean el contagio. Al sanar todas las plantas, el minijuego emite completed. No hay temporizador interno.

## Frontend

- Content/Artwork muestra la mesa del invernadero. El fondo y la maceta se generaron con ImageGen y están en assets/ junto a los prompts.
- Plants contiene cuatro instancias de Plant.tscn. Artwork muestra la maceta y Spores indica la infección con la luz UV encendida.
- Routes contiene las instancias de Barrier.tscn. Los índices Left Plant y Right Plant corresponden al orden de las plantas. Gate es la barrera visible entre las macetas.
- ManualTreatment.tscn reutiliza el arte de la maceta a mayor tamaño. Puedes mover las instancias de FungusSpot.tscn sobre las hojas desde el editor 2D. El contador se adapta al número de manchas.
- La escena principal emite completed para que el juego anfitrión pueda resolver el evento del invernadero.
