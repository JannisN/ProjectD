//glslangValidator --target-env vulkan1.3 rasterFrag2.frag -o rasterFrag2.spv
#version 460 core

struct Drawable {
    float posX, posY, posZ;
    float dposX, dposY, dposZ;
    float scaleX, scaleY, scaleZ;
    float rotX, rotY, rotZ;
    float r, g, b;
    uint modelId;
};

layout (location = 0) out vec4 o_color;
//layout (location = 2) in vec2 uvout;
layout (location = 2) in vec3 normalOut;
layout (location = 3) in float rotXout;
layout (location = 4) in float rotYout;
layout (location = 5) flat in Drawable drawable;

layout (push_constant) uniform mypc_t {
	vec3 pos;
    float rotX, rotY;
    float screenRatio;
    float width, height;
} mypc;

void main() {
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
	//o_color = vec4((0.5 * dot(normalize(vec3(-1, -1, -1)), normalOut) + 0.5) * vec3(drawable.r, drawable.g, drawable.b), 1.0);
	//o_color = vec4((0.5 * dot(normalize(vec3(-1, -1, -1)), normalOut) + 0.5) * vec3(drawable.dposX, drawable.dposY, drawable.dposZ), 1.0);
	//o_color = vec4(vec3(1.0 / gl_FragCoord.w, 0.0, 0), 1.0);
    vec3 pos = vec3((gl_FragCoord.x / float(mypc.width) * 2 - 1) / gl_FragCoord.w / 2.0 / mypc.screenRatio, (gl_FragCoord.y / float(mypc.height) * 2 - 1) / gl_FragCoord.w / -2.0, 1.0 / gl_FragCoord.w);
    pos = rotX * rotY * pos + mypc.pos - vec3(drawable.dposX, drawable.dposY, drawable.dposZ);
    vec3 finalPos = rotYinv * rotXinv * (pos - mypc.pos);
	finalPos.x *= mypc.screenRatio * 2.0;
	finalPos.y *= -2.0;
    finalPos.x /= finalPos.z;
    finalPos.y /= finalPos.z;
    vec2 oldCoords = finalPos.xy;
	o_color = vec4(0.5 + 0.5 * sin(100 * oldCoords.x), 0.5 + 0.5 * sin(100 * oldCoords.y), 0.0, 1.0);
	//o_color = vec4(finalPos.xy, 0.0, 1.0);
	//o_color = vec4(vec3(drawable.dposX * 0.5 + 0.5, drawable.dposY * 0.5 + 0.5, drawable.dposZ * 0.5 + 0.5), 1.0);
}