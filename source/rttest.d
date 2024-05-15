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

// todo:
// getcomponents sollte virtualcomponents zurückgeben(das heisst neue iterator struct)

struct TestApp(ECS) {
	ECS* ecs;
	void initialize(ref ECS ecs) {
		this.ecs = &ecs;
		initVulkan();
		surface = (*ecs.createView!(GlfwVulkanWindow)[0])[0].createVulkanSurface(instance);
		initWindow();
		char[10] fval;
		import core.stdc.stdio;
		snprintf(fval.ptr, 10, "%f", 0f);
		timeCounter = dynEcs.add().entityId;
        dynEcs.addComponent!Text(timeCounter);
        dynEcs.getComponent!Text(timeCounter).text = String(fval);
        dynEcs.getComponent!Text(timeCounter).x = -1;
        dynEcs.getComponent!Text(timeCounter).y = -1;
        dynEcs.getComponent!Text(timeCounter).scale = 1;
		dynEcs.add().add!Circle(Circle(
			4, 4, 0.3,
			1, 0, 0
		));
		pos[0] = -2.0;
		pos[1] = 2.0;
		pos[2] = -10.0;
		rot[0] = 0.0;
		rot[1] = 0.0;
		//rtTime = 4;
	}
	void receive(MouseButtonEvent event) {
		writeln("event");
		if (event.action == MouseButtonAction.press) {
			char[20] fval;
			import core.stdc.stdio;
			snprintf(fval.ptr, 20, "Die Zeit ist:\n%f", passedTime);
            dynEcs.getComponent!Text(timeCounter).text = String(fval);
            dynEcs.getComponent!Text(timeCounter).x = -1;
            dynEcs.getComponent!Text(timeCounter).y = -1;
            dynEcs.getComponent!Text(timeCounter).scale = 1;
			foreach (id; dynEcs.getComponentEntityIds!(Circle)()) {
				dynEcs.remove(id);
			}
			rtTime++;

			import std.math.trigonometry;
			/*VkTransformMatrixKHR transformMatrix2;
			transformMatrix2.matrix = [
				[1.0f, 0.0f, 0.0f, sin(passedTime)],
				[0.0f, 1.0f, 0.0f, cos(passedTime)],
				[0.0f, 0.0f, 1.0f, 1.0f],
			];
			VkAccelerationStructureInstanceKHR testInstance;
			testInstance.transform = transformMatrix2;
			testInstance.instanceCustomIndex = 1;
			testInstance.mask = 0xff;
			testInstance.instanceShaderBindingTableRecordOffset = 1;
			testInstance.flags = VkGeometryInstanceFlagBitsKHR.VK_GEOMETRY_INSTANCE_TRIANGLE_FACING_CULL_DISABLE_BIT_KHR;
			testInstance.accelerationStructureReference = accelStruct.aabbBlasBuffer.getDeviceAddress();
			sphereEcs.add().add!VkAccelerationStructureInstanceKHR(testInstance);
			*/

			sphereEcs.add().add!Sphere(Sphere(2.0 * sin(passedTime), 1.0, 2.0 * cos(passedTime), 1.0));
			//sphereEcs.add().add!Cube(Cube(0.0, 0.0, 0.0, 1.0));

			/*cmdBuffer.begin();
			instanceShaderList.update2(sphereEcs, cmdBuffer);
			cmdBuffer.end();
			queue.submit(cmdBuffer, fence);
			fence.wait();
			fence.reset();

			rebuildAccelerationStructure();*/
			//rebuildAccelerationStructure();
		}
	}
	void receive(WindowResizeEvent event) {
	}
	struct AddressBuffers {
		ulong vertices;
		ulong indices;
		ulong normals;
		ulong normalIndices;
	}
	struct Aabb {
		float[3] min;
		float[3] max;
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

		// model sollte AdressBuffers struktur enthalten nicht den buffer
		// der buffer muss eine shaderlist sein und enthält adressbuffers von allen models
		AddressBuffers[1] addressBuffers;
		addressBuffers[0].vertices = vertexBufferAddress;
		addressBuffers[0].indices = indexBufferAddress;
		addressBuffers[0].normals = normalBufferAddress;
		addressBuffers[0].normalIndices = normalIndexBufferAddress;
		model.addressBuffer = AllocatedResource!Buffer(device.createBuffer(0, addressBuffers.length * AddressBuffers.sizeof, VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT));
		memoryAllocator.allocate(model.addressBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT);
		memory = &cast(Memory) model.addressBuffer.allocatedMemory.allocatorList.memory;
		byte* byteptr = cast(byte*) memory.map(model.addressBuffer.allocatedMemory.allocation.offset, addressBuffers.length * AddressBuffers.sizeof);
		foreach (i; 0 .. addressBuffers.length * AddressBuffers.sizeof) {
			byteptr[i] = (cast(byte*)addressBuffers.ptr)[i];
		}
		memory.flush(array(mappedMemoryRange(*memory, model.addressBuffer.allocatedMemory.allocation.offset, addressBuffers.length * AddressBuffers.sizeof)));
		memory.unmap();

