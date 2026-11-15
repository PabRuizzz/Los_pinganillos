extends PanelContainer

# Tarjeta de una muestra en la galería de la pantalla final: foto y nombre.

@onready var artwork: TextureRect = $VBox/Artwork
@onready var name_label: Label = $VBox/NameLabel


func set_sample(sample: RockSampleData):
	artwork.texture = sample.sample_image
	name_label.text = sample.sample_name
	tooltip_text = "%s\n%s" % [sample.rock_type, sample.location]
