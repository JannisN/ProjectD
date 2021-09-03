module ecs;

alias DefaultDataStructure(T) = T[1];

struct Info(Args...) {
	alias Type = Args[0];
	alias DataStructure = Args[1];
	alias CompatibleTypes = Args[2 .. Args.length];
	DataStructure!Type instance;
}

// static erstmal nur als Test
struct StaticECS(Args...) {
	enum int staticComponents = Args.length;
}