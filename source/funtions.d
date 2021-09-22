module funtions;

version (Windows) {
	version = Desktop;
}
version (linux) {
	version = Desktop;
}
version (OSX) {
	version = Desktop;
}

version (WebAssembly) {
	
}