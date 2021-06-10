module window;

import std.string;

enum WindowState {
	Default,
	Minimized, 
	Maximized,
	Fullscreen
}

interface Window {
	/*uint getWidth();
	uint getHeight();
	string getTitle();
	WindowState getState();*/
}

interface GLWindow : Window {
	version (Windows) {
		@property int* wglContext();
		@property int* wglDC();
	}
	version (OSX) {
		@property void* cglContext();
	}
	version (linux) {
		@property void* glxContext();
		@property void* glxDisplay();
	}
}

interface VulkanWindow {
	void getSurface();
}

struct GlfwVulkanWindow {
	void getSurface() {
		
	}
}