module utils;

import functions;
//import core.stdc.stdlib : malloc, free, realloc;
//import core.stdc.string : memcpy;

// alignment hinzufügen
// unit tests

// thread struct hinzfügen: mit createLowLevelThread https://dlang.org/phobos/core_thread_osthread.html#.createLowLevelThread

// vorsicht: man darf klassen nicht verschieben, auch kein S!$
// soll heissen: immer H! verwenden
struct S(T) if (is(T == class)) {
	byte[__traits(classInstanceSize, T)] data;
	static S!T opCall(Args...)(Args args) {
		S!T value;
		emplace!(T, Args)(cast(void[T.sizeof]) value.data[0 .. __traits(classInstanceSize, T)], args);
		return value;
	}
	~this() {
		(cast(T) data.ptr).destroy();
	}
	ref S!T opAssign(T t) {
		(cast(T) data.ptr).destroy();
		if (__ctfe) {
			foreach (i; 0 .. T.sizeof) {
				data[i] = (cast(byte*) t)[i];
			}
		} else {
			memcpy(cast(void*) data, cast(void*) t, T.sizeof);
		}
		return this;
	}
	T get() @property {
		return cast(T) data.ptr;
	}
	T ptr() @property {
		return cast(T) data.ptr;
	}
	alias get this;
}

/*struct S(T) if (!is(T == class)) {
	T data;
	static S!T opCall(Args...)(Args args) {
		S!T value;
		value.data = T(args);
		return value;
	}
	ref T get() @property {
		return data;
	}
	T* ptr() @property {
		return &data;
	}
	alias data this;
}*/

struct H(T) if (is(T == class)) {
	T data;
	~this() {
		if (!__ctfe && data!is null) {
			data.destroy();
			free(cast(void*) data);
		}
	}
	/*this(T t) {
		data = t;
	}*/
	static H!T opCall(Args...)(Args args) {
		H!T value;
		if (__ctfe) {
			value.data = new T(args);
		} else {
			value.data = cast(T) malloc(__traits(classInstanceSize, T));
			emplace!(T, Args)((cast(void*) value.data)[0 .. __traits(classInstanceSize, T)], args);
		}
		return value;
	}
	T get() @property {
		return data;
	}
	T ptr() @property {
		return data;
	}
	alias get this;
	ref H!T opAssign(H!T t) {
		t.destroy();
		if (__ctfe) {
			foreach (i; 0 .. T.sizeof) {
				(cast(byte*) data)[i] = (cast(byte*) t.data)[i];
			}
		} else {
			memcpy(cast(void*) data, cast(void*) t.data, __traits(classInstanceSize, T));
		}
		return this;
	}
	ref H!T takeOwnership(H!T t) {
		data = t.data;
		t.data = null;
		return this;
	}
	auto toBase(U)() {
		auto ret = H!U(data);
		data = null;
		return ret;
	}
}

struct H(T) if (!is(T == class)) {
	T* data;
	~this() {
		if (!__ctfe && data != null) {
			(*data).destroy();
			free(data);
		}
	}
	this(T* t) {
		data = t;
	}
	static H!T opCall(Args...)(Args args) {
		H!T value;
		if (__ctfe) {
			value.data = new T(args);
		} else {
			value.data = cast(T*) malloc(T.sizeof);
			emplace(value.data, args);
		}
		return value;
	}
	ref T get() @property {
		return *data;
	}
	T* ptr() @property {
		return data;
	}
	alias get this;
	ref H!T opAssign(T t) {
		*data = t;
		return this;
	}
	ref H!T opAssign(H!T t) {
		t.destroy();
		if (__ctfe) {
			foreach (i; 0 .. T.sizeof) {
				(cast(byte*) data)[i] = (cast(byte*) t.data)[i];
			}
		} else {
			memcpy(cast(void*) data, cast(void*) t.data, T.sizeof);
		}
		return this;
	}
	ref H!T takeOwnership(H!T t) {
		data = t.data;
		t.data = null;
		return this;
	}
}

struct Ref(T) if (is(T == class) || is(T == interface)) {
	T data;
	T get() @property {
		return data;
	}
	T ptr() @property {
		return data;
	}
	alias get this;
	this(T t) {
		data = t;
	}
	this(ref S!T value) {
		data = value.ptr;
	}
	this(ref H!T value) {
		data = value.ptr;
	}
	ref Ref!T opAssign(T t) {
		data = t;
	}
	ref Ref!T opAssign(ref S!T value) {
		data = value.ptr;
	}
	ref Ref!T opAssign(ref H!T value) {
		data = value.ptr;
	}
}

