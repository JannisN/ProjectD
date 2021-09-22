module glfw_vulkan_window;

import glfw3;
import utils;

alias GlfwResult = Result!(uint, GLFW_TRUE);

private uint initCount = 0;

interface GlfwCallback {
	void onWindowResize(int width, int height);
	void onMouseButton(int button, int action, int mods);
	void onWindowClose();
}

// sollte in einem allgemeineren file definitiert werden
struct WindowResizeEvent {
	int width;
	int height;
}

enum MouseButton {
	left,
	right
}

enum MouseButtonAction {
	press,
	release
}

struct MouseButtonEvent {
	MouseButton button;
	MouseButtonAction action;
}

struct WindowCloseEvent {
}

private extern(C) {
	import vulkan_core;
	VkResult glfwCreateWindowSurface(VkInstance, void*, VkAllocationCallbacks*, VkSurfaceKHR*);

	void windowSizeCallback(GLFWwindow* window, int width, int height) {
		if (glfwGetWindowUserPointer(window) != null) {
			GlfwCallback callback = cast(GlfwCallback)glfwGetWindowUserPointer(window);
			callback.onWindowResize(width, height);
		}
	}
	void mouseButtonCallback(GLFWwindow* window, int button, int action, int mods) {
		if (glfwGetWindowUserPointer(window) != null) {
			GlfwCallback callback = cast(GlfwCallback)glfwGetWindowUserPointer(window);
			callback.onMouseButton(button, action, mods);
		}
	}
	void windowCloseCallback(GLFWwindow* window) {
		if (glfwGetWindowUserPointer(window) != null) {
			GlfwCallback callback = cast(GlfwCallback)glfwGetWindowUserPointer(window);
			callback.onWindowClose();
		}
	}
}

struct GlfwVulkanWindow(Sender) {
	import vk : Result, Instance, Surface;
	GLFWwindow* window;
	GlfwResult result;
	Result vkResult;
	Box!(GlfwVulkanWindow!Sender*, GlfwCallback) callbackPtr;
	Sender* sender;
	this(int width, int height, string title) {
		if (initCount == 0) {
			result = glfwInit();
		}
		initCount++;
		glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
		window = glfwCreateWindow(width, height, title.ptr, null, null);
		glfwSetWindowSizeCallback(window, &windowSizeCallback);
		glfwSetMouseButtonCallback(window, &mouseButtonCallback);
		glfwSetWindowCloseCallback(window, &windowCloseCallback);
		//funktioniert bei dmd nicht, da nach dem konstruktor das objekt im speicher verschoben wird -> &this zeigt an falsche stelle
		// zumindest wenn nicht bei deklaration verwendet
		callbackPtr = Box!(GlfwVulkanWindow*, GlfwCallback)(&this);
		// doppel cast notwendig
		glfwSetWindowUserPointer(window, cast(void*)cast(GlfwCallback)callbackPtr.data);
	}
	~this() {
		if (window != null) {
			glfwSetWindowUserPointer(window, null);
			glfwDestroyWindow(window);
			initCount--;
			if (initCount == 0) {
				glfwTerminate();
			}
		}
	}
	void initialize(ref Sender ecs) {
		sender = &ecs;
		if (initCount == 0) {
			result = glfwInit();
		}
		initCount++;
		glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
		window = glfwCreateWindow(800, 800, "bla", null, null);
		glfwSetWindowSizeCallback(window, &windowSizeCallback);
		glfwSetMouseButtonCallback(window, &mouseButtonCallback);
		glfwSetWindowCloseCallback(window, &windowCloseCallback);
		callbackPtr = Box!(GlfwVulkanWindow*, GlfwCallback)(&this);
		// doppel cast notwendig
		glfwSetWindowUserPointer(window, cast(void*)cast(GlfwCallback)callbackPtr.data);

	}
	void update() {
		glfwPollEvents();
	}
	void close() {
		glfwSetWindowUserPointer(window, null);
		glfwDestroyWindow(window);
	}
	bool shouldClose() {
		return cast(bool) glfwWindowShouldClose(window);
	}
	Surface createVulkanSurface(ref Instance instance) {
		VkSurfaceKHR vksurface;
		vkResult = glfwCreateWindowSurface(instance.instance, window, null, &vksurface);
		return instance.createSurface(vksurface);
	}
	const(char*)[] getRequiredExtensions() {
		uint reqcount;
		const(char*)* requiredExtensions = glfwGetRequiredInstanceExtensions(&reqcount);
		return requiredExtensions[0 .. reqcount];
	}
	void onWindowResize(int width, int height) {
		sender.send(WindowResizeEvent(width, height));
	}
	void onMouseButton(int button, int action, int mods) {
		sender.send(MouseButtonEvent(button == GLFW_MOUSE_BUTTON_RIGHT ? MouseButton.right : MouseButton.left, action == GLFW_PRESS ? MouseButtonAction.press : MouseButtonAction.release));
	}
	void onWindowClose() {
		sender.send(WindowCloseEvent());
	}
}