		VkAccelerationStructureGeometryTrianglesDataKHR triangles;
		triangles.sType = VkStructureType.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_TRIANGLES_DATA_KHR;
		triangles.vertexFormat = VkFormat.VK_FORMAT_R32G32B32_SFLOAT;
		triangles.vertexData.deviceAddress = vertexBufferAddress; //wichtig: muss für gpu buffer auf device umgestellt werden!
		//triangles.vertexData.hostAddress = cast(void*)vertices.ptr;
		triangles.vertexStride = 3 * float.sizeof;
		triangles.indexType = VkIndexType.VK_INDEX_TYPE_UINT32;
		triangles.indexData.deviceAddress = indexBufferAddress; // hier ebenso
		//triangles.indexData.hostAddress = cast(void*)indices.ptr;
		triangles.maxVertex = cast(uint) vertices.length / 3; //3; //cast(uint) vertices.length - 1;//oder 2?
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
	void createTlas2() {
		VkAccelerationStructureGeometryInstancesDataKHR instancesData;
		instancesData.sType = VkStructureType.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_INSTANCES_DATA_KHR;
		instancesData.arrayOfPointers = VK_FALSE;
		instancesData.data.deviceAddress = instanceShaderList.gpuBuffer.getDeviceAddress(); //.getDeviceAddress();

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
		rangeInfo.primitiveCount = instanceShaderList.length;
		rangeInfo.primitiveOffset = 0;
		rangeInfo.transformOffset = 0;

		VkAccelerationStructureBuildSizesInfoKHR sizeInfo = device.getAccelerationStructureBuildSizesKHR(
			VkAccelerationStructureBuildTypeKHR.VK_ACCELERATION_STRUCTURE_BUILD_TYPE_DEVICE_KHR,
			&buildInfo,
			&rangeInfo.primitiveCount
		);
		tlas.tlasBuffer = AllocatedResource!Buffer(device.createBuffer(0, sizeInfo.accelerationStructureSize, VkBufferUsageFlagBits.VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_STORAGE_BIT_KHR));
		VkMemoryAllocateFlagsInfo flagsInfo;
		flagsInfo.sType = VkStructureType.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_FLAGS_INFO;
		flagsInfo.flags = VkMemoryAllocateFlagBits.VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT;
		memoryAllocator.allocate(tlas.tlasBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, flagsInfo);
		tlas.tlas = device.createAccelerationStructure(buildInfo.type, sizeInfo.accelerationStructureSize, 0, tlas.tlasBuffer.buffer, 0);

		VkPhysicalDeviceAccelerationStructurePropertiesKHR accProperties;
		accProperties.sType = VkStructureType.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ACCELERATION_STRUCTURE_PROPERTIES_KHR;
		VkPhysicalDeviceProperties2 properties;
		properties.sType = VkStructureType.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2;
		properties.pNext = cast(void*) &accProperties;
		device.physicalDevice.getProperties(&properties);
		tlas.scratchBuffer = AllocatedResource!Buffer(device.createBuffer(0, sizeInfo.buildScratchSize + accProperties.minAccelerationStructureScratchOffsetAlignment, VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT));
		memoryAllocator.allocate(tlas.scratchBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, flagsInfo);
	}
	void recreateTlas2() {
		tlas.tlas.destroy();
		tlas.tlasBuffer.destroy();
		createTlas2();
	}
	void buildTlas2() {
		VkAccelerationStructureGeometryInstancesDataKHR instancesData;
		instancesData.sType = VkStructureType.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_INSTANCES_DATA_KHR;
		instancesData.arrayOfPointers = VK_FALSE;
		instancesData.data.deviceAddress = instanceShaderList.gpuBuffer.getDeviceAddress(); //.getDeviceAddress();

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
		buildInfo.dstAccelerationStructure = tlas.tlas;

		VkAccelerationStructureBuildRangeInfoKHR rangeInfo;
		rangeInfo.firstVertex = 0;
		rangeInfo.primitiveCount = instanceShaderList.length;
		rangeInfo.primitiveOffset = 0;
		rangeInfo.transformOffset = 0;

		VkPhysicalDeviceAccelerationStructurePropertiesKHR accProperties;
		accProperties.sType = VkStructureType.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ACCELERATION_STRUCTURE_PROPERTIES_KHR;
		VkPhysicalDeviceProperties2 properties;
		properties.sType = VkStructureType.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2;
		properties.pNext = cast(void*) &accProperties;
		device.physicalDevice.getProperties(&properties);
		VkDeviceAddress da = tlas.scratchBuffer.getDeviceAddress();
		size_t daOffset = (accProperties.minAccelerationStructureScratchOffsetAlignment - (da % accProperties.minAccelerationStructureScratchOffsetAlignment)) % accProperties.minAccelerationStructureScratchOffsetAlignment;
		buildInfo.scratchData.deviceAddress = tlas.scratchBuffer.getDeviceAddress() + daOffset;

		// komisch dass rangeInfo ein pointer ist... muss dieser vlt länger existieren?
		cmdBuffer.buildAccelerationStructures((&buildInfo)[0..1], array(&rangeInfo));
	}
	void updateTlas2() {
		VkAccelerationStructureGeometryInstancesDataKHR instancesData;
		instancesData.sType = VkStructureType.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_INSTANCES_DATA_KHR;
		instancesData.arrayOfPointers = VK_FALSE;
		instancesData.data.deviceAddress = instanceShaderList.gpuBuffer.getDeviceAddress(); //.getDeviceAddress();

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
		buildInfo.srcAccelerationStructure = tlas.tlas;
		buildInfo.dstAccelerationStructure = tlas.tlas;

		VkAccelerationStructureBuildRangeInfoKHR rangeInfo;
		rangeInfo.firstVertex = 0;
		rangeInfo.primitiveCount = instanceShaderList.length;
		rangeInfo.primitiveOffset = 0;
		rangeInfo.transformOffset = 0;

		VkPhysicalDeviceAccelerationStructurePropertiesKHR accProperties;
		accProperties.sType = VkStructureType.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ACCELERATION_STRUCTURE_PROPERTIES_KHR;
		VkPhysicalDeviceProperties2 properties;
		properties.sType = VkStructureType.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2;
		properties.pNext = cast(void*) &accProperties;
		device.physicalDevice.getProperties(&properties);
		VkDeviceAddress da = tlas.scratchBuffer.getDeviceAddress();
		size_t daOffset = (accProperties.minAccelerationStructureScratchOffsetAlignment - (da % accProperties.minAccelerationStructureScratchOffsetAlignment)) % accProperties.minAccelerationStructureScratchOffsetAlignment;
		buildInfo.scratchData.deviceAddress = tlas.scratchBuffer.getDeviceAddress() + daOffset;

		// komisch dass rangeInfo ein pointer ist... muss dieser vlt länger existieren?
		cmdBuffer.buildAccelerationStructures((&buildInfo)[0..1], array(&rangeInfo));
	}
	void initAccelStructure() {
		enum string wavefrontCode = import("cube.wobj");
		WavefrontModel wavefrontModel = WavefrontModel(wavefrontCode);

		rtCube = createPolygonBlas(wavefrontModel);
		rtSphere = createProceduralBlas(array(0.0f, 0.0f, -1.0f), array(2.0f, 2.0f, 1.0f));
		
		VkPhysicalDeviceAccelerationStructurePropertiesKHR accProperties;
		accProperties.sType = VkStructureType.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ACCELERATION_STRUCTURE_PROPERTIES_KHR;
		VkPhysicalDeviceProperties2 properties;
		properties.sType = VkStructureType.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2;
		properties.pNext = cast(void*) &accProperties;
		device.physicalDevice.getProperties(&properties);

		VkMemoryAllocateFlagsInfo flagsInfo;
		flagsInfo.sType = VkStructureType.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_FLAGS_INFO;
		flagsInfo.flags = VkMemoryAllocateFlagBits.VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT;

		VkAccelerationStructureBuildGeometryInfoKHR[2] buildInfos;
		VkAccelerationStructureBuildRangeInfoKHR*[2] rangeInfos;
		AllocatedResource!Buffer[2] scratchBuffers;

		scratchBuffers[0] = AllocatedResource!Buffer(device.createBuffer(0, rtCube.sizeInfo.buildScratchSize + accProperties.minAccelerationStructureScratchOffsetAlignment, VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT));
		memoryAllocator.allocate(scratchBuffers[0], VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, flagsInfo);
		buildInfos[0].sType = VkStructureType.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_BUILD_GEOMETRY_INFO_KHR;
		buildInfos[0].flags = VkBuildAccelerationStructureFlagBitsKHR.VK_BUILD_ACCELERATION_STRUCTURE_PREFER_FAST_TRACE_BIT_KHR;
		buildInfos[0].geometryCount = 1;
		buildInfos[0].pGeometries = &rtCube.geometry;
		buildInfos[0].mode = VkBuildAccelerationStructureModeKHR.VK_BUILD_ACCELERATION_STRUCTURE_MODE_BUILD_KHR;
		buildInfos[0].type = VkAccelerationStructureTypeKHR.VK_ACCELERATION_STRUCTURE_TYPE_BOTTOM_LEVEL_KHR;
		buildInfos[0].dstAccelerationStructure = rtCube.blas.accelerationStructure;
		//buildInfo.srcAccelerationStructure = cast(VkAccelerationStructureKHR_T*)VK_NULL_HANDLE;
		size_t deviceAddressOffset = (accProperties.minAccelerationStructureScratchOffsetAlignment - (scratchBuffers[0].getDeviceAddress() % accProperties.minAccelerationStructureScratchOffsetAlignment)) % accProperties.minAccelerationStructureScratchOffsetAlignment;
		buildInfos[0].scratchData.deviceAddress = scratchBuffers[0].getDeviceAddress() + deviceAddressOffset;
		rangeInfos[0] = &rtCube.rangeInfo;

		scratchBuffers[1] = AllocatedResource!Buffer(device.createBuffer(0, rtSphere.sizeInfo.buildScratchSize + accProperties.minAccelerationStructureScratchOffsetAlignment, VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT));
		memoryAllocator.allocate(scratchBuffers[1], VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, flagsInfo);
		buildInfos[1].sType = VkStructureType.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_BUILD_GEOMETRY_INFO_KHR;
		buildInfos[1].flags = VkBuildAccelerationStructureFlagBitsKHR.VK_BUILD_ACCELERATION_STRUCTURE_PREFER_FAST_TRACE_BIT_KHR;
		buildInfos[1].geometryCount = 1;
		buildInfos[1].pGeometries = &rtSphere.geometry;
		buildInfos[1].mode = VkBuildAccelerationStructureModeKHR.VK_BUILD_ACCELERATION_STRUCTURE_MODE_BUILD_KHR;
		buildInfos[1].type = VkAccelerationStructureTypeKHR.VK_ACCELERATION_STRUCTURE_TYPE_BOTTOM_LEVEL_KHR;
		buildInfos[1].dstAccelerationStructure = rtSphere.blas.accelerationStructure;
		//buildInfo.srcAccelerationStructure = cast(VkAccelerationStructureKHR_T*)VK_NULL_HANDLE;
		deviceAddressOffset = (accProperties.minAccelerationStructureScratchOffsetAlignment - (scratchBuffers[1].getDeviceAddress() % accProperties.minAccelerationStructureScratchOffsetAlignment)) % accProperties.minAccelerationStructureScratchOffsetAlignment;
		buildInfos[1].scratchData.deviceAddress = scratchBuffers[1].getDeviceAddress() + deviceAddressOffset;
		rangeInfos[1] = &rtSphere.rangeInfo;


		cmdBuffer.begin();
		cmdBuffer.buildAccelerationStructures(buildInfos, rangeInfos);
		cmdBuffer.end();
		writeln("result: ", queue.submit(cmdBuffer, fence));
		writeln("result: ", fence.wait());
		cmdBuffer.reset();
		fence.reset();

		createTlas2();

		cmdBuffer.begin();
		buildTlas2();
		cmdBuffer.end();
		writeln("result: ", queue.submit(cmdBuffer, fence));
		writeln("result: ", fence.wait());
		cmdBuffer.reset();
		fence.reset();
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
	void initRtPipeline() {
		enum string raygenCode = import("raygen.spv");
		enum string missCode = import("miss.spv");
		enum string closesthitCode = import("closesthit.spv");
		enum string intersectCode = import("intersect.spv");
		enum string closesthit2Code = import("closesthit2.spv");
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
			VkShaderStageFlagBits.VK_SHADER_STAGE_CLOSEST_HIT_BIT_KHR,
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
			VkShaderStageFlagBits.VK_SHADER_STAGE_CLOSEST_HIT_BIT_KHR,
			null
		), VkDescriptorSetLayoutBinding(
			6,
			VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
			1,
			VkShaderStageFlagBits.VK_SHADER_STAGE_CLOSEST_HIT_BIT_KHR,
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

		/*PFN_vkCreateRayTracingPipelinesKHR pfnCreateRayTracingPipelinesKHR = cast(PFN_vkCreateRayTracingPipelinesKHR)(vkGetDeviceProcAddr(device, "vkCreateRayTracingPipelinesKHR"));

		VkRayTracingPipelineCreateInfoKHR rtpci;
		rtpci.sType = VkStructureType.VK_STRUCTURE_TYPE_RAY_TRACING_PIPELINE_CREATE_INFO_KHR;
		rtpci.stageCount = 3;
		rtpci.pStages = pssci.ptr;
		rtpci.groupCount = 3;
		rtpci.pGroups = rtsgci.ptr;
		rtpci.maxPipelineRayRecursionDepth = 1;
		rtpci.layout = rtPipeline.pipelineLayout;

		writeln("test: ", pfnCreateRayTracingPipelinesKHR(device.device, cast(VkDeferredOperationKHR_T*)VK_NULL_HANDLE, cast(VkPipelineCache_T*)VK_NULL_HANDLE, 1, &rtpci, null, &rtPipeline.rtPipeline));*/
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

		/*PFN_vkGetRayTracingShaderGroupHandlesKHR pfnGetRayTracingShaderGroupHandlesKHR = cast(PFN_vkGetRayTracingShaderGroupHandlesKHR)(vkGetDeviceProcAddr(device, "vkGetRayTracingShaderGroupHandlesKHR"));
		writeln("test: ", pfnGetRayTracingShaderGroupHandlesKHR(device.device, rtPipeline.rtPipeline, 0, groupCount, sbtSize, cast(void*)shaderHandleStorage.ptr));*/
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
		//rt = false;

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
			device = Device(instance.physicalDevices[0], features, array("VK_LAYER_KHRONOS_validation"), array("VK_KHR_swapchain"), array(createQueue(0, 1)));
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
		enum string vertexSourceNoRT = import("rasterVert.spv");
		enum string fragmentSourceNoRT = import("rasterFrag.spv");
		rasterizerPackage.vertexShader = device.createShader(vertexSourceNoRT);
		rasterizerPackage.fragmentShader = device.createShader(fragmentSourceNoRT);
		createComputeShader();
		timer.update();
		writeln(instance.physicalDevices[0].properties.limits.maxComputeWorkGroupInvocations);
		writeln(instance.physicalDevices[0].properties.limits.maxComputeWorkGroupSize[0]);
		writeln(instance.physicalDevices[0].properties.limits.maxComputeWorkGroupSize[1]);
		writeln(instance.physicalDevices[0].properties.limits.maxComputeWorkGroupSize[2]);

		circleShaderList = ShaderList!(Circle, false)(device, memoryAllocator, 16);

		VkMemoryAllocateFlagsInfo flagsInfo;
		flagsInfo.sType = VkStructureType.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_FLAGS_INFO;
		flagsInfo.flags = VkMemoryAllocateFlagBits.VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT;
		if (rt) {
			instanceShaderList = ShaderList!(VkAccelerationStructureInstanceKHR, false)(device, memoryAllocator, 16, 0, VkBufferUsageFlagBits.VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_BUILD_INPUT_READ_ONLY_BIT_KHR, null, &flagsInfo);
			initRtPipeline();
		}
		sphereShaderList = ShaderList!(Sphere, false)(device, memoryAllocator, 16);
		cubeShaderList = ShaderList!(Cube, false)(device, memoryAllocator, 16);

		if (rt) {
			cmdBuffer.begin();
			instanceShaderList.update2(sphereEcs, cmdBuffer);
			sphereShaderList.update2(sphereEcs, cmdBuffer);
			cubeShaderList.update2(sphereEcs, cmdBuffer);
			cmdBuffer.end();
			queue.submit(cmdBuffer, fence);
			fence.wait();
			fence.reset();
			initAccelStructure();
		}
		sphereEcs.add().add!Cube(Cube(0.0, -5.0, 0.0, 5.0));
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

		enum string sphereCode = import("sphere.wobj");
		WavefrontModel wavefrontModel = WavefrontModel(sphereCode);

		float[] vertices = wavefrontModel.vertices;
		uint[] indices = wavefrontModel.indicesVertices;
		float[] normals = wavefrontModel.normals;
		uint[] normalIndices = wavefrontModel.indicesNormals;
		float[] uvs = wavefrontModel.uvs;
		uint[] uvIndices = wavefrontModel.indicesUvs;

		Vector!float normalsOrdered = Vector!float(vertices.length);
		foreach (i, e; normalIndices) {
			normalsOrdered[indices[i] * 3] = normals[e * 3];
			normalsOrdered[indices[i] * 3 + 1] = normals[e * 3 + 1];
			normalsOrdered[indices[i] * 3 + 2] = normals[e * 3 + 2];
			/*normalsOrdered[i * 3] = normals[e * 3];
			normalsOrdered[i * 3 + 1] = normals[e * 3 + 1];
			normalsOrdered[i * 3 + 2] = normals[e * 3 + 2];*/
		}

		sphereVertexCount = cast(uint)vertices.length / 3;
		sphereIndexCount = cast(uint)indices.length;

		// provisorisch ---------
		/*sphereVertexBuffer = AllocatedResource!Buffer(device.createBuffer(0, indices.length * float.sizeof * 4, VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT));
		memoryAllocator.allocate(sphereVertexBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT);
		memory = &cast(Memory) sphereVertexBuffer.allocatedMemory.allocatorList.memory;
		float* floatptr = cast(float*) memory.map(sphereVertexBuffer.allocatedMemory.allocation.offset, indices.length * float.sizeof * 4);
		for (int i = 0; i < indices.length; i += 3) {
			floatptr[i * 4] = vertices[indices[i] * 3] * 1.0 + 0.0;
			floatptr[i * 4 + 1] = vertices[indices[i] * 3 + 1] * 1.0 + 0.0;
			floatptr[i * 4 + 2] = uvs[uvIndices[i] * 2] * 128;
			floatptr[i * 4 + 3] = uvs[uvIndices[i] * 2 + 1] * 128;

			floatptr[i * 4 + 4] = vertices[indices[i + 1] * 3] * 1.0 + 0.0;
			floatptr[i * 4 + 5] = vertices[indices[i + 1] * 3 + 1] * 1.0 + 0.0;
			floatptr[i * 4 + 6] = uvs[uvIndices[i + 1] * 2] * 128;
			floatptr[i * 4 + 7] = uvs[uvIndices[i + 1] * 2 + 1] * 128;

			floatptr[i * 4 + 8] = vertices[indices[i + 2] * 3] * 1.0 + 0.0;
			floatptr[i * 4 + 9] = vertices[indices[i + 2] * 3 + 1] * 1.0 + 0.0;
			floatptr[i * 4 + 10] = uvs[uvIndices[i + 2] * 2] * 128;
			floatptr[i * 4 + 11] = uvs[uvIndices[i + 2] * 2 + 1] * 128;
		}
		memory.flush(array(mappedMemoryRange(*memory, sphereVertexBuffer.allocatedMemory.allocation.offset, indices.length * float.sizeof * 4)));
		memory.unmap();
		sphereVertexCount = cast(uint)indices.length;*/
		// ------------

		sphereVertexBuffer = AllocatedResource!Buffer(device.createBuffer(0, vertices.length * float.sizeof, VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT));
		memoryAllocator.allocate(sphereVertexBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT);
		sphereVertexIndexBuffer = AllocatedResource!Buffer(device.createBuffer(0, indices.length * float.sizeof, VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_INDEX_BUFFER_BIT));
		memoryAllocator.allocate(sphereVertexIndexBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT);

		memory = &cast(Memory) sphereVertexBuffer.allocatedMemory.allocatorList.memory;
		float* floatptr = cast(float*) memory.map(sphereVertexBuffer.allocatedMemory.allocation.offset, vertices.length * float.sizeof);
		foreach (j, float f; vertices) {
			floatptr[j] = f;
		}
		memory.flush(array(mappedMemoryRange(*memory, sphereVertexBuffer.allocatedMemory.allocation.offset, vertices.length * float.sizeof)));
		memory.unmap();

		memory = &cast(Memory) sphereVertexIndexBuffer.allocatedMemory.allocatorList.memory;
		uint* intptr = cast(uint*) memory.map(sphereVertexIndexBuffer.allocatedMemory.allocation.offset, indices.length * uint.sizeof);
		foreach (j, uint f; indices) {
			intptr[j] = f;
		}
		memory.flush(array(mappedMemoryRange(*memory, sphereVertexIndexBuffer.allocatedMemory.allocation.offset, indices.length * uint.sizeof)));
		memory.unmap();


		sphereNormalBuffer = AllocatedResource!Buffer(device.createBuffer(0, normalsOrdered.length * float.sizeof, VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT));
		memoryAllocator.allocate(sphereNormalBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT);
		sphereNormalIndexBuffer = AllocatedResource!Buffer(device.createBuffer(0, normalIndices.length * float.sizeof, VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT));
		memoryAllocator.allocate(sphereNormalIndexBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT);

		memory = &cast(Memory) sphereNormalBuffer.allocatedMemory.allocatorList.memory;
		floatptr = cast(float*) memory.map(sphereNormalBuffer.allocatedMemory.allocation.offset, normalsOrdered.length * float.sizeof);
		foreach (j, float f; normalsOrdered) {
			floatptr[j] = f;
		}
		memory.flush(array(mappedMemoryRange(*memory, sphereNormalBuffer.allocatedMemory.allocation.offset, normalsOrdered.length * float.sizeof)));
		memory.unmap();

		memory = &cast(Memory) sphereNormalIndexBuffer.allocatedMemory.allocatorList.memory;
		intptr = cast(uint*) memory.map(sphereNormalIndexBuffer.allocatedMemory.allocation.offset, normalIndices.length * uint.sizeof);
		foreach (j, uint f; normalIndices) {
			intptr[j] = f;
		}
		memory.flush(array(mappedMemoryRange(*memory, sphereNormalIndexBuffer.allocatedMemory.allocation.offset, normalIndices.length * uint.sizeof)));
		memory.unmap();

		// ---------------

		enum string cubeCode = import("cube.wobj");
		WavefrontModel cubeWavefrontModel = WavefrontModel(cubeCode);

		vertices = cubeWavefrontModel.vertices;
		indices = cubeWavefrontModel.indicesVertices;
		normals = cubeWavefrontModel.normals;
		normalIndices = cubeWavefrontModel.indicesNormals;
		uvs = cubeWavefrontModel.uvs;
		uvIndices = cubeWavefrontModel.indicesUvs;

		uint cubeVerticesLength = cast(uint)(3 * indices.length);

		Vector!float cubeNormalsOrdered = Vector!float(normals.length);
		foreach (i, e; normalIndices) {
			cubeNormalsOrdered[normalIndices[i] * 3] = normals[e * 3];
			cubeNormalsOrdered[normalIndices[i] * 3 + 1] = normals[e * 3 + 1];
			cubeNormalsOrdered[normalIndices[i] * 3 + 2] = normals[e * 3 + 2];
			/*normalsOrdered[i * 3] = normals[e * 3];
			normalsOrdered[i * 3 + 1] = normals[e * 3 + 1];
			normalsOrdered[i * 3 + 2] = normals[e * 3 + 2];*/
		}

		cubeVertexCount = cast(uint)vertices.length / 3;
		cubeIndexCount = cast(uint)indices.length;
		//cubeVertexCount = cast(uint)normals.length / 3;

		cubeVertexBuffer = AllocatedResource!Buffer(device.createBuffer(0, cubeVerticesLength * float.sizeof, VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT));
		memoryAllocator.allocate(cubeVertexBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT);
		cubeVertexIndexBuffer = AllocatedResource!Buffer(device.createBuffer(0, indices.length * float.sizeof, VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_INDEX_BUFFER_BIT));
		memoryAllocator.allocate(cubeVertexIndexBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT);

		memory = &cast(Memory) cubeVertexBuffer.allocatedMemory.allocatorList.memory;
		floatptr = cast(float*) memory.map(cubeVertexBuffer.allocatedMemory.allocation.offset, cubeVerticesLength * float.sizeof);
		/*foreach (j, float f; cubeVerticesLength) {
			floatptr[j] = f;
		}*/
		for (uint j = 0; j < indices.length; j++) {
			floatptr[3 * j] = vertices[3 * indices[j]];
			floatptr[3 * j + 1] = vertices[3 * indices[j] + 1];
			floatptr[3 * j + 2] = vertices[3 * indices[j] + 2];
			/*floatptr[9 * j * 3] = vertices[3 * indices[j + 1]];
			floatptr[9 * j + 4] = vertices[3 * indices[j] + 1];
			floatptr[9 * j + 5] = vertices[3 * indices[j] + 2];
			floatptr[9 * j + 6] = vertices[3 * indices[j]];
			floatptr[9 * j + 7] = vertices[3 * indices[j] + 1];
			floatptr[9 * j + 8] = vertices[3 * indices[j] + 2];*/
		}
		memory.flush(array(mappedMemoryRange(*memory, cubeVertexBuffer.allocatedMemory.allocation.offset, cubeVerticesLength * float.sizeof)));
		memory.unmap();
		cubeVertexCount = cast(uint)indices.length;

		memory = &cast(Memory) cubeVertexIndexBuffer.allocatedMemory.allocatorList.memory;
		intptr = cast(uint*) memory.map(cubeVertexIndexBuffer.allocatedMemory.allocation.offset, indices.length * uint.sizeof);
		foreach (j, uint f; indices) {
			intptr[j] = f;
		}
		memory.flush(array(mappedMemoryRange(*memory, cubeVertexIndexBuffer.allocatedMemory.allocation.offset, indices.length * uint.sizeof)));
		memory.unmap();


		cubeNormalBuffer = AllocatedResource!Buffer(device.createBuffer(0, cubeVerticesLength * float.sizeof, VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT));
		memoryAllocator.allocate(cubeNormalBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT);
		cubeNormalIndexBuffer = AllocatedResource!Buffer(device.createBuffer(0, normalIndices.length * float.sizeof, VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT));
		memoryAllocator.allocate(cubeNormalIndexBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT);

		memory = &cast(Memory) cubeNormalBuffer.allocatedMemory.allocatorList.memory;
		floatptr = cast(float*) memory.map(cubeNormalBuffer.allocatedMemory.allocation.offset, cubeVerticesLength * float.sizeof);
		/*foreach (j, float f; normals) {
			floatptr[j] = f;
		}*/
		for (uint j = 0; j < indices.length; j++) {
			floatptr[3 * j] = normals[3 * normalIndices[j]];
			floatptr[3 * j + 1] = normals[3 * normalIndices[j] + 1];
			floatptr[3 * j + 2] = normals[3 * normalIndices[j] + 2];
			/*floatptr[9 * j * 3] = vertices[3 * indices[j + 1]];
			floatptr[9 * j + 4] = vertices[3 * indices[j] + 1];
			floatptr[9 * j + 5] = vertices[3 * indices[j] + 2];
			floatptr[9 * j + 6] = vertices[3 * indices[j]];
			floatptr[9 * j + 7] = vertices[3 * indices[j] + 1];
			floatptr[9 * j + 8] = vertices[3 * indices[j] + 2];*/
		}
		/*for (uint i = 0; i < indices.length; i++) {
			writeln(floatptr[3 * indices[i]]);
			writeln(floatptr[3 * indices[i] + 1]);
			writeln(floatptr[3 * indices[i] + 2]);
		}*/
		memory.flush(array(mappedMemoryRange(*memory, cubeNormalBuffer.allocatedMemory.allocation.offset, cubeVerticesLength * float.sizeof)));
		memory.unmap();

		memory = &cast(Memory) cubeNormalIndexBuffer.allocatedMemory.allocatorList.memory;
		intptr = cast(uint*) memory.map(cubeNormalIndexBuffer.allocatedMemory.allocation.offset, normalIndices.length * uint.sizeof);
		foreach (j, uint f; normalIndices) {
			intptr[j] = f;
		}
		memory.flush(array(mappedMemoryRange(*memory, cubeNormalIndexBuffer.allocatedMemory.allocation.offset, normalIndices.length * uint.sizeof)));
		memory.unmap();

		/*cubeIndexBuffer = AllocatedResource!Buffer(device.createBuffer(0, 2 * normalIndices.length * uint.sizeof, VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT));
		memoryAllocator.allocate(cubeIndexBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT);
		memory = &cast(Memory) cubeIndexBuffer.allocatedMemory.allocatorList.memory;
		intptr = cast(uint*) memory.map(cubeNormalIndexBuffer.allocatedMemory.allocation.offset, 2 * normalIndices.length * uint.sizeof);
		for (uint i = 0; i < normalIndices.length / 3; i++) {
			intptr[6 * i] = indices[i * 3];
			intptr[6 * i + 1] = indices[i * 3 + 1];
			intptr[6 * i + 2] = indices[i * 3 + 2];
			intptr[6 * i + 3] = normalIndices[i * 3];
			intptr[6 * i + 4] = normalIndices[i * 3 + 1];
			intptr[6 * i + 5] = normalIndices[i * 3 + 2];
		}
		memory.flush(array(mappedMemoryRange(*memory, cubeNormalIndexBuffer.allocatedMemory.allocation.offset, 2 * normalIndices.length * uint.sizeof)));
		memory.unmap();*/
	}
	struct CircleImplStruct {
		DescriptorSetLayout descriptorSetLayout;
		DescriptorPool descriptorPool;
		DescriptorSet descriptorSet;
		AllocatedResource!Buffer buffer;
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
		/*), VkDescriptorSetLayoutBinding(
			2,
			VkDescriptorType.VK_DESCRIPTOR_TYPE_ACCELERATION_STRUCTURE_KHR,
			1,
			VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT,
			null
		)));*/
		
		/*circleImplStruct.descriptorSetLayout = device.createDescriptorSetLayout(array(
			VkDescriptorSetLayoutBinding(
				0,
				VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
				1,
				VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT,
				null
			)
		));
		circleImplStruct.buffer = AllocatedResource!Buffer(device.createBuffer(0, Circle.sizeof * 3 + int.sizeof, VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT));
		memoryAllocator.allocate(circleImplStruct.buffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT);
		Memory* memory = &circleImplStruct.buffer.allocatedMemory.allocatorList.memory;
		void* mappedMem = memory.map(circleImplStruct.buffer.allocatedMemory.allocation.offset, VK_WHOLE_SIZE);
		int* circleCount = cast(int*) mappedMem;
		*circleCount = 3;
		Circle* circles = cast(Circle*) (mappedMem + int.sizeof);
		circles[0].x = 0;
		circles[0].y = 0;
		circles[0].radius = 0.1;
		circles[0].r = 1;
		circles[0].g = 0;
		circles[0].b = 0;
		circles[1].x = 1;
		circles[1].y = 1;
		circles[1].radius = 0.1;
		circles[1].r = 0;
		circles[1].g = 1;
		circles[1].b = 0;
		circles[2].x = 2;
		circles[2].y = 2;
		circles[2].radius = 0.1;
		circles[2].r = 0;
		circles[2].g = 0;
		circles[2].b = 1;*/
		//memory.flush(array(mappedMemoryRange(*memory, circleImplStruct.buffer.allocatedMemory.allocation.offset, /*1024 + pngFont.byteCount*/ VK_WHOLE_SIZE)));
		//memory.unmap();
		/*circleImplStruct.descriptorPool = device.createDescriptorPool(0, 1, array(
			VkDescriptorPoolSize(
				VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
				1
			)
		));
		circleImplStruct.descriptorSet = circleImplStruct.descriptorPool.allocateSet(circleImplStruct.descriptorSetLayout);*/

		pipelineLayout = device.createPipelineLayout(array(descriptorSetLayout/*, circleImplStruct.descriptorSetLayout*/), array(VkPushConstantRange(VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT, 0, uint.sizeof * 1)));//array(/*VkPushConstantRange(VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT, 0, float.sizeof)*/));
		import core.stdc.math : sqrt;
		int size2D = cast(int) sqrt(instance.physicalDevices[0].properties.limits.maxComputeWorkGroupInvocations);
		localWorkGroupSize[0] = size2D;
		localWorkGroupSize[1] = size2D;
		localWorkGroupSize[2] = 1;
		writeln(localWorkGroupSize);
		computePipeline = device.createComputePipeline(computeShader, "main", pipelineLayout, array(VkSpecializationMapEntry(0, 0, 4), VkSpecializationMapEntry(1, 4, 4), VkSpecializationMapEntry(2, 8, 4)), 12, localWorkGroupSize.ptr, null, null);
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
		/*), VkDescriptorPoolSize(
			VkDescriptorType.VK_DESCRIPTOR_TYPE_ACCELERATION_STRUCTURE_KHR,
			1
		)));*/
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
		blurPipeline.computePipeline = device.createComputePipeline(blurPipeline.computeShader, "main", blurPipeline.pipelineLayout, array(VkSpecializationMapEntry(0, 0, 4), VkSpecializationMapEntry(1, 4, 4), VkSpecializationMapEntry(2, 8, 4)), 12, localWorkGroupSize.ptr, null, null);
		blurPipeline.descriptorPool = device.createDescriptorPool(0, 1, array(VkDescriptorPoolSize(
			VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
			3
		)));
		blurPipeline.descriptorSet = blurPipeline.descriptorPool.allocateSet(blurPipeline.descriptorSetLayout);
	}
	void rebuildSwapchain() {
		vkDeviceWaitIdle(device.device);
		swapchainViews.resize(0);
		framebuffers.resize(0);
		graphicsDescriptorSet.destroy();
		graphicsDescriptorPool.destroy();
		graphicsPipeline.destroy();
		renderPass.destroy();
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

		{
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
		}

		// man sollte vlt zuerst ein physical device finden mit surface support bevor man ein device erstellt
		bool surfacesupport = instance.physicalDevices[0].surfaceSupported(surface);
		capabilities = instance.physicalDevices[0].getSurfaceCapabilities(surface);
		auto surfaceformats = instance.physicalDevices[0].getSurfaceFormats(surface);
		auto oldSwapchain = swapchain.swapchain;
		swapchain.swapchain = null;
		swapchain = device.createSwapchain(
			surface,
			2,
			VkFormat.VK_FORMAT_B8G8R8A8_UNORM,
			VkColorSpaceKHR.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR,
			capabilities.currentExtent,
			1,
			VkImageUsageFlagBits.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VkImageUsageFlagBits.VK_IMAGE_USAGE_TRANSFER_DST_BIT | VkImageUsageFlagBits.VK_IMAGE_USAGE_STORAGE_BIT,
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
		rasterDepthImage = AllocatedResource!Image(device.createImage(0, VkImageType.VK_IMAGE_TYPE_2D, VkFormat.VK_FORMAT_D32_SFLOAT, VkExtent3D(capabilities.currentExtent.width, capabilities.currentExtent.height, 1), 1, 1, VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT, VkImageTiling.VK_IMAGE_TILING_OPTIMAL, VkImageUsageFlagBits.VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT, VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED));
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
				)
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
		{
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
		if (rt) {
		cmdBuffer.begin();
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
		cmdBuffer.end();
		queue.submit(cmdBuffer, fence);
		fence.wait();
		fence.reset();
		}
	}
	double circlePos = 0.0;
	double circleVel = 0.0;
	void update() {
		auto dt = timer.update();
		passedTime += dt;
		// ?zweite update funktion für shader list so dass alles kopiert wird

		rtTime++;
		//rtTime %= 9;
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

        // problem: getComponents sollte virtualcomponent zurückgeben wegen updates
		foreach (id; dynEcs.getComponentEntityIds!Circle()) {
			import std.math.trigonometry;
			circlePos += dt * circleVel + dt * dt / 2.0 * (10.0 + circlePos * 10.0 * sin(10.0 * passedTime));
			circleVel += dt * (10.0 + circlePos * 10.0 * sin(10.0 * passedTime));
			//writeln(circlePos);
            dynEcs.getComponent!Circle(id).x = 5 + 0.1 * circlePos;//+ sin(10.0 * passedTime);
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
		circleShaderList.update2(dynEcs, cmdBuffer);
		cmdBuffer.end();
		queue.submit(cmdBuffer, fence);
		fence.wait();
		cmdBuffer.reset();
		fence.reset();
		dynEcs.clearAddUpdateList!Text();
		dynEcs.clearGeneralUpdateList!Text();

		if (sphereEcs.getAddUpdateList!Sphere().length > 0 || sphereEcs.getRemoveUpdateList!Sphere().length > 0) {
			cmdBuffer.begin();
			sphereShaderList.update2(sphereEcs, cmdBuffer, false);
			cmdBuffer.end();
			queue.submit(cmdBuffer, fence);
			fence.wait();
			fence.reset();
		}
		if (sphereEcs.getAddUpdateList!Cube().length > 0 || sphereEcs.getRemoveUpdateList!Cube().length > 0) {
			cmdBuffer.begin();
			cubeShaderList.update2(sphereEcs, cmdBuffer, false);
			cmdBuffer.end();
			queue.submit(cmdBuffer, fence);
			fence.wait();
			fence.reset();
		}
		if (rt) {
			foreach (i; sphereEcs.getAddUpdateList!Sphere()) {
				auto entity = sphereEcs.getEntity(i);
				Sphere sphere = entity.get!Sphere();
				VkTransformMatrixKHR transformMatrix2;
				transformMatrix2.matrix = [
					[sphere.radius, 0.0f, 0.0f, sphere.x - 1],
					[0.0f, sphere.radius, 0.0f, sphere.y - 1],
					[0.0f, 0.0f, sphere.radius, sphere.z],
				];
				VkAccelerationStructureInstanceKHR testInstance;
				testInstance.transform = transformMatrix2;
				testInstance.instanceCustomIndex = entity.get!(ShaderListIndex!Sphere)().index;
				testInstance.mask = 0xff;
				testInstance.instanceShaderBindingTableRecordOffset = 1;
				testInstance.flags = VkGeometryInstanceFlagBitsKHR.VK_GEOMETRY_INSTANCE_TRIANGLE_FACING_CULL_DISABLE_BIT_KHR;
				testInstance.accelerationStructureReference = rtSphere.blasBuffer.getDeviceAddress();
				sphereEcs.addComponent!VkAccelerationStructureInstanceKHR(i, testInstance);
			}
			foreach (i; sphereEcs.getAddUpdateList!Cube()) {
				auto entity = sphereEcs.getEntity(i);
				Cube cube = entity.get!Cube();
				VkTransformMatrixKHR transformMatrix2;
				transformMatrix2.matrix = [
					[cube.size, 0.0f, 0.0f, cube.x],
					[0.0f, cube.size, 0.0f, cube.y],
					[0.0f, 0.0f, cube.size, cube.z],
				];
				VkAccelerationStructureInstanceKHR testInstance;
				testInstance.transform = transformMatrix2;
				testInstance.instanceCustomIndex = entity.get!(ShaderListIndex!Cube)().index;
				testInstance.mask = 0xff;
				testInstance.instanceShaderBindingTableRecordOffset = 0;
				testInstance.flags = VkGeometryInstanceFlagBitsKHR.VK_GEOMETRY_INSTANCE_TRIANGLE_FACING_CULL_DISABLE_BIT_KHR;
				testInstance.accelerationStructureReference = rtCube.blasBuffer.getDeviceAddress();
				sphereEcs.addComponent!VkAccelerationStructureInstanceKHR(i, testInstance);
			}
		}
		sphereEcs.clearAddUpdateList!Sphere();
		sphereEcs.clearAddUpdateList!Cube();
		if (rt) {
			foreach (i; sphereEcs.getGeneralUpdateList!(ShaderListIndex!Sphere)()) {
				auto entity = sphereEcs.getEntity(i);
				entity.get!VkAccelerationStructureInstanceKHR().instanceCustomIndex = entity.get!(ShaderListIndex!Sphere)().index;
			}
			foreach (i; sphereEcs.getGeneralUpdateList!(ShaderListIndex!Cube)()) {
				auto entity = sphereEcs.getEntity(i);
				entity.get!VkAccelerationStructureInstanceKHR().instanceCustomIndex = entity.get!(ShaderListIndex!Cube)().index;
			}

			if (sphereEcs.getGeneralUpdateList!VkAccelerationStructureInstanceKHR().length > 0 || sphereEcs.getAddUpdateList!VkAccelerationStructureInstanceKHR().length > 0 || sphereEcs.getRemoveUpdateList!VkAccelerationStructureInstanceKHR().length > 0) {
				cmdBuffer.begin();
				instanceShaderList.update2(sphereEcs, cmdBuffer, false);
				cmdBuffer.end();
				queue.submit(cmdBuffer, fence);
				fence.wait();
				fence.reset();
				if (sphereEcs.getAddUpdateList!VkAccelerationStructureInstanceKHR().length > 0 || sphereEcs.getRemoveUpdateList!VkAccelerationStructureInstanceKHR().length > 0) {
					recreateTlas2();
				}
			}
		}
		
		/*import std.math.trigonometry;
		VkTransformMatrixKHR transformMatrix2;
		transformMatrix2.matrix = [
			[1.0f, 0.0f, 0.0f, sin(passedTime)],
			[0.0f, 1.0f, 0.0f, sin(passedTime)],
			[0.0f, 0.0f, 1.0f, sin(passedTime)],
		];
		Memory* memory = &cast(Memory) accelStruct.instanceBuffer.allocatedMemory.allocatorList.memory;
		VkAccelerationStructureInstanceKHR* instanceptr = cast(VkAccelerationStructureInstanceKHR*) memory.map(accelStruct.instanceBuffer.allocatedMemory.allocation.offset, 2 * VkAccelerationStructureInstanceKHR.sizeof);
		instanceptr[1].transform = transformMatrix2;
		memory.flush(array(mappedMemoryRange(*memory, accelStruct.instanceBuffer.allocatedMemory.allocation.offset, 2 * VkAccelerationStructureInstanceKHR.sizeof)));
		memory.unmap();*/
		
		cmdBuffer.begin();
		if (rt) {

		if (sphereEcs.getAddUpdateList!VkAccelerationStructureInstanceKHR().length > 0) {
			buildTlas2();
			/*cmdBuffer.end();
			queue.submit(cmdBuffer, fence);
			fence.wait();
			fence.reset();
			cmdBuffer.begin();*/
		} else if (sphereEcs.getGeneralUpdateList!VkAccelerationStructureInstanceKHR().length > 0) {
			updateTlas2();
			/*cmdBuffer.end();
			queue.submit(cmdBuffer, fence);
			fence.wait();
			fence.reset();
			cmdBuffer.begin();*/
		}
		sphereEcs.clearAddUpdateList!VkAccelerationStructureInstanceKHR();
		sphereEcs.clearGeneralUpdateList!VkAccelerationStructureInstanceKHR();
		sphereEcs.clearRemoveUpdateList!VkAccelerationStructureInstanceKHR();
		//cmdBuffer.buildAccelerationStructures((&accelStruct.buildInfo2)[0..1], (&accelStruct.rangeInfoPtr2)[0..1]);
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
			WriteDescriptorSet(1, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, blurredImageView/*swapchainViews[imageIndex]*/, VkImageLayout.VK_IMAGE_LAYOUT_GENERAL),
			WriteDescriptorSet(2, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, rtCube.addressBuffer),
			WriteDescriptorSet(3, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, normalImageView, VkImageLayout.VK_IMAGE_LAYOUT_GENERAL),
			WriteDescriptorSet(4, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, depthImageView, VkImageLayout.VK_IMAGE_LAYOUT_GENERAL),
			WriteDescriptorSet(5, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, sphereShaderList.gpuBuffer),
			WriteDescriptorSet(6, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, cubeShaderList.gpuBuffer),
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

		//PFN_vkCmdTraceRaysKHR pfnCmdTraceRaysKHR = cast(PFN_vkCmdTraceRaysKHR)(vkGetDeviceProcAddr(device, "vkCmdTraceRaysKHR"));

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


		/*
		VkWriteDescriptorSetAccelerationStructureKHR descriptorAccelStructInfo = writeAccelerationStructure(accelStruct.tlas);
		descriptorSet.write(array!VkWriteDescriptorSet(
			WriteDescriptorSet(0, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, swapchainViews[imageIndex], VkImageLayout.VK_IMAGE_LAYOUT_GENERAL),
			WriteDescriptorSet(1, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, fontImageView, VkImageLayout.VK_IMAGE_LAYOUT_GENERAL),
			WriteDescriptorSet(2, VkDescriptorType.VK_DESCRIPTOR_TYPE_ACCELERATION_STRUCTURE_KHR, 1, descriptorAccelStructInfo),
		));
		circleImplStruct.descriptorSet.write(array!VkWriteDescriptorSet(WriteDescriptorSet(0, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, circleShaderList.gpuBuffer)));
		cmdBuffer.bindPipeline(computePipeline, VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_COMPUTE);
		cmdBuffer.bindDescriptorSets(VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_COMPUTE, pipelineLayout, 0, array(descriptorSet, circleImplStruct.descriptorSet), []);
		cmdBuffer.pushConstants(pipelineLayout, VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT, 0, float.sizeof, &passedTime);
		int borderX = capabilities.currentExtent.width % localWorkGroupSize[0] > 0 ? 1 : 0;
		int borderY = capabilities.currentExtent.height % localWorkGroupSize[1] > 0 ? 1 : 0;
		cmdBuffer.dispatch(capabilities.currentExtent.width / localWorkGroupSize[0] + borderX, capabilities.currentExtent.height / localWorkGroupSize[1] + borderY, 1);
		*/


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
		/*descriptorSet2.write(array!VkWriteDescriptorSet(
			WriteDescriptorSet(0, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, blurredImageView, VkImageLayout.VK_IMAGE_LAYOUT_GENERAL),
			WriteDescriptorSet(1, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, swapchainViews[imageIndex], VkImageLayout.VK_IMAGE_LAYOUT_GENERAL),
		));*/
		cmdBuffer.bindPipeline(computePipeline, VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_COMPUTE);
		cmdBuffer.bindDescriptorSets(VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_COMPUTE, pipelineLayout, 0, array(descriptorSet), []);
		borderX = capabilities.currentExtent.width % localWorkGroupSize[0] > 0 ? 1 : 0;
		borderY = capabilities.currentExtent.height % localWorkGroupSize[1] > 0 ? 1 : 0;
		uint[1] pushConstants3;
		pushConstants3[0] = rtTime % 9;
		cmdBuffer.pushConstants(pipelineLayout, VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT, 0, uint.sizeof * 1, pushConstants3.ptr);
		cmdBuffer.dispatch(capabilities.currentExtent.width / localWorkGroupSize[0] + borderX, capabilities.currentExtent.height / localWorkGroupSize[1] + borderY, 1);

		/*foreach (i; 0 .. 30) {
			cmdBuffer.pipelineBarrier(
				VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
				VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
				0, [], [],
				array(imageMemoryBarrier(
					VkAccessFlagBits.VK_ACCESS_SHADER_READ_BIT,
					VkAccessFlagBits.VK_ACCESS_SHADER_WRITE_BIT,
					VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
					VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
					blurredImage,
					VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
				), imageMemoryBarrier(
					VkAccessFlagBits.VK_ACCESS_SHADER_WRITE_BIT,
					VkAccessFlagBits.VK_ACCESS_SHADER_READ_BIT,
					VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
					VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
					swapchain.images[imageIndex],
					VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
				))
			);
			cmdBuffer.bindDescriptorSets(VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_COMPUTE, pipelineLayout, 0, array(descriptorSet2), []);
			cmdBuffer.dispatch(capabilities.currentExtent.width / localWorkGroupSize[0] + borderX, capabilities.currentExtent.height / localWorkGroupSize[1] + borderY, 1);

			cmdBuffer.pipelineBarrier(
				VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
				VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
				0, [], [],
				array(imageMemoryBarrier(
					VkAccessFlagBits.VK_ACCESS_SHADER_WRITE_BIT,
					VkAccessFlagBits.VK_ACCESS_SHADER_READ_BIT,
					VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
					VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
					blurredImage,
					VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
				), imageMemoryBarrier(
					VkAccessFlagBits.VK_ACCESS_SHADER_READ_BIT,
					VkAccessFlagBits.VK_ACCESS_SHADER_WRITE_BIT,
					VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
					VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
					swapchain.images[imageIndex],
					VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
				))
			);
			cmdBuffer.bindDescriptorSets(VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_COMPUTE, pipelineLayout, 0, array(descriptorSet), []);
			cmdBuffer.dispatch(capabilities.currentExtent.width / localWorkGroupSize[0] + borderX, capabilities.currentExtent.height / localWorkGroupSize[1] + borderY, 1);
		}*/

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
				array(imageMemoryBarrier(
					0,
					0,
					VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
					VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
					swapchain.images[imageIndex],
					VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
				))
			);
			cmdBuffer.clearColorImage(
				swapchain.images[imageIndex],
				VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
				VkClearColorValue([1.0, 1.0, 1.0, 1.0]),
				array(VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1))
			);
			/*cmdBuffer.clearDepthStencilImage(
				rasterDepthImage,
				VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
				VkClearDepthStencilValue(0.0, 0),
				array(VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_DEPTH_BIT, 0, 1, 0, 1))
			);*/
			cmdBuffer.pipelineBarrier(
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
				)/*, imageMemoryBarrier(
					0,
					VkAccessFlagBits.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT,
					VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
					VkImageLayout.VK_IMAGE_LAYOUT_DEPTH_ATTACHMENT_OPTIMAL,
					rasterDepthImage,
					VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_DEPTH_BIT, 0, 1, 0, 1)
				)*/)
			);
		}
		/*cmdBuffer.pipelineBarrier(
			VkPipelineStageFlagBits.VK_PIPELINE_STAGE_RAY_TRACING_SHADER_BIT_KHR,
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
		);*/

