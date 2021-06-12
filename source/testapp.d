import vk;
import glfw_vulkan_window;
import glfw3;
import events;
import utils;
import vulkan_core;
import std.stdio;

struct TestApp {
	void run() {
		initVulkan();
		// komisch: wenn man den code der initWindow funktion direkt hineinschreibt gibt es keine fehler wegem dem callback...
		// problem geösst: man darf klassen nicht verschieben, also auch keine S! klasse...
		initWindow();
		while (!window.shouldClose()) {
			window.update();
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
	}
	GlfwVulkanWindow!(Sender!(TestApp*)) window;
	Instance instance;
	Device device;
	CommandPool cmdPool;
	CommandBuffer cmdBuffer;
	MemoryAllocator memoryAllocator;
	Queue* queue;
}

void main() {
	TestApp testapp;
	testapp.run();
}

extern(C) __gshared bool rt_cmdline_enabled = false;
extern(C) __gshared string[] rt_options = ["gcopt=gc:manual disable:1"];