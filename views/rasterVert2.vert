#version 460 core

struct Drawable {
    float posX, posY, posZ;
    float dposX, dposY, dposZ;
    float scaleX, scaleY, scaleZ;
    float rotX, rotY, rotZ;
    float r, g, b;
    uint modelId;
};

layout (location = 0) in vec3 pos;
layout (location = 1) in vec3 normal;
layout (location = 5) out vec3 normalOut;
//layout (location = 1) in vec2 uv;
//layout (location = 2) out vec2 uvout;
layout (location = 6) out float rotXout;
layout (location = 7) out float rotYout;
layout (location = 8) out Drawable drawableOut;

layout (push_constant) uniform mypc_t {
	vec3 pos;
    float rotX, rotY;
    float screenRatio;
    float width, height;
	vec3 oldPos;
    float oldRotX, oldRotY;
} mypc;

layout (set = 0, binding = 0) buffer readonly drawableList_t {
	Drawable drawables[];
} drawableList;

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
	Drawable drawable = drawableList.drawables[gl_InstanceIndex];
    drawableOut = drawable;
    //colour = vec3(drawable.scale.x);
	//gl_Position = vec4(pos, 1);
	vec3 finalPos = pos * vec3(drawable.scaleX, drawable.scaleY, drawable.scaleZ) + vec3(drawable.posX, drawable.posY, drawable.posZ) - mypc.pos;
	finalPos = rotYinv * rotXinv * finalPos;
	finalPos.x *= mypc.screenRatio * 2.0;
	finalPos.y *= -2.0;
	gl_Position = vec4(finalPos.xy, 0.01, finalPos.z);
	//gl_Position = vec4(pos * 0.1 + 0.1 * vec3(sphere.x, sphere.y, sphere.z), 1);
}