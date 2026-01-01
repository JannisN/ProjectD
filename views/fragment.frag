#version 460 core
#extension GL_EXT_shader_image_load_formatted : enable

layout (location = 0) out vec4 o_color;
layout (location = 2) in vec2 uvout;
layout (set = 0, binding = 0) uniform image2D texelBuffer;

void main() {
	vec3 colour = vec4(imageLoad(texelBuffer, ivec2(uvout.x, uvout.y))).xyz;
	float alpha = vec4(imageLoad(texelBuffer, ivec2(uvout.x, uvout.y))).a;
	o_color = vec4(0.3 * colour, alpha);
}
