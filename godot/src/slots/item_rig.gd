class_name ItemRig
extends AssetSlot
## A slot for something the player can carry (lug wrench, spare wheel, jack). The wrapper scene
## has a `Grip` marker: the point and orientation that sit in the character's hand socket.
## It lives outside the model, so it survives a model swap; nudge it per real model.

@onready var grip: Marker3D = get_node_or_null(^"Grip") as Marker3D


## Local transform to use under a hand socket so the grip lands in the hand.
func hold_transform() -> Transform3D:
	return grip.transform.affine_inverse() if grip else Transform3D.IDENTITY
