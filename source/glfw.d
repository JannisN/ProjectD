module glfw;

extern(C) {
	bool glfwInit();
	void glfwTerminate();
	void* glfwCreateWindow(int, int, const char*, void*, void*);
	void glfwMakeContextCurrent(void*);
	bool glfwWindowShouldClose(void*);
	void glfwPollEvents();
	void glfwSwapBuffers(void*);
	void glfwGetFramebufferSize(void*, int*, int*);
	void glfwSetFramebufferSizeCallback(void*, void function(void*, int, int));
}

extern(C) {
	version(Windows) {
		int* wglGetCurrentContext();
		int* wglGetCurrentDC();
		//void* glfwGetWin32Window(void*);
	}
	version (OSX) {
		void* CGLGetShareGroup(void*);
		void* CGLGetCurrentContext();
	}
	version (linux) {
		void* glXGetCurrentContext();
		void* glXGetCurrentDisplay();
	}
	import vulkan_core;
	VkResult glfwCreateWindowSurface(VkInstance, void*, VkAllocationCallbacks*, VkSurfaceKHR*);
	char** glfwGetRequiredInstanceExtensions(uint*);
	void glfwWindowHint(int, int);
	void glfwSetWindowAttrib(void*, int, int);
}

extern(C) {
	void glClear(uint);
	void glBegin(uint);
	void glEnd();
	void glVertex3f(float, float, float);
	void glEnable(uint);
	void glDisable(uint);
	void glGenTextures(int, uint*);
	void glBindTexture(uint, uint);
	void glTexParameteri(uint, uint, int);
	void glTexImage2D(uint, int, int, int, int, int, uint, uint, void*);
	void glTexCoord2i(int, int);
	uint glGetError();
	void glFinish();
	void glViewport(int, int, int, int);
	void glDeleteTextures(int, uint*);
}
