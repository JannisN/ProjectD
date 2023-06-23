#version 450 core

layout (location = 0) out vec4 o_color;
layout (location = 2) in vec2 uvout;

void main() {
	o_color = vec4(1.0, 0.5, 0.5, 1.0);
}