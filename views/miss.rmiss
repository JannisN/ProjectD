#version 460
#extension GL_EXT_ray_tracing : enable

struct RayPayload {
    vec3 colour;
    vec3 pos;
    vec3 normal;
    int hitType;
    vec3 radiance;
};

layout(location = 0) rayPayloadInEXT RayPayload hitValue;

void main() {
    hitValue.colour = vec3(1.0, 1.0, 1.0);
    hitValue.hitType = 0;
    hitValue.radiance = vec3(1.0, 1.0, 1.0);
    hitValue.normal = vec3(1,0,0);
    hitValue.pos = vec3(50, 50, 50);
}