struct Ref(T) if (!is(T == class) && !is(T == interface)) {
	T* data;
	ref T get() @property {
		return *data;
	}
	T* ptr() @property {
		return data;
	}
	alias get this;
	this(T* t) {
		data = t;
	}
	this(ref T t) {
		data = &t;
	}
	this(ref S!T value) {
		data = value.ptr;
	}
	this(ref H!T value) {
		data = value.ptr;
	}
	ref Ref!T opAssign(ref T t) {
		data = &t;
	}
	ref Ref!T opAssign(T* t) {
		data = t;
	}
	ref Ref!T opAssign(ref S!T value) {
		data = value.ptr;
	}
	ref Ref!T opAssign(ref H!T value) {
		data = value.ptr;
	}
}

struct StaticArray(T, size_t size) {
	this(Args...)(Args args) {
		static foreach (e, i; Args) {
			elements[e] = args[e];
		}
	}
	T[size] elements;
	alias elements this;
}

auto array() {
	return [];
}

// test ob typ kopierbar
void copyTest(T)(T t) {
}
void copyTest2(T)() {
	T t1;
	T t2;
	t1 = t2;
}

auto getCopyableType(T)() {
	static if (!__traits(compiles, copyTest2!T())) {
		return getCopyableType!(typeof(__traits(getMember, T, __traits(getAliasThis, T)[0])))();
	} else {
		return T();
	}
}

auto array(Args...)(in Args args) {
	static foreach (i; 0 .. Args.length) {
		/*static if (!__traits(compiles, copyTest(args[i]))) {
			static if (!__traits(compiles, arrayType)) {
				alias arrayType = Unqual!(typeof(__traits(getMember, Args[0], __traits(getAliasThis, Args[0])[0])));
			}
		}*/
		static if (!__traits(compiles, arrayType)) {
			static if (__traits(compiles, getCopyableType!(Args[i])())) {
				alias arrayType = Unqual!(typeof(getCopyableType!(Args[i])()));
			}
		}
	}
	static if (!__traits(compiles, arrayType)) {
		alias arrayType = Unqual!(Args[0]);
	}
	arrayType [Args.length] a;
	static foreach (i; 0 .. Args.length) {
		a[i] = cast(arrayType) args[i];
	}
	return a;
}

auto array(T, Args...)(Args args) {
	T[Args.length] a;
	static foreach (i; 0 .. Args.length) {
		a[i] = cast(T) args[i];
	}
	return a;
}

auto array(T, Args...)(ref Args args) {
	T[Args.length] a;
	static foreach (i; 0 .. Args.length) {
		a[i] = cast(T) args[i];
	}
	return a;
}

auto move(T)(ref T t) {
	T moved = t;
	emplace(&t);
	return moved;
}

struct Vector(T) if (!is(T == class)) {
	T[] t;
	this(size_t size) {
		if (__ctfe) {
			t = new T[size];
		} else {
			t = cast(T[]) (cast(void[]) malloc(size * T.sizeof)[0 .. size * T.sizeof]);
			foreach (i; 0 .. size) {
				emplace(&t[i]);
			}
		}
	}
	~this() {
		if (!__ctfe) {
			foreach (i; 0 .. t.length) {
				t[i].destroy();
			}
			free(t.ptr);
		}
	}
	void resize(size_t size) {
		if (size != t.length) {
			if (__ctfe) {
				t.length = size;
			} else {
				T[] u = cast(T[]) (cast(void[]) malloc(size * T.sizeof)[0 .. size * T.sizeof]);
				memcpy(cast(void*) u.ptr, cast(void*) t.ptr, (t.length < size ? t.length : size) * T.sizeof);
				foreach (i; (t.length > size ? t.length : size) .. t.length) {
					t[i].destroy();
				}
				size_t oldLength = t.length;
				free(t.ptr);
				t = u;
				foreach (i; oldLength .. size) {
					emplace(&t[i]);
				}
			}
		}
	}
	ref Vector!T opAssign(Vector!T v) {
		if (__ctfe) {
			t = v.t;
		} else {
			foreach (i; 0 .. t.length) {
				t[i].destroy();
			}
			free(t.ptr);
			t = cast(T[]) (cast(void[]) malloc(v.length * T.sizeof)[0 .. v.length * T.sizeof]);
			memcpy(cast(void*) t.ptr, cast(void*) v.ptr, v.length);
		}
		return this;
	}
	T* data() @property {
		return t.ptr;
	}
	T* ptr() @property {
		return t.ptr;
	}
	size_t size() @property {
		return t.length;
	}
	size_t length() @property {
		return t.length;
	}
	alias t this;
}

