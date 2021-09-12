module ecs;

import utils;

alias DefaultDataStructure(T) = T[1];

struct Info(Args...) {
	alias Type = Args[0];
	alias DataStructure = Args[1];
	alias CompatibleTypes = Args[2 .. Args.length];
}

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

// könnte man statt U alias U nötig haben in gewissen situationen?`
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

template CheckIfAllTypesContained(TS, Args...) {
	bool impl(TS, Args...)() {
		bool found = false;
		static foreach (E; TS.TypeSeq) {
			found = false;
			static foreach (F; Args) {
				static if (is(F == E)) {
					found = true;
				}
			}
			if (found == false) {
				return false;
			}
		}
		return true;
	}
	enum bool CheckIfAllTypesContained = impl!(TS, Args);
}

template FindCompatibleTypesMultiple(U, size_t index, Args...) {
	static if (Args.length == 0) {
		alias FindCompatibleTypesMultiple = TypeSeq!();
	} else {
		static if (CheckIfAllTypesContained!(U, Args[0].TypeSeq)) {
			alias FindCompatibleTypesMultiple = TypeSeq!(index, FindCompatibleTypesMultiple!(U, index + 1, Args[1 .. Args.length]));
		} else {
			alias FindCompatibleTypesMultiple = FindCompatibleTypesMultiple!(U, index + 1, Args[1 .. Args.length]);
		}
	}
}

template CheckIfAllTypesContainedWithType(ECS, TS, MainType, Args...) {
	bool impl() {
		bool found = false;
		static foreach (E; TS.TypeSeq) {
			found = false;
			static foreach (F; Args) {
				static if (is(F == E)) {
					found = true;
				}
			}
			static if (is(MainType!ECS == E!ECS)) {
				found = true;
			}
			static if (is(MainType == E)) {
				found = true;
			}
			if (found == false) {
				return false;
			}
		}
		return true;
	}
	enum bool CheckIfAllTypesContainedWithType = impl();
}

template FindCompatibleTypesMultipleWithType(ECS, TS, size_t index, MainTypes, Args...) {
	static if (Args.length == 0) {
		alias FindCompatibleTypesMultipleWithType = TypeSeq!();
	} else {
		static if (CheckIfAllTypesContainedWithType!(ECS, TS, MainTypes.TypeSeq[0], Args[0].TypeSeq)) {
			alias FindCompatibleTypesMultipleWithType = TypeSeq!(index, FindCompatibleTypesMultipleWithType!(ECS, TS, index + 1, TypeSeqStruct!(MainTypes.TypeSeq[1 .. Args.length]), Args[1 .. Args.length]));
		} else {
			alias FindCompatibleTypesMultipleWithType = FindCompatibleTypesMultipleWithType!(ECS, TS, index + 1, TypeSeqStruct!(MainTypes.TypeSeq[1 .. Args.length]), Args[1 .. Args.length]);
		}
	}
}

template ExtractInterfaces(T) {
	static if (is(T.TypeSeq[0] == interface)) {
		alias ExtractInterfaces = T.TypeSeq[0];
	} else {
		alias ExtractInterfaces = TypeSeq!();
	}
}

struct StaticView(Args...) {
	Args args;
	alias args this;
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
	template GetTypesWithoutArgsFromInfo(Info) {
		alias GetTypesWithoutArgsFromInfo = Info.Type;
	}
	enum int entitiesCount = Args.length;
	alias RawTypes = ApplyTypeSeq!(GetTypesWithoutArgsFromInfo, Args);
	alias Types = ApplyTypeSeq!(GetTypesFromInfo, Args);
	alias CompatibleTypes = ApplyTypeSeq!(GetCompatibleTypesFromInfo, Args);
	enum string[][] tags = [ApplyTypeSeq!(StringSeq, Args)];

	ApplyTypeSeq!(GetTypeDataStructureFromInfo, Args) entities;

	template findTypes(alias T) {
		static if(__traits(compiles, FindMatchingTypes!(T, 0, Types))) {
			enum auto findTypes = array(FindMatchingTypes!(T, 0, Types));
		} else {
			enum auto findTypes = array(FindMatchingTypes!(T!(StaticECS!Args), 0, Types));
		}
	}
	enum auto findCompatibleTypes(T) = array(FindCompatibleTypes!(T, 0, CompatibleTypes));
	enum auto findCompatibleTypesMultiple(Args...) = array(FindCompatibleTypesMultiple!(TypeSeqStruct!(Args), 0, CompatibleTypes));
	enum auto findCompatibleTypesMultipleWithType(T...) = array(FindCompatibleTypesMultipleWithType!(StaticECS!Args, TypeSeqStruct!(T), 0, TypeSeqStruct!(Types), CompatibleTypes));

