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
layout(set = 0, binding = 2) buffer _scene_desc { AddressBuffers i[]; } sceneDesc;
layout(buffer_reference, scalar) buffer Vertices {vec3 v[]; };
layout(buffer_reference, scalar) buffer Indices {uvec3 i[]; };
layout(buffer_reference, scalar) buffer Normals {vec3 v[]; };
layout(buffer_reference, scalar) buffer NormalIndices {uvec3 i[]; };

struct Cube {
	float x, y, z;
	float size;
};
layout (set = 0, binding = 6) buffer cubeList_t {
	Cube cubes[];
} cubeList;

void main() {
    AddressBuffers addressBuffers = sceneDesc.i[gl_InstanceCustomIndexEXT];
    Vertices vertices = Vertices(addressBuffers.vertices);
    Indices indices = Indices(addressBuffers.indices);
    Normals normals = Normals(addressBuffers.normals);
    NormalIndices normalIndices = NormalIndices(addressBuffers.normalIndices);
    
    uvec3 ind = indices.i[gl_PrimitiveID];
    uvec3 indNormals = normalIndices.i[gl_PrimitiveID];

    vec3 n0 = normals.v[indNormals.x];
    vec3 n1 = normals.v[indNormals.y];
    vec3 n2 = normals.v[indNormals.z];

    Cube cube = cubeList.cubes[gl_InstanceCustomIndexEXT];

    const vec3 barycentricCoords = vec3(1.0f - attribs.x - attribs.y, attribs.x, attribs.y);
    vec3 N = n0 * barycentricCoords.x + n1 * barycentricCoords.y + n2 * barycentricCoords.z;
    N = normalize(((N) * gl_WorldToObjectEXT).xyz/* - vec3(cube.x, cube.y, cube.z)*/);

    vec3 worldPos = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * gl_HitTEXT;

    const vec3 lightDir = vec3(0, 1.0, 0);
    float dotProduct = dot(lightDir, N);
    RayPayload hitValue2;
    hitValue2.colour = vec3(1.0, 1.0, 1.0);//barycentricCoords;// * dotProduct;//vec3(dotProduct, dotProduct, dotProduct);
    hitValue2.pos = worldPos;
    hitValue2.normal = N;
    hitValue2.hitType = 1;
    hitValue2.radiance = vec3(0);
    hitValue = hitValue2;
    //hitValue = barycentricCoords;
    //hitValue = exp(worldPos);
}