		VkClearValue clear;
		clear.depthStencil = VkClearDepthStencilValue(0.0, 0);

		if (!rt) {
			cmdBuffer.pipelineBarrier(
				VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
				VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
				0, [], [],
				array(imageMemoryBarrier(
					VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
					VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
					VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
					VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
					swapchain.images[imageIndex],
					VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
				))
			);
		cmdBuffer.bindPipeline(rasterizerPackage.pipeline, VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS);
		cmdBuffer.bindDescriptorSets(VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS, rasterizerPackage.pipelineLayout, 0, array(rasterizerPackage.descriptorSet), []);
		float[6] rtPushConstants;
		rtPushConstants[0] = pos[0];
		rtPushConstants[1] = pos[1];
		rtPushConstants[2] = pos[2];
		rtPushConstants[3] = rot[1];
		rtPushConstants[4] = rot[0];
		rtPushConstants[5] = cast(float) capabilities.currentExtent.height / cast(float) capabilities.currentExtent.width;
		cmdBuffer.pushConstants(rasterizerPackage.pipelineLayout, VkShaderStageFlagBits.VK_SHADER_STAGE_VERTEX_BIT, 0, float.sizeof * 6, rtPushConstants.ptr);
		cmdBuffer.beginRenderPass(renderPass, framebuffers[imageIndex], VkRect2D(VkOffset2D(0, 0), capabilities.currentExtent), array(VkClearValue(VkClearColorValue([1.0, 1.0, 0.0, 1.0])), clear), VkSubpassContents.VK_SUBPASS_CONTENTS_INLINE);

		cmdBuffer.bindVertexBuffers(0, array(cast(Buffer)sphereVertexBuffer.t, cast(Buffer)sphereNormalBuffer.t), array(cast(ulong) 0, cast(ulong) 0));
		cmdBuffer.bindIndexBuffer(cast(Buffer)sphereVertexIndexBuffer.t, 0, VkIndexType.VK_INDEX_TYPE_UINT32);
		//cmdBuffer.draw(sphereVertexCount, 1, 0, 0);
		cmdBuffer.drawIndexed(sphereIndexCount, sphereShaderList.length, 0, 0, 0);
		//cmdBuffer.endRenderPass();

		cmdBuffer.bindDescriptorSets(VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS, rasterizerPackage.pipelineLayout, 0, array(cubeDescriptorSet), []);
		//cmdBuffer.beginRenderPass(renderPass, framebuffers[imageIndex], VkRect2D(VkOffset2D(0, 0), capabilities.currentExtent), array(VkClearValue(VkClearColorValue([1.0, 1.0, 0.0, 1.0])), clear), VkSubpassContents.VK_SUBPASS_CONTENTS_INLINE);
		cmdBuffer.bindVertexBuffers(0, array(cast(Buffer)cubeVertexBuffer.t, cast(Buffer)cubeNormalBuffer.t), array(cast(ulong) 0, cast(ulong) 0));
		cmdBuffer.bindIndexBuffer(cast(Buffer)cubeVertexIndexBuffer.t, 0, VkIndexType.VK_INDEX_TYPE_UINT32);
		cmdBuffer.draw(cubeVertexCount, cubeShaderList.length, 0, 0);
		//cmdBuffer.drawIndexed(cubeIndexCount, cubeShaderList.length, 0, 0, 0);
		cmdBuffer.endRenderPass();
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
		//cmdBuffer.bindVertexBuffers(0, array(cast(Buffer)sphereVertexBuffer.t), array(cast(ulong) 0));
		//cmdBuffer.draw(sphereVertexCount, 1, 0, 0);
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
		
		queue.submit(cmdBuffer, fence);
		VkResult testResult = fence.wait();
		/*while (testResult != VkResult.VK_SUCCESS) {
			testResult = fence.wait();
		}*/
		fence.reset();
		auto submitResult = queue.present(swapchain, imageIndex);
		if (submitResult != VkResult.VK_SUCCESS) {
			cmdBuffer.reset();
			rebuildSwapchain();
			return;
		}
		cmdBuffer.reset();
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
			Circle,
            ShaderListIndex!Circle
		),
		TypeSeqStruct!(Text, Circle), // general
		TypeSeqStruct!(),
		TypeSeqStruct!(),
		TypeSeqStruct!(),
		TypeSeqStruct!(Text, Circle), // add
		TypeSeqStruct!(/*Text*/Circle, ShaderListIndex!Circle), // remove
		TypeSeqStruct!(),
        ECSConfig(true, true)
	) dynEcs;
	size_t timeCounter;
	
