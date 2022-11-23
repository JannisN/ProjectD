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
		}
	}
	void receive(WindowResizeEvent event) {
	}
	struct AccelStruct {
		AllocatedResource!Buffer vertexBuffer;
		AllocatedResource!Buffer indexBuffer;
	}
	void initAccelStructure() {
		float[9] vertices = [
			0.0, 0.0, -1.0,
			0.0, 1.0, -1.0,
			-1.0, 0.0, -1.0
		];
		uint[3] indices = [ 0, 1, 2 ];
		accelStruct.vertexBuffer = AllocatedResource!Buffer(device.createBuffer(0, vertices.length * float.sizeof, VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT));
		memoryAllocator.allocate(cast(AllocatedResource!Buffer)accelStruct.vertexBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT);
		accelStruct.indexBuffer = AllocatedResource!Buffer(device.createBuffer(0, indices.length * float.sizeof, VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_INDEX_BUFFER_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT));
		memoryAllocator.allocate(cast(AllocatedResource!Buffer)accelStruct.indexBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT);

		Memory* memory = &cast(Memory) accelStruct.vertexBuffer.allocatedMemory.allocatorList.memory;
		float* floatptr = cast(float*) memory.map(accelStruct.vertexBuffer.allocatedMemory.allocation.offset, vertices.length * float.sizeof);
		foreach (j, float f; vertices) {
			floatptr[j] = f;
		}
		memory.flush(array(mappedMemoryRange(*memory, accelStruct.vertexBuffer.allocatedMemory.allocation.offset, accelStruct.vertexBuffer.allocatedMemory.allocation.length)));
		memory.unmap();

		memory = &cast(Memory) accelStruct.indexBuffer.allocatedMemory.allocatorList.memory;
		floatptr = cast(float*) memory.map(accelStruct.indexBuffer.allocatedMemory.allocation.offset, indices.length * float.sizeof);
		foreach (j, float f; indices) {
			floatptr[j] = f;
		}
		memory.flush(array(mappedMemoryRange(*memory, accelStruct.indexBuffer.allocatedMemory.allocation.offset, accelStruct.indexBuffer.allocatedMemory.allocation.length)));
		memory.unmap();

		VkDeviceAddress vertexBufferAddress = accelStruct.vertexBuffer.getDeviceAddress();
		VkDeviceAddress indexBufferAddress = accelStruct.indexBuffer.getDeviceAddress();

		VkAccelerationStructureGeometryTrianglesDataKHR triangles;
		triangles.sType = VkStructureType.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_TRIANGLES_DATA_KHR;
		triangles.vertexFormat = VkFormat.VK_FORMAT_R32G32B32_SFLOAT;
		triangles.vertexData.deviceAddress = vertexBufferAddress;
		triangles.vertexStride = 3 * float.sizeof;
		triangles.indexType = VkIndexType.VK_INDEX_TYPE_UINT32;
		triangles.indexData.deviceAddress = indexBufferAddress;
		triangles.maxVertex = cast(uint) vertices.length - 1;
		// triangles.transformData, no transform
	}
	void initVulkan() {
		version(Windows) {
			instance = Instance("test", 1, VK_API_VERSION_1_0, array("VK_LAYER_KHRONOS_validation"), array("VK_KHR_surface", "VK_KHR_win32_surface"));
		}
		version(OSX) {
			instance = Instance("test", 1, VK_API_VERSION_1_0, array("VK_LAYER_KHRONOS_validation"), array("VK_KHR_surface", "VK_EXT_metal_surface"));
		}
		version(linux) {
			instance = Instance("test", 1, VK_API_VERSION_1_3, array("VK_LAYER_KHRONOS_validation"), array("VK_KHR_surface", "VK_KHR_xcb_surface"));
		}
		VkPhysicalDeviceFeatures features;
		features.shaderStorageImageWriteWithoutFormat = VK_TRUE;
		device = Device(instance.physicalDevices[0], features, array("VK_LAYER_KHRONOS_validation"), array("VK_KHR_swapchain", "VK_KHR_acceleration_structure", "VK_KHR_ray_tracing_pipeline", "VK_KHR_ray_query", "VK_KHR_spirv_1_4", "VK_KHR_deferred_host_operations"), array(createQueue(0, 1)));
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
		createComputeShader();
		timer.update();
		writeln(instance.physicalDevices[0].properties.limits.maxComputeWorkGroupInvocations);
		writeln(instance.physicalDevices[0].properties.limits.maxComputeWorkGroupSize[0]);
		writeln(instance.physicalDevices[0].properties.limits.maxComputeWorkGroupSize[1]);
		writeln(instance.physicalDevices[0].properties.limits.maxComputeWorkGroupSize[2]);

		circleShaderList = ShaderList!Circle(device, memoryAllocator, 16);
		
		initAccelStructure();
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
	struct CircleImplStruct {
		DescriptorSetLayout descriptorSetLayout;
		DescriptorPool descriptorPool;
		DescriptorSet descriptorSet;
		AllocatedResource!Buffer buffer;
	}
	void createComputeShader() {
		enum string computeSource = import("testimage.spv");
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
		)));
		
		circleImplStruct.descriptorSetLayout = device.createDescriptorSetLayout(array(
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
		circles[2].b = 1;
		memory.flush(array(mappedMemoryRange(*memory, circleImplStruct.buffer.allocatedMemory.allocation.offset, /*1024 + pngFont.byteCount*/ VK_WHOLE_SIZE)));
		memory.unmap();
		circleImplStruct.descriptorPool = device.createDescriptorPool(0, 1, array(
			VkDescriptorPoolSize(
				VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
				1
			)
		));
		circleImplStruct.descriptorSet = circleImplStruct.descriptorPool.allocateSet(circleImplStruct.descriptorSetLayout);

		pipelineLayout = device.createPipelineLayout(array(descriptorSetLayout, circleImplStruct.descriptorSetLayout), array(VkPushConstantRange(VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT, 0, float.sizeof)));
		import core.stdc.math : sqrt;
		int size2D = cast(int) sqrt(instance.physicalDevices[0].properties.limits.maxComputeWorkGroupInvocations);
		localWorkGroupSize[0] = size2D;
		localWorkGroupSize[1] = size2D;
		localWorkGroupSize[2] = 1;
		writeln(localWorkGroupSize);
		computePipeline = device.createComputePipeline(computeShader, "main", pipelineLayout, array(VkSpecializationMapEntry(0, 0, 4), VkSpecializationMapEntry(1, 4, 4), VkSpecializationMapEntry(2, 8, 4)), 12, localWorkGroupSize.ptr, null, null);
		descriptorPool = device.createDescriptorPool(0, 1, array(VkDescriptorPoolSize(
			VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
			1
		), VkDescriptorPoolSize(
			VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
			1
		)));
		descriptorSet = descriptorPool.allocateSet(descriptorSetLayout);
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
		renderPass = device.createRenderPass(
			array(VkAttachmentDescription(
				0,
				VkFormat.VK_FORMAT_B8G8R8A8_UNORM,
				VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT,
				VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_LOAD,
				VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_STORE,
				VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
				VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_DONT_CARE,
				VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
				VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
			)),
			array(
				subpassDescription(
					[],
					array(
						VkAttachmentReference(
							0,
							VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
						)
					),
					[],
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
			framebuffers[i] = renderPass.createFramebuffer(array(swapchainViews[i].imageView), capabilities.currentExtent.width, capabilities.currentExtent.height, 1);
		}
		
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
			VkCullModeFlagBits.VK_CULL_MODE_NONE,
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

		graphicsPipeline = renderPass.createGraphicsPipeline(
			vertStage,
			fragStage,
			vertexInputStateCreateInfo,
			inputAssemblyStateCreateInfo,
			viewportStateCreateInfo,
			rasterizationStateCreateInfo,
			multiSample,
			blend,
			pipelineLayoutGraphics
		);
	}
	double circlePos = 0.0;
	double circleVel = 0.0;
	void update() {
		auto dt = timer.update();
		passedTime += dt;
		// ?zweite update funktion für shader list so dass alles kopiert wird

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
		
		cmdBuffer.begin();
		cmdBuffer.pipelineBarrier(
			VkPipelineStageFlagBits.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
			VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
			0, [], [],
			array(imageMemoryBarrier(
				0,
				VkAccessFlagBits.VK_ACCESS_SHADER_WRITE_BIT,
				VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
				VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
				swapchain.images[imageIndex],
				VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
			))
		);
		//writeln(passedTime);
		descriptorSet.write(array!VkWriteDescriptorSet(WriteDescriptorSet(0, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, swapchainViews[imageIndex], VkImageLayout.VK_IMAGE_LAYOUT_GENERAL), WriteDescriptorSet(1, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, fontImageView, VkImageLayout.VK_IMAGE_LAYOUT_GENERAL)));
		circleImplStruct.descriptorSet.write(array!VkWriteDescriptorSet(WriteDescriptorSet(0, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, circleShaderList.gpuBuffer)));
		cmdBuffer.bindPipeline(computePipeline, VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_COMPUTE);
		cmdBuffer.bindDescriptorSets(VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_COMPUTE, pipelineLayout, 0, array(descriptorSet, circleImplStruct.descriptorSet), []);
		cmdBuffer.pushConstants(pipelineLayout, VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT, 0, float.sizeof, &passedTime);
		int borderX = capabilities.currentExtent.width % localWorkGroupSize[0] > 0 ? 1 : 0;
		int borderY = capabilities.currentExtent.height % localWorkGroupSize[1] > 0 ? 1 : 0;
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
		cmdBuffer.bindPipeline(graphicsPipeline, VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS);
		cmdBuffer.bindDescriptorSets(VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS, pipelineLayoutGraphics, 0, array(graphicsDescriptorSet), []);
		cmdBuffer.beginRenderPass(renderPass, framebuffers[imageIndex], VkRect2D(VkOffset2D(0, 0), capabilities.currentExtent), array(VkClearValue(VkClearColorValue([1.0, 1.0, 0.0, 1.0]))), VkSubpassContents.VK_SUBPASS_CONTENTS_INLINE);
		foreach (i; dynEcs.getComponentEntityIds!Text()) {
			auto text = dynEcs.getComponent!Text(i);
			auto gpuBuffer = &dynEcs.getComponent!(GpuLocal!Buffer)(i);
			cmdBuffer.bindVertexBuffers(0, array(cast(Buffer)gpuBuffer.resource), array(cast(ulong) 0));
			cmdBuffer.draw(6 * cast(uint)text.text.length, cast(uint)text.text.length * 2, 0, 0);
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
	}
	Instance instance;
	Device device;
	CommandPool cmdPool;
	CommandBuffer cmdBuffer;
	MemoryAllocator memoryAllocator;
	Queue* queue;
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
	ShaderList!Circle circleShaderList;

	AccelStruct accelStruct;
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