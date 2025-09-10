/*
glslangValidator --target-env vulkan1.3 ./views/rasterFrag2.frag -o ./views/rasterFrag2.spv
*/
#version 460

struct Drawable {
    float posX, posY, posZ;
    float dposX, dposY, dposZ;
    float scaleX, scaleY, scaleZ;
    float rotX, rotY, rotZ;
    float r, g, b;
    uint modelId;
};

layout (early_fragment_tests) in;
layout (location = 0) out vec4 o_color;
layout (location = 1) out vec4 o_dPos0;
layout (location = 2) out vec4 o_dPos1;
layout (location = 3) out vec4 o_currentDepth;
layout (location = 4) out vec4 o_guessDepth;
layout (location = 5) out vec4 o_normals;
//layout (location = 2) in vec2 uvout;
layout (location = 6) in vec3 normalOut;
layout (location = 7) in float rotXout;
layout (location = 8) in float rotYout;
layout (location = 9) flat in Drawable drawable;
layout (set = 0, binding = 1/*, rgba8*/) uniform sampler2D texelBuffer;
layout (set = 0, binding = 2, rgba8) uniform image2D dPos0;
layout (set = 0, binding = 3, rgba8) uniform image2D dPos1;
layout (set = 0, binding = 4, rgba8) uniform image2D currentDepth;
layout (set = 0, binding = 5, rgba8) uniform image2D oldDepth;
layout (set = 0, binding = 6, rgba8) uniform image2D guessDepth;

layout (push_constant) uniform mypc_t {
	vec3 pos;
    float rotX, rotY;
    float screenRatio;
    float width, height;
	vec3 oldPos;
    float oldRotX, oldRotY;
} mypc;

vec4 packFloatToVec4i(const float value) {
    const vec4 bitSh = vec4(256.0*256.0*256.0, 256.0*256.0, 256.0, 1.0);
    const vec4 bitMsk = vec4(0.0, 1.0/256.0, 1.0/256.0, 1.0/256.0);
    vec4 res = fract(value * bitSh);
    res -= res.xxyz * bitMsk;
    return res;
}
float unpackFloatFromVec4i(const vec4 value) {
    const vec4 bitSh = vec4(1.0/(256.0*256.0*256.0), 1.0/(256.0*256.0), 1.0/256.0, 1.0);
    return(dot(value, bitSh));
}

vec4 packFloat(float f) {
    uint i = floatBitsToUint(f);
    return vec4(
        1.0 / 255.0 * (i >> 24),
        1.0 / 255.0 * ((i >> 16) & 255),
        1.0 / 255.0 * ((i >> 8) & 255),
        1.0 / 255.0 * (i & 255)
    );
}
float unpackFloat(vec4 v) {
    return uintBitsToFloat(
        uint(v.x * 255) << 24 +
        uint(v.y * 255) << 16 +
        uint(v.z * 255) << 8 +
        uint(v.w * 255)
    );
}
vec4 EncodeFloatRGBA( float v )
{
    vec4 kEncodeMul = vec4(1.0, 255.0, 65025.0, 16581375.0);
    float kEncodeBit = 1.0/255.0;
    vec4 enc = kEncodeMul * v;
    enc = fract (enc);
    enc -= enc.yzww * kEncodeBit;
    return enc;
}

float DecodeFloatRGBA( vec4 enc )
{
    vec4 kDecodeDot = vec4(1.0, 1./255.0, 1./65025.0, 1./16581375.0);   
    return dot( enc, kDecodeDot );
}
// todo:
// -zweite textur für 16 bit farben
// -speichern wie alt pixel sind, dass für neue strength kleiner wird

float smoothOut(float new, float old) {
    if (abs(new - old) < 1.0 / 25.0) {
        if (abs(new - old) * 255.0 < 1.1) {
            return new;
        } else {
            return 0.5 * new + 0.5 * old;
        }
    } else {
        return 0.1 * new + 0.9 * old;
    }
}

