#version 460 core

struct Drawable {
    float posX, posY, posZ;
    float scaleX, scaleY, scaleZ;
    float rotX, rotY, rotZ;
    float r, g, b;
    uint modelId;
};

layout (location = 0) out vec4 o_color;
//layout (location = 2) in vec2 uvout;
layout (location = 2) in vec3 normalOut;
layout (location = 3) in float rotXout;
layout (location = 4) in float rotYout;
layout (location = 5) flat in Drawable drawable;

void main() {
	//o_color = vec4(colour, 1.0);
	o_color = vec4((0.5 * dot(normalize(vec3(-1, -1, -1)), normalOut) + 0.5) * vec3(drawable.r, drawable.g, drawable.b), 1.0);
}