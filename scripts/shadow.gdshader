shader_type canvas_item;

void fragment(){
  COLOR = texture(TEXTURE, UV); // Read from texture again.
  COLOR.r = 0.0; //set blue channel to 1.0
  COLOR.g = 0.0; //set blue channel to 1.0
  COLOR.b = 0.0; //set blue channel to 1.0

  COLOR.a = COLOR.a * 0.3; //set blue channel to 1.0
}