#version 450 core

layout (location = 0) out vec4 o_color;
//layout (location = 2) in vec2 uvout;
layout (location = 2) in vec3 normalOut;
layout (location = 3) in float rotXout;
layout (location = 4) in float rotYout;

void main() {
    /*mat3 rotXinv = mat3(
        cos(-rotX), 0, sin(-rotX),
        0, 1, 0,
        -sin(-rotX), 0, cos(-rotX)
    );
    mat3 rotYinv = mat3(
        1, 0, 0,
        0, cos(-rotY), sin(-rotY),
        0, -sin(-rotY), cos(-rotY)
    );*/
	o_color = vec4((0.5 * dot(normalize(vec3(-1, -1, -1)), normalOut) + 0.5) * vec3(0.5, 1.0, 0.5), 1.0);
}