import std.stdio;
import glfw_window;
import core.stdc.stdio;
import core.thread;
import std.conv : emplace;
import std.datetime;
import std.datetime.stopwatch : benchmark, StopWatch;

import utils;
import tensor;
import opencl_app;

string source = import("pathtrace.cl");

void main1()
{
	auto window = new GLFWWindow();
	window.open();
	{
		import opencl;
		auto instance = OpenCLInstance();
		auto context = Context(instance.platforms[0].devices[0], window);
		auto queue = CommandQueue(context, instance.platforms[0].devices[0]);
		auto program = Program(context, instance.platforms[0].devices[0], source);
		auto kernel = Kernel(program, "Draw");
		auto buffer = GLBuffer(context, CL_MEM_WRITE_ONLY, window.texture);
		float t = 0;
		queue.aquireGLObjects(buffer);
		kernel.setArg(0, buffer);
		kernel.setArg(1, &t);
		kernel.setArg(2, &window.width);
		kernel.setArg(3, &window.height);
		writeln(window.width, window.height);
		queue.run(kernel, 3, array(window.width, window.height, 1));
		queue.finish();
		//queue.releaseGLObjects(buffer);
		
		while (window.isOpen()) {
			t += 0.01;
			window.update();
			if (window.provUpdate) {
				window.provUpdate = false;

				//queue.releaseGLObjects(buffer);
				buffer.destroy();
				buffer = GLBuffer(context, CL_MEM_WRITE_ONLY, window.texture);
				queue.aquireGLObjects(buffer);

				kernel.setArg(0, buffer);

				//writeln("update");
			}
			kernel.setArg(1, &t);
			kernel.setArg(2, &window.width);
			kernel.setArg(3, &window.height);
			queue.run(kernel, 3, array(window.width, window.height, 1));
			queue.finish();
		}
		//queue.releaseGLObjects(buffer);
	}
}