	template FoundTypesToPointer(alias First, T...) {
		static if (T.length == 0) {
			alias FoundTypesToPointer = typeof(entities[First])*;
		} else {
			alias FoundTypesToPointer = TypeSeq!(typeof(entities[First])*, FoundTypesToPointer!(T));
		}
	}
	auto createView(T...)() {
		alias foundTypes = FindCompatibleTypesMultipleWithType!(StaticECS!Args, TypeSeqStruct!(T), 0, TypeSeqStruct!(Types), CompatibleTypes);
		StaticView!(FoundTypesToPointer!(foundTypes)) sv;
		static foreach (i; foundTypes) {
			sv.args[i] = &entities[i];
		}
		return sv;
	}
	
	void apply(alias Func)() {
		static foreach(i; 0 .. Types.length) {
			foreach (ref e; entities[i]) {
				e = Func(e);
			}
		}
	}
	void applyTo(alias Func, T)() {
		static foreach(i; findTypes!(T)) {
			foreach (ref e; entities[i]) {
				e = Func(e);
			}
		}
	}
	void applyToCompatible(alias Func, T...)() {
		static foreach(i; FindCompatibleTypesMultipleWithType!(StaticECS!Args, TypeSeqStruct!(T), 0, TypeSeqStruct!(Types), CompatibleTypes)) {
			foreach (ref e; entities[i]) {
				e = Func(e);
			}
		}
	}

	void send(Event)(Event event) {
		static foreach (i; 0 .. Args.length) {
			static if (__traits(compiles, entities[i][0].receive(event))) {
				foreach (ref e; entities[i]) {
					e.receive(event);
				}
			}
		}
	}
	void sendTo(Event, T)(Event event) {
		static foreach(i; findTypes!(T)) {
			static if (__traits(compiles, entities[i][0].receive(event))) {
				foreach (ref e; entities[i]) {
					e.receive(event);
				}
			}
		}
	}
	void sendToCompatible(Event, T...)(Event event) {
		static foreach(i; FindCompatibleTypesMultipleWithType!(StaticECS!Args, TypeSeqStruct!(T), 0, TypeSeqStruct!(Types), CompatibleTypes)) {
			static if (__traits(compiles, entities[i][0].receive(event))) {
				foreach (ref e; entities[i]) {
					e.receive(event);
				}
			}
		}
	}

	ECS createDynamicECS() {
		ECS ecs;
		static foreach(i; 0 .. Types.length) {
			foreach (ref e; entities[i]) {
				ECSEntry* entry = &ecs.add();
				static if (!is(Types[i] == class) && !is(Types[i] == interface)) {
					// nur zum test, später rausnehmen
					entry.addRef!(Types[i])(&e);
					static if (ApplyTypeSeq!(ExtractInterfaces, CompatibleTypes[i]).length > 0) {
						entry.add!(InterfaceAdapter!(Types[i]*, ApplyTypeSeq!(ExtractInterfaces, CompatibleTypes[i])));
						auto adapterClass = entry.get!(InterfaceAdapter!(Types[i]*, ApplyTypeSeq!(ExtractInterfaces, CompatibleTypes[i])));
						adapterClass.t = &e;
						static foreach (E; ApplyTypeSeq!(ExtractInterfaces, CompatibleTypes[i])) {
							entry.addRef!(E)(adapterClass);
						}
					}
				} else {
					entry.addRef!(Types[i])(e);
					static foreach (E; ApplyTypeSeq!(ExtractInterfaces, CompatibleTypes[i])) {
						entry.addRef!(E)(e);
					}
				}
			}
		}
		return ecs;
	}
}

struct Component {
	string type;
	bool isRef = false;
	void* data;
	this(string type, bool isRef, void* data) {
		this.type = type;
		this.isRef = isRef;
		this.data = data;
	}
	~this() {
		if (!isRef && data != null) {
			import core.stdc.stdlib : free;
			free(data);
		}
	}
}

