module glfw_vulkan_window;

import glfw3;
import utils;

alias GlfwResult = Result!(uint, GLFW_TRUE);

private uint initCount = 0;

struct GlfwVulkanWindow {
    GLFWwindow* window;
    GlfwResult result;
    this(int width, int height, string title) {
        if (initCount == 0) {
            result = glfwInit();
        }
        initCount++;
        glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
        window = glfwCreateWindow(width, height, title.ptr, null, null);
    }
    ~this() {
        initCount--;
        if (initCount == 0) {
            glfwTerminate();
        }
    }
    void update() {
        glfwPollEvents();
        //sender hinzufügen für Events, wenn möglich keine callbacks verwenden
    }
}