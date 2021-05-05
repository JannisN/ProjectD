typedef struct {
	float3 pos;
	float3 dir;
} Ray;

typedef struct {
	float3 pos;
	float size;
	float3 color;
} Sphere;

typedef struct {
	float pos;
	float3 color;
} TestPlane;

float intersectSphere(Sphere sphere, Ray ray, float3* pos, float3* normal) {
	float discriminant = (2.0f * dot(ray.dir, (ray.pos - sphere.pos))) * (dot(ray.dir, (ray.pos - sphere.pos)) * 2.0f) - (4.0f * dot(ray.dir, ray.dir) * (dot(ray.pos, ray.pos) + dot(sphere.pos, sphere.pos) - sphere.size * sphere.size - 2.0f * dot(ray.pos, sphere.pos)));
	if (discriminant > 0.0f) {
		float distance = (-2.0f * dot(ray.dir, ray.pos - sphere.pos) - sqrt(discriminant)) / (2.0f * dot(ray.dir, ray.dir));
		*pos = ray.pos + distance * ray.dir;
		*normal = (*pos - sphere.pos) / sphere.size;
		return distance;
	}
	return -1.0f;
}

float intersectPlane(TestPlane plane, Ray ray, float3* pos, float3* normal) {
	if (ray.dir.y <= 0.0f) {
		float distance = (plane.pos - ray.pos.y) / ray.dir.y;
		*pos = ray.pos + ray.dir * distance;
		*normal = (float3)(0.0f, 1.0f, 0.0f);
		return distance;
	}
	return -1.0f;
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

static float noise3D(float x, float y, float z) {
    float ptr = 0.0f;
    return fract(sin(x*112.9898f + y*179.233f + z*237.212f) * 43758.5453f, &ptr);
}

#define count 4

__kernel void Draw(__write_only image2d_t image, __read_only float time, int width, int height) {
	int x = get_global_id(0);
	int y = get_global_id(1);
	
	if (x >= width || y >= height) {
		return;
	}
	float3 camDir = (float3)(((float) x / (float) width - 0.5f) * (float) width / (float) height, (float) y / (float) height + 3.7f - 0.5f, 1.0f);

	float t = sin(time) * 0.3f;
	float4 rot = (float4)(cos(t), 0.0f, sin(t), 0.0f);
	camDir = qRot(rot, camDir);

	Ray originalRay;
	originalRay.pos = (float3)(0.0f, 4.0f, 0.0f);
	originalRay.dir = normalize(camDir - originalRay.pos);

	float bounce = (fmod(time, 0.5f) - 0.25f) * 4.0f;
	Sphere sphere;
	sphere.pos = (float3)(0.0f, 1.0f - bounce * bounce, 10.0f);
	sphere.size = 1.0f;
	sphere.color = (float3)(1.0f, 0.8f, 0.8f);

	TestPlane plane;
	plane.pos = -1.0f;
	plane.color = (float3)(1.0f, 1.0f, 1.0f);

	float3 finalColor = (float3)(0.0f, 0.0f, 0.0f);
	for (int j = 0; j < 64; j++) {
		Ray ray = originalRay;

		float3 color = (float3)(0.0f, 0.0f, 0.0f);
		
		float3 pathColors[count];
		bool pathDirectLight[count];
		int length = 0;

		for (int i = 0; i < count; i++) {
			Ray newRay;
			float distance;
			float3 provColor = (float3)(0.0f, 0.0f, 0.0f);

			Ray closestRay;
			float closest = -1.0f;
			distance = intersectPlane(plane, ray, &newRay.pos, &newRay.dir);
			if ((distance < closest || closest < 0.0f) && distance > 0.00001f) {
				closest = distance;
				provColor = plane.color;
				closestRay = newRay;
			}
			distance = intersectSphere(sphere, ray, &newRay.pos, &newRay.dir);
			if ((distance < closest || closest < 0.0f) && distance > 0.00001f) {
				closest = distance;
				provColor = sphere.color;
				closestRay = newRay;
			}
			pathColors[i] = provColor;

			if (closest < 0.0f) {
				break;
			}
			length++;

			float randomId = (x * height + y) / (float)(width * height) * 153.24953f;
			float seed = 31.02349 + (float) j * 13.52648f + fmod(time, 0.523f) * 3.47f;
			float3 randomNormal;
			randomNormal.x = 2.0f * (noise3D(randomId, (float)(i * 3), seed) - 0.5f);
			randomNormal.y = 2.0f * (noise3D(randomId, (float)(i * 3 + 1), seed) - 0.5f);
			randomNormal.z = 2.0f * (noise3D(randomId, (float)(i * 3 + 2), seed) - 0.5f);

			// reflektion
			//float3 helpVector = cross(ray.dir, closestRay.dir);
			//float3 direction = normalize(cross(closestRay.dir, helpVector));
			//ray.dir = -ray.dir - direction * dot(-ray.dir, direction) * 2.0f;

			ray.dir = normalize(closestRay.dir + randomNormal);
			ray.pos = closestRay.pos + closestRay.dir * 0.0001f; // den delta wert als extra variable speichern

			// test ob direkt mit licht verbunden
			//Ray directLightRay;
			//directLightRay.pos = ray.pos;
			//directLightRay.dir = (float3)(0.0f, 1.0f, 0.0f); // vektor zum licht
			//pathDirectLight[i] = true;
			//if (intersectPlane(plane, directLightRay, &newRay.pos, &newRay.dir) > 0.0f) {
			//	pathDirectLight[i] = false;
			//} else if (intersectSphere(sphere, directLightRay, &newRay.pos, &newRay.dir) > 0.0f) {
			//	pathDirectLight[i] = false;
			//}
		}
		if (length == 0) {
			color = (float3)(100.0f / 255.0f, 149.0f / 255.0f, 237.0f / 255.0f);
		} else if (length == count) {
		} else {
			for (int i = 0; i < length; i++) {
				/*if (pathDirectLight[i] == true)*/ {
					//float p = pow(2.0f, (float)-i);
					color += pathColors[i];
				}
			}
			color = pow(2.0f, (float) (-length + 1.0f) * 0.5f) * color / (float) length;
		}
		finalColor += color;
	}
	finalColor /= 64.0f;
	//if (pathDirectLight[0] == false) {
	//	color = (float3)(0.0f, 0.0f, 0.0f);
	//} else {
	//	color = pathColors[0];
	//}

	//float distance = intersectPlane(plane, ray, &ray.pos, &ray.dir);
	//color = (float3)(distance / 10.0, distance / 10.0, distance / 10.0);

	write_imagef(image, (int2)(x, y), (float4)(finalColor, 1.0f));
} 