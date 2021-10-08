#version 450 core

layout (location = 0) out vec4 o_color;
layout (location = 2) in vec2 uvout;
layout (set = 0, binding = 0, rgba8) uniform image2D texelBuffer;

void main() {
	o_color = vec4(imageLoad(texelBuffer, ivec2(uvout.x, uvout.y)).xyz, imageLoad(texelBuffer, ivec2(uvout.x, uvout.y)).w);
}