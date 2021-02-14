vulkanLib = input("Vulkan Lib:")
glfwLib = input("Glfw Lib:")

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
	f.write('lflags "' + vulkanLib + '" "' + glfwLib + '" platform="windows"\n')
	f.close()