struct ECSEntry {
	size_t id;
	LinkedList!Component components;
	ref ECSEntry add(T)() if (!is(T == class) && !is(T == interface)) {
		import core.stdc.stdlib : malloc;
		import std.conv : emplace;
		void* data = malloc(T.sizeof);
		emplace(cast(T*)data);
		components.add(Component(T.stringof, false, data));
		return this;
	}
	ref ECSEntry add(T)() if (is(T == class)) {
		import core.stdc.stdlib : malloc;
		import std.conv : emplace;
		void* data = malloc(S!T.sizeof);
		emplace(cast(S!T*)data);
		components.add(Component(T.stringof, false, data));
		return this;
	}
	ref ECSEntry add(T)(T t) if (!is(T == class) && !is(T == interface)) {
		import core.stdc.stdlib : malloc;
		void* data = malloc(T.sizeof);
		*(cast(T*)data) = t;
		components.add(Component(T.stringof, false, data));
		return this;
	}
	ref ECSEntry addRef(T)() if (!is(T == class) && !is(T == interface)) {
		components.add(Component(T.stringof, true, null));
		return this;
	}
	ref ECSEntry addRef(T)() if (is(T == class) || is(T == interface)) {
		components.add(Component(T.stringof, true, null));
		return this;
	}
	ref ECSEntry addRef(T)(T* t) if (!is(T == class) && !is(T == interface)) {
		components.add(Component(T.stringof, true, cast(void*) t));
		return this;
	}
	ref ECSEntry addRef(T)(T t) if (is(T == class) || is(T == interface)) {
		components.add(Component(T.stringof, true, cast(void*) t));
		return this;
	}
	ref T get(T)() if (!is(T == class) && !is(T == interface)) {
		foreach (ref e; components.iterate) {
			if (e.type == T.stringof) {
				return *(cast(T*) e.data);
			}
		}
		assert(false, "Component not found");
	}
	T get(T)() if (is(T == class) || is(T == interface)) {
		foreach (ref e; components.iterate) {
			if (e.type == T.stringof) {
				if (e.isRef) {
					return cast(T) e.data;
				} else {
					return (cast(S!T*)e.data).get;
				}
			}
		}
		assert(false, "Component not found");
	}
	bool has(T)() {
		foreach (ref e; components.iterate) {
			if (e.type == T.stringof) {
				return true;
			}
		}
		return false;
	}
	// am besten ohne i, sondern mit pointer zum entry, sonst wird doppelt gesucht
	ref ECSEntry remove(T)() {
		foreach (i, ref e; components.iterate) {
			if (e.type == T.stringof) {
				components.remove(i);
			}
		}
		return this;
	}
}

// verbessern mit views für performance, und erstellung von StaticECS
// vlt views erstellen mit funktionen die ausgeführt werden falls element hinzugefügt oder gelöscht wird
// performance kann auch verbessert werden wenn man mehrere objekte mit gleichen components austattet
struct ECS {
	enum size_t sizeIncrement = 100;
	size_t length;
	Vector!ECSEntry entities;
	LinkedList!size_t emptyEntries;
	ref ECSEntry add() {
		if (emptyEntries.length == 0) {
			if (length >= entities.length) {
				entities.resize(entities.length + sizeIncrement);
			}
			entities[length].id = length;
			length++;
			return entities[length - 1];
		} else {
			size_t id = emptyEntries.get(0);
			emptyEntries.remove(0);
			entities[id].id = id;
			return entities[id];
		}
	}
	void remove(size_t id) {
		entities[id] = ECSEntry();
		emptyEntries.add(id);
	}
	ref ECSEntry get(size_t id) {
		return entities[id];
	}
	// hier ebenfalls ändern um nur einmal zu suchen
	Vector!size_t get(T...)() {
		size_t foundSize;
		foreach (i; 0 .. length) {
			int found = 0;
			foreach (ref e; entities[i].components.iterate) {
				static foreach (E; T) {
					if (e.type == E.stringof) {
						found++;
					}
				}
			}
			if (found == T.length) {
				foundSize++;
			}
		}
		Vector!size_t foundEntries;
		foundEntries.resize(foundSize);
		size_t index;
		foreach (i; 0 .. length) {
			int found = 0;
			foreach (ref e; entities[i].components.iterate) {
				static foreach (E; T) {
					if (e.type == E.stringof) {
						found++;
					}
				}
			}
			if (found == T.length) {
				foundEntries[index] = i;
				index++;
			}
		}
		return foundEntries;
	}
}