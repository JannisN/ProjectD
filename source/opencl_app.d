module opencl_app;

import opencl;
import utils;
import core.stdcpp.vector;
import std.stdio;
import std.string : StringException;
import std.conv : to;
import window;

// todo: events, error checking, private members: mit properties und private members

private extern(C) cl_mem clCreateFromGLTexture(cl_context, cl_mem_flags, uint, int, uint, int*);
private extern(C) cl_int clEnqueueAcquireGLObjects(cl_command_queue, uint, cl_mem*, uint, cl_event*, cl_event*);
private extern(C) cl_int clEnqueueReleaseGLObjects(cl_command_queue, uint, cl_mem*, uint, cl_event*, cl_event*);

struct Platform {
	cl_platform_id id;
	String name;
	String vendor;
	String versionNumber;
	String profile;
	String extensions;
	Vector!Device devices;
}

struct Device {
	Platform* platform;
	cl_device_id id;
	String name;
	String deviceVersion;
	String driverVersion;
	String oclVersion;
	uint maxComputeUnits;
	uint maxWorkItemDimension;
	size_t maxWorkGroupSize;
	Vector!size_t maxWorkItemSize;
}

struct Context {
	cl_context context;
	this(ref Device device, cl_context_properties[] props) {
		int error;
		context = clCreateContext(props.ptr, 1, &device.id, null, null, &error);
		if (error != 0) {
			throw new StringException("clCreateContext error: " ~ to!string(error));
		}
	}
	this(Device*[] devices, cl_context_properties[] props) {
		Vector!cl_device_id deviceIds = Vector!cl_device_id(devices.length);
		foreach (i; 0 .. devices.length) {
			deviceIds[i] = devices[i].id;
		}
		int error;
		context = clCreateContext(props.ptr, cast(uint) devices.length, deviceIds.data, null, null, &error);
		if (error != 0) {
			throw new StringException("clCreateContext error: " ~ to!string(error));
		}
	}
	this(ref Device device) {
		int error;
		context = clCreateContext(null, 1, &device.id, null, null, &error);
		if (error != 0) {
			throw new StringException("clCreateContext error: " ~ to!string(error));
		}
	}
	this(Device*[] devices) {
		Vector!cl_device_id deviceIds = Vector!cl_device_id(devices.length);
		foreach (i; 0 .. devices.length) {
			deviceIds[i] = devices[i].id;
		}
		int error;
		context = clCreateContext(null, cast(uint) devices.length, deviceIds.data, null, null, &error);
		if (error != 0) {
			throw new StringException("clCreateContext error: " ~ to!string(error));
		}
	}
	this(ref Device device, GLWindow window) {
		version (Windows) {
			cl_context_properties[7] props = [
				CL_CONTEXT_PLATFORM, cast(cl_context_properties) device.platform.id,
				0x2008, cast(cl_context_properties) window.wglContext,
				0x200B, cast(cl_context_properties) window.wglDC,
				0
			];
		}
		version (OSX) {
			cl_context_properties[3] props = [
				0x10000000, cast(cl_context_properties) window.cglContext,
				0
			];
		}
		version (linux) {
			cl_context_properties[7] props = [
				0x2008, cast(cl_context_properties) window.glxContext,
				0x200A, cast(cl_context_properties) window.glxDisplay,
				CL_CONTEXT_PLATFORM, cast(cl_context_properties) device.platform.id,
				0
			];
		}
		this(device, props);
	}
	this(Device*[] devices, GLWindow window) {
		version (Windows) {
			cl_context_properties[7] props = [
				CL_CONTEXT_PLATFORM, cast(cl_context_properties) devices[0].platform.id,
				0x2008, cast(cl_context_properties) window.wglContext,
				0x200B, cast(cl_context_properties) window.wglDC,
				0
			];
		}
		version (OSX) {
			cl_context_properties[3] props = [
				0x10000000, cast(cl_context_properties) window.cglContext,
				0
			];
		}
		version (linux) {
			cl_context_properties[7] props = [
				0x2008, cast(cl_context_properties) window.glxContext,
				0x200A, cast(cl_context_properties) window.glxDisplay,
				CL_CONTEXT_PLATFORM, cast(cl_context_properties) devices[0].platform.id,
				0
			];
		}
		this(devices, props);
	}
	@disable this(ref return scope Context);
	~this() {
		clReleaseContext(context);
	}
}

