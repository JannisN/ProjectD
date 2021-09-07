import vk;
import glfw_vulkan_window;
import glfw3;
import events;
import utils;
import vulkan_core;
import std.stdio;
import core.thread.osthread;
import core.time;

// für ein ECS sollte zb glfwwindow ohne template parameter ans ECS übergeben werden, damit keine unendliche referenz entsteht
// es muss auch nicht alles abstrahiert/runtime mässig gemacht werden. zb. für memory allocation reicht eine malloc funktion die dann je nach version definition was anderes ausführt.

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
		window = GlfwVulkanWindow!(Sender!(TestApp*))(640, 480, "Hello");
		window.sender = createSender(&this);

		surface = window.createVulkanSurface(instance);
		// man sollte vlt zuerst ein physical device finden mit surface support bevor man ein device erstellt
		bool surfacesupport = instance.physicalDevices[0].surfaceSupported(surface);
		VkSurfaceCapabilitiesKHR capabilities = instance.physicalDevices[0].getSurfaceCapabilities(surface);
		auto surfaceformats = instance.physicalDevices[0].getSurfaceFormats(surface);
	}
	GlfwVulkanWindow!(Sender!(TestApp*)) window;
	Instance instance;
	Device device;
	CommandPool cmdPool;
	CommandBuffer cmdBuffer;
	MemoryAllocator memoryAllocator;
	Queue* queue;
	Surface surface;
}

alias TestFunc(T) = TypeSeq!(T);

struct T234(Args...) {
	ApplyTypeSeq!(TestFunc, Args) args;
}
void main() {
	T234!(int, double, char) t234;
	import ecs;
	StaticECS!(Info!(int, Vector, double), Info!(double, DefaultDataStructure, "hallo"), Info!(double, DefaultDataStructure, "hallo123")) someEcs;
	someEcs.entities[0].resize(10);
	someEcs.entities[0][0] = 1;
	someEcs.entities[1] = 1.23;
	someEcs.entities[2] = 2.23;
	static foreach (e; someEcs.tags) {
		static foreach (s; e) {
			writeln(s);
		}
	}
	someEcs.applyTo!(double, function double(double c) { return c + 1.23; })();
	auto someVar = seqToArray!(someEcs.findStaticTypes!(double));

	SomeStruct somestruct;
	auto tstruct = Box!(SomeStruct*, I1, I2)(&somestruct);
	tstruct.bla1();
	tstruct.bla2();
	TestApp testapp;
	testapp.run();
}

extern(C) __gshared bool rt_cmdline_enabled = false;
extern(C) __gshared string[] rt_options = ["gcopt=gc:manual disable:1"];
