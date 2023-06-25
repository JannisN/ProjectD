#version 450 core

layout (location = 0) in vec3 pos;
layout (location = 1) in vec3 normal;
layout (location = 2) out vec3 normalOut;
//layout (location = 1) in vec2 uv;
//layout (location = 2) out vec2 uvout;

void main() {
	//uvout = uv;
	normalOut = normal;
	gl_Position = vec4(pos, 1);
}