	CircleImplStruct circleImplStruct;
	ShaderList!(Circle, false) circleShaderList;

	RtPipeline rtPipeline;

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
	int rtTime;

	DynamicECS!(
        PartialVec,//Vector
		TypeSeqStruct!(
			Sphere,
            ShaderListIndex!Sphere,
			Cube,
			ShaderListIndex!Cube,
			VkAccelerationStructureInstanceKHR,
            ShaderListIndex!VkAccelerationStructureInstanceKHR,
		),
		TypeSeqStruct!(Sphere, ShaderListIndex!Sphere, Cube, ShaderListIndex!Cube, VkAccelerationStructureInstanceKHR), // general
		TypeSeqStruct!(),
		TypeSeqStruct!(),
		TypeSeqStruct!(),
		TypeSeqStruct!(Sphere, Cube, VkAccelerationStructureInstanceKHR), // add
		TypeSeqStruct!(Sphere, ShaderListIndex!Sphere, Cube, ShaderListIndex!Cube, VkAccelerationStructureInstanceKHR, ShaderListIndex!VkAccelerationStructureInstanceKHR), // remove
		TypeSeqStruct!(),
        ECSConfig(true, true)
	) sphereEcs;
	ShaderList!(VkAccelerationStructureInstanceKHR, false) instanceShaderList;
	ShaderList!(Sphere, false) sphereShaderList;
	ShaderList!(Cube, false) cubeShaderList;

