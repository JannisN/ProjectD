module functions;

version (Windows) {
	version = Desktop;
}
version (linux) {
	version = Desktop;
}
version (OSX) {
	version = Desktop;
}

version (Desktop) {
	public import std.conv : emplace;
	public import std.conv : to;
	public import core.stdc.stdlib : malloc, free, realloc;
	public import core.stdc.string : memcpy, strcmp;
	public import std.traits : Unqual;
	public import std.traits : ReturnType, Parameters;
	public import std.stdio : writeln;
	long ticks() {
		import core.time;
		return MonoTime.currTime().ticks();
	}
	long ticksPerSecond() {
		import core.time;
		return MonoTime().ticksPerSecond();
	}
}

version (WebAssembly) {
	
}