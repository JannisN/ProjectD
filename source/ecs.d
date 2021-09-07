module ecs;

import utils;

alias DefaultDataStructure(T) = T[1];

struct Info(Args...) {
	alias Type = Args[0];
	alias DataStructure = Args[1];
	alias CompatibleTypes = Args[2 .. Args.length];
}

/*template GetTypesFromInfo(ECS, Info) {
	static if (__traits(compiles, Info.Type!ECS())) {
		alias GetTypesFromInfo = Info.Type!ECS;
	} else {
		alias GetTypesFromInfo = Info.Type;
	}
}
template TypesFromInfo(ECS) {
	alias TypesFromInfo(Info) = GetTypesFromInfo!(ECS, Info);
}

template GetTypeDataStructureFromInfo(ECS, Info) {
	static if (__traits(compiles, Info.DataStructure!(Info.Type!ECS))) {
		alias GetTypeDataStructureFromInfo = Info.DataStructure!(Info.Type!ECS);
	} else {
		alias GetTypeDataStructureFromInfo = Info.DataStructure!(Info.Type);
	}
}
template TypeDataStructureFromInfo(ECS) {
	alias TypeDataStructureFromInfo(Info) = GetTypeDataStructureFromInfo!(ECS, Info);
}*/

template GetTypeIfString(alias T) {
	static if (is(typeof(T) == string)) {
		alias GetTypeIfString = T;
	} else {
		alias GetTypeIfString = TypeSeq!();
	}
}
template GetTypeIfNotString(alias T) {
	static if (is(typeof(T) == string)) {
		alias GetTypeIfNotString = TypeSeq!();
	} else {
		alias GetTypeIfNotString = T;
	}
}

template StringSeq(Info) {
	enum string[] StringSeq = [ApplyTypeSeq!(GetTypeIfString, Info.CompatibleTypes)];
}

alias GetCompatibleTypesFromInfo(Info) = TypeSeqStruct!(ApplyTypeSeq!(GetTypeIfNotString, Info.CompatibleTypes));

template FindMatchingTypes(U, size_t index, Args...) {
	static if (Args.length == 0) {
		alias FindMatchingTypes = TypeSeq!();
	} else {
		static if (is(Args[0] == U)) {
			alias FindMatchingTypes = TypeSeq!(index, FindMatchingTypes!(U, index + 1, Args[1 .. Args.length]));
		} else {
			alias FindMatchingTypes = FindMatchingTypes!(U, index + 1, Args[1 .. Args.length]);
		}
	}
}

template FindCompatibleTypes(U, size_t index, Args...) {
	static if (Args.length == 0) {
		alias FindCompatibleTypes = TypeSeq!();
	} else {
		static if (findTypes!(U, Args[0].TypeSeq).length > 0) {
			alias FindCompatibleTypes = TypeSeq!(index, FindCompatibleTypes!(U, index + 1, Args[1 .. Args.length]));
		} else {
			alias FindCompatibleTypes = FindCompatibleTypes!(U, index + 1, Args[1 .. Args.length]);
		}
	}
}

struct StaticECS(Args...) {
	template GetTypesFromInfo(Info) {
		static if (__traits(compiles, Info.Type!(StaticECS!Args)())) {
			alias GetTypesFromInfo = Info.Type!(StaticECS!Args);
		} else {
			alias GetTypesFromInfo = Info.Type;
		}
	}
	template GetTypeDataStructureFromInfo(Info) {
		static if (__traits(compiles, Info.DataStructure!(Info.Type!(StaticECS!Args)))) {
			alias GetTypeDataStructureFromInfo = Info.DataStructure!(Info.Type!(StaticECS!Args));
		} else {
			alias GetTypeDataStructureFromInfo = Info.DataStructure!(Info.Type);
		}
	}
	enum int entitiesCount = Args.length;
	alias Types = ApplyTypeSeq!(GetTypesFromInfo, Args);
	alias CompatibleTypes = ApplyTypeSeq!(GetCompatibleTypesFromInfo, Args);
	enum string[][] tags = [ApplyTypeSeq!(StringSeq, Args)];

	ApplyTypeSeq!(GetTypeDataStructureFromInfo, Args) entities;
	
	alias findStaticTypes(T) = FindMatchingTypes!(T, 0, Types);
	alias findStaticCompatibleTypes(T) = FindCompatibleTypes!(T, 0, CompatibleTypes);
	void apply(alias Func)() {
		static foreach(ref e; entities) {
			foreach (ref i; e) {
				i = Func(i);
			}
		}
	}
	void applyTo(T, alias Func)() {
		static foreach(e; findStaticTypes!(T)) {
			foreach (ref i; entities[e]) {
				i = Func(i);
			}
		}
	}
	void applyToCompatible(T, alias Func)() {
		static foreach(e; TypeSeq!(findStaticTypes!(T), findStaticCompatibleTypes!(T))) {
			foreach (ref i; entities[e]) {
				i = Func(i);
			}
		}
	}

	void send(Event)(Event event) {
		static foreach (i; 0 .. Args.length) {
			static if (__traits(compiles, entities[i].receive(event))) {
				entities[i].receive(event);
				foreach (ref i; e) {
					i.receive(event);
				}
			}
		}
	}
	void sendEventTo(T, Event)(Event event) {
		static foreach(e; findStaticTypes!(T)) {
			static if (__traits(compiles, e[0].receive(event))) {
				foreach (ref i; entities[e]) {
					i.receive(event);
				}
			}
		}
	}
	void sendEventToCompatible(T, Event)(Event event) {
		static foreach(e; TypeSeq!(findStaticTypes!(T), findStaticCompatibleTypes!(T))) {
			static if (__traits(compiles, e[0].receive(event))) {
				foreach (ref i; entities[e]) {
					i.receive(event);
				}
			}
		}
	}
}