// noch interpolation verbessern zwischen new/old und 0.5/0.5
float smoothOut(float new, float old, float strength) {
    if (abs(new - old) * (1.0 - strength) < 1.0 / 255.0) {
        if (abs(new - old) * 255.0 < 1.1) {
            return new;
        } else {
            return 0.5 * new + 0.5 * old;
        }
    } else {
        return (1.0 - strength) * new + strength * old;
    }
}

float smoothOut(float new, float old, float strength, float diff) {
    /*if (diff * (1.0 - strength) < 1.0 / 255.0) {
        if (diff * 255.0 < 1.1) {
            return new;
        } else {
            return 0.5 * new + 0.5 * old;
        }
    } else {
        return (1.0 - strength) * new + strength * old;
    }*/
    if (diff * (1.0 - strength) < 0.1 / 255.0) {
        strength = 0.5;
    }
    float ret = strength * old + (1.0 - strength) * new;
    if (abs(ret - old) < 1.0 / 255.0) {
        return ret + 1.0 / 255.0 * sign(ret - old);
    } else {
        return ret;
    }
}

vec3 smoothOut(vec3 new, vec3 old, float strength) {
    float diff = max(max(abs(new.r - old.r), abs(new.g - old.g)), abs(new.b - old.b));
    return vec3(
        smoothOut(new.r, old.r, strength, diff),
        smoothOut(new.g, old.g, strength, diff),
        smoothOut(new.b, old.b, strength, diff)
    );
}

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
    mat3 oldRotXinv = mat3(
        cos(-mypc.oldRotX), 0, sin(-mypc.oldRotX),
        0, 1, 0,
        -sin(-mypc.oldRotX), 0, cos(-mypc.oldRotX)
    );
    mat3 oldRotYinv = mat3(
        1, 0, 0,
        0, cos(-mypc.oldRotY), sin(-mypc.oldRotY),
        0, -sin(-mypc.oldRotY), cos(-mypc.oldRotY)
    );
    /*float width = mypc.width - 1;
    float height = mypc.height - 1;*/
	//o_color = vec4((0.5 * dot(normalize(vec3(-1, -1, -1)), normalOut) + 0.5) * vec3(drawable.r, drawable.g, drawable.b), 1.0);
	//o_color = vec4((0.5 * dot(normalize(vec3(-1, -1, -1)), normalOut) + 0.5) * vec3(drawable.dposX, drawable.dposY, drawable.dposZ), 1.0);
	//o_color = vec4(vec3(1.0 / gl_FragCoord.w, 0.0, 0), 1.0);
    vec3 pos = vec3((gl_FragCoord.x / float(mypc.width) * 2 - 1) / gl_FragCoord.w / 2.0 / mypc.screenRatio, (gl_FragCoord.y / float(mypc.height) * 2 - 1) / gl_FragCoord.w / -2.0, 1.0 / gl_FragCoord.w);
    vec3 posNew = pos - vec3(drawable.dposX, drawable.dposY, drawable.dposZ);
    pos = rotX * rotY * pos + mypc.pos - vec3(drawable.dposX, drawable.dposY, drawable.dposZ);
    vec3 finalPos = oldRotYinv * oldRotXinv * (pos - mypc.oldPos);
	finalPos.x *= mypc.screenRatio * 2.0;
	finalPos.y *= -2.0;
    finalPos.x /= finalPos.z;
    finalPos.y /= finalPos.z;
    vec2 oldCoords = finalPos.xy;
    oldCoords.x = oldCoords.x * 0.5 + 0.5;
    oldCoords.y = oldCoords.y * 0.5 + 0.5;
    //ivec2 oldCoordsInt = ivec2(oldCoords.x * mypc.width, oldCoords.y * mypc.height);
    vec3 oldPixel = texture(texelBuffer, oldCoords).rgb;
    //oldPixel.a = 1.0;
    //o_color = vec4((0.5 * dot(normalize(vec3(-1, -1, -1)), normalOut) + 0.5) * vec3(drawable.r, drawable.g, drawable.b), 1.0) * vec4(vec3(1.0 / 18.0), 1.0) + vec4(vec3(17.0 / 18.0), 1.0) * vec4(oldPixel, 1.0);
    //o_color = vec4(/*(0.5 * dot(normalize(vec3(-1, -1, -1)), normalOut) + 0.5) * a*/vec3(drawable.r, drawable.g, drawable.b), 1.0) * vec4(vec3(1.3 / 8.0), 1.0) + vec4(vec3(7.0 / 8.0), 1.0) * oldPixel;
    vec3 object = vec3(drawable.r, drawable.g, drawable.b) * (0.25 * -dot(normalize(vec3(1, -1, 1)), normalOut) + 0.75);
    //o_color = vec4(smoothOut(object, oldPixel, 0.98), 1.0);
    if (oldCoords.x < 0.0 || oldCoords.x > 1.0 || oldCoords.y < 0.0 || oldCoords.y > 1.0) {
        o_color = vec4(object, 0.0);
    } else {
        o_color = vec4(object, 1.0);
    }
    o_normals = vec4(((rotYinv * rotXinv * normalOut) + 1.0) / 2.0, 1.0);
    /*float oldX = oldCoords.x * 0.5 + 0.25;
    float oldY = oldCoords.y * 0.5 + 0.25;
    if (oldCoords.x < 0) {
        oldX = 1 / 255.0;
    }
    if (oldCoords.x > 1) {
        oldX = 254.0 / 255.0;
    }
    if (oldCoords.y < 0) {
        oldY = 1 / 255.0;
    }
    if (oldCoords.y > 1) {
        oldY = 254.0 / 255.0;
    }*/
    /*
	imageStore(dPos0, ivec2(int(gl_FragCoord.x), int(gl_FragCoord.y)), EncodeFloatRGBA(oldCoords.x));
	imageStore(dPos1, ivec2(int(gl_FragCoord.x), int(gl_FragCoord.y)), EncodeFloatRGBA(oldCoords.y));
	imageStore(currentDepth, ivec2(int(gl_FragCoord.x), int(gl_FragCoord.y)), EncodeFloatRGBA(atan(posNew.z) / 3.14159 + 0.5));
	imageStore(guessDepth, ivec2(int(gl_FragCoord.x), int(gl_FragCoord.y)), EncodeFloatRGBA(atan(finalPos.z) / 3.14159 + 0.5));
    */
    o_dPos0 = EncodeFloatRGBA(oldCoords.x);
    o_dPos1 = EncodeFloatRGBA(oldCoords.y);
    o_currentDepth = EncodeFloatRGBA(atan(posNew.z) / 3.14159 + 0.5);
    o_guessDepth = EncodeFloatRGBA(atan(finalPos.z) / 3.14159 + 0.5);
    //o_color = vec4(object, 1.0);
	//o_color = vec4(200 * abs(oldCoords.x - gl_FragCoord.x / float(mypc.width)), 100 * abs(oldCoords.y - gl_FragCoord.y / float(mypc.height)), 0.0, 1.0);

    /*o_color = vec4(
        smoothOut(object.r, oldPixel.r, 0.9),
        smoothOut(object.g, oldPixel.g, 0.9),
        smoothOut(object.b, oldPixel.b, 0.9),
        1.0
    );*/
    /*o_color = vec4(
        round(((drawable.r * 255) * 1.5 + (oldPixel.r * 255) * 7) / 8.0) / 255.0,
        round(((drawable.g * 255) * 1.5 + (oldPixel.g * 255) * 7) / 8.0) / 255.0,
        round(((drawable.b * 255) * 1.5 + (oldPixel.b * 255) * 7) / 8.0) / 255.0,
        1);*/
    //o_color = vec4(0.0, 1.0, 1.0, 1.0) * 0.5 + 0.5 * imageLoad(texelBuffer, oldCoordsInt);
    //o_color = 0.9 * o_color + 0.1 * imageLoad(texelBuffer, oldCoordsInt);
	//o_color = vec4(0.5 + 0.5 * sin(1000 * oldCoords.x), 0.5 + 0.5 * sin(1000 * oldCoords.y), 0.0, 1.0);
	//o_color = vec4(finalPos.xy, 0.0, 1.0);
	//o_color = vec4(vec3(drawable.dposX * 0.5 + 0.5, drawable.dposY * 0.5 + 0.5, drawable.dposZ * 0.5 + 0.5), 1.0);
}