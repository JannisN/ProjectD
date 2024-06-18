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

hitAttributeEXT vec3 attribs;

struct AddressBuffers {
    uint64_t vertices;
    uint64_t indices;
    uint64_t normals;
    uint64_t normalIndices;
};
struct RTModelInfo {
    //AddressBuffers addressBuffers;
    uint64_t vertices;
    uint64_t indices;
    uint64_t normals;
    uint64_t normalIndices;
    uint proceduralModelId;
};
layout (set = 0, binding = 2) buffer modelList_t {
	RTModelInfo models[];
} modelList;

layout(buffer_reference, scalar) buffer Vertices {float v[]; };
layout(buffer_reference, scalar) buffer Indices {uint i[]; };
layout(buffer_reference, scalar) buffer Normals {float v[]; };
layout(buffer_reference, scalar) buffer NormalIndices {uint i[]; };

struct Drawable {
    float posX, posY, posZ;
    float scaleX, scaleY, scaleZ;
    float rotX, rotY, rotZ;
    float r, g, b;
    uint modelId;
};
layout (set = 0, binding = 5) buffer drawableList_t {
	Drawable drawables[];
} drawableList;

void main() {
    Drawable drawable = drawableList.drawables[gl_InstanceCustomIndexEXT];
    RTModelInfo addressBuffers = modelList.models[drawable.modelId];
    Vertices vertices = Vertices(addressBuffers.vertices);
    Indices indices = Indices(addressBuffers.indices);
    Normals normals = Normals(addressBuffers.normals);
    NormalIndices normalIndices = NormalIndices(addressBuffers.normalIndices);
    
    uvec3 ind = uvec3(indices.i[gl_PrimitiveID * 3], indices.i[gl_PrimitiveID * 3 + 1], indices.i[gl_PrimitiveID * 3 + 2]);
    uvec3 indNormals = uvec3(normalIndices.i[gl_PrimitiveID * 3], normalIndices.i[gl_PrimitiveID * 3 + 1], normalIndices.i[gl_PrimitiveID * 3 + 2]);

    //vec3 n0 = normals.v[indNormals.x];
    //vec3 n1 = normals.v[indNormals.y];
    //vec3 n2 = normals.v[indNormals.z];
    vec3 n0 = vec3(normals.v[indNormals.x * 3], normals.v[indNormals.x * 3 + 1], normals.v[indNormals.x * 3 + 2]);
    vec3 n1 = vec3(normals.v[indNormals.y * 3], normals.v[indNormals.y * 3 + 1], normals.v[indNormals.y * 3 + 2]);
    vec3 n2 = vec3(normals.v[indNormals.z * 3], normals.v[indNormals.z * 3 + 1], normals.v[indNormals.z * 3 + 2]);

    const vec3 barycentricCoords = vec3(1.0f - attribs.x - attribs.y, attribs.x, attribs.y);
    vec3 N = n0 * barycentricCoords.x + n1 * barycentricCoords.y + n2 * barycentricCoords.z;
    N = normalize(((N) * gl_WorldToObjectEXT).xyz/* - vec3(cube.x, cube.y, cube.z)*/);

    vec3 worldPos = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * gl_HitTEXT;

    const vec3 lightDir = vec3(0, 1.0, 0);
    float dotProduct = dot(lightDir, N);
    RayPayload hitValue2;
    hitValue2.colour = vec3(drawable.r, drawable.g, drawable.b);
    //hitValue2.colour = vec3(1.0, 1.0, 1.0);//barycentricCoords;// * dotProduct;//vec3(dotProduct, dotProduct, dotProduct);
    hitValue2.pos = worldPos;
    hitValue2.normal = N;
    hitValue2.hitType = 1;
    hitValue2.radiance = vec3(0);
    hitValue = hitValue2;
    //hitValue = barycentricCoords;
    //hitValue = exp(worldPos);
}