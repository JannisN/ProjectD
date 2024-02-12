#version 450 core

layout (location = 0) in vec3 pos;
layout (location = 1) in vec3 normal;
layout (location = 2) out vec3 normalOut;
//layout (location = 1) in vec2 uv;
//layout (location = 2) out vec2 uvout;
layout (location = 3) out float rotXout;
layout (location = 4) out float rotYout;

layout (push_constant) uniform mypc_t {
	vec3 pos;
    float rotX, rotY;
    float screenRatio;
} mypc;

struct Sphere {
	float x, y, z;
	float radius;
};
layout (set = 0, binding = 1) buffer sphereList_t {
	Sphere spheres[];
} sphereList;

void main() {
	rotXout = mypc.rotX;
	rotYout = mypc.rotY;
    mat3 rotX = mat3(
        cos(mypc.rotX), 0, sin(mypc.rotX),
        0, 1, 0,
        -sin(mypc.rotX), 0, cos(mypc.rotX)
    );
    mat3 rotY = mat3(
        1, 0, 0,
        0, cos(mypc.rotY), sin(mypc.rotY),
        0, -sin(mypc.rotY), cos(mypc.rotY)
    );
    mat3 rotXinv = mat3(
        cos(-mypc.rotX), 0, sin(-mypc.rotX),
        0, 1, 0,
        -sin(-mypc.rotX), 0, cos(-mypc.rotX)
    );
    mat3 rotYinv = mat3(
        1, 0, 0,
        0, cos(-mypc.rotY), sin(-mypc.rotY),
        0, -sin(-mypc.rotY), cos(-mypc.rotY)
    );
	//uvout = uv;
	normalOut = normal;
	normalOut.x *= 1.0;
	normalOut.y *= -1.0;
	Sphere sphere = sphereList.spheres[gl_InstanceIndex];
	//gl_Position = vec4(pos, 1);
	vec3 finalPos = pos * sphere.radius + vec3(sphere.x, sphere.y, sphere.z) - mypc.pos;
	finalPos = rotYinv * rotXinv * finalPos;
	finalPos.x *= mypc.screenRatio * 2.0;
	finalPos.y *= -2.0;
	gl_Position = vec4(finalPos.xy, 0.01, finalPos.z);
	//gl_Position = vec4(pos * 0.1 + 0.1 * vec3(sphere.x, sphere.y, sphere.z), 1);
}