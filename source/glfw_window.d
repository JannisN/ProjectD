module glfw_window;

import glfw;
import glfw3;
import core.thread.osthread;
import utils;
import std.stdio;
import window;

private uint initCount = 0;
private Vector!(void*) v1 = Vector!(void*)(1);
private Vector!(void delegate(int, int)) v2 = Vector!(void delegate(int, int))(1);

class GLFWWindow : GLWindow {
	private void* window;
	private shared bool running = false;
	uint texture;
	int width, height;
	bool provUpdate = false;
	~this() {
		// hier noch einträge aus v1. v2 entfernen
		glDeleteTextures(1, &texture);
		initCount--;
		if (initCount == 0) {
			glfwTerminate();
		}
	}
	version(Windows) {
		shared int* wglContextVar;
		shared int* wglDCVar;
		@property int* wglContext() {
			return cast(int*) wglContextVar;
		}
		@property int* wglDC() {
			return cast(int*) wglDCVar;
		}
	}
	version (OSX) {
		shared void* cglContextVar;
		@property void* cglContext() {
			return cast(int*) cglContextVar;
		}
	}
	version (linux) {
		void* glxContextVar;
		void* glxDisplayVar;
		@property void* glxContext() {
			return glxContextVar;
		}
		@property void* glxDisplay() {
			return glxDisplayVar;
		}
	}
	void open() {
		if (initCount == 0) {
			glfwInit();
		}
		initCount++;
		start();
	}
	bool isOpen() {
		return running;
	}
	void waitForCreation() {
		while (!running) {}
	}
	void aquireContext() {
		glfwMakeContextCurrent(cast(GLFWwindow*) window);
	}
	void releaseContext() {
		glfwMakeContextCurrent(null);
	}
	private void start() {
		window = glfwCreateWindow(640, 480, "Hello", null, null);
		glfwMakeContextCurrent(cast(GLFWwindow*) window);
		glfwGetFramebufferSize(cast(GLFWwindow*) window, &width, &height);
		glfwSetFramebufferSizeCallback(cast(GLFWwindow*) window, &setFramebufferSizeCallback);
		v1[0] = window;
		v2[0] = &test;
		version(Windows) {
			wglContextVar = cast(shared) wglGetCurrentContext();
			wglDCVar = cast(shared) wglGetCurrentDC();
			writeln(wglContextVar);
			writeln(wglDCVar);
		}
		version (OSX) {
			cglContextVar = cast(shared) CGLGetShareGroup(CGLGetCurrentContext());
		}
		version (linux) {
			glxContextVar = glXGetCurrentContext();
			glxDisplayVar = glXGetCurrentDisplay();
		}
		glEnable(0x0DE1);
		glGenTextures(1, &texture);
		glBindTexture(0x0DE1, texture);
		glTexParameteri(0x0DE1, 0x2800, 0x2601);
		glTexParameteri(0x0DE1, 0x2801, 0x2601);
		glTexImage2D(0x0DE1, 0, 0x8058, width, height, 0, 0x1908, 0x1401, null);
		running = true;
	}
	void update() {
		//glfwGetFramebufferSize(window, &width, &height);
		//glViewport(0, 0, width, height);

		glClear(0x00004000);
		
		glEnable(0x0DE1);
		glBindTexture(0x0DE1, texture);
		
		glBegin(0x0007);
		glTexCoord2i(0, 1);
		glVertex3f(-1f, 1f, 0.0f);
		glTexCoord2i(1, 1);
		glVertex3f(1f, 1f, 0.0f);
		glTexCoord2i(1, 0);
		glVertex3f(1f, -1f, 0.0f);
		glTexCoord2i(0, 0);
		glVertex3f(-1f, -1f, 0.0f);
		glEnd();
		glFinish();
		glfwSwapBuffers(cast(GLFWwindow*) window);
		glfwPollEvents();

		if (glfwWindowShouldClose(cast(GLFWwindow*) window)) {
			running = false;
		}
	}
	private void test(int w, int h) {
		glViewport(0, 0, w, h);
		width = w;
		height = h;

		glDeleteTextures(1, &texture);
		glGenTextures(1, &texture);
		glBindTexture(0x0DE1, texture);
		glTexParameteri(0x0DE1, 0x2800, 0x2601);
		glTexParameteri(0x0DE1, 0x2801, 0x2601);
		glTexImage2D(0x0DE1, 0, 0x8058, width, height, 0, 0x1908, 0x1401, null);

		provUpdate = true;
	}
}

extern(C) private void setFramebufferSizeCallback(void* window, int w, int h) {
	foreach (i; 0 .. v1.size) {
		if (v1[i] == window) {
			v2[i](w, h);
		}
	}
}