struct String {
	char[] s;
	this(size_t size) {
		if (__ctfe) {
			s = new char[size];
		} else {
			s = cast(char[]) malloc(size * char.sizeof)[0 .. size * char.sizeof];
		}
	}
	this(char[] str) {
		if (__ctfe) {
			s = str;
		} else {
			s = cast(char[]) malloc(str.length * char.sizeof)[0 .. str.length * char.sizeof];
		}
	}
	~this() {
		if (!__ctfe) {
			free(s.ptr);
		}
	}
	void resize(size_t size) {
		if (__ctfe) {
			s = new char[size];
		} else {
			s = cast(char[]) realloc(s.ptr, size * char.sizeof)[0 .. size * char.sizeof];
		}
	}
	void opAssign(char[] str) {
		if (__ctfe) {
			s = str;
		} else {
			resize(str.length);
			memcpy(cast(void*) s.ptr, cast(void*) str.ptr, str.length);
		}
	}
	char* data() @property {
		return s.ptr;
	}
	char* ptr() @property {
		return s.ptr;
	}
	size_t size() @property {
		return s.length;
	}
	size_t length() @property {
		return s.length;
	}
	alias s this;
}

template isType(T, Args...) {
	bool isTypeImpl(T, Args...)() {
		bool result = true;
		static foreach (i; 0 .. Args.length) {
			static if (!is(Args[i] == T)) {
				result = false;
			}
		}
		return result;
	}
	enum bool isType = isTypeImpl!(T, Args)();
}

template isTypeCompatible(T, Args...) {
	bool isTypeCompatibleImpl(T, Args...)() {
		bool result = true;
		static foreach (i; 0 .. Args.length) {
			static if (!is(Args[i] : T)) {
				result = false;
			}
		}
		return result;
	}
	enum bool isTypeCompatible = isTypeCompatibleImpl!(T, Args)();
}

template countType(T, Args...) {
	uint countTypeImpl(T, Args...)() {
		uint count = 0;
		static foreach (i; 0 .. Args.length) {
			static if (is(Args[i] == T)) {
				count++;
			}
		}
		return count;
	}
	enum uint countType = countTypeImpl!(T, Args)();
}

template countCompatibleTypes(T, Args...) {
	uint countCompatibleTypesImpl(T, Args...)() {
		uint count = 0;
		static foreach (i; 0 .. Args.length) {
			static if (is(Args[i] : T)) {
				count++;
			}
		}
		return count;
	}
	enum uint countCompatibleTypes = countCompatibleTypesImpl!(T, Args)();
}

template countTypeGroups(T, Args...) {
	uint countTypeGroupsImpl(T, Args...)() {
		uint count = 0;
		bool current = false;
		static foreach (i; 0 .. Args.length) {
			static if (is(Args[i] == T)) {
				if (!current) {
					count++;
					current = true;
				}
			} else {
				current = false;
			}
		}
		return count;
	}
	enum uint countTypeGroups = countTypeGroupsImpl!(T, Args)();
}

template countCompatibleTypeGroups(T, Args...) {
	uint countCompatibleTypeGroupsImpl(T, Args...)() {
		uint count = 0;
		bool current = false;
		static foreach (i; 0 .. Args.length) {
			static if (is(Args[i] : T)) {
				if (!current) {
					count++;
					current = true;
				}
			} else {
				current = false;
			}
		}
		return count;
	}
	enum uint countCompatibleTypeGroups = countCompatibleTypeGroupsImpl!(T, Args)();
}

