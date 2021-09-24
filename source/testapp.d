import vk;
import glfw_vulkan_window;
import utils;
import vulkan_core;
import functions;
import ecs;

struct TestApp(ECS) {
	ECS* ecs;
	~this() {

	}
	void initialize(ref ECS ecs) {
		//pragma(msg, Sender);
		this.ecs = &ecs;
		initVulkan();
		surface = (*ecs.createView!(GlfwVulkanWindow)[0])[0].createVulkanSurface(instance);
		initWindow();
	}
	void receive(MouseButtonEvent event) {
		writeln("event");
	}
	void receive(WindowResizeEvent event) {
		writeln("resize");
		initWindow();
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
		device = Device(instance.physicalDevices[0], VkPhysicalDeviceFeatures(), array("VK_LAYER_KHRONOS_validation"), array("VK_KHR_swapchain"), array(createQueue(0, 1)));
		cmdPool = device.createCommandPool(0, VkCommandPoolCreateFlagBits.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT);
		cmdBuffer = cmdPool.allocateCommandBuffer(VkCommandBufferLevel.VK_COMMAND_BUFFER_LEVEL_PRIMARY);
		memoryAllocator.device = &device;
		queue = &device.queues[0];
		uploadVertexData();
		enum string vertexSource = import("a.spv");
		enum string fragmentSource = import("frag.spv");
		vertexShader = device.createShader(vertexSource);
		fragmentShader = device.createShader(fragmentSource);
		fence = device.createFence();
		writeln(fence.result.result);
	}
	void uploadVertexData() {
		vertexBuffer = AllocatedResource!Buffer(device.createBuffer(0, 1024, VkBufferUsageFlagBits.VK_BUFFER_USAGE_TRANSFER_SRC_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_TRANSFER_DST_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT));
		memoryAllocator.allocate(vertexBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT);
		Memory* memory = &vertexBuffer.allocatedMemory.allocatorList.memory;
		float[] vertex_positions = [
			0, 0, 0.6, 1,
			0, 0.5, 0.6, 1,
			0.5, 0.5, 0.6, 1,
			0, 0, 0.1, 1,
			0, -0.5, 0.1, 1,
			-0.5, -0.5, 0.1, 1,
		];
		float* floatptr = cast(float*) memory.map(0, 1024);
		foreach (i, float f; vertex_positions) {
			floatptr[i] = f;
		}
		memory.flush(array(mappedMemoryRange(*memory, 0, 1024)));
		memory.unmap();
	}
	void initWindow() {
		// man sollte vlt zuerst ein physical device finden mit surface support bevor man ein device erstellt
		bool surfacesupport = instance.physicalDevices[0].surfaceSupported(surface);
		capabilities = instance.physicalDevices[0].getSurfaceCapabilities(surface);
		auto surfaceformats = instance.physicalDevices[0].getSurfaceFormats(surface);
		swapchain = device.createSwapchain(
			surface,
			2,
			VkFormat.VK_FORMAT_B8G8R8A8_UNORM,
			VkColorSpaceKHR.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR,
			capabilities.currentExtent,
			1,
			VkImageUsageFlagBits.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VkImageUsageFlagBits.VK_IMAGE_USAGE_TRANSFER_DST_BIT,
			VkSharingMode.VK_SHARING_MODE_EXCLUSIVE,
			[],
			VkSurfaceTransformFlagBitsKHR.VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR,
			VkCompositeAlphaFlagBitsKHR.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
			VkPresentModeKHR.VK_PRESENT_MODE_IMMEDIATE_KHR,
			true,
			swapchain.swapchain
		);
		renderPass = device.createRenderPass(
			array(VkAttachmentDescription(
				0,
				VkFormat.VK_FORMAT_B8G8R8A8_UNORM,
				VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT,
				VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_CLEAR,
				VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_STORE,
				VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
				VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_DONT_CARE,
				VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
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
			array(VkVertexInputAttributeDescription(0, 0, VkFormat.VK_FORMAT_R32G32B32A32_SFLOAT, 0))
		);
		auto inputAssemblyStateCreateInfo = inputAssemblyState(VkPrimitiveTopology.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST, false);
		auto dummyViewport = VkViewport(0.0f, 0.0f, capabilities.currentExtent.width, capabilities.currentExtent.height, 0.1f, 1.0f);
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
		blendAttachment.blendEnable = false;
		blendAttachment.colorWriteMask = 0xf;
		auto blend = colorBlendState(false, VkLogicOp.VK_LOGIC_OP_COPY, array(blendAttachment), [0.5, 0.5, 0.5, 0.5]);

		auto pipelineLayoutGraphics = device.createPipelineLayout([], []);
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
		fence.isSignaled();
		uint imageIndex = swapchain.aquireNextImage(100, /*semaphore*/null, fence);
		fence.wait();
		fence.reset();
		
		cmdBuffer.begin();
		cmdBuffer.pipelineBarrier(
			VkPipelineStageFlagBits.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
			VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
			0, [], [],
			array(imageMemoryBarrier(
				0,
				VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
				VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
				VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
				swapchain.images[imageIndex],
				VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
			))
		);
		cmdBuffer.bindPipeline(graphicsPipeline, VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS);
		cmdBuffer.beginRenderPass(renderPass, framebuffers[imageIndex], VkRect2D(VkOffset2D(0, 0), capabilities.currentExtent), array(VkClearValue(VkClearColorValue([1.0, 1.0, 0.0, 1.0]))), VkSubpassContents.VK_SUBPASS_CONTENTS_INLINE);
		cmdBuffer.bindVertexBuffers(0, array(vertexBuffer), array(cast(ulong) 0));
		cmdBuffer.draw(6, 2, 0, 0);
		cmdBuffer.endRenderPass();
		cmdBuffer.pipelineBarrier(
			VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
			VkPipelineStageFlagBits.VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
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
		queue.present(swapchain, imageIndex);
		fence.wait();
		fence.reset();
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
	AllocatedResource!Buffer vertexBuffer;
	Shader vertexShader;
	Shader fragmentShader;
	GraphicsPipeline graphicsPipeline;
	Fence fence;
	VkSurfaceCapabilitiesKHR capabilities;
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
void main() {
	TestController!(
		Info!(GlfwVulkanWindow, DefaultDataStructure),
		Info!(TestApp, DefaultDataStructure),
		Info!(DebugStruct, DefaultDataStructure),
		//Info!(DebugStruct1, DefaultDataStructure),
	) controller;
	controller.initialize();
	controller.run();
}


/* tests:
import vk;
import glfw_vulkan_window;
import glfw3;
import events;
import utils;
import vulkan_core;
import functions;
import core.thread.osthread;
import core.time;
import ecs;

interface I1 {
	void bla1();
}

interface I2 {
	void bla2();
}

struct SomeStruct {
	void bla1() {writeln("bla1");}
	void bla2() {writeln("bla2");}
}

struct TestApp {
	void run() {
		initVulkan();
		initWindow();
		Timer timer;
		timer.update();
		double time = 0;
		while (!window.shouldClose()) {
			window.update();
			time = timer.update();
			//writeln(1 / time);
			auto milstosleep = 10;
			if (time < 1.0 / 60.0)
				milstosleep = cast(int)(1000 * (1.0 / 60.0 - time));	
			if (milstosleep > 0)
				Thread.sleep(dur!("msecs")(milstosleep));
		}
	}
	void receive(MouseButtonEvent event) {
		writeln("event");
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
		device = Device(instance.physicalDevices[0], VkPhysicalDeviceFeatures(), array("VK_LAYER_KHRONOS_validation"), array("VK_KHR_swapchain"), array(createQueue(0, 1)));
		cmdPool = device.createCommandPool(0, VkCommandPoolCreateFlagBits.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT);
		cmdBuffer = cmdPool.allocateCommandBuffer(VkCommandBufferLevel.VK_COMMAND_BUFFER_LEVEL_PRIMARY);
		memoryAllocator.device = &device;
		queue = &device.queues[0];
	}
	void initWindow() {
		//window = GlfwVulkanWindow!(Sender!(TestApp*))(640, 480, "Hello");
		
		sender = createSender(&this);
		//window.sender = &sender;
		window.initialize(sender);

		surface = window.createVulkanSurface(instance);
		// man sollte vlt zuerst ein physical device finden mit surface support bevor man ein device erstellt
		bool surfacesupport = instance.physicalDevices[0].surfaceSupported(surface);
		VkSurfaceCapabilitiesKHR capabilities = instance.physicalDevices[0].getSurfaceCapabilities(surface);
		auto surfaceformats = instance.physicalDevices[0].getSurfaceFormats(surface);
	}
	Sender!(TestApp*) sender;
	GlfwVulkanWindow!(Sender!(TestApp*)) window;
	Instance instance;
	Device device;
	CommandPool cmdPool;
	CommandBuffer cmdBuffer;
	MemoryAllocator memoryAllocator;
	Queue* queue;
	Surface surface;
}

struct TestApp2 {
	void initialize(ECS)(ref ECS ecs) {
		initVulkan();
		initWindow(ecs);
	}
	void receive(MouseButtonEvent event) {
		writeln("event");
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
		device = Device(instance.physicalDevices[0], VkPhysicalDeviceFeatures(), array("VK_LAYER_KHRONOS_validation"), array("VK_KHR_swapchain"), array(createQueue(0, 1)));
		cmdPool = device.createCommandPool(0, VkCommandPoolCreateFlagBits.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT);
		cmdBuffer = cmdPool.allocateCommandBuffer(VkCommandBufferLevel.VK_COMMAND_BUFFER_LEVEL_PRIMARY);
		memoryAllocator.device = &device;
		queue = &device.queues[0];
	}
	void initWindow(ECS)(ref ECS ecs) {
		surface = ecs.createView!(GlfwVulkanWindow)[0][0].createVulkanSurface(instance);
		//surface = ecs.entities[ecs.findTypes!GlfwVulkanWindow[0]][0].createVulkanSurface(instance);
		// man sollte vlt zuerst ein physical device finden mit surface support bevor man ein device erstellt
		bool surfacesupport = instance.physicalDevices[0].surfaceSupported(surface);
		VkSurfaceCapabilitiesKHR capabilities = instance.physicalDevices[0].getSurfaceCapabilities(surface);
		auto surfaceformats = instance.physicalDevices[0].getSurfaceFormats(surface);
	}
	Instance instance;
	Device device;
	CommandPool cmdPool;
	CommandBuffer cmdBuffer;
	MemoryAllocator memoryAllocator;
	Queue* queue;
	Surface surface;
	void bla1() {

	}
}

struct TestController(Args...) {
	struct CloseReceiver {
		bool running = true;
		void receive(WindowCloseEvent) {
			running = false;
		}
	}
	StaticECS!(Args, Info!(CloseReceiver, DefaultDataStructure)) ecs;
	void initialize() {
		static foreach (i; 0 .. Args.length) {
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
			static foreach(i; 0 .. Args.length) {
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

void main() {
	ECS dynEcs;
	dynEcs.add().add!int(4).add!double(1.23);
	dynEcs.add().add!char.add!bool;
	dynEcs.add().add!int(4).add!SomeStruct;
	dynEcs.add().add!int(1).add!double(7.23);
	dynEcs.add().add!string.add!long;
	dynEcs.add().add!int(4).add!double(1.23);
	auto element = dynEcs.get(0).get!(double);
	auto elementSearch = dynEcs.get!(int, double);
	foreach (i; elementSearch) {
		writeln(i);
	}
	Vector!double testVec = Vector!double(3);
	testVec[0] = 1;
	testVec[1] = 2;
	testVec.resize(32);

	import ecs;
	StaticECS!(Info!(int, Vector, double), Info!(double, DefaultDataStructure, int, long, "hallo"), Info!(double, DefaultDataStructure, "hallo123")) someEcs;
	someEcs.entities[0].resize(10);
	someEcs.entities[0][0] = 1;
	someEcs.entities[1][0] = 1.23;
	someEcs.entities[2][0] = 2.23;
	static foreach (e; someEcs.tags) {
		static foreach (s; e) {
			writeln(s);
		}
	}
	someEcs.applyTo!(function double(double c) { return c + 1.23; }, double)();
	auto someVar = seqToArray!(someEcs.findTypes!(double));
	auto someVar2 = seqToArray!(someEcs.findCompatibleTypesMultiple!(int, long));
	auto someVar3 = seqToArray!(someEcs.findCompatibleTypesMultipleWithType!(int, double));
	auto view = someEcs.createView!(int, double);
	view[1][0] = 3.14;

	SomeStruct somestruct;
	auto tstruct = Box!(SomeStruct*, I1, I2)(&somestruct);
	tstruct.bla1();
	tstruct.bla2();
	//TestApp testapp;
	//testapp.run();

	// template erstellen dass man controller auch in trivialen fällen ohne Info! erstellen kann
	TestController!(
		Info!(GlfwVulkanWindow, DefaultDataStructure),
		Info!(TestApp2, DefaultDataStructure, I1)
	) controller;
	controller.initialize();
	controller.run();
	ECS newEcs = controller.ecs.createDynamicECS();
	foreach (ref e; newEcs.entities[0 .. newEcs.length]) {
		writeln(e.id);
		foreach (ref f; e.components.iterate) {
			writeln(f.type);
		}
	}
}

extern(C) __gshared bool rt_cmdline_enabled = false;
extern(C) __gshared string[] rt_options = ["gcopt=gc:manual disable:1"];
*/