#version 450 core

layout (location = 0) out vec4 o_color;
//layout (location = 2) in vec2 uvout;
layout (location = 2) in vec3 normalOut;

void main() {
	o_color = vec4((0.5 * dot(normalize(vec3(-1, -1, -1)), normalOut) + 0.5) * vec3(0.5, 1.0, 0.5), 1.0);
}