template countTypeInGroups(T, Args...) {
	uint[2][countTypeGroups!(T, Args)] countTypeInGroupsImpl(T, Args...)() {
		StaticArray!(uint[2], countTypeGroups!(T, Args)) groupCounts;
		uint count = 0;
		bool current = false;
		static foreach (i; 0 .. Args.length) {
			static if (is(Args[i] == T)) {
				if (!current) {
					count++;
					groupCounts[count - 1][0] = i;
					groupCounts[count - 1][1]++;
					current = true;
				} else {
					groupCounts[count - 1][1]++;
				}
			} else {
				current = false;
			}
		}
		return groupCounts;
	}
	enum uint[2][countTypeGroups!(T, Args)] countTypeInGroups = countTypeInGroupsImpl!(T, Args)();
}

template countCompatibleTypeInGroups(T, Args...) {
	uint[2][countCompatibleTypeGroups!(T, Args)] countCompatibleTypeInGroupsImpl(T, Args...)() {
		StaticArray!(uint[2], countCompatibleTypeGroups!(T, Args)) groupCounts;
		uint count = 0;
		bool current = false;
		static foreach (i; 0 .. Args.length) {
			static if (is(Args[i] : T)) {
				if (!current) {
					count++;
					groupCounts[count - 1][0] = i;
					groupCounts[count - 1][1]++;
					current = true;
				} else {
					groupCounts[count - 1][1]++;
				}
			} else {
				current = false;
			}
		}
		return groupCounts;
	}
	enum uint[2][countCompatibleTypeGroups!(T, Args)] countCompatibleTypeInGroups = countCompatibleTypeInGroupsImpl!(T, Args)();
}

template findTypes(T, Args...) {
	uint[countType!(T, Args)] findTypesImpl(T, Args...)() {
		StaticArray!(uint, countType!(T, Args)) indices;
		uint count = 0;
		static foreach (i; 0 .. Args.length) {
			static if (is(Args[i] == T)) {
				indices[count] = i;
				count++;
			}
		}
		return indices;
	}
	enum uint[countType!(T, Args)] findTypes = findTypesImpl!(T, Args)();
}

template findCompatibleTypes(T, Args...) {
	uint[countCompatibleTypes!(T, Args)] findCompatibleTypesImpl(T, Args...)() {
		//uint[countType!(T, Args)] indices;
		StaticArray!(uint, countCompatibleTypes!(T, Args)) indices;
		uint count = 0;
		static foreach (i; 0 .. Args.length) {
			static if (is(Args[i] : T)) {
				indices[count] = i;
				count++;
			}
		}
		return indices.elements;
	}
	enum uint[countCompatibleTypes!(T, Args)] findCompatibleTypes = findCompatibleTypesImpl!(T, Args)();
}

T[findTypes!(T, Args).length] typesToArray(T, Args...)(in Args args) {
	enum auto indices = findTypes!(T, Args);
	T[indices.length] a;
	static if (indices.length != 0) {
		static foreach (i, e; indices) {
			a[i] = cast(T) args[e];
		}
	}
	return a;
}

T[findCompatibleTypes!(T, Args).length] compatibleTypesToArray(T, Args...)(in Args args) {
	enum auto indices = findCompatibleTypes!(T, Args);
	T[indices.length] a;
	static if (indices.length != 0) {
		static foreach (i, e; indices) {
			a[i] = cast(T) args[e];
		}
	}
	return a;
}

auto typesToArrayInGroup(T, uint group, Args...)(in Args args) {
	static if (countTypeGroups!(T, Args) > group) {
		enum uint index = countTypeInGroups!(T, Args)[group][0];
		enum uint length = countTypeInGroups!(T, Args)[group][1];
		T[length] a;
		static if (length != 0) {
			static foreach (i; 0..length) {
				a[i] = cast(T) args[i + index];
			}
		}
		return a;
	} else {
		return cast(T[0]) [];
	}
}

auto compatibleTypesToArrayInGroup(T, uint group, Args...)(in Args args) {
	static if (countCompatibleTypeGroups!(T, Args) > group) {
		enum uint index = countCompatibleTypeInGroups!(T, Args)[group][0];
		enum uint length = countCompatibleTypeInGroups!(T, Args)[group][1];
		T[length] a;
		static if (length != 0) {
			static foreach (i; 0..length) {
				a[i] = cast(T) args[i + index];
			}
		}
		return a;
	} else {
		return cast(T[0]) [];
	}
}

