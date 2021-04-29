module glfw_vulkan_window;

import glfw3;
import utils;

alias GlfwResult = Result!(uint, GLFW_TRUE);

private uint initCount = 0;

private interface GlfwCallback {
    void onWindowResize(int width, int height);
}

private extern(C) void windowSizeCallback(GLFWwindow* window, int width, int height) {
    if (glfwGetWindowUserPointer(window) != null) {
        GlfwCallback callback = cast(GlfwCallback)glfwGetWindowUserPointer(window);
        callback.onWindowResize(width, height);
    }
}

// sollte in einem allgemeineren file definitiert werden
struct WindowResizeEvent {
    int width;
    int height;
}

// hier funktion um einfachere window erstellung mit sender

struct GlfwVulkanWindow(Sender) {
    GLFWwindow* window;
    GlfwResult result;
    S!(InterfaceAdapterPointer!(GlfwCallback, GlfwVulkanWindow)) callbackPtr;
    Sender sender;
    this(int width, int height, string title) {
        if (initCount == 0) {
            result = glfwInit();
        }
        initCount++;
        glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
        window = glfwCreateWindow(width, height, title.ptr, null, null);
        glfwSetWindowSizeCallback(window, &windowSizeCallback);
        callbackPtr = S!(InterfaceAdapterPointer!(GlfwCallback, GlfwVulkanWindow))(&this);
        glfwSetWindowUserPointer(window, cast(void*)callbackPtr.toInterface());
    }
    ~this() {
        glfwSetWindowUserPointer(window, null);
        glfwDestroyWindow(window);
        initCount--;
        if (initCount == 0) {
            glfwTerminate();
        }
    }
    void update() {
        glfwPollEvents();
    }
    void close() {
        glfwSetWindowUserPointer(window, null);
        glfwDestroyWindow(window);
    }
    void onWindowResize(int width, int height) {
        sender.send(WindowResizeEvent(width, height));
    }
}