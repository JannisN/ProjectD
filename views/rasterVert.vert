#version 450 core

layout (location = 0) in vec3 pos;
layout (location = 1) in vec3 normal;
layout (location = 2) out vec3 normalOut;
//layout (location = 1) in vec2 uv;
//layout (location = 2) out vec2 uvout;

struct Sphere {
	float x, y, z;
	float radius;
};
layout (set = 0, binding = 1) buffer sphereList_t {
	Sphere spheres[];
} sphereList;

void main() {
	//uvout = uv;
	normalOut = normal;
	Sphere sphere = sphereList.spheres[gl_InstanceIndex];
	//gl_Position = vec4(pos, 1);
	gl_Position = vec4(pos * 0.1 + 0.1 * vec3(sphere.x, sphere.y, sphere.z), 1);
}