template multiplyArgs(Args...) {
	static if (Args.length != 0) {
		static assert(isTypeCompatible!(Args[0], Args));
	}
	auto multiplyArgsImpl(Args...)() {
		static if (Args.length == 0) {
			return 1;
		} else {
			typeof(Args[0]) result = Args[0];
			static foreach (i; 1 .. Args.length) {
				result *= Args[i];
			}
			return result;
		}
	}
	enum auto multiplyArgs = multiplyArgsImpl!Args();
}

template methodToString(T, string methodName) {
	string methodToStringImpl() {
		string s;
		s = (ReturnType!(__traits(getMember, T, methodName))).stringof ~ " " ~ methodName ~ "(";
		static foreach (i; 0 .. Parameters!(__traits(getMember, T, methodName)).length) {
			static foreach (storageClass; __traits(getParameterStorageClasses, __traits(getMember, T, methodName), i)) {
				s = s ~ storageClass ~ " ";
			}
			s = s ~ (Parameters!(__traits(getMember, T, methodName))[i]).stringof ~ " a" ~ to!string(i) ~ ", ";
		}
		s = s ~ ")";
		static foreach (att; __traits(getFunctionAttributes, __traits(getMember, T, methodName))) {
			s = s ~ att ~ " ";
		}
		s = s ~ "{ return t." ~ methodName ~ "(";
		static foreach (i; 0 .. Parameters!(__traits(getMember, T, methodName)).length) {
			s = s ~ "a" ~ to!string(i) ~ ", ";
		}
		s = s ~ ");}";
		return s;
	}
	enum string methodToString = methodToStringImpl();
}

template methodToStringTest(T, string methodName) {
	string methodToStringTestImpl() {
		string s;
		s = methodName ~ "(";
		static foreach (i; 0 .. Parameters!(__traits(getMember, T, methodName)).length) {
			static foreach (storageClass; __traits(getParameterStorageClasses, __traits(getMember, T, methodName), i)) {
				s = s ~ storageClass ~ "(), ";
			}
		}
		s = s ~ ")";
		return s;
	}
	enum string methodToStringTest = methodToStringTestImpl();
}

class InterfaceAdapter(T, Interface...) : Interface {
	T t;
	this(T t) {
		this.t = t;
	}
	static foreach(I; Interface) {
		static foreach(member; __traits(allMembers, I)) {
			static if (!__traits(compiles, mixin(methodToStringTest!(T, member)))) {
				mixin(methodToString!(T, member));
			}
		}
	}
}

struct Box(T, Interface...) {
	H!(InterfaceAdapter!(T, Interface)) data;
	alias data this;
	this(H!(InterfaceAdapter!(T, Interface)) data) {
		this.data = data;
	}
	this(Args...)(Args args) {
		data = H!(InterfaceAdapter!(T, Interface))(args);
	}
}

struct Result(ResultType, ResultType successType) {
	this(ResultType result) {
		this.result = result;
	}
	bool success() immutable @property {
		return result == successType;
	}
	void reset() {
		result = successType;
	}
	ref Result opAssign(ResultType result) return {
		if (result != successType) {
			if (this.result == successType) {
				this.result = result;
			}
			if (!(onError is null)) {
				onError(result);
			}
		}
		return this;
	}
	ResultType result = successType;
	alias result this;
	void delegate(ResultType) onError;
}

struct ListElement(T) {
	T t;
	alias t this;
	ListElement!T* next = null;
	ListElement!T* previous = null;
	this(lazy T t) {
		this.t = t;
	}
}

// für foreach
struct LinkedListIterate(T) {
	ListElement!T* current = null;
	this(ListElement!T* e) {
		current = e;
	}
	@property bool empty() {
		return current == null;
	}
	@property ref T front() {
		return current.t;
	}
	@property void popFront() {
		current = current.next;
	}
	@property ref T back() {
		return current.t;
	}
	@property void popBack() {
		current = current.previous;
	}
}

