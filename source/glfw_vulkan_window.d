module glfw_vulkan_window;

import glfw3;

private uint initCount = 0;

struct GlfwVulkanWindow {
    GLFWwindow* window;
    this(int width, int height, string title) {
        if (initCount == 0) {
            glfwInit();
        }
        initCount++;
        window = glfwCreateWindow(width, height, title.ptr, null, null);
        glfwMakeContextCurrent(window);
    }
    ~this() {
        initCount--;
        if (initCount == 0) {
            glfwTerminate();
        }
    }
}