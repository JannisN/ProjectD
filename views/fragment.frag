#version 450 core

layout (location = 0) out vec4 o_color;
layout (set = 0, binding = 0, rgba8) uniform image2D texelBuffer;

void main() {
	o_color = vec4(imageLoad(texelBuffer, ivec2(2, 2)).xyz, 0.5f);
}