struct CommandQueue {
	cl_command_queue queue;
	this(ref Context context, ref Device device) {
		queue = clCreateCommandQueue(context.context, device.id, 0, null);
	}
	@disable this(ref return scope CommandQueue);
	~this() {
		clReleaseCommandQueue(queue);
	}
	// hier noch eine optionale wait list hinzufügen: https://www.khronos.org/registry/OpenCL/sdk/1.0/docs/man/xhtml/clEnqueueWriteBuffer.html
	void writeBuffer(T)(ref Buffer buffer, T[] data) {
		int error = clEnqueueWriteBuffer(queue, buffer.memory, true, 0, T.sizeof * data.length, cast(void*) data.ptr, 0, null, null);
		int i;
	}
	// mehr events
	void readBuffer(T)(ref Buffer buffer, T[] data) {
		clEnqueueReadBuffer(queue, buffer.memory, true, 0, T.sizeof * data.length, cast(void*) data.ptr, 0, null, null);
	}
	// mehr events
	void run(ref Kernel kernel, uint dim, size_t[] global, size_t[] local) {
		clEnqueueNDRangeKernel(queue, kernel.kernel, dim, null, global.ptr, local.ptr, 0, null, null);
	}
	void run(ref Kernel kernel, uint dim, size_t[] global) {
		clEnqueueNDRangeKernel(queue, kernel.kernel, dim, null, global.ptr, null, 0, null, null);
	}
	void run(ref Kernel kernel, uint dim, int[] global) {
		size_t[3] g;
		foreach (i; 0 .. dim) {
			g[i] = global[i];
		}
		run(kernel, dim, g);
	}
	void run(ref Kernel kernel, uint dim, int[] global, int[] local) {
		size_t[3] g;
		size_t[3] l;
		foreach (i; 0 .. dim) {
			g[i] = global[i];
			l[i] = local[i];
		}
		run(kernel, dim, g, l);
	}
	void aquireGLObjects(GLBuffer*[] buffer) {
		Vector!cl_mem memory = Vector!cl_mem(buffer.length);
		foreach (i; 0 .. buffer.length) {
			memory[i] = buffer[i].memory;
			buffer[i].aquired = true;
			buffer[i].queue = &this;
		}
		clEnqueueAcquireGLObjects(queue, cast(uint) buffer.length, memory.data, 0, null, null);
	}
	void aquireGLObjects(ref GLBuffer buffer) {
		clEnqueueAcquireGLObjects(queue, 1, &buffer.memory, 0, null, null);
		buffer.aquired = true;
		buffer.queue = &this;
	}
	void releaseGLObjects(GLBuffer*[] buffer) {
		Vector!cl_mem memory = Vector!cl_mem(buffer.length);
		foreach (i; 0 .. buffer.length) {
			memory[i] = buffer[i].memory;
			buffer[i].aquired = false;
		}
		clEnqueueReleaseGLObjects(queue, cast(uint) buffer.length, memory.data, 0, null, null);
	}
	void releaseGLObjects(ref GLBuffer buffer) {
		if (buffer.aquired) {
			clEnqueueReleaseGLObjects(queue, 1, &buffer.memory, 0, null, null);
			buffer.aquired = false;
		}
	}
	void finish() {
		clFinish(queue);
	}
}

struct Program {
	cl_program program;
	this(ref Context context, string source) {
		char* ptr = cast(char*) source.ptr;
		size_t length = source.length;
		program = clCreateProgramWithSource(context.context, 1, &ptr, &length, null);
		clBuildProgram(program, 0, null, null, null, null);
		// hier muss noch das resultat ausgewertet werden, dazu wird aber ein device gebraucht
	}
	this(ref Context context, Device*[] devices, string source) {
		char* ptr = cast(char*) source.ptr;
		size_t length = source.length;
		program = clCreateProgramWithSource(context.context, 1, &ptr, &length, null);

		Vector!cl_device_id deviceIds = Vector!cl_device_id(devices.length);
		foreach (i; 0 .. devices.length) {
			deviceIds[i] = devices[i].id;
		}
		clBuildProgram(program, cast(uint) devices.length, deviceIds.data, null, null, null);
		
		foreach (i; 0 .. devices.length) {
			size_t size;
			clGetProgramBuildInfo(program, deviceIds[i], CL_PROGRAM_BUILD_LOG, 0, null, &size);
			String log;
			log.resize(size);
			clGetProgramBuildInfo(program, deviceIds[i], CL_PROGRAM_BUILD_LOG, size, log.ptr, null);
			writeln(log.s);
		}
	}
	this(ref Context context, ref Device device, string source) {
		this(context, array(&device), source);
	}
	@disable this(ref return scope Program);
	~this() {
		clReleaseProgram(program);
	}
}

