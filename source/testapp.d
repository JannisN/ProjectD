import vulkan;
import glfw_vulkan_window;
import utils;
import vulkan_core;
import vulkan_tools;
import functions;
import ecs;
import png;
import font;

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
		timeCounter = dynEcs.add().id;
		dynEcs.entities[timeCounter].add!Text().get!Text.text = String(fval);
		dynEcs.entities[timeCounter].get!Text.x = -1;
		dynEcs.entities[timeCounter].get!Text.y = -1;
		dynEcs.entities[timeCounter].get!Text.scale = 1;
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
			dynEcs.entities[timeCounter].get!Text.text = String(fval);
			dynEcs.entities[timeCounter].get!Text.x = -1;
			dynEcs.entities[timeCounter].get!Text.y = -1;
			dynEcs.entities[timeCounter].get!Text.scale = 1;
			foreach (e; dynEcs.getView!(Circle).iterate) {
				dynEcs.remove(e);
			}
		}
	}
	void receive(WindowResizeEvent event) {
	}
	void initVulkan() {
		version(Windows) {
			instance = Instance("test", 1, VK_API_VERSION_1_0, array("VK_LAYER_KHRONOS_validation"), array("VK_KHR_surface", "VK_KHR_win32_surface"));
		}
		version(OSX) {
			instance = Instance("test", 1, VK_API_VERSION_1_0, array("VK_LAYER_KHRONOS_validation"), array("VK_KHR_surface", "VK_EXT_metal_surface"));
		}
		version(linux) {
			instance = Instance("test", 1, VK_API_VERSION_1_0, array("VK_LAYER_KHRONOS_validation"), array("VK_KHR_surface", "VK_KHR_xcb_surface"));
		}
		VkPhysicalDeviceFeatures features;
		features.shaderStorageImageWriteWithoutFormat = VK_TRUE;
		device = Device(instance.physicalDevices[0], features, array("VK_LAYER_KHRONOS_validation"), array("VK_KHR_swapchain"), array(createQueue(0, 1)));
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
	}
	void uploadVertexData() {
		Memory* memory = &uploadBuffer.allocatedMemory.allocatorList.memory;
		enum string fontfile = import("free_pixel_regular_16test.xml");
		font = AsciiBitfont(fontfile);
		enum string pngData = import("free_pixel_regular_16test.PNG");
		pngFont = Png(pngData);
		fontTexture = AllocatedResource!Image(device.createImage(0, VkImageType.VK_IMAGE_TYPE_2D, VkFormat.VK_FORMAT_B8G8R8A8_UNORM, VkExtent3D(pngFont.width, pngFont.height, 1), 1, 1, VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT, VkImageTiling.VK_IMAGE_TILING_OPTIMAL, VkImageUsageFlagBits.VK_IMAGE_USAGE_SAMPLED_BIT | VkImageUsageFlagBits.VK_IMAGE_USAGE_TRANSFER_DST_BIT | VkImageUsageFlagBits.VK_IMAGE_USAGE_STORAGE_BIT, VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED));
		memoryAllocator.allocate(fontTexture, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
		char* charptr = cast(char*) memory.map(1024, pngFont.byteCount * pngFont.height * pngFont.width);
		foreach (i; 0 .. pngFont.byteCount * pngFont.height * pngFont.width) {
			charptr[i] = pngFont.content[i];
		}
		
		memory.flush(array(mappedMemoryRange(*memory, 1024, /*1024 + pngFont.byteCount*/ VK_WHOLE_SIZE)));
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
		cmdBuffer.copyBufferToImage(uploadBuffer, fontTexture, VkImageLayout.VK_IMAGE_LAYOUT_GENERAL, 1024, pngFont.width, pngFont.height, VkImageSubresourceLayers(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1), VkOffset3D(0, 0, 0), VkExtent3D(pngFont.width, pngFont.height, 1));
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
	void update() {
		auto dt = timer.update();
		passedTime += dt;
		// neue utils datastructures: ein vektor aus statischen arrays, eine liste die aus einem vektor besteht(wie entities in StaticViewECS)
		// nicht gut: views liste sollte pointer beinhalten zu den components
		// get funktion sollte zuerst prüfen ob component in static view ist, dann kann component sofort gefunden werden
		// wenn man über ein view iteriert soll kein virtualcomponent benutzt werden/update listen ignorieren. für performance
		// generell sollte virtualcomponent bei get nur benutzt werden wenn struct in update liste enthalten.
		// getwithoutupdate sollte zudem ein immutable objekt zurückgeben
		// das gleiche evt. mit den update listen?
		// auch noch zu implementieren: views sollten alle components erhalten; schneller für den cache,
		// und sollte daher eine spezielle liste sein die mehrere anzahl an components enthält pro listeneintrag
		// zweite update funktion für shader list so dass alles kopiert wird, bzw zweite shaderlist die mit view arbeitet
		foreach (e; dynEcs.getView!(Circle).iterate) {
			import std.math.trigonometry;
			dynEcs.entities[e].get!Circle.x = 5 + sin(10.0 * passedTime);
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
		foreach (i; dynEcs.getEditUpdateList!Text.iterate()) {
			Text text = dynEcs.entities[i].getWithoutUpdate!Text();
			dynEcs.entities[i].remove!Text();
			dynEcs.entities[i].add!Text(text);
		}
		foreach (i; dynEcs.getAddUpdateList!Text.iterate) {
			auto textRef = dynEcs.entities[i].get!Text;
			auto vertPos = font.createText(cast(string)textRef.text, textRef.x, textRef.y, textRef.scale);
			dynEcs.entities[i].add!(GpuLocal!Buffer);
			dynEcs.entities[i].add!(CpuLocal!Buffer);
			auto gpuBuffer = dynEcs.entities[i].get!(GpuLocal!Buffer);
			auto cpuBuffer = dynEcs.entities[i].get!(CpuLocal!Buffer);
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
		circleShaderList.update(dynEcs, cmdBuffer);
		cmdBuffer.end();
		queue.submit(cmdBuffer, fence);
		fence.wait();
		cmdBuffer.reset();
		fence.reset();
		dynEcs.clearAddUpdateList!Text();
		dynEcs.clearEditUpdateList!Text();
		
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
		foreach (i; dynEcs.getView!Text.iterate) {
			auto text = dynEcs.entities[i].get!Text;
			auto gpuBuffer = dynEcs.entities[i].get!(GpuLocal!Buffer);
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
	StaticViewECS!(
		TypeSeqStruct!(
			TypeSeqStruct!(CpuLocal!Buffer),
			TypeSeqStruct!(GpuLocal!Buffer),
			TypeSeqStruct!(Text),
			TypeSeqStruct!(Circle),
		),
		TypeSeqStruct!(
		),
		TypeSeqStruct!(Text, Circle), // add
		TypeSeqStruct!(/*Text*/Circle, ShaderListIndex!Circle), // remove
		TypeSeqStruct!(Text, Circle), // editupdate
	) dynEcs;
	size_t timeCounter;
	
	CircleImplStruct circleImplStruct;
	ShaderList!Circle circleShaderList;
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

struct DebugStruct() {
	this(int bla) {

	}
	void initialize() {
	}
}
struct DebugStruct1(ECS) {
	ECS* ecs;
	this(int bla) {

	}
	void initialize(ref ECS ecs) {
		this.ecs = &ecs;
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
struct VirtualStruct {
	int i;
}
struct TestDestructor {
	~this() {
		writeln("destructor success");
	}
}

version(unittest) {} else {
	void main1() {
		StaticViewECS!(
			TypeSeqStruct!(
				TypeSeqStruct!(CpuLocal!Image),
				TypeSeqStruct!(VirtualStruct),
			),
			TypeSeqStruct!(
				TypeSeqStruct!(VirtualStruct, "i"),
			),
			TypeSeqStruct!(VirtualStruct), // add
			TypeSeqStruct!(VirtualStruct), // remove
			TypeSeqStruct!(), // editupdate
		) staticViewEcs;
		staticViewEcs.add().add!(GpuLocal!Image)().add!(VirtualStruct);
		staticViewEcs.add().add!(CpuLocal!Image)();
		staticViewEcs.add().add!(TestDestructor)();
		staticViewEcs.remove(2);
		LinkedList!size_t* cpuView2 = &staticViewEcs.getView!(CpuLocal!Image)();
		foreach (e; cpuView2.iterate) {
			writeln(e);
		}
		LinkedList!size_t* virtualView = &staticViewEcs.getView!(VirtualStruct)();
		foreach (e; virtualView.iterate) {
			auto test = staticViewEcs.entities[e].get!VirtualStruct;
			writeln(test.opDispatch!("i")(3));
		}
		auto updateList = &staticViewEcs.getUpdateList!(VirtualStruct, "i")();
		foreach (e; updateList.iterate) {
			writeln("update registrated");
		}
		auto addUpdateList = &staticViewEcs.getAddUpdateList!(VirtualStruct)();
		foreach (e; addUpdateList.iterate) {
			writeln("addUpdate");
		}
		staticViewEcs.remove(0);
		foreach (ref e; staticViewEcs.getRemoveUpdateList!VirtualStruct.iterate) {
			writeln("removeupdate");
		}
		TestController!(
			Info!(GlfwVulkanWindow, DefaultDataStructure),
			Info!(TestApp, DefaultDataStructure),
			Info!(DebugStruct, DefaultDataStructure),
			//Info!(DebugStruct1, DefaultDataStructure),
		) controller;
		controller.initialize();
		controller.run();
	}
}