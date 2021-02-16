vulkanLib = input("Vulkan Lib:")
glfwLib = input("Glfw Lib:")
openclLib = input("OpenCL Lib:")
cLib = input("C Lib directory:")

#C://Users/Admin/Desktop/dlang/dubtest/lib/vulkan-1.lib
#C://Users/Admin/Desktop/dlang/dubtest/lib/glfw.lib
#C://Program Files/NVIDIA GPU Computing Toolkit/CUDA/v10.1/lib/x64/OpenCL.lib
#C://Program Files (x86)/Windows Kits/10/Lib/10.0.17763.0/um/x64

import codecs
with codecs.open("dub.sdl", "x", encoding='utf8') as f:
	f.write('name "projectd"\n')
	f.write('description "A minimal D application."\n')
	f.write('authors "Admin"\n')
	f.write('copyright "Copyright © 2021, Admin"\n')
	f.write('license "proprietary"\n')
	f.write('\n')
	f.write('dflags "-preview=in"\n')
	f.write('buildRequirements "allowWarnings"\n')
	f.write('stringImportPaths "views"\n')
	f.write('\n')
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
	f.write('"' + vulkanLib + '" "' + glfwLib + '" "' + openclLib + '" "/NODEFAULTLIB:libvcruntime.lib" "/NODEFAULTLIB:libcmt.lib" platform="windows"\n')
	f.close()