struct Kernel {
	cl_kernel kernel;
	this(ref Program program, string name) {
		kernel = clCreateKernel(program.program, name.ptr, null);
	}
	@disable this(ref return scope Kernel);
	~this() {
		clReleaseKernel(kernel);
	}
	void setArg(uint arg, ref Buffer buffer) {
		clSetKernelArg(kernel, arg, cl_mem.sizeof, &buffer.memory);
	}
	void setArg(uint arg, ref GLBuffer buffer) {
		clSetKernelArg(kernel, arg, cl_mem.sizeof, &buffer.memory);
	}
	void setArg(T)(uint arg, T* t) {
		int error = clSetKernelArg(kernel, arg, T.sizeof, t);
		int i;
	}
}

struct Buffer {
	cl_mem memory;
	this(ref Context context, cl_mem_flags flags, size_t size) {
		int error;
		memory = clCreateBuffer(context.context, flags, size, null, &error);
		int i;
	}
	@disable this(ref return scope Buffer);
	~this() {
		clReleaseMemObject(memory);
	}
}

struct GLBuffer {
	cl_mem memory;
	bool aquired = false;
	CommandQueue* queue;
	this(ref Context context, cl_mem_flags flags, uint texture) {
		memory = clCreateFromGLTexture(context.context, flags, 0x0DE1, 0, texture, null);
	}
	@disable this(ref return scope Buffer);
	~this() {
		if (aquired) {
			queue.releaseGLObjects(this);
		}
		clReleaseMemObject(memory);
	}
}