struct LinkedList(T) {
	uint length;
	ListElement!T* first;
	ListElement!T* last;
	~this() {
		for (int i = 0; i < length; i++) {
			ListElement!T* current = last.previous;
			destroy(*last);
			free(cast(void*)last);
			last = current;
		}
	}
	ref LinkedList!T add(lazy T t) {
		if (length == 0) {
			auto newLast = cast(ListElement!T*) malloc(ListElement!T.sizeof);
			emplace(newLast);
			newLast.t = t();
			last = newLast;
			first = last;
		} else {
			last.next = cast(ListElement!T*) malloc(ListElement!T.sizeof);
			emplace(last.next);
			last.next.previous = last;
			last.next.t = t();
			last = last.next;
		}
		length++;
		return this;
	}
	ref LinkedList!T add() {
		if (length == 0) {
			last = cast(ListElement!T*) malloc(ListElement!T.sizeof);
			emplace(last);
			first = last;
		} else {
			last.next = cast(ListElement!T*) malloc(ListElement!T.sizeof);
			emplace(last.next);
			last.next.previous = last;
			last = last.next;
		}
		length++;
		return this;
	}
	ref T get(uint index) {
		assert(index < length);
		ListElement!T* current = first;
		for (int i = 0; i < cast(int)index; i++) {
			current = current.next;
		}
		return current.t;
	}
	ListElement!T* getListElement(uint index) {
		assert(index < length);
		ListElement!T* current = first;
		for (int i = 0; i < cast(int)index; i++) {
			current = current.next;
		}
		return current;
	}
	ref LinkedList!T remove(uint index) {
		assert(index < length);
		ListElement!T* current = first;
		for (int i = 0; i < cast(int)index; i++) {
			current = current.next;
		}
		if (current.previous != null)
			current.previous.next = current.next;
		if (current.next != null)
			current.next.previous = current.previous;
		if (first == current) {
			first = first.next;
		}
		if (last == current) {
			last = last.previous;
		}
		destroy(*current);
		free(cast(void*)current);
		length--;
		return this;
	}
	ref LinkedList!T remove(ListElement!T* current) {
		if (current != null) {
			if (current.previous != null)
				current.previous.next = current.next;
			if (current.next != null)
				current.next.previous = current.previous;
			if (first == current) {
				first = first.next;
			}
			if (last == current) {
				last = last.previous;
			}
			destroy(*current);
			free(cast(void*)current);
			length--;
		}
		return this;
	}
	// todo: falls current = first oder = last
	ref LinkedList!T insert(uint index, lazy T t) {
		assert(index < length);
		ListElement!T* current = first;
		for (int i = 0; i < cast(int)index; i++) {
			current = current.next;
		}
		ListElement!T* previousElement = current.previous;
		previousElement.next = cast(ListElement!T*) malloc(ListElement!T.sizeof);
		emplace(previousElement.next);
		previousElement.next.t = t();
		previousElement.next.previous = previousElement;
		previousElement.next.next = current;
		current.previous = previousElement.next;
		return this;
	}
	ref LinkedList!T insertBefore(ListElement!T* current, lazy T t) {
		ListElement!T* previousElement = current.previous;
		previousElement.next = cast(ListElement!T*) malloc(ListElement!T.sizeof);
		emplace(previousElement.next);
		previousElement.next.t = t();
		previousElement.next.previous = previousElement;
		previousElement.next.next = current;
		current.previous = previousElement.next;
		return this;
	}
	ref LinkedList!T insertAfter(ListElement!T* current, lazy T t) {
		ListElement!T* nextElement = current.next;
		nextElement.previous = cast(ListElement!T*) malloc(ListElement!T.sizeof);
		emplace(nextElement.previous);
		nextElement.previous.t = t();
		nextElement.previous.previous = current;
		nextElement.previous.next = nextElement;
		current.next = nextElement.previous;
		return this;
	}
	@property LinkedListIterate!T iterate() {
		return LinkedListIterate!T(first);
	}
	@property LinkedListIterate!T iterateBackwards() {
		return LinkedListIterate!T(last);
	}
}

struct Timer {
	long ticks;
	double update() {
		long newTicks = functions.ticks();
		double dt = cast(double)(newTicks - ticks) / cast(double)functions.ticksPerSecond();
		ticks = newTicks;
		return dt;
	}
}

template TypeSeq(Args...) {
	alias TypeSeq = Args;
}

// hier noch viele compile time funktionen hinzufügen um die Args zu bearbeiten
struct TypeSeqStruct(Args...) {
	alias TypeSeq = Args;
}

template ApplyTypeSeq(alias Func, Args...) {
	static if (Args.length == 0) {
		alias ApplyTypeSeq = TypeSeq!();
	} else {
		alias ApplyTypeSeq = TypeSeq!(Func!(Args[0]), ApplyTypeSeq!(Func, Args[1 .. Args.length]));
	}
}

auto seqToArray(Args...)() {
	return array(Args);
}