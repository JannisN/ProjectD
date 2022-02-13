from sys import platform
import os

if platform == "darwin":
	os.system('mkdir extern/build')
	os.system('cp extern/stb/stb_image.h extern/build/stb_image.c')
	os.system('clang -D STB_IMAGE_IMPLEMENTATION -c -o extern/build/stb.o extern/build/stb_image.c')
	os.system('ar rcs extern/build/stb.a extern/build/stb.o')
	os.system('cmake -S extern/glfw -B extern/glfw/build -D BUILD_SHARED_LIBS=OFF')
	os.system('cmake --build extern/glfw/build')

if platform == "win32":
	vulkanLib = input("Vulkan Lib:")
	glfwLib = input("Glfw Lib:")
	openclLib = input("OpenCL Lib:")
	cLib = input("C Lib directory:")
	stbimage = input("stb_image Lib:")

if platform == "darwin":
	vulkanLib = input("Vulkan SDK:")
	glfwLib = 'extern/glfw/build/src/libglfw3.a'
	stbimage = 'extern/build/stb.a'

if platform == "linux":
	vulkanLib = input("Vulkan Lib:")
	glfwLib = 'extern/glfw/build/src/libglfw3.a'
	stbimage = 'extern/build/stb.a'

#C://Users/Admin/Desktop/dlang/dubtest/lib/vulkan-1.lib
#C://Users/Admin/Desktop/dlang/dubtest/lib/glfw.lib
#C://Program Files/NVIDIA GPU Computing Toolkit/CUDA/v10.1/lib/x64/OpenCL.lib
#C://Program Files (x86)/Windows Kits/10/Lib/10.0.17763.0/um/x64

#/Users/Shared/Relocated Items/Security/Repositories/dlib/lib/libglfw3.a
#/Users/jannis/Desktop/vulkansdk

import codecs
with codecs.open("dub.sdl", "x", encoding='utf8') as f:
	f.write('name "projectd"\n')
	f.write('description "A minimal D application."\n')
	f.write('authors "Admin"\n')
	f.write('copyright "Copyright 2021, Admin"\n')
	f.write('license "proprietary"\n')
	f.write('\n')
	f.write('dflags "-preview=in"\n')
	f.write('buildRequirements "allowWarnings"\n')
	f.write('stringImportPaths "views"\n')
	f.write('\n')
	if platform == "win32":
		#f.write('lflags "' + vulkanLib + '" "' + glfwLib + '" "/NODEFAULTLIB:libvcruntime.lib" "/NODEFAULTLIB:libcmt.lib" platform="windows"\n')
		f.write('lflags ')
		#f.write('"' + cLib + '/msvcrt.lib" ')
		f.write('"' + cLib + '/opengl32.lib" ')
		#f.write('"' + cLib + '/kernel32.lib" ')
		f.write('"' + cLib + '/user32.lib" ')
		f.write('"' + cLib + '/gdi32.lib" ')
		#f.write('"' + cLib + '/winspool.lib" ')
		#f.write('"' + cLib + '/shell32.lib" ')
		#f.write('"' + cLib + '/ole32.lib" ')
		#f.write('"' + cLib + '/oleaut32.lib" ')
		#f.write('"' + cLib + '/uuid.lib" ')
		#f.write('"' + cLib + '/comdlg32.lib" ')
		#f.write('"' + cLib + '/advapi32.lib" ')
		f.write('"' + vulkanLib + '"' + stbimage + '" "' + glfwLib + '" "' + openclLib + '" "/NODEFAULTLIB:libvcruntime.lib" "/NODEFAULTLIB:libcmt.lib" platform="windows"\n')
	if platform == "darwin":
		f.write('lflags ')
		#f.write('"' + vulkanLib + '/vulkan.framework" ')
		f.write('"' + glfwLib + '" ')
		f.write('"' + stbimage + '" ')
		f.write('"/System/Library/Frameworks/OpenGL.framework/OpenGL" ')
		f.write('"/System/Library/Frameworks/OpenCL.framework/OpenCL" ')
		f.write('"/System/Library/Frameworks/Cocoa.framework/Cocoa" ')
		f.write('"/System/Library/Frameworks/IOKit.framework/IOKIt" ')
		f.write('"/System/Library/Frameworks/Metal.framework/Metal" ')
		f.write('"/System/Library/Frameworks/QuartzCore.framework/QuartzCore" ')
		f.write('"/System/Library/Frameworks/IOSurface.framework/IOSurface" ')
		f.write('"/System/Library/Frameworks/Quartz.framework/Quartz" ')
		f.write('"/' + vulkanLib + '/macOS/lib/libvulkan.dylib" ')
		f.write('"-L//' + vulkanLib + '/macOS/Frameworks/vulkan.framework" ')
		f.write('"-rpath" "/' + vulkanLib + '/macOS/Frameworks" ')
		f.write('platform="osx"\n')
		f.write('libs "stdc++" platform="osx"')
	if platform == "linux":
		f.write('lflags ')
		f.write('"' + glfwLib + '" ')
		f.write('"/' + vulkanLib + '" ')
		f.write('"' + stbimage + '" ')
		f.write('"/usr/lib/libOpenCL.so" platform="linux"\n')
		f.write('libs "GL" "X11" platform="linux"\n')
	f.close()