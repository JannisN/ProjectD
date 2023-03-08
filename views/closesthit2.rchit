#version 460

#extension GL_EXT_ray_tracing : enable
#extension GL_EXT_scalar_block_layout : enable
#extension GL_EXT_nonuniform_qualifier : enable

#extension GL_EXT_shader_explicit_arithmetic_types_int64 : require
#extension GL_EXT_buffer_reference2 : require

struct RayPayload {
    vec3 colour;
    vec3 pos;
    vec3 normal;
    int hitType;
    vec3 radiance;
};

layout(location = 0) rayPayloadInEXT RayPayload hitValue;

void main() {
    vec4 origin4 = vec4(1, 1, -0, 1);
    //vec4 origin4 = vec4(-1, -1, -7, 1);
    vec3 origin = gl_ObjectToWorldEXT * origin4;
    vec3 worldPos = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * gl_HitTEXT;
    //hitValue = vec3(0.0, 1.0, 1.0);
    const vec3 lightDir = vec3(0, 1.0, 0);
    float dotProduct = dot(lightDir, normalize(worldPos - origin));
    RayPayload hitValue2;
    hitValue2.colour = vec3(1, 0.5, 0.5);//vec3(dotProduct, dotProduct, dotProduct);
    hitValue2.pos = worldPos;
    hitValue2.normal = normalize(worldPos - origin);
    hitValue2.hitType = 2;
    hitValue2.radiance = vec3(0);
    hitValue = hitValue2;
}