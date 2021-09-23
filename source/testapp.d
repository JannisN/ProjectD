import vk;
import glfw_vulkan_window;
import utils;
import vulkan_core;
import functions;
import ecs;

struct TestApp {
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
	TestController!(
		Info!(GlfwVulkanWindow, DefaultDataStructure),
		Info!(TestApp, DefaultDataStructure)
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