	AllocatedResource!Buffer sphereVertexBuffer;
	AllocatedResource!Buffer sphereVertexIndexBuffer;
	AllocatedResource!Buffer sphereNormalBuffer;
	AllocatedResource!Buffer sphereNormalIndexBuffer;
	AllocatedResource!Buffer sphereUvBuffer;
	AllocatedResource!Buffer sphereUvIndexBuffer;
	uint sphereVertexCount;
	uint sphereIndexCount;

	AllocatedResource!Buffer cubeVertexBuffer;
	AllocatedResource!Buffer cubeVertexIndexBuffer;
	AllocatedResource!Buffer cubeNormalBuffer;
	AllocatedResource!Buffer cubeNormalIndexBuffer;
	AllocatedResource!Buffer cubeUvBuffer;
	AllocatedResource!Buffer cubeUvIndexBuffer;

	AllocatedResource!Buffer cubeIndexBuffer;
	uint cubeVertexCount;
	uint cubeIndexCount;
	uint cubeNormalCount;

	struct GraphicsPackage {
		Shader vertexShader;
		Shader fragmentShader;
		GraphicsPipeline pipeline;
		DescriptorSetLayout descriptorSetLayout;
		PipelineLayout pipelineLayout;
		DescriptorPool descriptorPool;
		DescriptorSet descriptorSet;
	}
	GraphicsPackage rasterizerPackage;
	DescriptorSet cubeDescriptorSet;
	bool rt;

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
		TypeSeqStruct!(), // general
		TypeSeqStruct!(),
		TypeSeqStruct!(),
		TypeSeqStruct!(),
		TypeSeqStruct!(), // add
		TypeSeqStruct!(), // remove
		TypeSeqStruct!(),
        ECSConfig(false, false)
	) models;
	ShaderList!(RTModelInfo, false) rtModelInfoShaderList;

	RTPolygonModel rtCube;
	RTProceduralModel rtSphere;
	Tlas tlas;
}

struct Tlas {
	AllocatedResource!Buffer tlasBuffer;
	AccelerationStructure tlas;
	AllocatedResource!Buffer scratchBuffer;
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

}

struct RTPolygonModel {
	AllocatedResource!Buffer vertexBuffer;
	AllocatedResource!Buffer vertexIndexBuffer;
	AllocatedResource!Buffer normalBuffer;
	AllocatedResource!Buffer normalIndexBuffer;
	AllocatedResource!Buffer addressBuffer;
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
	Tensor!(float, 3) scale;
	Tensor!(float, 3) rot;
	Tensor!(float, 3) rgb;
}

struct Circle {
	float x, y;
	float radius;
	float r, g, b;
}

struct Text {
	String text;
	float x, y;
	float scale;
}

struct Sphere {
	float x, y, z;
	float radius;
}

struct Cube {
	float x, y, z;
	float size;
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