struct OpenCLInstance {
	Vector!Platform platforms;
	static OpenCLInstance opCall() {
		OpenCLInstance instance;
		uint n;
		int error;
		error = clGetPlatformIDs(0, null, &n);
		instance.platforms = Vector!Platform(n);
		Vector!cl_platform_id platformIds = Vector!cl_platform_id(n);
		error = clGetPlatformIDs(n, platformIds.data, null);
		foreach (i; 0 .. n) {
			instance.platforms[i].id = platformIds[i];
			ulong size;
			clGetPlatformInfo(instance.platforms[i].id, CL_PLATFORM_NAME, 0, null, &size);
			instance.platforms[i].name.resize(size);
			clGetPlatformInfo(instance.platforms[i].id, CL_PLATFORM_NAME, size, instance.platforms[i].name.s.ptr, null);
			clGetPlatformInfo(instance.platforms[i].id, CL_PLATFORM_VENDOR, 0, null, &size);
			instance.platforms[i].vendor.resize(size);
			clGetPlatformInfo(instance.platforms[i].id, CL_PLATFORM_VENDOR, size, instance.platforms[i].vendor.s.ptr, null);
			clGetPlatformInfo(instance.platforms[i].id, CL_PLATFORM_VERSION, 0, null, &size);
			instance.platforms[i].versionNumber.resize(size);
			clGetPlatformInfo(instance.platforms[i].id, CL_PLATFORM_VERSION, size, instance.platforms[i].versionNumber.s.ptr, null);
			clGetPlatformInfo(instance.platforms[i].id, CL_PLATFORM_PROFILE, 0, null, &size);
			instance.platforms[i].profile.resize(size);
			clGetPlatformInfo(instance.platforms[i].id, CL_PLATFORM_PROFILE, size, instance.platforms[i].profile.s.ptr, null);
			clGetPlatformInfo(instance.platforms[i].id, CL_PLATFORM_EXTENSIONS, 0, null, &size);
			instance.platforms[i].extensions.resize(size);
			clGetPlatformInfo(instance.platforms[i].id, CL_PLATFORM_EXTENSIONS, size, instance.platforms[i].extensions.s.ptr, null);

			writeln(instance.platforms[i].name.s);
			writeln(instance.platforms[i].vendor.s);
			writeln(instance.platforms[i].versionNumber.s);
			writeln(instance.platforms[i].profile.s);
			writeln(instance.platforms[i].extensions.s);

			clGetDeviceIDs(instance.platforms[i].id, CL_DEVICE_TYPE_GPU, 0, null, &n);
			instance.platforms[i].devices = Vector!Device(n);
			Vector!cl_device_id deviceIds = Vector!cl_device_id(n);
			clGetDeviceIDs(instance.platforms[i].id, CL_DEVICE_TYPE_GPU, n, deviceIds.data, null);
			foreach (j; 0 .. deviceIds.size) {
				instance.platforms[i].devices[j].platform = &instance.platforms[i];
				instance.platforms[i].devices[j].id = deviceIds[j];
				clGetDeviceInfo(instance.platforms[i].devices[j].id, CL_DEVICE_NAME, 0, null, &size);
				instance.platforms[i].devices[j].name.resize(size);
				clGetDeviceInfo(instance.platforms[i].devices[j].id, CL_DEVICE_NAME, size, instance.platforms[i].devices[j].name.s.ptr, null);
				clGetDeviceInfo(instance.platforms[i].devices[j].id, CL_DEVICE_VERSION, 0, null, &size);
				instance.platforms[i].devices[j].deviceVersion.resize(size);
				clGetDeviceInfo(instance.platforms[i].devices[j].id, CL_DEVICE_VERSION, size, instance.platforms[i].devices[j].deviceVersion.s.ptr, null);
				clGetDeviceInfo(instance.platforms[i].devices[j].id, CL_DRIVER_VERSION, 0, null, &size);
				instance.platforms[i].devices[j].driverVersion.resize(size);
				clGetDeviceInfo(instance.platforms[i].devices[j].id, CL_DRIVER_VERSION, size, instance.platforms[i].devices[j].driverVersion.s.ptr, null);
				clGetDeviceInfo(instance.platforms[i].devices[j].id, CL_DEVICE_OPENCL_C_VERSION, 0, null, &size);
				instance.platforms[i].devices[j].oclVersion.resize(size);
				clGetDeviceInfo(instance.platforms[i].devices[j].id, CL_DEVICE_OPENCL_C_VERSION, size, instance.platforms[i].devices[j].oclVersion.s.ptr, null);
				clGetDeviceInfo(instance.platforms[i].devices[j].id, CL_DEVICE_MAX_COMPUTE_UNITS, uint.sizeof, &instance.platforms[i].devices[j].maxComputeUnits, null);
				clGetDeviceInfo(instance.platforms[i].devices[j].id, CL_DEVICE_MAX_WORK_ITEM_DIMENSIONS, uint.sizeof, &instance.platforms[i].devices[j].maxWorkItemDimension, null);
				clGetDeviceInfo(instance.platforms[i].devices[j].id, CL_DEVICE_MAX_WORK_GROUP_SIZE, size_t.sizeof, &instance.platforms[i].devices[j].maxWorkGroupSize, null);
				clGetDeviceInfo(instance.platforms[i].devices[j].id, CL_DEVICE_MAX_WORK_ITEM_SIZES, 0, null, &size);
				instance.platforms[i].devices[j].maxWorkItemSize.resize(size / size_t.sizeof);
				clGetDeviceInfo(instance.platforms[i].devices[j].id, CL_DEVICE_MAX_WORK_ITEM_SIZES, size, instance.platforms[i].devices[j].maxWorkItemSize.data, null);

				writeln(instance.platforms[i].devices[j].name.s);
				writeln(instance.platforms[i].devices[j].deviceVersion.s);
				writeln(instance.platforms[i].devices[j].driverVersion.s);
				writeln(instance.platforms[i].devices[j].oclVersion.s);
				writeln(instance.platforms[i].devices[j].maxComputeUnits);
				writeln(instance.platforms[i].devices[j].maxWorkItemDimension);
				writeln(instance.platforms[i].devices[j].maxWorkGroupSize);
				foreach (k; 0 .. instance.platforms[i].devices[j].maxWorkItemSize.size) {
					writeln(instance.platforms[i].devices[j].maxWorkItemSize[k]);
				}
			}
		}
		return instance;
	}
}
