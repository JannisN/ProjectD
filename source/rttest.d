module rttest;

import vulkan;
import glfw_vulkan_window;
import utils;
import vulkan_core;
import functions;
import ecs;
import png;
import font;
import ecs2;
import wavefront;
import tensor;
import std.mathspecial;
import std.random;
import core.internal.container.common;

struct TestApp(ECS) {
	ECS* ecs;
	void initialize(ref ECS ecs) {
		this.ecs = &ecs;
		initVulkan();
		initWindow();

		import core.stdc.stdio;
		char[10] fval;
		snprintf(fval.ptr, 10, "%f", 0f);
		timeCounter = dynEcs.add().entityId;
        dynEcs.addComponent!Text(timeCounter);
		dynEcs.getComponent!Text(timeCounter).opDispatch!"text";
        dynEcs.getComponent!Text(timeCounter).text = String(fval);
        dynEcs.getComponent!Text(timeCounter).x = -1;
        dynEcs.getComponent!Text(timeCounter).y = -1;
        dynEcs.getComponent!Text(timeCounter).scale = 1;
		pos[0] = -2.0;
		pos[1] = 2.0;
		pos[2] = -10.0;
		rot[0] = 0.0;
		rot[1] = 0.0;

		enum string cubeCode = import("cube.wobj");
		enum string sphereCode = import("sphere.wobj");
		cubeModel = models.add().add!WavefrontModel(cubeCode).entityId;
		sphereModel = models.add().add!WavefrontModel(sphereCode).add!ProceduralModel(0, array(-1.0f, -1.0f, -1.0f), array(1.0f, 1.0f, 1.0f)).entityId;

		cmdBuffer.begin();
		updateModels(cmdBuffer);
		if (rt) {
			tlas.build(asInstances.gpuBuffer.getDeviceAddress(), asInstances.length, cmdBuffer);
		}
		cmdBuffer.end();
		writeln("Update models result: ", queue.submit(cmdBuffer, fence));
		writeln("Fence wait result: ", fence.wait());
		cmdBuffer.reset();
		fence.reset();
		
		Drawable drawable;
		drawable.pos = Tensor!(float, 3)(0, -5, 0);
		drawable.dpos = Tensor!(float, 3)(0, 0, 0);
		drawable.scale = Tensor!(float, 3)(5, 5, 5);
		drawable.rot = Tensor!(float, 3)(0, 0, 0);
		drawable.rgb = Tensor!(float, 3)(0.9, 0.8, 0.6);
		drawable.modelId = cast(uint)cubeModel;

		Drawable drawable2;
		drawable2.pos = Tensor!(float, 3)(0, 0, 15);
		drawable2.dpos = Tensor!(float, 3)(0, 0, 0);
		drawable2.scale = Tensor!(float, 3)(5, 5, 5);
		drawable2.rot = Tensor!(float, 3)(0, 0, 0);
		drawable2.rgb = Tensor!(float, 3)(0.8, 0.8, 0.8);
		drawable2.modelId = cast(uint)cubeModel;
		objects.add().add!Drawable(drawable);
		objects.add().add!Drawable(drawable2);

		//rnd = Random(42);
	}
	void receive(MouseButtonEvent event) {
		writeln("event");
		if (event.action == MouseButtonAction.press) {
			import core.stdc.stdio;
			char[20] fval;
			snprintf(fval.ptr, 20, "Die Zeit ist:\n%f", passedTime);
            dynEcs.getComponent!Text(timeCounter).text = String(fval);
            dynEcs.getComponent!Text(timeCounter).x = -1;
            dynEcs.getComponent!Text(timeCounter).y = -1;
            dynEcs.getComponent!Text(timeCounter).scale = 1;
			//rtTime++;

			import std.math.trigonometry;
			Drawable drawable;
			drawable.pos = Tensor!(float, 3)(2.0 * sin(passedTime), 1.0, 2.0 * cos(passedTime));
			drawable.dpos = Tensor!(float, 3)(0, 0, 0);
			drawable.scale = Tensor!(float, 3)(1, 1, 1);
			drawable.rot = Tensor!(float, 3)(0, 0, 0);
			drawable.rgb = Tensor!(float, 3)(0.0, 0.0, 0.0);
			//drawable.rgb = Tensor!(float, 3)(0.0, 1.0, 1.0);
			drawable.modelId = cast(uint)sphereModel;
			objects.add().add!Drawable(drawable);
		}
	}
	void receive(WindowResizeEvent event) {
	}
	RTProceduralModel createProceduralBlas(float[3] min, float[3] max) {
		RTProceduralModel model;

		Aabb[1] aabb;
		aabb[0].min = min[0..3];
		aabb[0].max = max[0..3];
		model.aabbBuffer = AllocatedResource!Buffer(device.createBuffer(0, aabb.length * Aabb.sizeof, VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_BUILD_INPUT_READ_ONLY_BIT_KHR));
		VkMemoryAllocateFlagsInfo flagsInfo;
		flagsInfo.sType = VkStructureType.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_FLAGS_INFO;
		flagsInfo.flags = VkMemoryAllocateFlagBits.VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT;
		memoryAllocator.allocate(model.aabbBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT, flagsInfo);
		Memory* memory = &cast(Memory) model.aabbBuffer.allocatedMemory.allocatorList.memory;
		byte* byteptr = cast(byte*) memory.map(model.aabbBuffer.allocatedMemory.allocation.offset, aabb.length * Aabb.sizeof);
		foreach (i; 0 .. aabb.length * Aabb.sizeof) {
			byteptr[i] = (cast(byte*)aabb.ptr)[i];
		}
		memory.flush(array(mappedMemoryRange(*memory, model.aabbBuffer.allocatedMemory.allocation.offset, aabb.length * Aabb.sizeof)));
		memory.unmap();
		VkAccelerationStructureGeometryAabbsDataKHR aabbs;
		aabbs.sType = VkStructureType.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_AABBS_DATA_KHR;
		aabbs.data.deviceAddress = model.aabbBuffer.getDeviceAddress();
		aabbs.stride = Aabb.sizeof;
		model.geometry.sType = VkStructureType.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_KHR;
		model.geometry.geometryType = VkGeometryTypeKHR.VK_GEOMETRY_TYPE_AABBS_KHR;
		model.geometry.geometry.aabbs = aabbs;
		model.geometry.flags = VkGeometryFlagBitsKHR.VK_GEOMETRY_OPAQUE_BIT_KHR;
		model.rangeInfo.firstVertex = 0;
		model.rangeInfo.primitiveCount = cast(uint) (aabb.length);
		model.rangeInfo.primitiveOffset = 0;
		model.rangeInfo.transformOffset = 0;
		VkAccelerationStructureBuildGeometryInfoKHR aabbBuildInfo;
		aabbBuildInfo.sType = VkStructureType.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_BUILD_GEOMETRY_INFO_KHR;
		aabbBuildInfo.flags = VkBuildAccelerationStructureFlagBitsKHR.VK_BUILD_ACCELERATION_STRUCTURE_PREFER_FAST_TRACE_BIT_KHR;
		aabbBuildInfo.geometryCount = 1;
		aabbBuildInfo.pGeometries = &model.geometry;
		aabbBuildInfo.mode = VkBuildAccelerationStructureModeKHR.VK_BUILD_ACCELERATION_STRUCTURE_MODE_BUILD_KHR;
		aabbBuildInfo.type = VkAccelerationStructureTypeKHR.VK_ACCELERATION_STRUCTURE_TYPE_BOTTOM_LEVEL_KHR;
		aabbBuildInfo.srcAccelerationStructure = cast(VkAccelerationStructureKHR_T*)VK_NULL_HANDLE;
		model.sizeInfo = device.getAccelerationStructureBuildSizesKHR(
			VkAccelerationStructureBuildTypeKHR.VK_ACCELERATION_STRUCTURE_BUILD_TYPE_DEVICE_KHR,
			&aabbBuildInfo,
			&model.rangeInfo.primitiveCount
		);
		model.blasBuffer = AllocatedResource!Buffer(device.createBuffer(0, model.sizeInfo.accelerationStructureSize, VkBufferUsageFlagBits.VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_STORAGE_BIT_KHR));
		memoryAllocator.allocate(model.blasBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, flagsInfo);
		model.blas = device.createAccelerationStructure(aabbBuildInfo.type, model.sizeInfo.accelerationStructureSize, 0, model.blasBuffer.buffer, 0);

		return model;
	}
	RTPolygonModel createPolygonBlas(ref WavefrontModel wavefrontModel) {
		RTPolygonModel model;

		float[] vertices = wavefrontModel.vertices;
		uint[] indices = wavefrontModel.indicesVertices;

		VkMemoryAllocateFlagsInfo flagsInfo;
		flagsInfo.sType = VkStructureType.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_FLAGS_INFO;
		flagsInfo.flags = VkMemoryAllocateFlagBits.VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT;

		model.vertexBuffer = AllocatedResource!Buffer(device.createBuffer(0, vertices.length * float.sizeof, VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_BUILD_INPUT_READ_ONLY_BIT_KHR));
		memoryAllocator.allocate(model.vertexBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT, flagsInfo);
		model.vertexIndexBuffer = AllocatedResource!Buffer(device.createBuffer(0, indices.length * float.sizeof, VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_INDEX_BUFFER_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_BUILD_INPUT_READ_ONLY_BIT_KHR));
		memoryAllocator.allocate(model.vertexIndexBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT, flagsInfo);

		Memory* memory = &cast(Memory) model.vertexBuffer.allocatedMemory.allocatorList.memory;
		float* floatptr = cast(float*) memory.map(model.vertexBuffer.allocatedMemory.allocation.offset, vertices.length * float.sizeof);
		foreach (j, float f; vertices) {
			floatptr[j] = f;
		}
		memory.flush(array(mappedMemoryRange(*memory, model.vertexBuffer.allocatedMemory.allocation.offset, vertices.length * float.sizeof)));
		memory.unmap();

		memory = &cast(Memory) model.vertexIndexBuffer.allocatedMemory.allocatorList.memory;
		uint* intptr = cast(uint*) memory.map(model.vertexIndexBuffer.allocatedMemory.allocation.offset, indices.length * uint.sizeof);
		foreach (j, uint f; indices) {
			intptr[j] = f;
		}
		memory.flush(array(mappedMemoryRange(*memory, model.vertexIndexBuffer.allocatedMemory.allocation.offset, indices.length * uint.sizeof)));
		memory.unmap();

		float[] normals = wavefrontModel.normals;
		uint[] normalIndices = wavefrontModel.indicesNormals;

		model.normalBuffer = AllocatedResource!Buffer(device.createBuffer(0, normals.length * float.sizeof, VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_BUILD_INPUT_READ_ONLY_BIT_KHR));
		memoryAllocator.allocate(model.normalBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT, flagsInfo);
		model.normalIndexBuffer = AllocatedResource!Buffer(device.createBuffer(0, normalIndices.length * float.sizeof, VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_BUILD_INPUT_READ_ONLY_BIT_KHR));
		memoryAllocator.allocate(model.normalIndexBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT, flagsInfo);

		memory = &cast(Memory) model.normalBuffer.allocatedMemory.allocatorList.memory;
		floatptr = cast(float*) memory.map(model.normalBuffer.allocatedMemory.allocation.offset, normals.length * float.sizeof);
		foreach (j, float f; normals) {
			floatptr[j] = f;
		}
		memory.flush(array(mappedMemoryRange(*memory, model.normalBuffer.allocatedMemory.allocation.offset, normals.length * float.sizeof)));
		memory.unmap();

		memory = &cast(Memory) model.normalIndexBuffer.allocatedMemory.allocatorList.memory;
		intptr = cast(uint*) memory.map(model.normalIndexBuffer.allocatedMemory.allocation.offset, normalIndices.length * uint.sizeof);
		foreach (j, uint f; normalIndices) {
			intptr[j] = f;
		}
		memory.flush(array(mappedMemoryRange(*memory, model.normalIndexBuffer.allocatedMemory.allocation.offset, normalIndices.length * uint.sizeof)));
		memory.unmap();

		VkDeviceAddress vertexBufferAddress = model.vertexBuffer.getDeviceAddress();
		VkDeviceAddress indexBufferAddress = model.vertexIndexBuffer.getDeviceAddress();
		VkDeviceAddress normalBufferAddress = model.normalBuffer.getDeviceAddress();
		VkDeviceAddress normalIndexBufferAddress = model.normalIndexBuffer.getDeviceAddress();

		VkAccelerationStructureGeometryTrianglesDataKHR triangles;
		triangles.sType = VkStructureType.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_TRIANGLES_DATA_KHR;
		triangles.vertexFormat = VkFormat.VK_FORMAT_R32G32B32_SFLOAT;
		triangles.vertexData.deviceAddress = vertexBufferAddress; //wichtig: muss für gpu buffer auf device umgestellt werden!
		//triangles.vertexData.hostAddress = cast(void*)vertices.ptr;
		triangles.vertexStride = 3 * float.sizeof;
		triangles.indexType = VkIndexType.VK_INDEX_TYPE_UINT32;
		triangles.indexData.deviceAddress = indexBufferAddress; // hier ebenso
		//triangles.indexData.hostAddress = cast(void*)indices.ptr;
		triangles.maxVertex = cast(uint) vertices.length / 3;
		// triangles.transformData, no transform

		model.geometry.sType = VkStructureType.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_KHR;
		model.geometry.geometryType = VkGeometryTypeKHR.VK_GEOMETRY_TYPE_TRIANGLES_KHR;
		model.geometry.geometry.triangles = triangles;
		model.geometry.flags = VkGeometryFlagBitsKHR.VK_GEOMETRY_OPAQUE_BIT_KHR;

		model.rangeInfo.firstVertex = 0;
		model.rangeInfo.primitiveCount = cast(uint) (indices.length / 3);
		model.rangeInfo.primitiveOffset = 0;
		model.rangeInfo.transformOffset = 0;

		VkAccelerationStructureBuildGeometryInfoKHR buildInfo;
		buildInfo.sType = VkStructureType.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_BUILD_GEOMETRY_INFO_KHR;
		buildInfo.flags = VkBuildAccelerationStructureFlagBitsKHR.VK_BUILD_ACCELERATION_STRUCTURE_PREFER_FAST_TRACE_BIT_KHR;
		buildInfo.geometryCount = 1;
		buildInfo.pGeometries = &model.geometry;
		buildInfo.mode = VkBuildAccelerationStructureModeKHR.VK_BUILD_ACCELERATION_STRUCTURE_MODE_BUILD_KHR;
		buildInfo.type = VkAccelerationStructureTypeKHR.VK_ACCELERATION_STRUCTURE_TYPE_BOTTOM_LEVEL_KHR;
		//buildInfo.srcAccelerationStructure = cast(VkAccelerationStructureKHR_T*)VK_NULL_HANDLE;

		model.sizeInfo = device.getAccelerationStructureBuildSizesKHR(
			VkAccelerationStructureBuildTypeKHR.VK_ACCELERATION_STRUCTURE_BUILD_TYPE_DEVICE_KHR,
			&buildInfo,
			&model.rangeInfo.primitiveCount
		);
		model.blasBuffer = AllocatedResource!Buffer(device.createBuffer(0, model.sizeInfo.accelerationStructureSize, VkBufferUsageFlagBits.VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_STORAGE_BIT_KHR));
		memoryAllocator.allocate(model.blasBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, flagsInfo);
		model.blas = device.createAccelerationStructure(buildInfo.type, model.sizeInfo.accelerationStructureSize, 0, model.blasBuffer.buffer, 0);

		return model;
	}
	void initrtPipeline() {
		enum string raygenCode = import("raygen.spv");
		enum string missCode = import("miss.spv");
		enum string closesthitCode = import("polygon.spv");
		enum string intersectCode = import("proceduralIntersect.spv");
		enum string closesthit2Code = import("procedural.spv");
		rtPipeline.raygenShader = device.createShader(raygenCode);
		rtPipeline.missShader = device.createShader(missCode);
		rtPipeline.closesthitShader = device.createShader(closesthitCode);
		rtPipeline.intersectShader = device.createShader(intersectCode);
		rtPipeline.closesthitShader2 = device.createShader(closesthit2Code);

		VkPipelineShaderStageCreateInfo[5] pssci;

		pssci[0].sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
		pssci[0].module_ = rtPipeline.raygenShader.shader;
		pssci[0].pName = "main";
		pssci[0].stage = VkShaderStageFlagBits.VK_SHADER_STAGE_RAYGEN_BIT_KHR;

		pssci[1].sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
		pssci[1].module_ = rtPipeline.missShader.shader;
		pssci[1].pName = "main";
		pssci[1].stage = VkShaderStageFlagBits.VK_SHADER_STAGE_MISS_BIT_KHR;

		pssci[2].sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
		pssci[2].module_ = rtPipeline.closesthitShader.shader;
		pssci[2].pName = "main";
		pssci[2].stage = VkShaderStageFlagBits.VK_SHADER_STAGE_CLOSEST_HIT_BIT_KHR;

		pssci[3].sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
		pssci[3].module_ = rtPipeline.intersectShader.shader;
		pssci[3].pName = "main";
		pssci[3].stage = VkShaderStageFlagBits.VK_SHADER_STAGE_INTERSECTION_BIT_KHR;

		pssci[4].sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
		pssci[4].module_ = rtPipeline.closesthitShader2.shader;
		pssci[4].pName = "main";
		pssci[4].stage = VkShaderStageFlagBits.VK_SHADER_STAGE_CLOSEST_HIT_BIT_KHR;

		VkRayTracingShaderGroupCreateInfoKHR[4] rtsgci;

		rtsgci[0].sType = VkStructureType.VK_STRUCTURE_TYPE_RAY_TRACING_SHADER_GROUP_CREATE_INFO_KHR;
		rtsgci[0].type = VkRayTracingShaderGroupTypeKHR.VK_RAY_TRACING_SHADER_GROUP_TYPE_GENERAL_KHR;
		rtsgci[0].generalShader = 0;
		rtsgci[0].closestHitShader = VK_SHADER_UNUSED_KHR;
		rtsgci[0].anyHitShader = VK_SHADER_UNUSED_KHR;
		rtsgci[0].intersectionShader = VK_SHADER_UNUSED_KHR;

		rtsgci[1].sType = VkStructureType.VK_STRUCTURE_TYPE_RAY_TRACING_SHADER_GROUP_CREATE_INFO_KHR;
		rtsgci[1].type = VkRayTracingShaderGroupTypeKHR.VK_RAY_TRACING_SHADER_GROUP_TYPE_GENERAL_KHR;
		rtsgci[1].generalShader = 1;
		rtsgci[1].closestHitShader = VK_SHADER_UNUSED_KHR;
		rtsgci[1].anyHitShader = VK_SHADER_UNUSED_KHR;
		rtsgci[1].intersectionShader = VK_SHADER_UNUSED_KHR;

		rtsgci[2].sType = VkStructureType.VK_STRUCTURE_TYPE_RAY_TRACING_SHADER_GROUP_CREATE_INFO_KHR;
		rtsgci[2].type = VkRayTracingShaderGroupTypeKHR.VK_RAY_TRACING_SHADER_GROUP_TYPE_TRIANGLES_HIT_GROUP_KHR;
		rtsgci[2].generalShader = VK_SHADER_UNUSED_KHR;
		rtsgci[2].closestHitShader = 2;
		rtsgci[2].anyHitShader = VK_SHADER_UNUSED_KHR;
		rtsgci[2].intersectionShader = VK_SHADER_UNUSED_KHR;

		rtsgci[3].sType = VkStructureType.VK_STRUCTURE_TYPE_RAY_TRACING_SHADER_GROUP_CREATE_INFO_KHR;
		rtsgci[3].type = VkRayTracingShaderGroupTypeKHR.VK_RAY_TRACING_SHADER_GROUP_TYPE_PROCEDURAL_HIT_GROUP_KHR;
		rtsgci[3].generalShader = VK_SHADER_UNUSED_KHR;
		rtsgci[3].closestHitShader = 4;
		rtsgci[3].anyHitShader = VK_SHADER_UNUSED_KHR;
		rtsgci[3].intersectionShader = 3;

		rtPipeline.descriptorSetLayout = device.createDescriptorSetLayout(array(VkDescriptorSetLayoutBinding(
			0,
			VkDescriptorType.VK_DESCRIPTOR_TYPE_ACCELERATION_STRUCTURE_KHR,
			1,
			VkShaderStageFlagBits.VK_SHADER_STAGE_RAYGEN_BIT_KHR,
			null
		), VkDescriptorSetLayoutBinding(
			1,
			VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
			1,
			VkShaderStageFlagBits.VK_SHADER_STAGE_RAYGEN_BIT_KHR,
			null
		), VkDescriptorSetLayoutBinding(
			2,
			VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
			1,
			VkShaderStageFlagBits.VK_SHADER_STAGE_CLOSEST_HIT_BIT_KHR | VkShaderStageFlagBits.VK_SHADER_STAGE_INTERSECTION_BIT_KHR,
			null
		), VkDescriptorSetLayoutBinding(
			3,
			VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
			1,
			VkShaderStageFlagBits.VK_SHADER_STAGE_RAYGEN_BIT_KHR,
			null
		), VkDescriptorSetLayoutBinding(
			4,
			VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
			1,
			VkShaderStageFlagBits.VK_SHADER_STAGE_RAYGEN_BIT_KHR,
			null
		), VkDescriptorSetLayoutBinding(
			5,
			VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
			1,
			VkShaderStageFlagBits.VK_SHADER_STAGE_CLOSEST_HIT_BIT_KHR | VkShaderStageFlagBits.VK_SHADER_STAGE_INTERSECTION_BIT_KHR,
			null
		)));
		rtPipeline.descriptorPool = device.createDescriptorPool(0, 1, array(
			VkDescriptorPoolSize(
				VkDescriptorType.VK_DESCRIPTOR_TYPE_ACCELERATION_STRUCTURE_KHR,
				1
			),
			VkDescriptorPoolSize(
				VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
				1
			),
			VkDescriptorPoolSize(
				VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
				1
			),
			VkDescriptorPoolSize(
				VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
				1
			),
			VkDescriptorPoolSize(
				VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
				1
			),
			VkDescriptorPoolSize(
				VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
				1
			)
		));
		rtPipeline.pipelineLayout = device.createPipelineLayout(
			array(rtPipeline.descriptorSetLayout),
			array(VkPushConstantRange(VkShaderStageFlagBits.VK_SHADER_STAGE_RAYGEN_BIT_KHR, 0, uint.sizeof * 6))
		);
		rtPipeline.descriptorSet = rtPipeline.descriptorPool.allocateSet(rtPipeline.descriptorSetLayout);
		rtPipeline.rtPipeline = device.createRayTracingPipeline(pssci, rtsgci, 1, rtPipeline.pipelineLayout, cast(VkDeferredOperationKHR_T*)VK_NULL_HANDLE, cast(VkPipelineCache_T*)VK_NULL_HANDLE);

		VkPhysicalDeviceRayTracingPipelinePropertiesKHR rtProperties;
		rtProperties.sType = VkStructureType.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_RAY_TRACING_PIPELINE_PROPERTIES_KHR;
		VkPhysicalDeviceProperties2 properties;
		properties.sType = VkStructureType.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2;
		properties.pNext = cast(void*) &rtProperties;
		device.physicalDevice.getProperties(&properties);

		uint groupCount = 4;
		rtPipeline.groupHandleSize = rtProperties.shaderGroupHandleSize;
		//rtPipeline.addressOffset = rtPipeline.groupHandleSize % rtProperties.shaderGroupBaseAlignment;
		rtPipeline.groupSizeAligned = (rtPipeline.groupHandleSize % rtProperties.shaderGroupBaseAlignment == 0) ? rtPipeline.groupHandleSize : ((rtPipeline.groupHandleSize / rtProperties.shaderGroupBaseAlignment + 1) * rtProperties.shaderGroupBaseAlignment);
		writeln("data: ", rtPipeline.groupHandleSize, " ", rtProperties.shaderGroupBaseAlignment, " ", rtPipeline.groupSizeAligned, " ");
		uint sbtSize = groupCount * rtPipeline.groupSizeAligned;
		rtPipeline.recordSize = rtPipeline.groupSizeAligned;
		Vector!byte shaderHandleStorage = Vector!byte(sbtSize);
		rtPipeline.rtPipeline.getShaderGroupHandles(0, groupCount, sbtSize, cast(void*)shaderHandleStorage.ptr);

		VkMemoryAllocateFlagsInfo flagsInfo;
		flagsInfo.sType = VkStructureType.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_FLAGS_INFO;
		flagsInfo.flags = VkMemoryAllocateFlagBits.VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT;

		rtPipeline.sbRayGen = AllocatedResource!Buffer(device.createBuffer(0, rtPipeline.groupSizeAligned, VkBufferUsageFlagBits.VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_TRANSFER_SRC_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_SHADER_BINDING_TABLE_BIT_KHR));
		memoryAllocator.allocate(rtPipeline.sbRayGen, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, flagsInfo);
		rtPipeline.sbMiss = AllocatedResource!Buffer(device.createBuffer(0, rtPipeline.groupSizeAligned, VkBufferUsageFlagBits.VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_TRANSFER_SRC_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_SHADER_BINDING_TABLE_BIT_KHR));
		memoryAllocator.allocate(rtPipeline.sbMiss, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, flagsInfo);
		rtPipeline.sbHit = AllocatedResource!Buffer(device.createBuffer(0, 2 * rtPipeline.groupSizeAligned, VkBufferUsageFlagBits.VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_TRANSFER_SRC_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_SHADER_BINDING_TABLE_BIT_KHR));
		memoryAllocator.allocate(rtPipeline.sbHit, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, flagsInfo);

		VkDeviceAddress da = rtPipeline.sbRayGen.getDeviceAddress();
		size_t daOffset = (rtProperties.shaderGroupBaseAlignment - (da % rtProperties.shaderGroupBaseAlignment)) % rtProperties.shaderGroupBaseAlignment;
		rtPipeline.offsetRayGen = daOffset;
		Memory* memory = &cast(Memory) rtPipeline.sbRayGen.allocatedMemory.allocatorList.memory;
		byte* byteptr = cast(byte*) memory.map(rtPipeline.sbRayGen.allocatedMemory.allocation.offset, rtPipeline.groupSizeAligned);
		foreach (j; 0 .. rtPipeline.groupHandleSize) {
			byteptr[j + daOffset] = shaderHandleStorage[0 * rtPipeline.groupHandleSize + j];
		}
		memory.flush(array(mappedMemoryRange(*memory, rtPipeline.sbRayGen.allocatedMemory.allocation.offset, rtPipeline.groupSizeAligned)));
		memory.unmap();

		da = rtPipeline.sbMiss.getDeviceAddress();
		daOffset = (rtProperties.shaderGroupBaseAlignment - (da % rtProperties.shaderGroupBaseAlignment)) % rtProperties.shaderGroupBaseAlignment;
		rtPipeline.offsetMiss = daOffset;
		memory = &cast(Memory) rtPipeline.sbMiss.allocatedMemory.allocatorList.memory;
		byteptr = cast(byte*) memory.map(rtPipeline.sbMiss.allocatedMemory.allocation.offset, rtPipeline.groupSizeAligned);
		foreach (j; 0 .. rtPipeline.groupHandleSize) {
			byteptr[j + daOffset] = shaderHandleStorage[1 * rtPipeline.groupHandleSize + j];
		}
		memory.flush(array(mappedMemoryRange(*memory, rtPipeline.sbMiss.allocatedMemory.allocation.offset, rtPipeline.groupSizeAligned)));
		memory.unmap();

		da = rtPipeline.sbHit.getDeviceAddress();
		daOffset = (rtProperties.shaderGroupBaseAlignment - (da % rtProperties.shaderGroupBaseAlignment)) % rtProperties.shaderGroupBaseAlignment;
		rtPipeline.offsetHit = daOffset;
		memory = &cast(Memory) rtPipeline.sbHit.allocatedMemory.allocatorList.memory;
		byteptr = cast(byte*) memory.map(rtPipeline.sbHit.allocatedMemory.allocation.offset, 2 * rtPipeline.groupSizeAligned);
		foreach (j; 0 .. rtPipeline.groupHandleSize) {
			byteptr[j + daOffset] = shaderHandleStorage[2 * rtPipeline.groupHandleSize + j];
		}
		foreach (j; 0 .. rtPipeline.groupHandleSize) {
			byteptr[j + rtPipeline.groupSizeAligned + daOffset] = shaderHandleStorage[3 * rtPipeline.groupHandleSize + j];
		}
		memory.flush(array(mappedMemoryRange(*memory, rtPipeline.sbHit.allocatedMemory.allocation.offset, 2 * rtPipeline.groupSizeAligned)));
		memory.unmap();
	}
	void initVulkan() {
		version(Windows) {
			instance = Instance("test", 1, VK_API_VERSION_1_3, array("VK_LAYER_KHRONOS_validation"), array("VK_KHR_surface", "VK_KHR_win32_surface"));
		}
		version(OSX) {
			instance = Instance("test", 1, VK_API_VERSION_1_0, array("VK_LAYER_KHRONOS_validation"), array("VK_KHR_surface", "VK_EXT_metal_surface"));
		}
		version(linux) {
			instance = Instance("test", 1, VK_API_VERSION_1_3, array("VK_LAYER_KHRONOS_validation"), array("VK_KHR_surface", "VK_KHR_xcb_surface"));
		}
		
		rt = instance.physicalDevices[0].hasExtensions(array("VK_KHR_swapchain", "VK_KHR_acceleration_structure", "VK_KHR_ray_tracing_pipeline", "VK_KHR_ray_query", "VK_KHR_spirv_1_4", "VK_KHR_deferred_host_operations"));
		rt = false;

		VkPhysicalDeviceSampleLocationsPropertiesEXT sampleProperties;
		sampleProperties.sType = VkStructureType.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SAMPLE_LOCATIONS_PROPERTIES_EXT;
		VkPhysicalDeviceProperties2 pdp2;
		pdp2.sType = VkStructureType.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2;
		pdp2.pNext = &sampleProperties;
		instance.physicalDevices[0].getProperties(&pdp2);
		sampleLocationRange[0] = sampleProperties.sampleLocationCoordinateRange[0];
		sampleLocationRange[1] = sampleProperties.sampleLocationCoordinateRange[1];
		
		VkPhysicalDeviceFeatures features;
		features.shaderStorageImageWriteWithoutFormat = VK_TRUE;
		features.shaderInt64 = VK_TRUE;
		features.fragmentStoresAndAtomics = VK_TRUE; //???
		VkPhysicalDeviceVulkan12Features features12;
		features12.sType = VkStructureType.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES;
		features12.bufferDeviceAddress = VK_TRUE;
		features12.descriptorIndexing = VK_TRUE;
		
		VkPhysicalDeviceRayQueryFeaturesKHR rayQueryFeatures;
		rayQueryFeatures.sType = VkStructureType.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_RAY_QUERY_FEATURES_KHR;
		rayQueryFeatures.rayQuery = VK_TRUE;
		VkPhysicalDeviceRayTracingPipelineFeaturesKHR rayTracingPipelineFeatures;
		rayTracingPipelineFeatures.sType = VkStructureType.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_RAY_TRACING_PIPELINE_FEATURES_KHR;
		rayTracingPipelineFeatures.rayTracingPipeline = VK_TRUE;
		VkPhysicalDeviceAccelerationStructureFeaturesKHR accelerationStructureFeatures;
		accelerationStructureFeatures.sType = VkStructureType.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ACCELERATION_STRUCTURE_FEATURES_KHR;
		accelerationStructureFeatures.accelerationStructure = VK_TRUE;
		// noch nicht verfügbar im treiber
		//accelerationStructureFeatures.accelerationStructureHostCommands = VK_TRUE;
		VkPhysicalDeviceVulkan13Features features13;
		features13.sType = VkStructureType.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES;
		features13.maintenance4 = VK_TRUE;
		if (rt) {
			device = Device(instance.physicalDevices[0], features, array("VK_LAYER_KHRONOS_validation"), array("VK_KHR_swapchain", "VK_KHR_acceleration_structure", "VK_KHR_ray_tracing_pipeline", "VK_KHR_ray_query", "VK_KHR_spirv_1_4", "VK_KHR_deferred_host_operations"), array(createQueue(0, 1)), features12, rayQueryFeatures, rayTracingPipelineFeatures, accelerationStructureFeatures, features13);
		} else {
			device = Device(instance.physicalDevices[0], features, array("VK_LAYER_KHRONOS_validation"), array("VK_KHR_swapchain", "VK_EXT_sample_locations"), array(createQueue(0, 1)));
		}
		cmdPool = device.createCommandPool(0, VkCommandPoolCreateFlagBits.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT);
		cmdBuffer = cmdPool.allocateCommandBuffer(VkCommandBufferLevel.VK_COMMAND_BUFFER_LEVEL_PRIMARY);
		memoryAllocator.device = &device;
		queue = &device.queues[0];
		fence = device.createFence();

		uploadBuffer = AllocatedResource!Buffer(device.createBuffer(0, 1024 * 16 * 16, VkBufferUsageFlagBits.VK_BUFFER_USAGE_TRANSFER_SRC_BIT));
		memoryAllocator.allocate(uploadBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT);

		uploadVertexData();
		enum string vertexSource = import("a.spv");
		enum string fragmentSource = import("frag.spv");
		vertexShader = device.createShader(vertexSource);
		fragmentShader = device.createShader(fragmentSource);
		enum string vertexSourceNoRT2 = import("rasterVert2.spv");
		enum string fragmentSourceNoRT2 = import("rasterFrag2.spv");
		rasterizer.vertexShader = device.createShader(vertexSourceNoRT2);
		rasterizer.fragmentShader = device.createShader(fragmentSourceNoRT2);

		createComputeShader();
		timer.update();
		writeln(instance.physicalDevices[0].properties.limits.maxComputeWorkGroupInvocations);
		writeln(instance.physicalDevices[0].properties.limits.maxComputeWorkGroupSize[0]);
		writeln(instance.physicalDevices[0].properties.limits.maxComputeWorkGroupSize[1]);
		writeln(instance.physicalDevices[0].properties.limits.maxComputeWorkGroupSize[2]);

		VkMemoryAllocateFlagsInfo flagsInfo;
		flagsInfo.sType = VkStructureType.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_FLAGS_INFO;
		flagsInfo.flags = VkMemoryAllocateFlagBits.VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT;

		drawables = ShaderList!(Drawable, false)(device, memoryAllocator, 16);
		if (rt) {
			initrtPipeline();
			rtModelInfos = ShaderList!(RTModelInfo, false)(device, memoryAllocator, 16);
			asInstances = ShaderList!(VkAccelerationStructureInstanceKHR, false)(device, memoryAllocator, 16, 0, VkBufferUsageFlagBits.VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_BUILD_INPUT_READ_ONLY_BIT_KHR, null, &flagsInfo);
			tlas = Tlas(device, memoryAllocator);
			tlas.create(asInstances.gpuBuffer.getDeviceAddress(), asInstances.length);
		}

		surface = (*ecs.createView!(GlfwVulkanWindow)[0])[0].createVulkanSurface(instance);

		sampler = Sampler(
			device,
			VkFilter.VK_FILTER_LINEAR,
			VkFilter.VK_FILTER_LINEAR,
			VkSamplerMipmapMode.VK_SAMPLER_MIPMAP_MODE_LINEAR,
			VkSamplerAddressMode.VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
			VkSamplerAddressMode.VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
			VkSamplerAddressMode.VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
			0.0,
			false,
			0.0,
			false,
			VkCompareOp.VK_COMPARE_OP_ALWAYS,
			0.0,
			0.0,
			VkBorderColor.VK_BORDER_COLOR_INT_OPAQUE_BLACK,
			false
		);

	}
	// muss noch umgestellt werden, memory von host zu device
	void updateModels(ref CommandBuffer cmdBuffer) {
		if (rt) {
			VkPhysicalDeviceAccelerationStructurePropertiesKHR accProperties;
			accProperties.sType = VkStructureType.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ACCELERATION_STRUCTURE_PROPERTIES_KHR;
			VkPhysicalDeviceProperties2 properties;
			properties.sType = VkStructureType.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2;
			properties.pNext = cast(void*) &accProperties;
			device.physicalDevice.getProperties(&properties);
			VkMemoryAllocateFlagsInfo flagsInfo;
			flagsInfo.sType = VkStructureType.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_FLAGS_INFO;
			flagsInfo.flags = VkMemoryAllocateFlagBits.VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT;

			size_t n = models.getAddUpdateList!WavefrontModel().length;
			auto buildInfos = Vector!VkAccelerationStructureBuildGeometryInfoKHR(n);
			auto rangeInfos = Vector!(VkAccelerationStructureBuildRangeInfoKHR*)(n);
			// in zukunft evt besser nur einen scratch buffer verwenden
			auto scratchBuffers = Vector!(AllocatedResource!Buffer)(n);
			uint i = 0;
			// man könnte onApply erweitern so dass i automatisch gezählt wird
			foreach (id; models.getAddUpdateList!WavefrontModel()) {
				auto entity = models.getEntity(id);
				if (entity.has!ProceduralModel()) {
					entity.add!RTProceduralModel(createProceduralBlas(entity.get!ProceduralModel().min, entity.get!ProceduralModel().max));
					RTModelInfo info;
					info.proceduralModelId = entity.get!ProceduralModel.id;
					entity.add!RTModelInfo(info);
					scratchBuffers[i] = AllocatedResource!Buffer(device.createBuffer(0, entity.get!RTProceduralModel().sizeInfo.buildScratchSize + accProperties.minAccelerationStructureScratchOffsetAlignment, VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT));
					buildInfos[i].pGeometries = &entity.get!RTProceduralModel().geometry;
					buildInfos[i].dstAccelerationStructure = entity.get!RTProceduralModel().blas.accelerationStructure;
					rangeInfos[i] = &entity.get!RTProceduralModel().rangeInfo;
				} else {
					entity.add!RTPolygonModel(createPolygonBlas(entity.get!WavefrontModel()));
					RTModelInfo info;
					info.addresses.vertices = entity.get!RTPolygonModel().vertexBuffer.getDeviceAddress();
					info.addresses.vertexIndices = entity.get!RTPolygonModel().vertexIndexBuffer.getDeviceAddress();
					info.addresses.normals = entity.get!RTPolygonModel().normalBuffer.getDeviceAddress();
					info.addresses.normalIndices = entity.get!RTPolygonModel().normalIndexBuffer.getDeviceAddress();
					entity.add!RTModelInfo(info);
					scratchBuffers[i] = AllocatedResource!Buffer(device.createBuffer(0, entity.get!RTPolygonModel().sizeInfo.buildScratchSize + accProperties.minAccelerationStructureScratchOffsetAlignment, VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT));
					buildInfos[i].pGeometries = &entity.get!RTPolygonModel().geometry;
					buildInfos[i].dstAccelerationStructure = entity.get!RTPolygonModel().blas.accelerationStructure;
					rangeInfos[i] = &entity.get!RTPolygonModel().rangeInfo;
				}
				memoryAllocator.allocate(scratchBuffers[i], VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, flagsInfo);
				buildInfos[i].sType = VkStructureType.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_BUILD_GEOMETRY_INFO_KHR;
				buildInfos[i].flags = VkBuildAccelerationStructureFlagBitsKHR.VK_BUILD_ACCELERATION_STRUCTURE_PREFER_FAST_TRACE_BIT_KHR;
				buildInfos[i].geometryCount = 1;
				buildInfos[i].mode = VkBuildAccelerationStructureModeKHR.VK_BUILD_ACCELERATION_STRUCTURE_MODE_BUILD_KHR;
				buildInfos[i].type = VkAccelerationStructureTypeKHR.VK_ACCELERATION_STRUCTURE_TYPE_BOTTOM_LEVEL_KHR;
				size_t deviceAddressOffset = (accProperties.minAccelerationStructureScratchOffsetAlignment - (scratchBuffers[i].getDeviceAddress() % accProperties.minAccelerationStructureScratchOffsetAlignment)) % accProperties.minAccelerationStructureScratchOffsetAlignment;
				buildInfos[i].scratchData.deviceAddress = scratchBuffers[i].getDeviceAddress() + deviceAddressOffset;
				i++;
			}
			cmdBuffer.buildAccelerationStructures(buildInfos, rangeInfos);
			rtModelInfos.update2(models, cmdBuffer, false);
		} else {
			foreach (id; models.getAddUpdateList!WavefrontModel()) {
				auto entity = models.getEntity(id);
				entity.add!RasterizedModel();
				bool isSmooth = entity.get!WavefrontModel().isSmooth;
				float[] vertices = entity.get!WavefrontModel().vertices;
				uint[] vertexIndices = entity.get!WavefrontModel().indicesVertices;
				float[] normals = entity.get!WavefrontModel().normals;
				uint[] normalIndices = entity.get!WavefrontModel().indicesNormals;
				float[] uvs = entity.get!WavefrontModel().uvs;
				uint[] uvIndices = entity.get!WavefrontModel().indicesUvs;
				RasterizedModel* model = &entity.get!RasterizedModel();
				model.isSmooth = isSmooth;
				if (isSmooth) {
					Vector!float normalsOrdered = Vector!float(vertices.length);
					foreach (i, e; normalIndices) {
						normalsOrdered[vertexIndices[i] * 3] = normals[e * 3];
						normalsOrdered[vertexIndices[i] * 3 + 1] = normals[e * 3 + 1];
						normalsOrdered[vertexIndices[i] * 3 + 2] = normals[e * 3 + 2];
					}
					model.vertexCount = cast(uint)vertices.length / 3;
					model.indexCount = cast(uint)vertexIndices.length;

					model.vertexBuffer = AllocatedResource!Buffer(device.createBuffer(0, vertices.length * float.sizeof, VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT));
					memoryAllocator.allocate(model.vertexBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT);
					model.vertexIndexBuffer = AllocatedResource!Buffer(device.createBuffer(0, vertexIndices.length * float.sizeof, VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_INDEX_BUFFER_BIT));
					memoryAllocator.allocate(model.vertexIndexBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT);

					Memory* memory = &cast(Memory) model.vertexBuffer.allocatedMemory.allocatorList.memory;
					float* floatptr = cast(float*) memory.map(model.vertexBuffer.allocatedMemory.allocation.offset, vertices.length * float.sizeof);
					foreach (j, float f; vertices) {
						floatptr[j] = f;
					}
					memory.flush(array(mappedMemoryRange(*memory, model.vertexBuffer.allocatedMemory.allocation.offset, vertices.length * float.sizeof)));
					memory.unmap();

					memory = &cast(Memory) model.vertexIndexBuffer.allocatedMemory.allocatorList.memory;
					uint* intptr = cast(uint*) memory.map(model.vertexIndexBuffer.allocatedMemory.allocation.offset, vertexIndices.length * uint.sizeof);
					foreach (j, uint f; vertexIndices) {
						intptr[j] = f;
					}
					memory.flush(array(mappedMemoryRange(*memory, model.vertexIndexBuffer.allocatedMemory.allocation.offset, vertexIndices.length * uint.sizeof)));
					memory.unmap();

					model.normalBuffer = AllocatedResource!Buffer(device.createBuffer(0, normalsOrdered.length * float.sizeof, VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT));
					memoryAllocator.allocate(model.normalBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT);
					model.normalIndexBuffer = AllocatedResource!Buffer(device.createBuffer(0, normalIndices.length * float.sizeof, VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT));
					memoryAllocator.allocate(model.normalIndexBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT);

					memory = &cast(Memory) model.normalBuffer.allocatedMemory.allocatorList.memory;
					floatptr = cast(float*) memory.map(model.normalBuffer.allocatedMemory.allocation.offset, normalsOrdered.length * float.sizeof);
					foreach (j, float f; normalsOrdered) {
						floatptr[j] = f;
					}
					memory.flush(array(mappedMemoryRange(*memory, model.normalBuffer.allocatedMemory.allocation.offset, normalsOrdered.length * float.sizeof)));
					memory.unmap();

					memory = &cast(Memory) model.normalIndexBuffer.allocatedMemory.allocatorList.memory;
					intptr = cast(uint*) memory.map(model.normalIndexBuffer.allocatedMemory.allocation.offset, normalIndices.length * uint.sizeof);
					foreach (j, uint f; normalIndices) {
						intptr[j] = f;
					}
					memory.flush(array(mappedMemoryRange(*memory, model.normalIndexBuffer.allocatedMemory.allocation.offset, normalIndices.length * uint.sizeof)));
					memory.unmap();
				} else {
					uint verticesLength = cast(uint)(3 * vertexIndices.length);
					Vector!float normalsOrdered = Vector!float(normals.length);
					foreach (i, e; normalIndices) {
						normalsOrdered[normalIndices[i] * 3] = normals[e * 3];
						normalsOrdered[normalIndices[i] * 3 + 1] = normals[e * 3 + 1];
						normalsOrdered[normalIndices[i] * 3 + 2] = normals[e * 3 + 2];
					}
					model.vertexCount = cast(uint)vertices.length / 3;
					model.indexCount = cast(uint)vertexIndices.length;

					model.vertexBuffer = AllocatedResource!Buffer(device.createBuffer(0, verticesLength * float.sizeof, VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT));
					memoryAllocator.allocate(model.vertexBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT);
					model.vertexIndexBuffer = AllocatedResource!Buffer(device.createBuffer(0, vertexIndices.length * float.sizeof, VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_INDEX_BUFFER_BIT));
					memoryAllocator.allocate(model.vertexIndexBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT);

					Memory* memory = &cast(Memory) model.vertexBuffer.allocatedMemory.allocatorList.memory;
					float* floatptr = cast(float*) memory.map(model.vertexBuffer.allocatedMemory.allocation.offset, verticesLength * float.sizeof);
					for (uint j = 0; j < vertexIndices.length; j++) {
						floatptr[3 * j] = vertices[3 * vertexIndices[j]];
						floatptr[3 * j + 1] = vertices[3 * vertexIndices[j] + 1];
						floatptr[3 * j + 2] = vertices[3 * vertexIndices[j] + 2];
					}
					memory.flush(array(mappedMemoryRange(*memory, model.vertexBuffer.allocatedMemory.allocation.offset, verticesLength * float.sizeof)));
					memory.unmap();
					model.vertexCount = cast(uint)vertexIndices.length;

					memory = &cast(Memory) model.vertexIndexBuffer.allocatedMemory.allocatorList.memory;
					uint* intptr = cast(uint*) memory.map(model.vertexIndexBuffer.allocatedMemory.allocation.offset, vertexIndices.length * uint.sizeof);
					foreach (j, uint f; vertexIndices) {
						intptr[j] = f;
					}
					memory.flush(array(mappedMemoryRange(*memory, model.vertexIndexBuffer.allocatedMemory.allocation.offset, vertexIndices.length * uint.sizeof)));
					memory.unmap();

					model.normalBuffer = AllocatedResource!Buffer(device.createBuffer(0, verticesLength * float.sizeof, VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT));
					memoryAllocator.allocate(model.normalBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT);
					model.normalIndexBuffer = AllocatedResource!Buffer(device.createBuffer(0, normalIndices.length * float.sizeof, VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT));
					memoryAllocator.allocate(model.normalIndexBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT);

					memory = &cast(Memory) model.normalBuffer.allocatedMemory.allocatorList.memory;
					floatptr = cast(float*) memory.map(model.normalBuffer.allocatedMemory.allocation.offset, verticesLength * float.sizeof);

					for (uint j = 0; j < vertexIndices.length; j++) {
						floatptr[3 * j] = normals[3 * normalIndices[j]];
						floatptr[3 * j + 1] = normals[3 * normalIndices[j] + 1];
						floatptr[3 * j + 2] = normals[3 * normalIndices[j] + 2];
					}
					memory.flush(array(mappedMemoryRange(*memory, model.normalBuffer.allocatedMemory.allocation.offset, verticesLength * float.sizeof)));
					memory.unmap();

					memory = &cast(Memory) model.normalIndexBuffer.allocatedMemory.allocatorList.memory;
					intptr = cast(uint*) memory.map(model.normalIndexBuffer.allocatedMemory.allocation.offset, normalIndices.length * uint.sizeof);
					foreach (j, uint f; normalIndices) {
						intptr[j] = f;
					}
					memory.flush(array(mappedMemoryRange(*memory, model.normalIndexBuffer.allocatedMemory.allocation.offset, normalIndices.length * uint.sizeof)));
					memory.unmap();
				}
			}
		}
		models.clearAddUpdateList!WavefrontModel();
	}
	void uploadVertexData() {
		Memory* memory = &uploadBuffer.allocatedMemory.allocatorList.memory;
		enum string fontfile = import("free_pixel_regular_16test.xml");
		font = AsciiBitfont(fontfile);
		enum string pngData = import("free_pixel_regular_16test.PNG");
		pngFont = Png(pngData);
		fontTexture = AllocatedResource!Image(device.createImage(0, VkImageType.VK_IMAGE_TYPE_2D, VkFormat.VK_FORMAT_B8G8R8A8_UNORM, VkExtent3D(pngFont.width, pngFont.height, 1), 1, 1, VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT, VkImageTiling.VK_IMAGE_TILING_OPTIMAL, VkImageUsageFlagBits.VK_IMAGE_USAGE_SAMPLED_BIT | VkImageUsageFlagBits.VK_IMAGE_USAGE_TRANSFER_DST_BIT | VkImageUsageFlagBits.VK_IMAGE_USAGE_STORAGE_BIT, VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED));
		memoryAllocator.allocate(fontTexture, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
		char* charptr = cast(char*) memory.map(0, pngFont.byteCount * pngFont.height * pngFont.width);
		foreach (i; 0 .. pngFont.byteCount * pngFont.height * pngFont.width) {
			charptr[i] = pngFont.content[i];
		}
		
		memory.flush(array(mappedMemoryRange(*memory, 0, /*1024 + pngFont.byteCount*/ VK_WHOLE_SIZE)));
		memory.unmap();

		cmdBuffer.begin();
		cmdBuffer.pipelineBarrier(
			VkPipelineStageFlagBits.VK_PIPELINE_STAGE_ALL_COMMANDS_BIT,
			VkPipelineStageFlagBits.VK_PIPELINE_STAGE_ALL_COMMANDS_BIT,
			0, [], [],
			array(imageMemoryBarrier(
				0,
				0,
				VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
				VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
				fontTexture,
				VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
			))
		);
		cmdBuffer.copyBufferToImage(uploadBuffer, fontTexture, VkImageLayout.VK_IMAGE_LAYOUT_GENERAL, 0, pngFont.width, pngFont.height, VkImageSubresourceLayers(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1), VkOffset3D(0, 0, 0), VkExtent3D(pngFont.width, pngFont.height, 1));
		cmdBuffer.end();
		queue.submit(cmdBuffer, fence);
		fence.wait();
		cmdBuffer.reset();
		fence.reset();
		fontImageView = ImageView(
			device,
			fontTexture,
			VkImageViewType.VK_IMAGE_VIEW_TYPE_2D,
			VkFormat.VK_FORMAT_B8G8R8A8_UNORM,
			VkComponentMapping(
				VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
				VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
				VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
				VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY
			),
			VkImageSubresourceRange(
				VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT,
				0,
				1,
				0,
				1
			)
		);
	}
	void createComputeShader() {
		enum string computeSource = import("blur.spv");
		computeShader = Shader(device, computeSource);
		descriptorSetLayout = device.createDescriptorSetLayout(array(VkDescriptorSetLayoutBinding(
			0,
			VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
			1,
			VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT,
			null
		), VkDescriptorSetLayoutBinding(
			1,
			VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
			1,
			VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT,
			null
		), VkDescriptorSetLayoutBinding(
			2,
			VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
			1,
			VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT,
			null
		), VkDescriptorSetLayoutBinding(
			3,
			VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
			1,
			VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT,
			null
		)));

		pipelineLayout = device.createPipelineLayout(array(descriptorSetLayout/*, circleImplStruct.descriptorSetLayout*/), array(VkPushConstantRange(VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT, 0, uint.sizeof * 1)));//array(/*VkPushConstantRange(VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT, 0, float.sizeof)*/));
		import core.stdc.math : sqrt;
		int size2D = cast(int) sqrt(instance.physicalDevices[0].properties.limits.maxComputeWorkGroupInvocations);
		localWorkGroupSize[0] = size2D;
		localWorkGroupSize[1] = size2D;
		localWorkGroupSize[2] = 1;
		writeln(localWorkGroupSize);
		computePipeline = device.createComputePipeline(computeShader, "main", pipelineLayout, array(VkSpecializationMapEntry(0, 0, 4), VkSpecializationMapEntry(1, 4, 4), VkSpecializationMapEntry(2, 8, 4)), 12, localWorkGroupSize.ptr, null);
		descriptorPool = device.createDescriptorPool(0, 2, array(VkDescriptorPoolSize(
			VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
			1
		), VkDescriptorPoolSize(
			VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
			1
		), VkDescriptorPoolSize(
			VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
			1
		), VkDescriptorPoolSize(
			VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
			1
		)));
		descriptorSet = descriptorPool.allocateSet(descriptorSetLayout);
		descriptorSet2 = descriptorPool.allocateSet(descriptorSetLayout);

		enum string blur2Source = import("blur2.spv");
		blurPipeline.computeShader = Shader(device, blur2Source);
		blurPipeline.descriptorSetLayout = device.createDescriptorSetLayout(array(VkDescriptorSetLayoutBinding(
			0,
			VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
			1,
			VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT,
			null
		), VkDescriptorSetLayoutBinding(
			1,
			VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
			1,
			VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT,
			null
		), VkDescriptorSetLayoutBinding(
			2,
			VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
			1,
			VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT,
			null
		)));
		blurPipeline.pipelineLayout = device.createPipelineLayout(array(blurPipeline.descriptorSetLayout), array(VkPushConstantRange(VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT, 0, uint.sizeof * 8)));
		blurPipeline.computePipeline = device.createComputePipeline(blurPipeline.computeShader, "main", blurPipeline.pipelineLayout, array(VkSpecializationMapEntry(0, 0, 4), VkSpecializationMapEntry(1, 4, 4), VkSpecializationMapEntry(2, 8, 4)), 12, localWorkGroupSize.ptr, null);
		blurPipeline.descriptorPool = device.createDescriptorPool(0, 1, array(VkDescriptorPoolSize(
			VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
			3
		)));
		blurPipeline.descriptorSet = blurPipeline.descriptorPool.allocateSet(blurPipeline.descriptorSetLayout);

		imageAssembler.computeShader = Shader(device, import("assembler.spv"));
		imageAssembler.descriptorSetLayout = device.createDescriptorSetLayout(array(VkDescriptorSetLayoutBinding(
			0,
			VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
			1,
			VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT,
			null
		), VkDescriptorSetLayoutBinding(
			1,
			VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
			1,
			VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT,
			null
		), VkDescriptorSetLayoutBinding(
			2,
			VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
			1,
			VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT,
			null
		), VkDescriptorSetLayoutBinding(
			3,
			VkDescriptorType.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
			1,
			VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT,
			null
		), VkDescriptorSetLayoutBinding(
			4,
			VkDescriptorType.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
			1,
			VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT,
			null
		), VkDescriptorSetLayoutBinding(
			5,
			VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
			1,
			VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT,
			null
		), VkDescriptorSetLayoutBinding(
			6,
			VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
			1,
			VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT,
			null
		), VkDescriptorSetLayoutBinding(
			7,
			VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
			1,
			VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT,
			null
		), VkDescriptorSetLayoutBinding(
			8,
			VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
			1,
			VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT,
			null
		), VkDescriptorSetLayoutBinding(
			9,
			VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
			1,
			VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT,
			null
		), VkDescriptorSetLayoutBinding(
			10,
			VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
			1,
			VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT,
			null
		), VkDescriptorSetLayoutBinding(
			11,
			VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
			1,
			VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT,
			null
		), VkDescriptorSetLayoutBinding(
			12,
			VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
			1,
			VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT,
			null
		)));
		imageAssembler.pipelineLayout = device.createPipelineLayout(array(imageAssembler.descriptorSetLayout), array(VkPushConstantRange(VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT, 0, uint.sizeof * 8)));
		imageAssembler.computePipeline = device.createComputePipeline(imageAssembler.computeShader, "main", imageAssembler.pipelineLayout,
			array(VkSpecializationMapEntry(0, 0, 4), VkSpecializationMapEntry(1, 4, 4), VkSpecializationMapEntry(2, 8, 4)),
			12, localWorkGroupSize.ptr, null);
		imageAssembler.descriptorPool = device.createDescriptorPool(0, 1, array(
			VkDescriptorPoolSize(
				VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
				11
			),
			VkDescriptorPoolSize(
				VkDescriptorType.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
				2
			),
		));
		imageAssembler.descriptorSet = imageAssembler.descriptorPool.allocateSet(imageAssembler.descriptorSetLayout);
	}
	void rebuildSwapchain() {
		// müssen rasterizerpackages nicht explizit zerstört werden?
		vkDeviceWaitIdle(device.device);
		swapchainViews.resize(0);
		framebuffers.resize(0);
		firstFramebuffer[0].destroy();
		firstFramebuffer[1].destroy();
		graphicsDescriptorSet.destroy();
		graphicsDescriptorPool.destroy();
		graphicsPipeline.destroy();
		renderPass.destroy();
		rasterizer.renderPass.destroy();
		pipelineLayoutGraphics.destroy();
		graphicsDescriptorSetLayout.destroy();

		blurredImageView.destroy();
		blurredImage.destroy();
		normalImageView.destroy();
		normalImage.destroy();
		depthImageView.destroy();
		depthImage.destroy();
		rasterDepthImage.destroy();
		rasterDepthImageView.destroy();
		dPosImageView[0].destroy();
		dPosImage[0].destroy();
		dPosImageView[1].destroy();
		dPosImage[1].destroy();
		for (int i = 0; i < 2; i++) {
			for (int j = 0; j < 2; j++) {
				doubleColorImage[i][j].destroy();
				doubleColorImageView[i][j].destroy();
			}
		}
		oldDepthImageView[0].destroy();
		oldDepthImageView[1].destroy();
		oldDepthImage[0].destroy();
		oldDepthImage[1].destroy();
		depthGuessImageView.destroy();
		depthGuessImage.destroy();
		renderImageView.destroy();
		renderImage.destroy();
		normalsImageView[0].destroy();
		normalsImageView[1].destroy();
		normalsImage[0].destroy();
		normalsImage[1].destroy();

		swapchain.destroy();

		initWindow();
	}
	void initWindow() {
		graphicsDescriptorSetLayout = device.createDescriptorSetLayout(array(VkDescriptorSetLayoutBinding(
			0,
			VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
			1,
			VkShaderStageFlagBits.VK_SHADER_STAGE_FRAGMENT_BIT,
			null
		)));
		graphicsDescriptorPool = device.createDescriptorPool(0, 1, array(VkDescriptorPoolSize(
			VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
			1
		)));
		graphicsDescriptorSet = graphicsDescriptorPool.allocateSet(graphicsDescriptorSetLayout);
		graphicsDescriptorSet.write(WriteDescriptorSet(0, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, fontImageView, VkImageLayout.VK_IMAGE_LAYOUT_GENERAL));
		pipelineLayoutGraphics = device.createPipelineLayout(array(graphicsDescriptorSetLayout), []);

		/*{
			rasterizerPackage.descriptorSetLayout = device.createDescriptorSetLayout(array(
				VkDescriptorSetLayoutBinding(
					0,
					VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
					1,
					VkShaderStageFlagBits.VK_SHADER_STAGE_FRAGMENT_BIT,
					null
				),
				VkDescriptorSetLayoutBinding(
					1,
					VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
					1,
					VkShaderStageFlagBits.VK_SHADER_STAGE_VERTEX_BIT,
					null
				)
			));
			rasterizerPackage.descriptorPool = device.createDescriptorPool(0, 2, array(
				VkDescriptorPoolSize(
					VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
					2
				),
				VkDescriptorPoolSize(
					VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
					2
				)
			));
			rasterizerPackage.descriptorSet = rasterizerPackage.descriptorPool.allocateSet(rasterizerPackage.descriptorSetLayout);
			rasterizerPackage.descriptorSet.write(WriteDescriptorSet(0, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, fontImageView, VkImageLayout.VK_IMAGE_LAYOUT_GENERAL));
			rasterizerPackage.descriptorSet.write(WriteDescriptorSet(1, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, sphereShaderList.gpuBuffer));
			rasterizerPackage.pipelineLayout = device.createPipelineLayout(array(rasterizerPackage.descriptorSetLayout), array(VkPushConstantRange(VkShaderStageFlagBits.VK_SHADER_STAGE_VERTEX_BIT, 0, float.sizeof * 6)));

			cubeDescriptorSet = rasterizerPackage.descriptorPool.allocateSet(rasterizerPackage.descriptorSetLayout);
			cubeDescriptorSet.write(WriteDescriptorSet(0, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, fontImageView, VkImageLayout.VK_IMAGE_LAYOUT_GENERAL));
			cubeDescriptorSet.write(WriteDescriptorSet(1, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, cubeShaderList.gpuBuffer));
		}*/
		{
			rasterizer.descriptorSetLayout = device.createDescriptorSetLayout(array(
				/*VkDescriptorSetLayoutBinding(
					0,
					VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
					1,
					VkShaderStageFlagBits.VK_SHADER_STAGE_FRAGMENT_BIT,
					null
				),*/
				VkDescriptorSetLayoutBinding(
					0,
					VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
					1,
					VkShaderStageFlagBits.VK_SHADER_STAGE_VERTEX_BIT,
					null
				),
				VkDescriptorSetLayoutBinding(
					1,
					VkDescriptorType.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
					1,
					VkShaderStageFlagBits.VK_SHADER_STAGE_FRAGMENT_BIT,
					null
				),
				VkDescriptorSetLayoutBinding(
					2,
					VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
					1,
					VkShaderStageFlagBits.VK_SHADER_STAGE_FRAGMENT_BIT,
					null
				),
				VkDescriptorSetLayoutBinding(
					3,
					VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
					1,
					VkShaderStageFlagBits.VK_SHADER_STAGE_FRAGMENT_BIT,
					null
				),
				VkDescriptorSetLayoutBinding(
					4,
					VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
					1,
					VkShaderStageFlagBits.VK_SHADER_STAGE_FRAGMENT_BIT,
					null
				),
				VkDescriptorSetLayoutBinding(
					5,
					VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
					1,
					VkShaderStageFlagBits.VK_SHADER_STAGE_FRAGMENT_BIT,
					null
				),
				VkDescriptorSetLayoutBinding(
					6,
					VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
					1,
					VkShaderStageFlagBits.VK_SHADER_STAGE_FRAGMENT_BIT,
					null
				),
			));
			rasterizer.descriptorPool = device.createDescriptorPool(0, 1, array(
				/*VkDescriptorPoolSize(
					VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
					1
				),*/
				VkDescriptorPoolSize(
					VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
					1
				),
				VkDescriptorPoolSize(
					VkDescriptorType.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
					1
				),
				VkDescriptorPoolSize(
					VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
					5
				),
			));
			rasterizer.descriptorSet = rasterizer.descriptorPool.allocateSet(rasterizer.descriptorSetLayout);
			//rasterizer.descriptorSet.write(WriteDescriptorSet(0, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, fontImageView, VkImageLayout.VK_IMAGE_LAYOUT_GENERAL));
			rasterizer.descriptorSet.write(WriteDescriptorSet(0, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, drawables.gpuBuffer));
			rasterizer.pipelineLayout = device.createPipelineLayout(array(rasterizer.descriptorSetLayout), array(VkPushConstantRange(VkShaderStageFlagBits.VK_SHADER_STAGE_VERTEX_BIT | VkShaderStageFlagBits.VK_SHADER_STAGE_FRAGMENT_BIT, 0, float.sizeof * 13)));
		}

		// man sollte vlt zuerst ein physical device finden mit surface support bevor man ein device erstellt
		bool surfacesupport = instance.physicalDevices[0].surfaceSupported(surface);
		capabilities = instance.physicalDevices[0].getSurfaceCapabilities(surface);
		auto surfaceformats = instance.physicalDevices[0].getSurfaceFormats(surface);
		auto oldSwapchain = swapchain.swapchain;
		swapchain.swapchain = null;
		swapchain = device.createSwapchain(
			surface,
			3,
			VkFormat.VK_FORMAT_B8G8R8A8_UNORM,
			VkColorSpaceKHR.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR,
			capabilities.currentExtent,
			1,
			VkImageUsageFlagBits.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VkImageUsageFlagBits.VK_IMAGE_USAGE_TRANSFER_DST_BIT | VkImageUsageFlagBits.VK_IMAGE_USAGE_STORAGE_BIT | VkImageUsageFlagBits.VK_IMAGE_USAGE_SAMPLED_BIT,
			VkSharingMode.VK_SHARING_MODE_EXCLUSIVE,
			[],
			VkSurfaceTransformFlagBitsKHR.VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR,
			VkCompositeAlphaFlagBitsKHR.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
			// immediate gibt zu viele fps, fifo gibt vsync aber es laggt bei mir auf arch?
			//VkPresentModeKHR.VK_PRESENT_MODE_IMMEDIATE_KHR,
			VkPresentModeKHR.VK_PRESENT_MODE_FIFO_KHR,
			true,
			oldSwapchain
		);
		rasterDepthImage = AllocatedResource!Image(device.createImage(VkImageCreateFlagBits.VK_IMAGE_CREATE_SAMPLE_LOCATIONS_COMPATIBLE_DEPTH_BIT_EXT, VkImageType.VK_IMAGE_TYPE_2D, VkFormat.VK_FORMAT_D32_SFLOAT, VkExtent3D(capabilities.currentExtent.width, capabilities.currentExtent.height, 1), 1, 1, VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT, VkImageTiling.VK_IMAGE_TILING_OPTIMAL, VkImageUsageFlagBits.VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT, VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED));
		memoryAllocator.allocate(rasterDepthImage, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
		rasterDepthImageView = ImageView(
			device,
			rasterDepthImage,
			VkImageViewType.VK_IMAGE_VIEW_TYPE_2D,
			VkFormat.VK_FORMAT_D32_SFLOAT,
			VkComponentMapping(
				VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
				VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
				VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
				VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY
			),
			VkImageSubresourceRange(
				VkImageAspectFlagBits.VK_IMAGE_ASPECT_DEPTH_BIT,
				0,
				1,
				0,
				1
			)
		);
		auto depthAttachmentRef = VkAttachmentReference(
			1,
			VkImageLayout.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL
		);
		renderPass = device.createRenderPass(
			array(
				VkAttachmentDescription(
					0,
					VkFormat.VK_FORMAT_B8G8R8A8_UNORM,
					VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT,
					VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_LOAD,
					VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_STORE,
					VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
					VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_DONT_CARE,
					VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
					VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
				),
				VkAttachmentDescription(
					0,
					VkFormat.VK_FORMAT_D32_SFLOAT,
					VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT,
					VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_CLEAR,
					VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_STORE,
					VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_CLEAR,
					VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_DONT_CARE,
					VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
					VkImageLayout.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL
				),
			),
			array(
				subpassDescription(
					[],
					array(
						VkAttachmentReference(
							0,
							VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
						),
					),
					[],
					&depthAttachmentRef,
					[]
				)
			),
			[]
		);
		rasterizer.renderPass = device.createRenderPass(
			array(
				VkAttachmentDescription(
					0,
					VkFormat.VK_FORMAT_B8G8R8A8_UNORM,
					VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT,
					VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_CLEAR,
					VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_STORE,
					VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
					VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_DONT_CARE,
					VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
					VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
				),
				VkAttachmentDescription(
					0,
					VkFormat.VK_FORMAT_D32_SFLOAT,
					VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT,
					VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_CLEAR,
					VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_STORE,
					VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_CLEAR,
					VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_DONT_CARE,
					VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
					VkImageLayout.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL
				),
				VkAttachmentDescription(
					0,
					VkFormat.VK_FORMAT_B8G8R8A8_UNORM,
					VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT,
					VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_CLEAR,
					VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_STORE,
					VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
					VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_DONT_CARE,
					VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
					VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
				),
				VkAttachmentDescription(
					0,
					VkFormat.VK_FORMAT_B8G8R8A8_UNORM,
					VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT,
					VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_CLEAR,
					VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_STORE,
					VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
					VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_DONT_CARE,
					VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
					VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
				),
				VkAttachmentDescription(
					0,
					VkFormat.VK_FORMAT_B8G8R8A8_UNORM,
					VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT,
					VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_CLEAR,
					VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_STORE,
					VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
					VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_DONT_CARE,
					VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
					VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
				),
				VkAttachmentDescription(
					0,
					VkFormat.VK_FORMAT_B8G8R8A8_UNORM,
					VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT,
					VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_CLEAR,
					VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_STORE,
					VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
					VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_DONT_CARE,
					VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
					VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
				),
				VkAttachmentDescription(
					0,
					VkFormat.VK_FORMAT_B8G8R8A8_UNORM,
					VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT,
					VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_CLEAR,
					VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_STORE,
					VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
					VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_DONT_CARE,
					VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
					VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
				),
			),
			array(
				subpassDescription(
					[],
					array(
						VkAttachmentReference(
							0,
							VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
						),
						VkAttachmentReference(
							2,
							VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
						),
						VkAttachmentReference(
							3,
							VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
						),
						VkAttachmentReference(
							4,
							VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
						),
						VkAttachmentReference(
							5,
							VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
						),
						VkAttachmentReference(
							6,
							VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
						),
					),
					[],
					&depthAttachmentRef,
					[]
				)
			),
			array(
				VkSubpassDependency(
					VK_SUBPASS_EXTERNAL,
					0,
					VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
					VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
					0,
					VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
					0
				),
				VkSubpassDependency(
					VK_SUBPASS_EXTERNAL,
					0,
					VkPipelineStageFlagBits.VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT | VkPipelineStageFlagBits.VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT,
					VkPipelineStageFlagBits.VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT | VkPipelineStageFlagBits.VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT,
					0,
					VkAccessFlagBits.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT,
					0
				),
				VkSubpassDependency(
					VK_SUBPASS_EXTERNAL,
					0,
					VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
					VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
					0,
					VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
					0
				),
				VkSubpassDependency(
					VK_SUBPASS_EXTERNAL,
					0,
					VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
					VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
					0,
					VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
					0
				),
				VkSubpassDependency(
					VK_SUBPASS_EXTERNAL,
					0,
					VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
					VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
					0,
					VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
					0
				),
				VkSubpassDependency(
					VK_SUBPASS_EXTERNAL,
					0,
					VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
					VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
					0,
					VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
					0
				),
				VkSubpassDependency(
					VK_SUBPASS_EXTERNAL,
					0,
					VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
					VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
					0,
					VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
					0
				),
			)
		);
		
		swapchainViews.resize(swapchain.images.length);
		framebuffers.resize(swapchain.images.length);
		foreach (i; 0 .. swapchain.images.length) {
			swapchainViews[i] = ImageView(
				device,
				swapchain.images[i],
				VkImageViewType.VK_IMAGE_VIEW_TYPE_2D,
				VkFormat.VK_FORMAT_B8G8R8A8_UNORM,
				VkComponentMapping(
					VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
					VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
					VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
					VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY
				),
				VkImageSubresourceRange(
					VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT,
					0,
					1,
					0,
					1
				)
			);
			framebuffers[i] = renderPass.createFramebuffer(array(swapchainViews[i].imageView, rasterDepthImageView), capabilities.currentExtent.width, capabilities.currentExtent.height, 1);
		}
		
		// gui
		{
			auto vertStage = shaderStageInfo(VkShaderStageFlagBits.VK_SHADER_STAGE_VERTEX_BIT, vertexShader, "main", [], 0, null);
			auto fragStage = shaderStageInfo(VkShaderStageFlagBits.VK_SHADER_STAGE_FRAGMENT_BIT, fragmentShader, "main", [], 0, null);
			auto vertexInputStateCreateInfo = vertexInputState(
				array(VkVertexInputBindingDescription(0, float.sizeof * 4, VkVertexInputRate.VK_VERTEX_INPUT_RATE_VERTEX)),
				array(
					VkVertexInputAttributeDescription(0, 0, VkFormat.VK_FORMAT_R32G32B32A32_SFLOAT, 0),
					VkVertexInputAttributeDescription(1, 0, VkFormat.VK_FORMAT_R32G32_SFLOAT, float.sizeof * 2)
				)
			);
			auto inputAssemblyStateCreateInfo = inputAssemblyState(VkPrimitiveTopology.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST, false);
			VkViewport dummyViewport;
			if (capabilities.currentExtent.width < capabilities.currentExtent.height)
				dummyViewport = VkViewport(0.0f, 0.0f, capabilities.currentExtent.width, capabilities.currentExtent.width, 0.1f, 1.0f);
			else
				dummyViewport = VkViewport(0.0f, 0.0f, capabilities.currentExtent.height, capabilities.currentExtent.height, 0.1f, 1.0f);
			auto dummyScissor = VkRect2D(VkOffset2D(0, 0), capabilities.currentExtent);
			auto viewportStateCreateInfo = viewportState(array(dummyViewport), array(dummyScissor));
			auto rasterizationStateCreateInfo = rasterizationState(
				false,
				false,
				VkPolygonMode.VK_POLYGON_MODE_FILL,
				//VkCullModeFlagBits.VK_CULL_MODE_NONE,
				VkCullModeFlagBits.VK_CULL_MODE_FRONT_BIT,
				VkFrontFace.VK_FRONT_FACE_COUNTER_CLOCKWISE,
				false,
				0, 0, 0, 1
			);
			auto multiSample = multisampleState(VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT, false, 0, [], false, false);
			VkPipelineColorBlendAttachmentState blendAttachment;
			blendAttachment.blendEnable = VK_TRUE;
			blendAttachment.colorWriteMask = 0xf;
			blendAttachment.srcColorBlendFactor = VkBlendFactor.VK_BLEND_FACTOR_SRC_ALPHA;
			blendAttachment.dstColorBlendFactor = VkBlendFactor.VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA;
			blendAttachment.colorBlendOp = VkBlendOp.VK_BLEND_OP_ADD;
			//blendAttachment.srcAlphaBlendFactor = VkBlendFactor.VK_BLEND_FACTOR_SRC_ALPHA;
			//blendAttachment.dstAlphaBlendFactor = VkBlendFactor.VK_BLEND_FACTOR_DST_ALPHA;
			//blendAttachment.alphaBlendOp = VkBlendOp.VK_BLEND_OP_ADD;
			auto blend = colorBlendState(false, VkLogicOp.VK_LOGIC_OP_OR, array(blendAttachment), [0.5, 0.5, 0.5, 0.5]);

			auto depthStencil = depthStencilState(
				true,
				true,
				VkCompareOp.VK_COMPARE_OP_GREATER_OR_EQUAL,
				false,
				false,
				VkStencilOpState(),
				VkStencilOpState(),
				0.0,
				1.0
			);

			graphicsPipeline = renderPass.createGraphicsPipeline(
				vertStage,
				fragStage,
				vertexInputStateCreateInfo,
				inputAssemblyStateCreateInfo,
				viewportStateCreateInfo,
				rasterizationStateCreateInfo,
				multiSample,
				blend,
				depthStencil,
				pipelineLayoutGraphics
			);
		}
		
		// no RT
		/*{
			auto vertStage = shaderStageInfo(VkShaderStageFlagBits.VK_SHADER_STAGE_VERTEX_BIT, rasterizerPackage.vertexShader, "main", [], 0, null);
			auto fragStage = shaderStageInfo(VkShaderStageFlagBits.VK_SHADER_STAGE_FRAGMENT_BIT, rasterizerPackage.fragmentShader, "main", [], 0, null);
			auto vertexInputStateCreateInfo = vertexInputState(
				array(
					VkVertexInputBindingDescription(0, float.sizeof * 3, VkVertexInputRate.VK_VERTEX_INPUT_RATE_VERTEX),
					VkVertexInputBindingDescription(1, float.sizeof * 3, VkVertexInputRate.VK_VERTEX_INPUT_RATE_VERTEX)
				),
				array(
					VkVertexInputAttributeDescription(0, 0, VkFormat.VK_FORMAT_R32G32B32_SFLOAT, 0),
					VkVertexInputAttributeDescription(1, 1, VkFormat.VK_FORMAT_R32G32B32_SFLOAT, 0),
					//VkVertexInputAttributeDescription(1, 0, VkFormat.VK_FORMAT_R32G32_SFLOAT, float.sizeof * 2)
				)
			);
			auto inputAssemblyStateCreateInfo = inputAssemblyState(VkPrimitiveTopology.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST, false);
			VkViewport dummyViewport;
			//dummyViewport = VkViewport(capabilities.currentExtent.width / 2.0 - capabilities.currentExtent.height / 2.0, 0.0f, capabilities.currentExtent.height, capabilities.currentExtent.height, 0.1f, 1.0f);
			dummyViewport = VkViewport(0.0, 0.0f, capabilities.currentExtent.width, capabilities.currentExtent.height, 0.0f, 1.0f);
			//dummyViewport = VkViewport(0.0, 0.0f, cast(float)capabilities.currentExtent.height * (cast(float)capabilities.currentExtent.height / cast(float) capabilities.currentExtent.width), capabilities.currentExtent.height, 0.1f, 1.0f);
			//dummyViewport = VkViewport(0.0, 0.0f, capabilities.currentExtent.height, capabilities.currentExtent.height, 0.1f, 1.0f);
			auto dummyScissor = VkRect2D(VkOffset2D(0, 0), capabilities.currentExtent);
			auto viewportStateCreateInfo = viewportState(array(dummyViewport), array(dummyScissor));
			auto rasterizationStateCreateInfo = rasterizationState(
				false,
				false,
				VkPolygonMode.VK_POLYGON_MODE_FILL,
				//VkCullModeFlagBits.VK_CULL_MODE_NONE,
				VkCullModeFlagBits.VK_CULL_MODE_FRONT_BIT,
				VkFrontFace.VK_FRONT_FACE_COUNTER_CLOCKWISE,
				false,
				0, 0, 0, 1
			);
			auto multiSample = multisampleState(VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT, false, 0, [], false, false);
			VkPipelineColorBlendAttachmentState blendAttachment;
			blendAttachment.blendEnable = VK_TRUE;
			blendAttachment.colorWriteMask = 0xf;
			blendAttachment.srcColorBlendFactor = VkBlendFactor.VK_BLEND_FACTOR_SRC_ALPHA;
			blendAttachment.dstColorBlendFactor = VkBlendFactor.VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA;
			blendAttachment.colorBlendOp = VkBlendOp.VK_BLEND_OP_ADD;
			//blendAttachment.srcAlphaBlendFactor = VkBlendFactor.VK_BLEND_FACTOR_SRC_ALPHA;
			//blendAttachment.dstAlphaBlendFactor = VkBlendFactor.VK_BLEND_FACTOR_DST_ALPHA;
			//blendAttachment.alphaBlendOp = VkBlendOp.VK_BLEND_OP_ADD;
			auto blend = colorBlendState(false, VkLogicOp.VK_LOGIC_OP_OR, array(blendAttachment), [0.5, 0.5, 0.5, 0.5]);

			auto depthStencil = depthStencilState(
				true,
				true,
				VkCompareOp.VK_COMPARE_OP_GREATER_OR_EQUAL,
				false,
				false,
				VkStencilOpState(),
				VkStencilOpState(),
				0.0,
				1.0
			);

			rasterizerPackage.pipeline = renderPass.createGraphicsPipeline(
				vertStage,
				fragStage,
				vertexInputStateCreateInfo,
				inputAssemblyStateCreateInfo,
				viewportStateCreateInfo,
				rasterizationStateCreateInfo,
				multiSample,
				blend,
				depthStencil,
				rasterizerPackage.pipelineLayout
			);
		}*/
		{
			auto vertStage = shaderStageInfo(VkShaderStageFlagBits.VK_SHADER_STAGE_VERTEX_BIT, rasterizer.vertexShader, "main", [], 0, null);
			auto fragStage = shaderStageInfo(VkShaderStageFlagBits.VK_SHADER_STAGE_FRAGMENT_BIT, rasterizer.fragmentShader, "main", [], 0, null);
			auto vertexInputStateCreateInfo = vertexInputState(
				array(
					VkVertexInputBindingDescription(0, float.sizeof * 3, VkVertexInputRate.VK_VERTEX_INPUT_RATE_VERTEX),
					VkVertexInputBindingDescription(1, float.sizeof * 3, VkVertexInputRate.VK_VERTEX_INPUT_RATE_VERTEX)
				),
				array(
					VkVertexInputAttributeDescription(0, 0, VkFormat.VK_FORMAT_R32G32B32_SFLOAT, 0),
					VkVertexInputAttributeDescription(1, 1, VkFormat.VK_FORMAT_R32G32B32_SFLOAT, 0),
					//VkVertexInputAttributeDescription(1, 0, VkFormat.VK_FORMAT_R32G32_SFLOAT, float.sizeof * 2)
				)
			);
			auto inputAssemblyStateCreateInfo = inputAssemblyState(VkPrimitiveTopology.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST, false);
			VkViewport dummyViewport;
			//dummyViewport = VkViewport(capabilities.currentExtent.width / 2.0 - capabilities.currentExtent.height / 2.0, 0.0f, capabilities.currentExtent.height, capabilities.currentExtent.height, 0.1f, 1.0f);
			dummyViewport = VkViewport(0.0, 0.0f, capabilities.currentExtent.width, capabilities.currentExtent.height, 0.0f, 1.0f);
			//dummyViewport = VkViewport(0.0, 0.0f, cast(float)capabilities.currentExtent.height * (cast(float)capabilities.currentExtent.height / cast(float) capabilities.currentExtent.width), capabilities.currentExtent.height, 0.1f, 1.0f);
			//dummyViewport = VkViewport(0.0, 0.0f, capabilities.currentExtent.height, capabilities.currentExtent.height, 0.1f, 1.0f);
			auto dummyScissor = VkRect2D(VkOffset2D(0, 0), capabilities.currentExtent);
			auto viewportStateCreateInfo = viewportState(array(dummyViewport), array(dummyScissor));
			auto rasterizationStateCreateInfo = rasterizationState(
				false,
				false,
				VkPolygonMode.VK_POLYGON_MODE_FILL,
				//VkCullModeFlagBits.VK_CULL_MODE_NONE,
				VkCullModeFlagBits.VK_CULL_MODE_FRONT_BIT,
				VkFrontFace.VK_FRONT_FACE_COUNTER_CLOCKWISE,
				false,
				0, 0, 0, 1
			);
			auto multiSample = multisampleState(VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT, false, 0, [], false, false);
			VkPipelineSampleLocationsStateCreateInfoEXT locInfo;
			locInfo.sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_SAMPLE_LOCATIONS_STATE_CREATE_INFO_EXT;
			locInfo.sampleLocationsEnable = true;
			locInfo.sampleLocationsInfo.sType = VkStructureType.VK_STRUCTURE_TYPE_SAMPLE_LOCATIONS_INFO_EXT;
			multiSample.pNext = &locInfo;

			VkPipelineColorBlendAttachmentState blendAttachment;
			blendAttachment.blendEnable = VK_TRUE;
			blendAttachment.colorWriteMask = 0xf;
			blendAttachment.srcColorBlendFactor = VkBlendFactor.VK_BLEND_FACTOR_SRC_ALPHA;
			blendAttachment.dstColorBlendFactor = VkBlendFactor.VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA;
			blendAttachment.colorBlendOp = VkBlendOp.VK_BLEND_OP_ADD;

			VkPipelineColorBlendAttachmentState blendAttachmentData;
			blendAttachmentData.blendEnable = VK_TRUE;
			blendAttachmentData.colorWriteMask = 0xf;
			blendAttachmentData.srcColorBlendFactor = VkBlendFactor.VK_BLEND_FACTOR_ONE;
			blendAttachmentData.dstColorBlendFactor = VkBlendFactor.VK_BLEND_FACTOR_ZERO;
			blendAttachmentData.srcAlphaBlendFactor = VkBlendFactor.VK_BLEND_FACTOR_ONE;
			blendAttachmentData.dstAlphaBlendFactor = VkBlendFactor.VK_BLEND_FACTOR_ZERO;
			blendAttachmentData.colorBlendOp = VkBlendOp.VK_BLEND_OP_ADD;
			blendAttachmentData.alphaBlendOp = VkBlendOp.VK_BLEND_OP_ADD;
			/*
			blendAttachmentData.srcColorBlendFactor = VkBlendFactor.VK_BLEND_FACTOR_SRC_ALPHA;
			blendAttachmentData.dstColorBlendFactor = VkBlendFactor.VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA;
			blendAttachmentData.colorBlendOp = VkBlendOp.VK_BLEND_FACTOR_ONE;*/
			//blendAttachment.srcAlphaBlendFactor = VkBlendFactor.VK_BLEND_FACTOR_SRC_ALPHA;
			//blendAttachment.dstAlphaBlendFactor = VkBlendFactor.VK_BLEND_FACTOR_DST_ALPHA;
			//blendAttachment.alphaBlendOp = VkBlendOp.VK_BLEND_OP_ADD;
			auto blend = colorBlendState(false, VkLogicOp.VK_LOGIC_OP_COPY, array(blendAttachmentData, blendAttachmentData, blendAttachmentData, blendAttachmentData, blendAttachmentData, blendAttachmentData), [0.0, 0.0, 0.0, 0.0]);

			auto depthStencil = depthStencilState(
				true,
				true,
				VkCompareOp.VK_COMPARE_OP_GREATER_OR_EQUAL,
				false,
				false,
				VkStencilOpState(),
				VkStencilOpState(),
				0.0,
				1.0
			);

			auto dynamic = dynamicState(array(VkDynamicState.VK_DYNAMIC_STATE_SAMPLE_LOCATIONS_EXT));

			rasterizer.pipeline = rasterizer.renderPass.createGraphicsPipeline(
				vertStage,
				fragStage,
				vertexInputStateCreateInfo,
				inputAssemblyStateCreateInfo,
				viewportStateCreateInfo,
				rasterizationStateCreateInfo,
				multiSample,
				blend,
				depthStencil,
				dynamic,
				rasterizer.pipelineLayout
			);
		}

		uint extendedWidth = capabilities.currentExtent.width + capabilities.currentExtent.width / 3;
		if (capabilities.currentExtent.width % 3 != 0) {
			extendedWidth++;
		}
		blurredImage = AllocatedResource!Image(device.createImage(0, VkImageType.VK_IMAGE_TYPE_2D, VkFormat.VK_FORMAT_B8G8R8A8_UNORM, VkExtent3D(extendedWidth, capabilities.currentExtent.height, 1), 1, 1, VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT, VkImageTiling.VK_IMAGE_TILING_OPTIMAL, VkImageUsageFlagBits.VK_IMAGE_USAGE_SAMPLED_BIT | VkImageUsageFlagBits.VK_IMAGE_USAGE_STORAGE_BIT, VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED));
		memoryAllocator.allocate(blurredImage, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
		blurredImageView = ImageView(
			device,
			blurredImage,
			VkImageViewType.VK_IMAGE_VIEW_TYPE_2D,
			VkFormat.VK_FORMAT_B8G8R8A8_UNORM,
			VkComponentMapping(
				VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
				VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
				VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
				VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY
			),
			VkImageSubresourceRange(
				VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT,
				0,
				1,
				0,
				1
			)
		);
		normalImage = AllocatedResource!Image(device.createImage(0, VkImageType.VK_IMAGE_TYPE_2D, VkFormat.VK_FORMAT_B8G8R8A8_UNORM, VkExtent3D(extendedWidth, capabilities.currentExtent.height, 1), 1, 1, VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT, VkImageTiling.VK_IMAGE_TILING_OPTIMAL, VkImageUsageFlagBits.VK_IMAGE_USAGE_SAMPLED_BIT | VkImageUsageFlagBits.VK_IMAGE_USAGE_STORAGE_BIT, VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED));
		memoryAllocator.allocate(normalImage, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
		normalImageView = ImageView(
			device,
			normalImage,
			VkImageViewType.VK_IMAGE_VIEW_TYPE_2D,
			VkFormat.VK_FORMAT_B8G8R8A8_UNORM,
			VkComponentMapping(
				VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
				VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
				VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
				VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY
			),
			VkImageSubresourceRange(
				VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT,
				0,
				1,
				0,
				1
			)
		);
		depthImage = AllocatedResource!Image(device.createImage(0, VkImageType.VK_IMAGE_TYPE_2D, VkFormat.VK_FORMAT_B8G8R8A8_UNORM, VkExtent3D(extendedWidth, capabilities.currentExtent.height, 1), 1, 1, VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT, VkImageTiling.VK_IMAGE_TILING_OPTIMAL, VkImageUsageFlagBits.VK_IMAGE_USAGE_SAMPLED_BIT | VkImageUsageFlagBits.VK_IMAGE_USAGE_STORAGE_BIT, VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED));
		memoryAllocator.allocate(depthImage, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
		depthImageView = ImageView(
			device,
			depthImage,
			VkImageViewType.VK_IMAGE_VIEW_TYPE_2D,
			VkFormat.VK_FORMAT_B8G8R8A8_UNORM,
			VkComponentMapping(
				VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
				VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
				VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
				VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY
			),
			VkImageSubresourceRange(
				VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT,
				0,
				1,
				0,
				1
			)
		);
		for (int i = 0; i < 2; i++) {
			for (int j = 0; j < 2; j++) {
				doubleColorImage[i][j] = AllocatedResource!Image(device.createImage(0, VkImageType.VK_IMAGE_TYPE_2D, VkFormat.VK_FORMAT_B8G8R8A8_UNORM, VkExtent3D(capabilities.currentExtent.width, capabilities.currentExtent.height, 1), 1, 1, VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT, VkImageTiling.VK_IMAGE_TILING_OPTIMAL, VkImageUsageFlagBits.VK_IMAGE_USAGE_SAMPLED_BIT | VkImageUsageFlagBits.VK_IMAGE_USAGE_STORAGE_BIT | VkImageUsageFlagBits.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VkImageUsageFlagBits.VK_IMAGE_USAGE_TRANSFER_DST_BIT, VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED));
				memoryAllocator.allocate(doubleColorImage[i][j], VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
				doubleColorImageView[i][j] = ImageView(
					device,
					doubleColorImage[i][j],
					VkImageViewType.VK_IMAGE_VIEW_TYPE_2D,
					VkFormat.VK_FORMAT_B8G8R8A8_UNORM,
					VkComponentMapping(
						VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
						VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
						VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
						VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY
					),
					VkImageSubresourceRange(
						VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT,
						0,
						1,
						0,
						1
					)
				);
			}
		}
		for (int i = 0; i < 2; i++) {
			oldDepthImage[i] = AllocatedResource!Image(device.createImage(0, VkImageType.VK_IMAGE_TYPE_2D, VkFormat.VK_FORMAT_B8G8R8A8_UNORM, VkExtent3D(capabilities.currentExtent.width, capabilities.currentExtent.height, 1), 1, 1, VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT, VkImageTiling.VK_IMAGE_TILING_OPTIMAL, VkImageUsageFlagBits.VK_IMAGE_USAGE_SAMPLED_BIT | VkImageUsageFlagBits.VK_IMAGE_USAGE_STORAGE_BIT | VkImageUsageFlagBits.VK_IMAGE_USAGE_TRANSFER_DST_BIT | VkImageUsageFlagBits.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT, VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED));
			memoryAllocator.allocate(oldDepthImage[i], VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
			oldDepthImageView[i] = ImageView(
				device,
				oldDepthImage[i],
				VkImageViewType.VK_IMAGE_VIEW_TYPE_2D,
				VkFormat.VK_FORMAT_B8G8R8A8_UNORM,
				VkComponentMapping(
					VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
					VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
					VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
					VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY
				),
				VkImageSubresourceRange(
					VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT,
					0,
					1,
					0,
					1
				)
			);
		}
		depthGuessImage = AllocatedResource!Image(device.createImage(0, VkImageType.VK_IMAGE_TYPE_2D, VkFormat.VK_FORMAT_B8G8R8A8_UNORM, VkExtent3D(capabilities.currentExtent.width, capabilities.currentExtent.height, 1), 1, 1, VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT, VkImageTiling.VK_IMAGE_TILING_OPTIMAL, VkImageUsageFlagBits.VK_IMAGE_USAGE_SAMPLED_BIT | VkImageUsageFlagBits.VK_IMAGE_USAGE_STORAGE_BIT | VkImageUsageFlagBits.VK_IMAGE_USAGE_TRANSFER_DST_BIT | VkImageUsageFlagBits.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT, VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED));
		memoryAllocator.allocate(depthGuessImage, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
		depthGuessImageView = ImageView(
			device,
			depthGuessImage,
			VkImageViewType.VK_IMAGE_VIEW_TYPE_2D,
			VkFormat.VK_FORMAT_B8G8R8A8_UNORM,
			VkComponentMapping(
				VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
				VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
				VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
				VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY
			),
			VkImageSubresourceRange(
				VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT,
				0,
				1,
				0,
				1
			)
		);
		for (int i = 0; i < 2; i++) {
			normalsImage[i] = AllocatedResource!Image(device.createImage(0, VkImageType.VK_IMAGE_TYPE_2D, VkFormat.VK_FORMAT_B8G8R8A8_UNORM, VkExtent3D(capabilities.currentExtent.width, capabilities.currentExtent.height, 1), 1, 1, VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT, VkImageTiling.VK_IMAGE_TILING_OPTIMAL, VkImageUsageFlagBits.VK_IMAGE_USAGE_SAMPLED_BIT | VkImageUsageFlagBits.VK_IMAGE_USAGE_STORAGE_BIT | VkImageUsageFlagBits.VK_IMAGE_USAGE_TRANSFER_DST_BIT | VkImageUsageFlagBits.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT, VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED));
			memoryAllocator.allocate(normalsImage[i], VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
			normalsImageView[i] = ImageView(
				device,
				normalsImage[i],
				VkImageViewType.VK_IMAGE_VIEW_TYPE_2D,
				VkFormat.VK_FORMAT_B8G8R8A8_UNORM,
				VkComponentMapping(
					VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
					VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
					VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
					VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY
				),
				VkImageSubresourceRange(
					VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT,
					0,
					1,
					0,
					1
				)
			);
		}
		dPosImage[0] = AllocatedResource!Image(device.createImage(0, VkImageType.VK_IMAGE_TYPE_2D, VkFormat.VK_FORMAT_B8G8R8A8_UNORM, VkExtent3D(capabilities.currentExtent.width, capabilities.currentExtent.height, 1), 1, 1, VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT, VkImageTiling.VK_IMAGE_TILING_OPTIMAL, VkImageUsageFlagBits.VK_IMAGE_USAGE_SAMPLED_BIT | VkImageUsageFlagBits.VK_IMAGE_USAGE_STORAGE_BIT | VkImageUsageFlagBits.VK_IMAGE_USAGE_TRANSFER_DST_BIT | VkImageUsageFlagBits.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT, VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED));
		memoryAllocator.allocate(dPosImage[0], VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
		dPosImageView[0] = ImageView(
			device,
			dPosImage[0],
			VkImageViewType.VK_IMAGE_VIEW_TYPE_2D,
			VkFormat.VK_FORMAT_B8G8R8A8_UNORM,
			VkComponentMapping(
				VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
				VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
				VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
				VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY
			),
			VkImageSubresourceRange(
				VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT,
				0,
				1,
				0,
				1
			)
		);
		dPosImage[1] = AllocatedResource!Image(device.createImage(0, VkImageType.VK_IMAGE_TYPE_2D, VkFormat.VK_FORMAT_B8G8R8A8_UNORM, VkExtent3D(capabilities.currentExtent.width, capabilities.currentExtent.height, 1), 1, 1, VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT, VkImageTiling.VK_IMAGE_TILING_OPTIMAL, VkImageUsageFlagBits.VK_IMAGE_USAGE_SAMPLED_BIT | VkImageUsageFlagBits.VK_IMAGE_USAGE_STORAGE_BIT | VkImageUsageFlagBits.VK_IMAGE_USAGE_TRANSFER_DST_BIT | VkImageUsageFlagBits.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT, VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED));
		memoryAllocator.allocate(dPosImage[1], VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
		dPosImageView[1] = ImageView(
			device,
			dPosImage[1],
			VkImageViewType.VK_IMAGE_VIEW_TYPE_2D,
			VkFormat.VK_FORMAT_B8G8R8A8_UNORM,
			VkComponentMapping(
				VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
				VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
				VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
				VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY
			),
			VkImageSubresourceRange(
				VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT,
				0,
				1,
				0,
				1
			)
		);
		renderImage = AllocatedResource!Image(device.createImage(0, VkImageType.VK_IMAGE_TYPE_2D, VkFormat.VK_FORMAT_B8G8R8A8_UNORM, VkExtent3D(capabilities.currentExtent.width, capabilities.currentExtent.height, 1), 1, 1, VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT, VkImageTiling.VK_IMAGE_TILING_OPTIMAL, VkImageUsageFlagBits.VK_IMAGE_USAGE_SAMPLED_BIT | VkImageUsageFlagBits.VK_IMAGE_USAGE_STORAGE_BIT | VkImageUsageFlagBits.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VkImageUsageFlagBits.VK_IMAGE_USAGE_TRANSFER_DST_BIT, VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED));
		memoryAllocator.allocate(renderImage, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
		renderImageView = ImageView(
			device,
			renderImage,
			VkImageViewType.VK_IMAGE_VIEW_TYPE_2D,
			VkFormat.VK_FORMAT_B8G8R8A8_UNORM,
			VkComponentMapping(
				VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
				VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
				VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
				VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY
			),
			VkImageSubresourceRange(
				VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT,
				0,
				1,
				0,
				1
			)
		);
		firstFramebuffer[0] = rasterizer.renderPass.createFramebuffer(array(renderImageView, rasterDepthImageView, dPosImageView[0], dPosImageView[1], oldDepthImageView[0], depthGuessImageView, normalsImageView[0]), capabilities.currentExtent.width, capabilities.currentExtent.height, 1);
		firstFramebuffer[1] = rasterizer.renderPass.createFramebuffer(array(renderImageView, rasterDepthImageView, dPosImageView[0], dPosImageView[1], oldDepthImageView[1], depthGuessImageView, normalsImageView[1]), capabilities.currentExtent.width, capabilities.currentExtent.height, 1);
		cmdBuffer.begin();
		if (rt) {
		cmdBuffer.pipelineBarrier(
			VkPipelineStageFlagBits.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
			VkPipelineStageFlagBits.VK_PIPELINE_STAGE_RAY_TRACING_SHADER_BIT_KHR,
			0, [],
			[],
			array(
				imageMemoryBarrier(
					0,
					0,
					VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
					VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
					blurredImage,
					VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
				),
				imageMemoryBarrier(
					0,
					0,
					VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
					VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
					normalImage,
					VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
				),
				imageMemoryBarrier(
					0,
					0,
					VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
					VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
					depthImage,
					VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
				),
			)
		);
		}
		cmdBuffer.pipelineBarrier(
			VkPipelineStageFlagBits.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
			VkPipelineStageFlagBits.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
			0, [],
			[],
			array(
				imageMemoryBarrier(
					0,
					0,
					VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
					VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
					dPosImage[0],
					VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
				),
				imageMemoryBarrier(
					0,
					0,
					VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
					VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
					dPosImage[1],
					VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
				),
				imageMemoryBarrier(
					0,
					0,
					VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
					VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
					doubleColorImage[0][0],
					VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
				),
				imageMemoryBarrier(
					0,
					0,
					VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
					VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
					doubleColorImage[0][1],
					VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
				),
				imageMemoryBarrier(
					0,
					0,
					VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
					VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
					doubleColorImage[1][0],
					VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
				),
				imageMemoryBarrier(
					0,
					0,
					VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
					VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
					doubleColorImage[1][1],
					VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
				),
				imageMemoryBarrier(
					0,
					0,
					VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
					VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
					oldDepthImage[0],
					VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
				),
				imageMemoryBarrier(
					0,
					0,
					VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
					VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
					oldDepthImage[1],
					VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
				),
				imageMemoryBarrier(
					0,
					0,
					VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
					VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
					depthGuessImage,
					VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
				),
				imageMemoryBarrier(
					0,
					0,
					VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
					VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
					renderImage,
					VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
				),
				imageMemoryBarrier(
					0,
					0,
					VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
					VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
					normalsImage[0],
					VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
				),
				imageMemoryBarrier(
					0,
					0,
					VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
					VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
					normalsImage[1],
					VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
				),
			)
		);
		cmdBuffer.end();
		queue.submit(cmdBuffer, fence);
		fence.wait();
		fence.reset();
	}
	void update() {
		auto dt = timer.update();
		passedTime += dt;

		rtTime++;
		//rtTime %= 9;
		oldPos[0] = pos[0];
		oldPos[1] = pos[1];
		oldPos[2] = pos[2];
		oldRot[0] = rot[0];
		oldRot[1] = rot[1];
		import std.math.trigonometry;
		if ((*ecs.createView!(GlfwVulkanWindow)[0])[0].getKey(cast(int)'W')) {
			pos[2] += 2.0 * dt * cos(rot[1]);
			pos[0] += -2.0 * dt * sin(rot[1]);
		}
		if ((*ecs.createView!(GlfwVulkanWindow)[0])[0].getKey(cast(int)'S')) {
			pos[2] += -2.0 * dt * cos(rot[1]);
			pos[0] += 2.0 * dt * sin(rot[1]);
		}
		if ((*ecs.createView!(GlfwVulkanWindow)[0])[0].getKey(cast(int)'A')) {
			pos[2] += -2.0 * dt * sin(rot[1]);
			pos[0] += -2.0 * dt * cos(rot[1]);
		}
		if ((*ecs.createView!(GlfwVulkanWindow)[0])[0].getKey(cast(int)'D')) {
			pos[2] += 2.0 * dt * sin(rot[1]);
			pos[0] += 2.0 * dt * cos(rot[1]);
		}
		if ((*ecs.createView!(GlfwVulkanWindow)[0])[0].getKey(cast(int)' ')) {
			pos[1] += 2.0 * dt;
		}
		if ((*ecs.createView!(GlfwVulkanWindow)[0])[0].getKey(341)) {
			pos[1] += -2.0 * dt;
		}
		
		if ((*ecs.createView!(GlfwVulkanWindow)[0])[0].getKey(262)) {
			rot[1] += -2.0 * dt;
		}
		if ((*ecs.createView!(GlfwVulkanWindow)[0])[0].getKey(263)) {
			rot[1] += 2.0 * dt;
		}
		if ((*ecs.createView!(GlfwVulkanWindow)[0])[0].getKey(264)) {
			rot[0] += 2.0 * dt;
		}
		if ((*ecs.createView!(GlfwVulkanWindow)[0])[0].getKey(265)) {
			rot[0] += -2.0 * dt;
		}
		
		//pos[0] = 10 * sin(passedTime);
		if (objects.getComponentEntityIds!Drawable().length >= 2) {
			auto entity = objects.getEntity(objects.getComponentEntityIds!Drawable()[1]);
			//entity.get!Drawable().pos = Tensor!(float, 3)(sin(passedTime), 1, cos(passedTime));
			// nachher noch umstellen dass shader dt bekommt
			entity.get!Drawable().dpos[0] = (sin(passedTime) - entity.get!Drawable().pos[0])/* / dt*/;
			entity.get!Drawable().pos[0] = sin(passedTime);
		}

		uint imageIndex = swapchain.aquireNextImage(/*semaphore*/null, fence);
		if (swapchain.result.result != VkResult.VK_SUCCESS) {
			fence.wait();
			fence.reset();
			rebuildSwapchain();
			return;
		}
		fence.wait();
		fence.reset();
		cmdBuffer.begin();
		foreach (id; dynEcs.getGeneralUpdateList!Text()) {
			Text text = dynEcs.getForced!Text(id);
            dynEcs.removeComponent!Text(id);
			if (dynEcs.getEntity(id).has!(GpuLocal!Buffer))
				dynEcs.removeComponent!(GpuLocal!Buffer)(id);
			if (dynEcs.getEntity(id).has!(CpuLocal!Buffer))
				dynEcs.removeComponent!(CpuLocal!Buffer)(id);
            dynEcs.addComponent!Text(id, text);
		}
		foreach (i; dynEcs.getAddUpdateList!Text()) {
			auto textRef = dynEcs.getComponent!Text(i);//dynEcs.entities[i].get!Text;
			auto vertPos = font.createText(cast(string)textRef.text, textRef.x, textRef.y, textRef.scale);
            dynEcs.addComponent!(GpuLocal!Buffer)(i);
            dynEcs.addComponent!(CpuLocal!Buffer)(i);
			auto gpuBuffer = &dynEcs.getComponent!(GpuLocal!Buffer)(i);
			auto cpuBuffer = &dynEcs.getComponent!(CpuLocal!Buffer)(i);
			//textRef.text.opDispatch!"length";
			size_t dataSize = 24 * float.sizeof * textRef.text.length;
			gpuBuffer.resource = (AllocatedResource!Buffer(device.createBuffer(0, dataSize, VkBufferUsageFlagBits.VK_BUFFER_USAGE_TRANSFER_DST_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT)));
			cpuBuffer.resource = (AllocatedResource!Buffer(device.createBuffer(0, dataSize, VkBufferUsageFlagBits.VK_BUFFER_USAGE_TRANSFER_SRC_BIT)));
			memoryAllocator.allocate(cast(AllocatedResource!Buffer)gpuBuffer.resource, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
			memoryAllocator.allocate(cast(AllocatedResource!Buffer)cpuBuffer.resource, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT);
			Memory* memoryGpu = &cast(Memory) gpuBuffer.resource.allocatedMemory.allocatorList.memory;
			Memory* memoryCpu = &cast(Memory) cpuBuffer.resource.allocatedMemory.allocatorList.memory;
			float* floatptr = cast(float*) memoryCpu.map(cpuBuffer.resource.allocatedMemory.allocation.offset, dataSize);
			foreach (j, float f; vertPos) {
				floatptr[j] = f;
			}
			memoryCpu.flush(array(mappedMemoryRange(*memoryCpu, cpuBuffer.resource.allocatedMemory.allocation.offset, cpuBuffer.resource.allocatedMemory.allocation.length)));
			memoryCpu.unmap();
			cmdBuffer.copyBuffer(cast(Buffer)cpuBuffer.resource, 0, cast(Buffer)gpuBuffer.resource, 0, dataSize);
		}
		//circleShaderList.update2(dynEcs, cmdBuffer);
		cmdBuffer.end();
		queue.submit(cmdBuffer, fence);
		fence.wait();
		cmdBuffer.reset();
		fence.reset();
		dynEcs.clearAddUpdateList!Text();
		dynEcs.clearGeneralUpdateList!Text();

		if (objects.getAddUpdateList!Drawable().length > 0 || objects.getRemoveUpdateList!Drawable().length > 0 || objects.getGeneralUpdateList!Drawable().length > 0) {
			cmdBuffer.begin();
			drawables.update2(objects, cmdBuffer, false);
			cmdBuffer.end();
			queue.submit(cmdBuffer, fence);
			fence.wait();
			fence.reset();
		}
		if (rt) {
			foreach (i; objects.getAddUpdateList!Drawable()) {
				auto entity = objects.getEntity(i);
				Drawable drawable = entity.get!Drawable();
				VkTransformMatrixKHR transformMatrix;
				transformMatrix.matrix = array(
					array(drawable.scale[0], 0.0f, 0.0f, drawable.pos[0]),
					array(0.0f, drawable.scale[1], 0.0f, drawable.pos[1]),
					array(0.0f, 0.0f, drawable.scale[2], drawable.pos[2]),
				);
				VkAccelerationStructureInstanceKHR instance;
				instance.transform = transformMatrix;
				instance.instanceCustomIndex = entity.get!(ShaderListIndex!Drawable)().index;
				instance.mask = 0xff;
				if (models.getEntity(drawable.modelId).has!RTProceduralModel()) {
					instance.instanceShaderBindingTableRecordOffset = 1;
					instance.accelerationStructureReference = models.getEntity(drawable.modelId).get!RTProceduralModel().blasBuffer.getDeviceAddress();
				} else {
					instance.instanceShaderBindingTableRecordOffset = 0;
					instance.accelerationStructureReference = models.getEntity(drawable.modelId).get!RTPolygonModel().blasBuffer.getDeviceAddress();
				}
				instance.flags = VkGeometryInstanceFlagBitsKHR.VK_GEOMETRY_INSTANCE_TRIANGLE_FACING_CULL_DISABLE_BIT_KHR;
				objects.addComponent!VkAccelerationStructureInstanceKHR(i, instance);
			}
			foreach (i; objects.getGeneralUpdateList!Drawable()) {
				auto entity = objects.getEntity(i);
				Drawable drawable = entity.get!Drawable();
				objects.getComponent!VkAccelerationStructureInstanceKHR(i).transform.matrix = array(
					array(drawable.scale[0], 0.0f, 0.0f, drawable.pos[0]),
					array(0.0f, drawable.scale[1], 0.0f, drawable.pos[1]),
					array(0.0f, 0.0f, drawable.scale[2], drawable.pos[2]),
				);
			}
		}
		objects.clearAddUpdateList!Drawable();
		objects.clearGeneralUpdateList!Drawable();
		objects.clearRemoveUpdateList!Drawable();
		if (rt) {
			foreach (i; objects.getGeneralUpdateList!(ShaderListIndex!Drawable)()) {
				auto entity = objects.getEntity(i);
				entity.get!VkAccelerationStructureInstanceKHR().instanceCustomIndex = entity.get!(ShaderListIndex!Drawable)().index;
				int bla = entity.get!VkAccelerationStructureInstanceKHR().opDispatch!"instanceCustomIndex";
			}
			if (objects.getGeneralUpdateList!VkAccelerationStructureInstanceKHR().length > 0 || objects.getAddUpdateList!VkAccelerationStructureInstanceKHR().length > 0 || objects.getRemoveUpdateList!VkAccelerationStructureInstanceKHR().length > 0) {
				cmdBuffer.begin();
				asInstances.update2(objects, cmdBuffer, false);
				cmdBuffer.end();
				queue.submit(cmdBuffer, fence);
				fence.wait();
				fence.reset();
				if (objects.getAddUpdateList!VkAccelerationStructureInstanceKHR().length > 0 || objects.getRemoveUpdateList!VkAccelerationStructureInstanceKHR().length > 0) {
					tlas.recreate(asInstances.gpuBuffer.getDeviceAddress(), asInstances.length);
				}
			}
		}
		
		cmdBuffer.begin();
		if (rt) {
			if (objects.getAddUpdateList!VkAccelerationStructureInstanceKHR().length > 0) {
				tlas.build(asInstances.gpuBuffer.getDeviceAddress(), asInstances.length, cmdBuffer);
			} else if (objects.getGeneralUpdateList!VkAccelerationStructureInstanceKHR().length > 0) {
				tlas.update(asInstances.gpuBuffer.getDeviceAddress(), asInstances.length, cmdBuffer);
			}
			objects.clearAddUpdateList!VkAccelerationStructureInstanceKHR();
			objects.clearGeneralUpdateList!VkAccelerationStructureInstanceKHR();
			objects.clearRemoveUpdateList!VkAccelerationStructureInstanceKHR();

			cmdBuffer.pipelineBarrier(
				VkPipelineStageFlagBits.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
				VkPipelineStageFlagBits.VK_PIPELINE_STAGE_RAY_TRACING_SHADER_BIT_KHR,
				0, [],
				[],
				array(
					imageMemoryBarrier(
						0,
						VkAccessFlagBits.VK_ACCESS_SHADER_WRITE_BIT,
						VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						swapchain.images[imageIndex],
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
				)
			);
			{
				cmdBuffer.pipelineBarrier(
					VkPipelineStageFlagBits.VK_PIPELINE_STAGE_ACCELERATION_STRUCTURE_BUILD_BIT_KHR,
					VkPipelineStageFlagBits.VK_PIPELINE_STAGE_RAY_TRACING_SHADER_BIT_KHR,
					0, [],
					array(
						bufferMemoryBarrier(
							VkAccessFlagBits.VK_ACCESS_ACCELERATION_STRUCTURE_WRITE_BIT_KHR,
							VkAccessFlagBits.VK_ACCESS_ACCELERATION_STRUCTURE_READ_BIT_KHR,
							tlas.tlasBuffer
						),
					),
					[]
				);
				VkWriteDescriptorSetAccelerationStructureKHR descriptorAccelStructInfo = writeAccelerationStructure(tlas.tlas);
				rtPipeline.descriptorSet.write(array!VkWriteDescriptorSet(
					WriteDescriptorSet(0, VkDescriptorType.VK_DESCRIPTOR_TYPE_ACCELERATION_STRUCTURE_KHR, 1, descriptorAccelStructInfo),
					WriteDescriptorSet(1, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, blurredImageView, VkImageLayout.VK_IMAGE_LAYOUT_GENERAL),
					WriteDescriptorSet(2, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, rtModelInfos.gpuBuffer),
					WriteDescriptorSet(3, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, normalImageView, VkImageLayout.VK_IMAGE_LAYOUT_GENERAL),
					WriteDescriptorSet(4, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, depthImageView, VkImageLayout.VK_IMAGE_LAYOUT_GENERAL),
					WriteDescriptorSet(5, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, drawables.gpuBuffer.t.buffer),
				));
				cmdBuffer.bindPipeline(rtPipeline.rtPipeline, VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_RAY_TRACING_KHR);
				cmdBuffer.bindDescriptorSets(VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_RAY_TRACING_KHR, rtPipeline.pipelineLayout, 0, array(rtPipeline.descriptorSet), []);
				float[6] rtPushConstants;
				rtPushConstants[0] = pos[0];
				rtPushConstants[1] = pos[1];
				rtPushConstants[2] = pos[2];
				rtPushConstants[3] = rot[1];
				rtPushConstants[4] = rot[0];
				rtPushConstants[5] = cast(float) rtTime;
				cmdBuffer.pushConstants(rtPipeline.pipelineLayout, VkShaderStageFlagBits.VK_SHADER_STAGE_RAYGEN_BIT_KHR, 0, float.sizeof * 6, rtPushConstants.ptr);

				VkStridedDeviceAddressRegionKHR rayGenRegion;
				rayGenRegion.deviceAddress = rtPipeline.sbRayGen.getDeviceAddress() + rtPipeline.offsetRayGen;
				rayGenRegion.size = rtPipeline.groupHandleSize;
				rayGenRegion.stride = rtPipeline.groupHandleSize;

				VkStridedDeviceAddressRegionKHR missRegion;
				missRegion.deviceAddress = rtPipeline.sbMiss.getDeviceAddress() + rtPipeline.offsetMiss;
				missRegion.size = rtPipeline.groupHandleSize;
				missRegion.stride = rtPipeline.groupHandleSize;

				VkStridedDeviceAddressRegionKHR hitRegion;
				hitRegion.deviceAddress = rtPipeline.sbHit.getDeviceAddress() + rtPipeline.offsetHit;
				hitRegion.size = rtPipeline.groupHandleSize * 2;
				hitRegion.stride = rtPipeline.groupSizeAligned;

				VkStridedDeviceAddressRegionKHR callableRegion;

				cmdBuffer.traceRays(&rayGenRegion, &missRegion, &hitRegion, &callableRegion, capabilities.currentExtent.width, capabilities.currentExtent.height, 1);
			}

			cmdBuffer.pipelineBarrier(
				VkPipelineStageFlagBits.VK_PIPELINE_STAGE_RAY_TRACING_SHADER_BIT_KHR,
				VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
				0, [], [],
				array(
					imageMemoryBarrier(
						VkAccessFlagBits.VK_ACCESS_SHADER_WRITE_BIT,
						VkAccessFlagBits.VK_ACCESS_SHADER_READ_BIT | VkAccessFlagBits.VK_ACCESS_SHADER_WRITE_BIT,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						blurredImage,
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
					imageMemoryBarrier(
						VkAccessFlagBits.VK_ACCESS_SHADER_WRITE_BIT,
						VkAccessFlagBits.VK_ACCESS_SHADER_READ_BIT | VkAccessFlagBits.VK_ACCESS_SHADER_WRITE_BIT,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						normalImage,
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
					imageMemoryBarrier(
						VkAccessFlagBits.VK_ACCESS_SHADER_WRITE_BIT,
						VkAccessFlagBits.VK_ACCESS_SHADER_READ_BIT | VkAccessFlagBits.VK_ACCESS_SHADER_WRITE_BIT,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						depthImage,
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
				)
			);

			blurPipeline.descriptorSet.write(array!VkWriteDescriptorSet(
				WriteDescriptorSet(0, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, blurredImageView, VkImageLayout.VK_IMAGE_LAYOUT_GENERAL),
				WriteDescriptorSet(1, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, normalImageView, VkImageLayout.VK_IMAGE_LAYOUT_GENERAL),
				WriteDescriptorSet(2, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, depthImageView, VkImageLayout.VK_IMAGE_LAYOUT_GENERAL),
			));
			cmdBuffer.bindPipeline(blurPipeline.computePipeline, VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_COMPUTE);
			uint[8] pushConstants;
			pushConstants[0] = 0;
			pushConstants[1] = 0;
			pushConstants[2] = capabilities.currentExtent.width;
			pushConstants[3] = 0;
			pushConstants[4] = capabilities.currentExtent.width / 3;
			pushConstants[5] = capabilities.currentExtent.height / 3;
			pushConstants[6] = rtTime % 3;
			pushConstants[7] = 0;
			cmdBuffer.bindDescriptorSets(VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_COMPUTE, blurPipeline.pipelineLayout, 0, array(blurPipeline.descriptorSet), []);
			cmdBuffer.pushConstants(blurPipeline.pipelineLayout, VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT, 0, uint.sizeof * 8, pushConstants.ptr);
			uint compressedX = capabilities.currentExtent.width / 3;// + ((capabilities.currentExtent.width % 3 == 0) ? 0 : 1);
			uint compressedY = capabilities.currentExtent.height / 3;// + ((capabilities.currentExtent.height % 3 == 0) ? 0 : 1);
			//uint compressedX = capabilities.currentExtent.width / 3 + ((capabilities.currentExtent.width % 3 == 0) ? 0 : 1);
			//uint compressedY = capabilities.currentExtent.height / 3 + ((capabilities.currentExtent.height % 3 == 0) ? 0 : 1);
			int borderX = compressedX % localWorkGroupSize[0] > 0 ? 1 : 0;
			int borderY = compressedY % localWorkGroupSize[1] > 0 ? 1 : 0;
			cmdBuffer.dispatch(compressedX / localWorkGroupSize[0] + borderX, compressedY / localWorkGroupSize[1] + borderY, 1);
			cmdBuffer.pipelineBarrier(
				VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
				VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
				0, [], [],
				array(
					imageMemoryBarrier(
						VkAccessFlagBits.VK_ACCESS_SHADER_READ_BIT | VkAccessFlagBits.VK_ACCESS_SHADER_WRITE_BIT,
						VkAccessFlagBits.VK_ACCESS_SHADER_READ_BIT | VkAccessFlagBits.VK_ACCESS_SHADER_WRITE_BIT,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						blurredImage,
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
					imageMemoryBarrier(
						VkAccessFlagBits.VK_ACCESS_SHADER_READ_BIT | VkAccessFlagBits.VK_ACCESS_SHADER_WRITE_BIT,
						VkAccessFlagBits.VK_ACCESS_SHADER_READ_BIT | VkAccessFlagBits.VK_ACCESS_SHADER_WRITE_BIT,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						normalImage,
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
					imageMemoryBarrier(
						VkAccessFlagBits.VK_ACCESS_SHADER_READ_BIT | VkAccessFlagBits.VK_ACCESS_SHADER_WRITE_BIT,
						VkAccessFlagBits.VK_ACCESS_SHADER_READ_BIT | VkAccessFlagBits.VK_ACCESS_SHADER_WRITE_BIT,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						depthImage,
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
				)
			);
			uint[8] pushConstants2;
			pushConstants2[0] = capabilities.currentExtent.width;
			pushConstants2[1] = 0;
			pushConstants2[2] = capabilities.currentExtent.width;
			pushConstants2[3] = capabilities.currentExtent.height / 3;// + ((capabilities.currentExtent.height % 3 == 0) ? 0 : 1);
			//pushConstants2[3] = capabilities.currentExtent.height / 3 + ((capabilities.currentExtent.height % 3 == 0) ? 0 : 1);
			pushConstants2[4] = capabilities.currentExtent.width / 9;
			pushConstants2[5] = capabilities.currentExtent.height / 9;
			pushConstants2[6] = rtTime / 3 % 3;
			pushConstants2[7] = rtTime % 3;
			compressedX = compressedX / 3;// + ((compressedX % 3 == 0) ? 0 : 1);
			compressedY = compressedY / 3;// + ((compressedY % 3 == 0) ? 0 : 1);
			//compressedX = compressedX / 3 + ((compressedX % 3 == 0) ? 0 : 1);
			//compressedY = compressedY / 3 + ((compressedY % 3 == 0) ? 0 : 1);
			borderX = compressedX % localWorkGroupSize[0] > 0 ? 1 : 0;
			borderY = compressedY % localWorkGroupSize[1] > 0 ? 1 : 0;
			cmdBuffer.pushConstants(blurPipeline.pipelineLayout, VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT, 0, uint.sizeof * 8, pushConstants2.ptr);
			cmdBuffer.dispatch(compressedX / localWorkGroupSize[0] + borderX, compressedY / localWorkGroupSize[1] + borderY, 1);

			cmdBuffer.pipelineBarrier(
				VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
				VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
				0, [], [],
				array(
					imageMemoryBarrier(
						VkAccessFlagBits.VK_ACCESS_SHADER_READ_BIT | VkAccessFlagBits.VK_ACCESS_SHADER_WRITE_BIT,
						VkAccessFlagBits.VK_ACCESS_SHADER_READ_BIT,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						blurredImage,
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
					imageMemoryBarrier(
						VkAccessFlagBits.VK_ACCESS_SHADER_READ_BIT | VkAccessFlagBits.VK_ACCESS_SHADER_WRITE_BIT,
						VkAccessFlagBits.VK_ACCESS_SHADER_READ_BIT,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						normalImage,
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
					imageMemoryBarrier(
						VkAccessFlagBits.VK_ACCESS_SHADER_READ_BIT | VkAccessFlagBits.VK_ACCESS_SHADER_WRITE_BIT,
						VkAccessFlagBits.VK_ACCESS_SHADER_READ_BIT,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						depthImage,
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
				)
			);
			descriptorSet.write(array!VkWriteDescriptorSet(
				WriteDescriptorSet(0, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, swapchainViews[imageIndex], VkImageLayout.VK_IMAGE_LAYOUT_GENERAL),
				WriteDescriptorSet(1, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, blurredImageView, VkImageLayout.VK_IMAGE_LAYOUT_GENERAL),
				WriteDescriptorSet(2, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, normalImageView, VkImageLayout.VK_IMAGE_LAYOUT_GENERAL),
				WriteDescriptorSet(3, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, depthImageView, VkImageLayout.VK_IMAGE_LAYOUT_GENERAL),
			));
			cmdBuffer.bindPipeline(computePipeline, VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_COMPUTE);
			cmdBuffer.bindDescriptorSets(VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_COMPUTE, pipelineLayout, 0, array(descriptorSet), []);
			borderX = capabilities.currentExtent.width % localWorkGroupSize[0] > 0 ? 1 : 0;
			borderY = capabilities.currentExtent.height % localWorkGroupSize[1] > 0 ? 1 : 0;
			uint[1] pushConstants3;
			pushConstants3[0] = rtTime % 9;
			cmdBuffer.pushConstants(pipelineLayout, VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT, 0, uint.sizeof * 1, pushConstants3.ptr);
			cmdBuffer.dispatch(capabilities.currentExtent.width / localWorkGroupSize[0] + borderX, capabilities.currentExtent.height / localWorkGroupSize[1] + borderY, 1);

			cmdBuffer.pipelineBarrier(
				VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
				VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
				0, [], [],
				array(imageMemoryBarrier(
					VkAccessFlagBits.VK_ACCESS_SHADER_WRITE_BIT,
					VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
					VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
					VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
					swapchain.images[imageIndex],
					VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
				))
			);
		}
		if (!rt) {
			cmdBuffer.pipelineBarrier(
				VkPipelineStageFlagBits.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
				VkPipelineStageFlagBits.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
				0, [], [],
				array(
					imageMemoryBarrier(
						0,
						0,
						VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						swapchain.images[imageIndex],
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
					imageMemoryBarrier(
						0,
						0,
						VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						dPosImage[0],
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
					imageMemoryBarrier(
						0,
						0,
						VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						dPosImage[1],
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
				)
			);
			/*cmdBuffer.clearColorImage(
				doubleColorImage[(rtTime + 0) % 2][0],
				VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
				VkClearColorValue([0.0, 1.0, 1.0, 1.0]),
				array(VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1))
			);*/
			/*cmdBuffer.pipelineBarrier(
				VkPipelineStageFlagBits.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
				VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
				0, [], [],
				array(imageMemoryBarrier(
					0,
					VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
					VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
					VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
					swapchain.images[imageIndex],
					VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
				))
			);*/
		}

		VkClearValue clear;
		clear.depthStencil = VkClearDepthStencilValue(0.0, 0);

		if (!rt) {
			if (lastImageIndex == imageIndex) {
				lastImageIndex = imageIndex + 1;
			}
			cmdBuffer.pipelineBarrier(
				VkPipelineStageFlagBits.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
				VkPipelineStageFlagBits.VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
				0, [], [],
				array(imageMemoryBarrier(
					0,
					VkAccessFlagBits.VK_ACCESS_SHADER_READ_BIT,
					VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
					VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
					swapchain.images[lastImageIndex],
					VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
				))
			);
			cmdBuffer.pipelineBarrier(
				VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
				VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
				0, [], [],
				array(
					/*imageMemoryBarrier(
						0,
						VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
						VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
						VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
						swapchain.images[imageIndex],
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),*/
					imageMemoryBarrier(
						0,
						VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
						renderImage,
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
					imageMemoryBarrier(
						0,
						VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
						dPosImage[0],
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
					imageMemoryBarrier(
						0,
						VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
						dPosImage[1],
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
					imageMemoryBarrier(
						0,
						VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
						doubleColorImage[rtTime % 2][0],
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
					imageMemoryBarrier(
						0,
						VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
						oldDepthImage[rtTime % 2],
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
					imageMemoryBarrier(
						0,
						VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
						depthGuessImage,
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
					imageMemoryBarrier(
						0,
						VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
						normalsImage[rtTime % 2],
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
					imageMemoryBarrier(
						0,
						VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
						normalsImage[(rtTime + 1) % 2],
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
					// wieso die auch?
					imageMemoryBarrier(
						0,
						VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
						doubleColorImage[(rtTime + 1) % 2][0],
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
					imageMemoryBarrier(
						0,
						VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
						oldDepthImage[(rtTime + 1) % 2],
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
				)
			);
			float[13] rtPushConstants;
			rtPushConstants[0] = pos[0];
			rtPushConstants[1] = pos[1];
			rtPushConstants[2] = pos[2];
			rtPushConstants[3] = rot[1];
			rtPushConstants[4] = rot[0];
			rtPushConstants[5] = cast(float) capabilities.currentExtent.height / cast(float) capabilities.currentExtent.width;
			rtPushConstants[6] = capabilities.currentExtent.width;
			rtPushConstants[7] = capabilities.currentExtent.height;
			rtPushConstants[8] = oldPos[0];
			rtPushConstants[9] = oldPos[1];
			rtPushConstants[10] = oldPos[2];
			rtPushConstants[11] = oldRot[1];
			rtPushConstants[12] = oldRot[0];

			rasterizer.descriptorSet.write(WriteDescriptorSet(1, VkDescriptorType.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, sampler, swapchainViews[lastImageIndex], VkImageLayout.VK_IMAGE_LAYOUT_GENERAL));
			rasterizer.descriptorSet.write(WriteDescriptorSet(2, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, dPosImageView[0], VkImageLayout.VK_IMAGE_LAYOUT_GENERAL));
			rasterizer.descriptorSet.write(WriteDescriptorSet(3, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, dPosImageView[1], VkImageLayout.VK_IMAGE_LAYOUT_GENERAL));
			rasterizer.descriptorSet.write(WriteDescriptorSet(4, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, oldDepthImageView[rtTime % 2], VkImageLayout.VK_IMAGE_LAYOUT_GENERAL));
			rasterizer.descriptorSet.write(WriteDescriptorSet(5, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, oldDepthImageView[(rtTime + 1) % 2], VkImageLayout.VK_IMAGE_LAYOUT_GENERAL));
			rasterizer.descriptorSet.write(WriteDescriptorSet(6, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, depthGuessImageView, VkImageLayout.VK_IMAGE_LAYOUT_GENERAL));
			
			VkSampleLocationEXT sampleLoc;
			import std.random;
			import std.math;
			// aa noch nicht gut genug irgendwie?
			aaCount++;
			//sampleLoc.x = aaCount % 17 / 16.0 * sampleLocationRange[1];
			//sampleLoc.y = (aaCount % (16 * 16 + 1) / 16.0 - cast(uint)(aaCount % (16 * 16 + 1) / 16.0)) * sampleLocationRange[1];
			if (aaCount % 2 == 0) {
				sampleLoc.x = (aaCount) % 17 / 16.0 * sampleLocationRange[1];
			} else {
				sampleLoc.y = (aaCount - 1) % 17 / 16.0 * sampleLocationRange[1];
			}
			sampleLoc.x = uniform(sampleLocationRange[0], sampleLocationRange[1], rnd);
			sampleLoc.y = uniform(sampleLocationRange[0], sampleLocationRange[1], rnd);
			//sampleLoc.x = 0;
			//sampleLoc.y = 0;
			//sampleLoc.x = (passedTime * 17.2183 - trunc(passedTime * 17.2183)) * sampleLocationRange[1];
			//writeln(sampleLoc.x, " ", sampleLoc.y);

			//sampleLoc.x = cos(passedTime) * 0.4 + 0.4;
			//sampleLoc.y = cos(passedTime) * 0.4 + 0.4;
			VkSampleLocationsInfoEXT sampleLocations;
			sampleLocations.sType = VkStructureType.VK_STRUCTURE_TYPE_SAMPLE_LOCATIONS_INFO_EXT;
			sampleLocations.sampleLocationsPerPixel = VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT;
			sampleLocations.sampleLocationGridSize = VkExtent2D(1, 1);
			sampleLocations.sampleLocationsCount = 1;
			sampleLocations.pSampleLocations = &sampleLoc;

			PFN_vkCmdSetSampleLocationsEXT pfnCmdSetSampleLocationsEXT = cast(PFN_vkCmdSetSampleLocationsEXT)(vkGetDeviceProcAddr(device, "vkCmdSetSampleLocationsEXT"));
			pfnCmdSetSampleLocationsEXT(cmdBuffer, &sampleLocations);
			cmdBuffer.bindPipeline(rasterizer.pipeline, VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS);
			cmdBuffer.bindDescriptorSets(VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS, rasterizer.pipelineLayout, 0, array(rasterizer.descriptorSet), []);
			cmdBuffer.pushConstants(rasterizer.pipelineLayout, VkShaderStageFlagBits.VK_SHADER_STAGE_VERTEX_BIT | VkShaderStageFlagBits.VK_SHADER_STAGE_FRAGMENT_BIT, 0, float.sizeof * 13, rtPushConstants.ptr);
			cmdBuffer.beginRenderPass(rasterizer.renderPass, firstFramebuffer[(rtTime + 0) % 2], VkRect2D(VkOffset2D(0, 0), capabilities.currentExtent), array(
				VkClearValue(VkClearColorValue([1.0, 1.0, 1.0, 1.0])), clear,
				VkClearValue(VkClearColorValue([0.0, 0.0, 0.0, 0.0])),
				VkClearValue(VkClearColorValue([0.0, 0.0, 0.0, 0.0])),
				VkClearValue(VkClearColorValue([0.0, 0.0, 0.0, 0.0])),
				VkClearValue(VkClearColorValue([0.0, 0.0, 0.0, 0.0])),
				VkClearValue(VkClearColorValue([0.5, 0.5, 0.0, 0.0])),
			), VkSubpassContents.VK_SUBPASS_CONTENTS_INLINE);
			pfnCmdSetSampleLocationsEXT(cmdBuffer, &sampleLocations);

			cmdBuffer.bindDescriptorSets(VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS, rasterizer.pipelineLayout, 0, array(rasterizer.descriptorSet), []);
			foreach (i; objects.getComponentEntityIds!Drawable()) {
				auto entity = objects.getEntity(i);
				RasterizedModel* model = &models.getEntity(cast(size_t)entity.get!Drawable().modelId).get!RasterizedModel();
				if (model.isSmooth) {
					cmdBuffer.bindVertexBuffers(0, array(cast(Buffer)model.vertexBuffer.t, cast(Buffer)model.normalBuffer.t), array(cast(ulong) 0, cast(ulong) 0));
					cmdBuffer.bindIndexBuffer(cast(Buffer)model.vertexIndexBuffer.t, 0, VkIndexType.VK_INDEX_TYPE_UINT32);
					//cmdBuffer.draw(sphereVertexCount, 1, 0, 0);
					cmdBuffer.drawIndexed(model.indexCount, 1, 0, 0, entity.get!(ShaderListIndex!Drawable).index);
				} else {
					cmdBuffer.bindVertexBuffers(0, array(cast(Buffer)model.vertexBuffer.t, cast(Buffer)model.normalBuffer.t), array(cast(ulong) 0, cast(ulong) 0));
					cmdBuffer.draw(model.vertexCount, 1, 0, entity.get!(ShaderListIndex!Drawable).index);
				}
			}

			cmdBuffer.endRenderPass();

			/*cmdBuffer.pipelineBarrier(
				VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
				VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
				0, [], [],
				array(
					imageMemoryBarrier(
						VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
						VkAccessFlagBits.VK_ACCESS_SHADER_READ_BIT | VkAccessFlagBits.VK_ACCESS_SHADER_WRITE_BIT,
						VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						swapchain.images[imageIndex],
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
				)
			);*/
			cmdBuffer.pipelineBarrier(
				VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
				VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
				0, [], [],
				array(
					/*imageMemoryBarrier(
						VkAccessFlagBits.VK_ACCESS_SHADER_WRITE_BIT,
						VkAccessFlagBits.VK_ACCESS_SHADER_READ_BIT,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						dPosImage[0],
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
					imageMemoryBarrier(
						VkAccessFlagBits.VK_ACCESS_SHADER_WRITE_BIT,
						VkAccessFlagBits.VK_ACCESS_SHADER_READ_BIT,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						dPosImage[1],
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
					imageMemoryBarrier(
						VkAccessFlagBits.VK_ACCESS_SHADER_WRITE_BIT,
						VkAccessFlagBits.VK_ACCESS_SHADER_READ_BIT,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						oldDepthImage[0],
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
					imageMemoryBarrier(
						VkAccessFlagBits.VK_ACCESS_SHADER_WRITE_BIT,
						VkAccessFlagBits.VK_ACCESS_SHADER_READ_BIT,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						oldDepthImage[1],
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
					imageMemoryBarrier(
						VkAccessFlagBits.VK_ACCESS_SHADER_WRITE_BIT,
						VkAccessFlagBits.VK_ACCESS_SHADER_READ_BIT,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						depthGuessImage,
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),*/
					imageMemoryBarrier(
						VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
						VkAccessFlagBits.VK_ACCESS_SHADER_READ_BIT,
						VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						renderImage,
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
					imageMemoryBarrier(
						VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
						VkAccessFlagBits.VK_ACCESS_SHADER_READ_BIT,
						VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						dPosImage[0],
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
					imageMemoryBarrier(
						VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
						VkAccessFlagBits.VK_ACCESS_SHADER_READ_BIT,
						VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						dPosImage[1],
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
					imageMemoryBarrier(
						VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
						VkAccessFlagBits.VK_ACCESS_SHADER_READ_BIT | VkAccessFlagBits.VK_ACCESS_SHADER_WRITE_BIT,
						VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						doubleColorImage[rtTime % 2][0],
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
					imageMemoryBarrier(
						VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
						VkAccessFlagBits.VK_ACCESS_SHADER_READ_BIT,
						VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						oldDepthImage[rtTime % 2],
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
					imageMemoryBarrier(
						VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
						VkAccessFlagBits.VK_ACCESS_SHADER_READ_BIT,
						VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						depthGuessImage,
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
					imageMemoryBarrier(
						VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
						VkAccessFlagBits.VK_ACCESS_SHADER_READ_BIT,
						VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						normalsImage[rtTime % 2],
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
					imageMemoryBarrier(
						VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
						VkAccessFlagBits.VK_ACCESS_SHADER_READ_BIT,
						VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						normalsImage[(rtTime + 1) % 2],
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
					// wieso müssen diese beide auch auf general gesetzt werden?
					imageMemoryBarrier(
						VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
						VkAccessFlagBits.VK_ACCESS_SHADER_READ_BIT | VkAccessFlagBits.VK_ACCESS_SHADER_WRITE_BIT,
						VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						doubleColorImage[(rtTime + 1) % 2][0],
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
					imageMemoryBarrier(
						VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
						VkAccessFlagBits.VK_ACCESS_SHADER_READ_BIT,
						VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						oldDepthImage[(rtTime + 1) % 2],
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
				)
			);

			
			/*rasterizer.descriptorSet.write(WriteDescriptorSet(1, VkDescriptorType.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, sampler, swapchainViews[lastImageIndex], VkImageLayout.VK_IMAGE_LAYOUT_GENERAL));
			rasterizer.descriptorSet.write(WriteDescriptorSet(2, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, dPosImageView[0], VkImageLayout.VK_IMAGE_LAYOUT_GENERAL));
			rasterizer.descriptorSet.write(WriteDescriptorSet(3, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, dPosImageView[1], VkImageLayout.VK_IMAGE_LAYOUT_GENERAL));
			*/
			//imageAssembler.descriptorSet.write(array!VkWriteDescriptorSet(
			imageAssembler.descriptorSet.write(WriteDescriptorSet(0, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, swapchainViews[imageIndex], VkImageLayout.VK_IMAGE_LAYOUT_GENERAL));
				imageAssembler.descriptorSet.write(WriteDescriptorSet(1, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, dPosImageView[0], VkImageLayout.VK_IMAGE_LAYOUT_GENERAL));
				imageAssembler.descriptorSet.write(WriteDescriptorSet(2, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, dPosImageView[1], VkImageLayout.VK_IMAGE_LAYOUT_GENERAL));
				imageAssembler.descriptorSet.write(WriteDescriptorSet(3, VkDescriptorType.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, sampler, doubleColorImageView[(rtTime + 1) % 2][0], VkImageLayout.VK_IMAGE_LAYOUT_GENERAL));
				imageAssembler.descriptorSet.write(WriteDescriptorSet(4, VkDescriptorType.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, sampler, doubleColorImageView[(rtTime + 1) % 2][1], VkImageLayout.VK_IMAGE_LAYOUT_GENERAL));
				imageAssembler.descriptorSet.write(WriteDescriptorSet(5, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, doubleColorImageView[rtTime % 2][0], VkImageLayout.VK_IMAGE_LAYOUT_GENERAL));
				imageAssembler.descriptorSet.write(WriteDescriptorSet(6, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, doubleColorImageView[rtTime % 2][1], VkImageLayout.VK_IMAGE_LAYOUT_GENERAL));
				imageAssembler.descriptorSet.write(WriteDescriptorSet(7, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, oldDepthImageView[rtTime % 2], VkImageLayout.VK_IMAGE_LAYOUT_GENERAL));
				imageAssembler.descriptorSet.write(WriteDescriptorSet(8, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, oldDepthImageView[(rtTime + 1) % 2], VkImageLayout.VK_IMAGE_LAYOUT_GENERAL));
				imageAssembler.descriptorSet.write(WriteDescriptorSet(9, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, depthGuessImageView, VkImageLayout.VK_IMAGE_LAYOUT_GENERAL));
				imageAssembler.descriptorSet.write(WriteDescriptorSet(10, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, renderImageView, VkImageLayout.VK_IMAGE_LAYOUT_GENERAL));
				imageAssembler.descriptorSet.write(WriteDescriptorSet(11, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, normalsImageView[rtTime % 2], VkImageLayout.VK_IMAGE_LAYOUT_GENERAL));
				imageAssembler.descriptorSet.write(WriteDescriptorSet(12, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, normalsImageView[(rtTime + 1) % 2], VkImageLayout.VK_IMAGE_LAYOUT_GENERAL));
			//));
			
			cmdBuffer.bindPipeline(imageAssembler.computePipeline, VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_COMPUTE);
			uint[8] pushConstants;
			pushConstants[0] = 0;
			pushConstants[1] = 0;
			pushConstants[2] = capabilities.currentExtent.width;
			pushConstants[3] = capabilities.currentExtent.height;
			pushConstants[4] = capabilities.currentExtent.width / 3;
			pushConstants[5] = capabilities.currentExtent.height / 3;
			pushConstants[6] = rtTime % 3;
			pushConstants[7] = 0;
			cmdBuffer.bindDescriptorSets(VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_COMPUTE, imageAssembler.pipelineLayout, 0, array(imageAssembler.descriptorSet), []);
			cmdBuffer.pushConstants(imageAssembler.pipelineLayout, VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT, 0, uint.sizeof * 8, pushConstants.ptr);
			//cmdBuffer.dispatch(capabilities.currentExtent.width, capabilities.currentExtent.height, 1);
			int borderX = capabilities.currentExtent.width % localWorkGroupSize[0] > 0 ? 1 : 0;
			int borderY = capabilities.currentExtent.height % localWorkGroupSize[1] > 0 ? 1 : 0;
			cmdBuffer.dispatch(capabilities.currentExtent.width / localWorkGroupSize[0] + borderX, capabilities.currentExtent.height / localWorkGroupSize[1] + borderY, 1);
			cmdBuffer.pipelineBarrier(
				VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
				VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
				0, [], [],
				array(
					imageMemoryBarrier(
						VkAccessFlagBits.VK_ACCESS_SHADER_WRITE_BIT,
						VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
						VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
						VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
						swapchain.images[imageIndex],
						VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
					),
				)
			);
			/*cmdBuffer.clearColorImage(dPosImage[0], VkImageLayout.VK_IMAGE_LAYOUT_GENERAL, VkClearColorValue(0), array(VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)));
			cmdBuffer.clearColorImage(dPosImage[1], VkImageLayout.VK_IMAGE_LAYOUT_GENERAL, VkClearColorValue(0), array(VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)));
			cmdBuffer.clearColorImage(depthGuessImage, VkImageLayout.VK_IMAGE_LAYOUT_GENERAL, VkClearColorValue(0), array(VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)));
			cmdBuffer.clearColorImage(oldDepthImage[(rtTime + 1) % 2], VkImageLayout.VK_IMAGE_LAYOUT_GENERAL, VkClearColorValue(0), array(VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)));
			*/
		}

		cmdBuffer.bindPipeline(graphicsPipeline, VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS);
		cmdBuffer.bindDescriptorSets(VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS, pipelineLayoutGraphics, 0, array(graphicsDescriptorSet), []);
		cmdBuffer.beginRenderPass(renderPass, framebuffers[imageIndex], VkRect2D(VkOffset2D(0, 0), capabilities.currentExtent), array(VkClearValue(VkClearColorValue([1.0, 1.0, 0.0, 1.0])), clear), VkSubpassContents.VK_SUBPASS_CONTENTS_INLINE);
		foreach (i; dynEcs.getComponentEntityIds!Text()) {
			auto text = dynEcs.getComponent!Text(i);
			auto gpuBuffer = &dynEcs.getComponent!(GpuLocal!Buffer)(i);
			cmdBuffer.bindVertexBuffers(0, array(cast(Buffer)gpuBuffer.resource), array(cast(ulong) 0));
			cmdBuffer.draw(6 * cast(uint)text.text.length, 1, 0, 0);
		}
		cmdBuffer.endRenderPass();

		cmdBuffer.pipelineBarrier(
			VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
			VkPipelineStageFlagBits.VK_PIPELINE_STAGE_ALL_COMMANDS_BIT,
			0, [], [],
			array(imageMemoryBarrier(
				VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
				0,
				VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
				VkImageLayout.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
				swapchain.images[imageIndex],
				VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
			))
		);
		cmdBuffer.end();
		
		lastImageIndex = imageIndex;
		queue.submit(cmdBuffer, fence);
		fence.wait();
		fence.reset();
		auto submitResult = queue.present(swapchain, imageIndex);
		if (submitResult != VkResult.VK_SUCCESS) {
			cmdBuffer.reset();
			rebuildSwapchain();
			return;
		}
		cmdBuffer.reset();
		//assert(false);
	}
	Instance instance;
	Device device;
	CommandPool cmdPool;
	CommandBuffer cmdBuffer;
	MemoryAllocator memoryAllocator;
	Queue* queue;

	AllocatedResource!Image rasterDepthImage;
	ImageView rasterDepthImageView;

	Surface surface;
	Swapchain swapchain;
	RenderPass renderPass;
	Vector!ImageView swapchainViews;
	Vector!Framebuffer framebuffers;
	Shader vertexShader;
	Shader fragmentShader;
	GraphicsPipeline graphicsPipeline;
	Fence fence;
	VkSurfaceCapabilitiesKHR capabilities;
	
	Shader computeShader;
	DescriptorSetLayout descriptorSetLayout;
	PipelineLayout pipelineLayout;
	ComputePipeline computePipeline;
	DescriptorPool descriptorPool;
	DescriptorSet descriptorSet;
	DescriptorSet descriptorSet2;
	Timer timer;
	float passedTime = 0;
	int[3] localWorkGroupSize;

	AllocatedResource!Buffer uploadBuffer;
	AllocatedResource!Image fontTexture;
	Png pngFont;
	ImageView fontImageView;
	DescriptorSetLayout graphicsDescriptorSetLayout;
	PipelineLayout pipelineLayoutGraphics;
	DescriptorPool graphicsDescriptorPool;
	DescriptorSet graphicsDescriptorSet;

	AsciiBitfont font;
    alias PartialVec(T) = PartialVector!(T, 100);
	DynamicECS!(
        PartialVec,//Vector
		TypeSeqStruct!(
			CpuLocal!Buffer,
			GpuLocal!Buffer,
			Text,
		),
		TypeSeqStruct!(Text), // general
		TypeSeqStruct!(),
		TypeSeqStruct!(),
		TypeSeqStruct!(),
		TypeSeqStruct!(Text), // add
		TypeSeqStruct!(), // remove
		TypeSeqStruct!(),
        ECSConfig(true, true)
	) dynEcs;
	size_t timeCounter;
	
	AllocatedResource!Image blurredImage;
	ImageView blurredImageView;
	AllocatedResource!Image normalImage;
	ImageView normalImageView;
	AllocatedResource!Image depthImage;
	ImageView depthImageView;

	struct ComputePackage {
		Shader computeShader;
		DescriptorSetLayout descriptorSetLayout;
		PipelineLayout pipelineLayout;
		ComputePipeline computePipeline;
		DescriptorPool descriptorPool;
		DescriptorSet descriptorSet;
	}
	ComputePackage blurPipeline;

	float[3] pos;
	float[2] rot;
	float[3] oldPos;
	float[2] oldRot;
	int rtTime;

	struct GraphicsPackage {
		RenderPass renderPass;
		Shader vertexShader;
		Shader fragmentShader;
		GraphicsPipeline pipeline;
		DescriptorSetLayout descriptorSetLayout;
		PipelineLayout pipelineLayout;
		DescriptorPool descriptorPool;
		DescriptorSet descriptorSet;
	}
	bool rt;

	GraphicsPackage rasterizer;
	RtPipeline rtPipeline;

	/*struct ModelInstances {
		// objekt ids für spezifisches model, für draw command, um im shader dann auf eigenschaften des objekts zugreifen zu können
		ShaderList!(uint, false) instances;
	}*/
	// wichtig: shader list RTModelInfo muss synchronisiert bleiben mit den models indices
	// am besten als ShaderList funktion implementieren
	DynamicECS!(
        Vector,
		TypeSeqStruct!(
			WavefrontModel,
			ProceduralModel,
			RTModelInfo,
			RTPolygonModel,
			RTProceduralModel,
			RasterizedModel,
            ShaderListIndex!RTModelInfo,
			//ModelInstances
		),
		TypeSeqStruct!(RTModelInfo, ShaderListIndex!RTModelInfo), // general
		TypeSeqStruct!(),
		TypeSeqStruct!(),
		TypeSeqStruct!(),
		TypeSeqStruct!(WavefrontModel, RTModelInfo), // add
		TypeSeqStruct!(RTModelInfo, ShaderListIndex!RTModelInfo), // remove
		TypeSeqStruct!(),
        ECSConfig(false, false)
	) models;
	ShaderList!(RTModelInfo, false) rtModelInfos;

	DynamicECS!(
        PartialVec,//Vector
		TypeSeqStruct!(
			Drawable,
            ShaderListIndex!Drawable,
			VkAccelerationStructureInstanceKHR,
            ShaderListIndex!VkAccelerationStructureInstanceKHR,
		),
		// überprüfen welche von denen auch wirklich gebraucht werden
		TypeSeqStruct!(Drawable, ShaderListIndex!Drawable, VkAccelerationStructureInstanceKHR), // general
		TypeSeqStruct!(),
		TypeSeqStruct!(),
		TypeSeqStruct!(),
		TypeSeqStruct!(Drawable, VkAccelerationStructureInstanceKHR), // add
		TypeSeqStruct!(Drawable, ShaderListIndex!Drawable, VkAccelerationStructureInstanceKHR, ShaderListIndex!VkAccelerationStructureInstanceKHR), // remove
		TypeSeqStruct!(),
        ECSConfig(true, true)
	) objects;
	ShaderList!(VkAccelerationStructureInstanceKHR, false) asInstances;
	ShaderList!(Drawable, false) drawables;

	Tlas tlas;
	size_t cubeModel;
	size_t sphereModel;
	uint lastImageIndex;

	Random rnd;
	float[2] sampleLocationRange;
	Sampler sampler;
	uint aaCount;

	AllocatedResource!Image[2] oldDepthImage;
	ImageView[2] oldDepthImageView;
	AllocatedResource!Image depthGuessImage;
	ImageView depthGuessImageView;
	AllocatedResource!Image[2] normalsImage;
	ImageView[2] normalsImageView;
	AllocatedResource!Image[2] dPosImage;
	ImageView[2] dPosImageView;
	AllocatedResource!Image[2][2] doubleColorImage;
	ImageView[2][2] doubleColorImageView;
	ComputePackage imageAssembler;
	Framebuffer[2] firstFramebuffer;
	AllocatedResource!Image renderImage;
	ImageView renderImageView;
}

struct Tlas {
	AllocatedResource!Buffer tlasBuffer;
	AccelerationStructure tlas;
	AllocatedResource!Buffer scratchBuffer;
	Device* device;
	MemoryAllocator* memoryAllocator;
	this(ref Device device, ref MemoryAllocator memoryAllocator) {
		this.device = &device;
		this.memoryAllocator = &memoryAllocator;
	}
	void create(VkDeviceAddress address, uint length) {
		VkAccelerationStructureGeometryInstancesDataKHR instancesData;
		instancesData.sType = VkStructureType.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_INSTANCES_DATA_KHR;
		instancesData.arrayOfPointers = VK_FALSE;
		instancesData.data.deviceAddress = address;

		VkAccelerationStructureGeometryKHR geometry;
		geometry.sType = VkStructureType.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_KHR;
		geometry.geometryType = VkGeometryTypeKHR.VK_GEOMETRY_TYPE_INSTANCES_KHR;
		geometry.geometry.instances = instancesData;

		VkAccelerationStructureBuildGeometryInfoKHR buildInfo;
		buildInfo.sType = VkStructureType.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_BUILD_GEOMETRY_INFO_KHR;
		buildInfo.flags = VkBuildAccelerationStructureFlagBitsKHR.VK_BUILD_ACCELERATION_STRUCTURE_PREFER_FAST_TRACE_BIT_KHR | VkBuildAccelerationStructureFlagBitsKHR.VK_BUILD_ACCELERATION_STRUCTURE_ALLOW_UPDATE_BIT_KHR;
		buildInfo.geometryCount = 1;
		buildInfo.pGeometries = &geometry;
		buildInfo.mode = VkBuildAccelerationStructureModeKHR.VK_BUILD_ACCELERATION_STRUCTURE_MODE_BUILD_KHR;
		buildInfo.type = VkAccelerationStructureTypeKHR.VK_ACCELERATION_STRUCTURE_TYPE_TOP_LEVEL_KHR;
		buildInfo.srcAccelerationStructure = cast(VkAccelerationStructureKHR_T*)VK_NULL_HANDLE;

		VkAccelerationStructureBuildRangeInfoKHR rangeInfo;
		rangeInfo.firstVertex = 0;
		rangeInfo.primitiveCount = length;
		rangeInfo.primitiveOffset = 0;
		rangeInfo.transformOffset = 0;

		VkAccelerationStructureBuildSizesInfoKHR sizeInfo = device.getAccelerationStructureBuildSizesKHR(
			VkAccelerationStructureBuildTypeKHR.VK_ACCELERATION_STRUCTURE_BUILD_TYPE_DEVICE_KHR,
			&buildInfo,
			&rangeInfo.primitiveCount
		);
		tlasBuffer = AllocatedResource!Buffer(device.createBuffer(0, sizeInfo.accelerationStructureSize, VkBufferUsageFlagBits.VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_STORAGE_BIT_KHR));
		VkMemoryAllocateFlagsInfo flagsInfo;
		flagsInfo.sType = VkStructureType.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_FLAGS_INFO;
		flagsInfo.flags = VkMemoryAllocateFlagBits.VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT;
		memoryAllocator.allocate(tlasBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, flagsInfo);
		tlas = device.createAccelerationStructure(buildInfo.type, sizeInfo.accelerationStructureSize, 0, tlasBuffer.buffer, 0);

		VkPhysicalDeviceAccelerationStructurePropertiesKHR accProperties;
		accProperties.sType = VkStructureType.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ACCELERATION_STRUCTURE_PROPERTIES_KHR;
		VkPhysicalDeviceProperties2 properties;
		properties.sType = VkStructureType.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2;
		properties.pNext = cast(void*) &accProperties;
		device.physicalDevice.getProperties(&properties);
		scratchBuffer = AllocatedResource!Buffer(device.createBuffer(0, sizeInfo.buildScratchSize + accProperties.minAccelerationStructureScratchOffsetAlignment, VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT));
		memoryAllocator.allocate(scratchBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, flagsInfo);
	}
	void recreate(VkDeviceAddress address, uint length) {
		tlas.destroy();
		tlasBuffer.destroy();
		this.create(address, length);
	}
	void build(VkDeviceAddress address, uint length, ref CommandBuffer cmdBuffer) {
		VkAccelerationStructureGeometryInstancesDataKHR instancesData;
		instancesData.sType = VkStructureType.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_INSTANCES_DATA_KHR;
		instancesData.arrayOfPointers = VK_FALSE;
		instancesData.data.deviceAddress = address;

		VkAccelerationStructureGeometryKHR geometry;
		geometry.sType = VkStructureType.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_KHR;
		geometry.geometryType = VkGeometryTypeKHR.VK_GEOMETRY_TYPE_INSTANCES_KHR;
		geometry.geometry.instances = instancesData;

		VkAccelerationStructureBuildGeometryInfoKHR buildInfo;
		buildInfo.sType = VkStructureType.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_BUILD_GEOMETRY_INFO_KHR;
		buildInfo.flags = VkBuildAccelerationStructureFlagBitsKHR.VK_BUILD_ACCELERATION_STRUCTURE_PREFER_FAST_TRACE_BIT_KHR | VkBuildAccelerationStructureFlagBitsKHR.VK_BUILD_ACCELERATION_STRUCTURE_ALLOW_UPDATE_BIT_KHR;
		buildInfo.geometryCount = 1;
		buildInfo.pGeometries = &geometry;
		buildInfo.mode = VkBuildAccelerationStructureModeKHR.VK_BUILD_ACCELERATION_STRUCTURE_MODE_BUILD_KHR;
		buildInfo.type = VkAccelerationStructureTypeKHR.VK_ACCELERATION_STRUCTURE_TYPE_TOP_LEVEL_KHR;
		buildInfo.srcAccelerationStructure = cast(VkAccelerationStructureKHR_T*)VK_NULL_HANDLE;
		buildInfo.dstAccelerationStructure = tlas;

		VkAccelerationStructureBuildRangeInfoKHR rangeInfo;
		rangeInfo.firstVertex = 0;
		rangeInfo.primitiveCount = length;
		rangeInfo.primitiveOffset = 0;
		rangeInfo.transformOffset = 0;

		VkPhysicalDeviceAccelerationStructurePropertiesKHR accProperties;
		accProperties.sType = VkStructureType.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ACCELERATION_STRUCTURE_PROPERTIES_KHR;
		VkPhysicalDeviceProperties2 properties;
		properties.sType = VkStructureType.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2;
		properties.pNext = cast(void*) &accProperties;
		device.physicalDevice.getProperties(&properties);
		VkDeviceAddress da = scratchBuffer.getDeviceAddress();
		size_t daOffset = (accProperties.minAccelerationStructureScratchOffsetAlignment - (da % accProperties.minAccelerationStructureScratchOffsetAlignment)) % accProperties.minAccelerationStructureScratchOffsetAlignment;
		buildInfo.scratchData.deviceAddress = scratchBuffer.getDeviceAddress() + daOffset;

		cmdBuffer.buildAccelerationStructures((&buildInfo)[0..1], array(&rangeInfo));
	}
	void update(VkDeviceAddress address, uint length, ref CommandBuffer cmdBuffer) {
		VkAccelerationStructureGeometryInstancesDataKHR instancesData;
		instancesData.sType = VkStructureType.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_INSTANCES_DATA_KHR;
		instancesData.arrayOfPointers = VK_FALSE;
		instancesData.data.deviceAddress = address;

		VkAccelerationStructureGeometryKHR geometry;
		geometry.sType = VkStructureType.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_KHR;
		geometry.geometryType = VkGeometryTypeKHR.VK_GEOMETRY_TYPE_INSTANCES_KHR;
		geometry.geometry.instances = instancesData;

		VkAccelerationStructureBuildGeometryInfoKHR buildInfo;
		buildInfo.sType = VkStructureType.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_BUILD_GEOMETRY_INFO_KHR;
		buildInfo.flags = VkBuildAccelerationStructureFlagBitsKHR.VK_BUILD_ACCELERATION_STRUCTURE_PREFER_FAST_TRACE_BIT_KHR | VkBuildAccelerationStructureFlagBitsKHR.VK_BUILD_ACCELERATION_STRUCTURE_ALLOW_UPDATE_BIT_KHR;
		buildInfo.geometryCount = 1;
		buildInfo.pGeometries = &geometry;
		buildInfo.mode = VkBuildAccelerationStructureModeKHR.VK_BUILD_ACCELERATION_STRUCTURE_MODE_UPDATE_KHR;
		buildInfo.type = VkAccelerationStructureTypeKHR.VK_ACCELERATION_STRUCTURE_TYPE_TOP_LEVEL_KHR;
		buildInfo.srcAccelerationStructure = tlas;
		buildInfo.dstAccelerationStructure = tlas;

		VkAccelerationStructureBuildRangeInfoKHR rangeInfo;
		rangeInfo.firstVertex = 0;
		rangeInfo.primitiveCount = length;
		rangeInfo.primitiveOffset = 0;
		rangeInfo.transformOffset = 0;

		VkPhysicalDeviceAccelerationStructurePropertiesKHR accProperties;
		accProperties.sType = VkStructureType.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ACCELERATION_STRUCTURE_PROPERTIES_KHR;
		VkPhysicalDeviceProperties2 properties;
		properties.sType = VkStructureType.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2;
		properties.pNext = cast(void*) &accProperties;
		device.physicalDevice.getProperties(&properties);
		VkDeviceAddress da = scratchBuffer.getDeviceAddress();
		size_t daOffset = (accProperties.minAccelerationStructureScratchOffsetAlignment - (da % accProperties.minAccelerationStructureScratchOffsetAlignment)) % accProperties.minAccelerationStructureScratchOffsetAlignment;
		buildInfo.scratchData.deviceAddress = scratchBuffer.getDeviceAddress() + daOffset;

		cmdBuffer.buildAccelerationStructures((&buildInfo)[0..1], array(&rangeInfo));
	}
}

struct Aabb {
	float[3] min;
	float[3] max;
}

struct RtPipeline {
	Shader raygenShader;
	Shader missShader;
	Shader closesthitShader;
	Shader intersectShader;
	Shader closesthitShader2;
	RayTracingPipeline rtPipeline;
	DescriptorSetLayout descriptorSetLayout;
	DescriptorPool descriptorPool;
	DescriptorSet descriptorSet;
	PipelineLayout pipelineLayout;
	AllocatedResource!Buffer sbRayGen;
	AllocatedResource!Buffer sbMiss;
	AllocatedResource!Buffer sbHit;
	size_t offsetRayGen;
	size_t offsetMiss;
	size_t offsetHit;
	uint groupHandleSize;
	uint recordSize;
	uint groupSizeAligned;
	uint addressOffset;
}

struct ProceduralModel {
	uint id;
	float[3] min;
	float[3] max;
}

struct BufferAddresses {
	ulong vertices;
	ulong vertexIndices;
	ulong normals;
	ulong normalIndices;
}

struct RTModelInfo {
	BufferAddresses addresses;
	uint proceduralModelId;
}

struct RasterizedModel {
	bool isSmooth;
	AllocatedResource!Buffer vertexBuffer;
	AllocatedResource!Buffer vertexIndexBuffer;
	AllocatedResource!Buffer normalBuffer;
	AllocatedResource!Buffer normalIndexBuffer;
	//AllocatedResource!Buffer uvBuffer;
	//AllocatedResource!Buffer uvIndexBuffer;
	uint vertexCount;
	uint indexCount;
	//uint normalCount;
}

struct RTPolygonModel {
	AllocatedResource!Buffer vertexBuffer;
	AllocatedResource!Buffer vertexIndexBuffer;
	AllocatedResource!Buffer normalBuffer;
	AllocatedResource!Buffer normalIndexBuffer;
	AllocatedResource!Buffer blasBuffer;
	AccelerationStructure blas;
	VkAccelerationStructureGeometryKHR geometry;
	VkAccelerationStructureBuildRangeInfoKHR rangeInfo;
	VkAccelerationStructureBuildSizesInfoKHR sizeInfo;
}

struct RTProceduralModel {
	AllocatedResource!Buffer aabbBuffer;
	AllocatedResource!Buffer blasBuffer;
	AccelerationStructure blas;
	VkAccelerationStructureGeometryKHR geometry;
	VkAccelerationStructureBuildRangeInfoKHR rangeInfo;
	VkAccelerationStructureBuildSizesInfoKHR sizeInfo;
}

struct Drawable {
	Tensor!(float, 3) pos;
	Tensor!(float, 3) dpos;
	Tensor!(float, 3) scale;
	Tensor!(float, 3) rot;
	Tensor!(float, 3) rgb;
	uint modelId;
}

struct Text {
	String text;
	float x, y;
	float scale;
}

struct TestController(Args...) {
	struct CloseReceiver(ECS) {
		bool running = true;
		void receive(WindowCloseEvent) {
			running = false;
		}
	}
	StaticECS!(Args, Info!(CloseReceiver, DefaultDataStructure)) ecs;
	void initialize() {
		static foreach (i; 0 .. ecs.entitiesCount) {
			static if (__traits(compiles, ecs.entities[i][0].initialize())) {
				foreach (ref e; ecs.entities[i]) {
					e.initialize();
				}
			} else static if (__traits(compiles, ecs.entities[i][0].initialize(ecs))) {
				foreach (ref e; ecs.entities[i]) {
					e.initialize(ecs);
				}
			}
		}
	}
	void run() {
		while (ecs.entities[ecs.findTypes!(CloseReceiver)[0]][0].running) {
			static foreach(i; 0 .. ecs.entitiesCount) {
				static if (__traits(compiles, ecs.entities[i][0].update())) {
					foreach (ref e; ecs.entities[i]) {
						e.update();
					}
				} else static if (__traits(compiles, ecs.entities[i][0].update(ecs))) {
					foreach (ref e; ecs.entities[i]) {
						e.update(ecs);
					}
				}
			}
		}
	}
}

struct CpuLocal(Resource) {
	AllocatedResource!Resource resource;
	alias resource this;
	@disable this(ref return scope CpuLocal!Resource rhs);
}
struct GpuLocal(Resource) {
	AllocatedResource!Resource resource;
	alias resource this;
	@disable this(ref return scope CpuLocal!Resource rhs);
}

ref int tint(ref int i) {
	return i;
}

struct tStruct {
	int ret() const {
		return 1;
	}
	template opDispatch(string member2) {
		auto opDispatch(Args...)(lazy Args args) {
			writeln("3 ", args[0]);
		}
		@property auto opDispatch() {
			writeln("1");
			return 1;
		}
		/*@property auto opDispatch(T)(lazy T t) {
			writeln("2");
			return t;
		}*/
	}
}

struct s2 {
	int i;
	void j() {
		writeln("bla");
	}
}

version(unittest) {} else {
	void main() {
		TestController!(
			Info!(GlfwVulkanWindow, DefaultDataStructure),
			Info!(TestApp, DefaultDataStructure),
		) controller;
		controller.initialize();
		controller.run();
	}
}