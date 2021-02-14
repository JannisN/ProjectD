typedef struct {
	float3 pos;
	float3 dir;
} Ray;

typedef struct {
	float3 pos;
	float size;
} Sphere;

typedef struct {
	float pos;
} TestPlane;

bool intersectSphere(Sphere sphere, Ray ray, float3* pos) {
	float discriminant = (2.0f * dot(ray.dir, (ray.pos - sphere.pos))) * (dot(ray.dir, (ray.pos - sphere.pos)) * 2.0f) - (4.0f * dot(ray.dir, ray.dir) * (dot(ray.pos, ray.pos) + dot(sphere.pos, sphere.pos) - sphere.size * sphere.size - 2.0f * dot(ray.pos, sphere.pos)));
	if (discriminant >= 0.0f) {
		float distance = (-2.0f * dot(ray.dir, ray.pos - sphere.pos) - sqrt(discriminant)) / (2.0f * dot(ray.dir, ray.dir));
		*pos = ray.pos + distance * ray.dir;
		return true;
	}
	return false;
}

bool intersectPlane(TestPlane plane, Ray ray, float3* pos) {
	if (ray.dir.y < 0.0f) {
		*pos = ray.pos - ray.dir * (ray.pos.y - plane.pos) / ray.dir.y;
		return true;
	}
	return false;
}

float4 qMult(float4 q1, float4 q2) {
	return (float4)(
		q1.x * q2.x - q1.y * q2.y - q1.z * q2.z - q1.w * q2.w,
		q1.x * q2.y + q1.y * q2.x + q1.z * q2.w - q1.w * q2.z,
		q1.x * q2.z + q1.z * q2.x - q1.y * q2.w + q1.w * q2.y,
		q1.x * q2.w + q1.w * q2.x + q1.y * q2.z - q1.z * q2.y
	);
}

float3 qRot(float4 q, float3 pos) {
	return qMult(q, qMult((float4)(0.0f, pos.x, pos.y, pos.z), (float4)(q.x, -q.y, -q.z, -q.w))).yzw;
}

// idee: noch ein shadow volumen für die sonne, das auf längere distanzen funktioniert

__kernel void Draw(__write_only image2d_t image, __read_only float time, int width, int height) {
	int x = get_global_id(0);
	int y = get_global_id(1);
	
	if (x >= width || y >= height) {
		return;
	}
	float3 camDir = (float3)(((float) x / (float) width - 0.5f) * (float) width / (float) height, (float) y / (float) height + 1.9f - 0.5f, 1.0f);

	float t = sin(time) * 0.1f;

	float4 rot = (float4)(cos(t), 0.0f, sin(t), 0.0f);
	camDir = qRot(rot, camDir);

	Ray ray;
	ray.pos = (float3)(0.0f, 2.0f, 0.0f);
	ray.dir = normalize(camDir - ray.pos);

	Sphere sphere;
	//sphere.pos = (float3)(0.0f, 1.0f + sin(2.0f * time), 10.0f);
	float bounce = (fmod(time, 0.5f) - 0.25f) * 4.0f;
	sphere.pos = (float3)(0.0f, 1.0f - bounce * bounce, 10.0f);
	sphere.size = 1.0f;

	TestPlane plane;
	plane.pos = -1.0f;

	float3 color = (float3)(100.0f / 255.0f, 149.0f / 255.0f, 237.0f / 255.0f);
	
	float3 planePos = (float3)(1.0f, 1.0f, 1.0f);
	if (intersectPlane(plane, ray, &planePos)) {
		//color = (float3)(1.0f, 1.0f, -planePos.y);
		float3 normal = normalize(planePos - sphere.pos);
		float modifier = max(-dot(normal, (float3)(0.0f, 1.0f, 0.0f)), 0.0f);
		float shadowStrength = 1.0f - smoothstep(sphere.size, sphere.size + 2.0f, sqrt(dot(planePos - sphere.pos, planePos - sphere.pos)));
		color = (float3)(1.0f, 1.0f, 1.0f) * (1.0f - shadowStrength * shadowStrength * modifier * modifier * shadowStrength * modifier); // das hier noch verbessern evt.
		//color = (float3)(modifier, modifier, modifier);
	}
	
	float3 spherePos = (float3)(1.0f, 1.0f, 1.0f);
	if (intersectSphere(sphere, ray, &spherePos)) {
		//color = (float3)(1.0f, 0.8f, -spherePos.z / 1.0);
		float3 normal = normalize(spherePos - sphere.pos);
		float modifier = max((-dot(normal, (float3)(0.0f, 1.0f, 0.0f))), 0.0f);
		//float modifier = (dot(normal, (float3)(0.0f, 1.0f, 0.0f)) + 1.0f) / 2.0f;
		float modifierSun = (max((dot(normal, (float3)(0.0f, 1.0f, 0.0f))), 0.0f) + 4.0f) / 5.0f;
		float shadowStrength = smoothstep(0.0f, 2.0f, sqrt((plane.pos - spherePos.y) * (plane.pos - spherePos.y)));
		color = (float3)(1.0f, 0.8f, 0.8f) * (1.0f - (1.0f - shadowStrength) * (1.0f - shadowStrength) * modifier) * modifierSun;
		//color = (float3)(modifier, modifier, modifier);
	}

	write_imagef(image, (int2)(x, y), (float4)(color, 1.0f));
}