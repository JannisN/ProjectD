#version 450 core

layout (location = 0) in vec4 pos;
layout (location = 1) in vec2 uv;
layout (location = 2) out vec2 uvout;

void main() {
	uvout = uv;
	gl_Position = vec4(pos.xy * 0.01, 1, 1);
}