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
	//@disable this(ref return scope H!T rhs);
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
	@disable this(ref return scope H!T rhs);
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

// sollte memcpy verwenden?
/*auto move(T)(ref T t) {
	T moved = t;
	emplace(&t);
	return moved;
}*/
auto move(T)(ref T t) {
	T empty;
	T ret;
	memcpy(cast(void*) &ret, cast(void*) &t, T.sizeof);
	memcpy(cast(void*) &t, cast(void*) &empty, T.sizeof);
	return ret;
}

struct Vector(T) if (!is(T == class)) {
	T[] t;
	alias t this;
	// war disabled
	this(ref return scope Vector!T rhs) {
		this(cast(T[]) rhs.t);
	}
	inout this(ref return scope inout Vector!T rhs) {
		static if (__traits(compiles, copyTest2!T())) {
			if (__ctfe) {
				t = cast(inout T[]) new T[rhs.t.length];
				foreach (i; 0 .. rhs.t.length) {
					(cast(T[])t)[i] = (cast(T[])rhs.t)[i];
				}
			} else {
				t = cast(inout T[])cast(T[]) (cast(void[]) malloc(rhs.t.length * T.sizeof)[0 .. rhs.t.length * T.sizeof]);
				memcpy(cast(void*) t.ptr, cast(void*) rhs.t.ptr, (t.length < rhs.t.length ? t.length : rhs.t.length) * T.sizeof);
			}
		} else {
			assert(false, "Type not copyable");
		}
	}
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
	this(immutable(T)[] copy) {
		this(cast(T[]) copy);
	}
	this(T[] copy) {
		static if (__traits(compiles, copyTest2!T())) {
			if (__ctfe) {
				t = new T[copy.length];
				foreach (i; 0 .. copy.length) {
					t[i] = copy[i];
				}
			} else {
				t = cast(T[]) (cast(void[]) malloc(copy.length * T.sizeof)[0 .. copy.length * T.sizeof]);
				memcpy(cast(void*) t.ptr, cast(void*) copy.ptr, (t.length < copy.length ? t.length : copy.length) * T.sizeof);
			}
		} else {
			assert(false, "Type not copyable");
		}
	}
	~this() {
		if (!__ctfe && t.ptr != null) {
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
				foreach (i; (t.length > size ? size : t.length) .. t.length) {
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
	void renew(size_t size) {
		if (size != t.length) {
			if (__ctfe) {
				t.length = size;
			} else {
				foreach (i; 0 .. t.length) {
					t[i].destroy();
				}
				T[] u = cast(T[]) (cast(void[]) malloc(size * T.sizeof)[0 .. size * T.sizeof]);
				free(t.ptr);
				t = u;
				foreach (i; 0 .. size) {
					emplace(&t[i]);
				}
			}
		}
	}
	void opAssign(T[] copy) {
		static if (__traits(compiles, copyTest2!T())) {
			if (__ctfe) {
				t = new T[copy.length];
				foreach (i; 0 .. copy.length) {
					t[i] = copy[i];
				}
			} else {
				foreach (i; 0 .. t.length) {
					t[i].destroy();
				}
				if (copy.length != t.length) {
					T[] u = cast(T[]) (cast(void[]) malloc(copy.length * T.sizeof)[0 .. copy.length * T.sizeof]);
					memcpy(cast(void*) u.ptr, cast(void*) copy.ptr, (t.length < copy.length ? t.length : copy.length) * T.sizeof);
					free(t.ptr);
					t = u;
				} else {
					memcpy(cast(void*) t.ptr, cast(void*) copy.ptr, (t.length < copy.length ? t.length : copy.length) * T.sizeof);
				}
			}
		} else {
			assert(false, "Type not copyable");
		}
	}
	/*ref Vector!T opAssign(Vector!T v) {
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
	}*/
	T* data() @property {
		return t.ptr;
	}
	T* ptr() @property {
		return t.ptr;
	}
	size_t size() @property {
		return t.length;
	}
	size_t size(size_t newSize) @property {
		resize(newSize);
		return t.length;
	}
	size_t length() @property {
		return t.length;
	}
	size_t length(size_t newSize) @property {
		resize(newSize);
		return t.length;
	}
	size_t getId(T* e) {
		if (e - t.ptr >= 0 && (e - t.ptr) / T.sizeof < t.length) {
			return (e - t.ptr) / T.sizeof;
		}
		assert(false);
	}
	size_t getId(ref T e) {
		return getId(&e);
	}
	private static bool refCompare(alias compare)(T* a, T* b) {
		//return *a < *b;
		return compare(*a, *b);
	}
	static if (__traits(hasMember, T, "opCmp") || __traits(isScalar, T)) {
		private static bool defaultCompare(ref T a, ref T b) {
			return a < b;
		}
		auto ref sort()  {
			return sort!defaultCompare(length);
		}
		auto ref sort(size_t length) {
			return sort!defaultCompare(length);
		}
	}
	auto ref sort(alias compare)() {
		return sort!compare(length);
	}
	// todo: falls T nicht kopierbar, und falls ctfe (momentan ist memcpy mit this = copy gemischt haha)
	auto ref sort(alias compare)(size_t length) {
		if (length <= 1) {
			return this;
		}
		static if (T.sizeof > size_t.sizeof) {
			Vector!T copy = this;
			Vector!(T*) refToSort = Vector!(T*)(length);
			foreach (i; 0 .. length) {
				refToSort[i] = &copy[i];
			}
			refToSort.sort!(refCompare!compare)();
			foreach (i; 0 .. length) {
				this[i] = *refToSort[i];
			}
			return this;
		} else {
			size_t l = length;
			size_t depth = 1;
			Vector!T copy = Vector!T(length);
			Vector!T* ref1 = &copy;
			Vector!T* ref2 = &this;
			while (l != 0) {
				l /= 2;
				size_t leftover = length - depth * 2 * l;
				foreach (i; 0 .. l) {
					size_t left, right;
					foreach (j; 0 .. depth * 2) {
						if (!compare((*ref2)[i * depth * 2 + left], (*ref2)[i * depth * 2 + depth + right])) {
							memcpy(cast(void*)&(*ref1)[i * depth * 2 + j], cast(void*)&(*ref2)[i * depth * 2 + depth + right], T.sizeof);
							right++;
						} else {
							memcpy(cast(void*)&(*ref1)[i * depth * 2 + j], cast(void*)&(*ref2)[i * depth * 2 + left], T.sizeof);
							left++;
						}
						if (left == depth) {
							memcpy(cast(void*)&(*ref1)[i * depth * 2 + j + 1], cast(void*)&(*ref2)[i * depth * 2 + depth + right], T.sizeof * (depth - right));
							break;
						}
						if (right == depth) {
							memcpy(cast(void*)&(*ref1)[i * depth * 2 + j + 1], cast(void*)&(*ref2)[i * depth * 2 + left], T.sizeof * (depth - left));
							break;
						}
					}
				}
				size_t left, right;
				if (leftover > depth) {
					foreach (i; 0 .. leftover) {
						if (!compare((*ref2)[l * depth * 2 + left], (*ref2)[l * depth * 2 + depth + right])) {
							memcpy(cast(void*)&(*ref1)[l * depth * 2 + i], cast(void*)&(*ref2)[l * depth * 2 + depth + right], T.sizeof);
							right++;
						} else {
							memcpy(cast(void*)&(*ref1)[l * depth * 2 + i], cast(void*)&(*ref2)[l * depth * 2 + left], T.sizeof);
							left++;
						}
						if (left == depth) {
							memcpy(cast(void*)&(*ref1)[l * depth * 2 + i + 1], cast(void*)&(*ref2)[l * depth * 2 + depth + right], T.sizeof * (leftover - depth - right));
							break;
						}
						if (right == leftover - depth) {
							memcpy(cast(void*)&(*ref1)[l * depth * 2 + i + 1], cast(void*)&(*ref2)[l * depth * 2 + left], T.sizeof * (depth - left));
							break;
						}
					}
				} else if (leftover != 0) {
					memcpy(cast(void*)&(*ref1)[l * depth * 2], cast(void*)&(*ref2)[l * depth * 2], T.sizeof * leftover);
				}
				depth *= 2;
				Vector!T* ref3 = ref2;
				ref2 = ref1;
				ref1 = ref3;
			}
			if (ref2 == &copy) {
				this = copy;
			}
			return this;
		}
	}
}

alias String = Vector!char;

struct PartialVector(T, size_t PartialLength) {
	Vector!(Vector!T) vector;
	this(size_t initialLength) {
		size_t count = initialLength / PartialLength + (initialLength % PartialLength) == 0 ? 0 : 1;
		vector = Vector!(Vector!T)(count);
		foreach (i; 0 .. count - 1) {
			vector[i].resize(PartialLength);
		}
		if (initialLength % PartialLength != 0) {
			vector[count - 1].resize(initialLength % PartialLength);
		}
	}
	ref T opIndex(size_t i) {
		return vector[i / PartialLength][i % PartialLength];
	}
	void resize(size_t size) {
		size_t oldLength = vector.length;
		size_t count = size / PartialLength + (size % PartialLength) == 0 ? 0 : 1;
		vector.resize(count);
		if (oldLength != 0) {
			vector[oldLength - 1].resize(PartialLength);
		}
		foreach (i; oldLength .. count - 1) {
			vector[i].resize(PartialLength);
		}
		if (size % PartialLength != 0) {
			vector[count - 1].resize(size % PartialLength);
		}
	}
	void renew(size_t size) {
		size_t oldLength = vector.length;
		size_t count = size / PartialLength + (size % PartialLength) == 0 ? 0 : 1;
		vector.renew(count);
		if (oldLength != 0) {
			vector[oldLength - 1].resize(PartialLength);
		}
		foreach (i; oldLength .. count - 1) {
			vector[i].resize(PartialLength);
		}
		if (size % PartialLength != 0) {
			vector[count - 1].resize(size % PartialLength);
		}
	}
	size_t size() @property {
		if (vector.length == 0) {
			return 0;
		} else {
			return (vector.length - 1) * PartialLength + vector[vector.length - 1].length;
		}
	}
	size_t size(size_t newSize) @property {
		resize(newSize);
		return size();
	}
	size_t length() @property {
		return size();
	}
	size_t length(size_t newSize) @property {
		return size(newSize);
	}
	size_t getId(T* e) {
		foreach (i; 0 .. vector.length) {
			if (e - vector[i].ptr >= 0 && (e - vector[i].ptr) / T.sizeof < vector[i].length) {
				return (e - vector[i].ptr) / T.sizeof;
			}
		}
		assert(false);
	}
	size_t getId(ref T e) {
		return getId(&e);
	}
}

struct VectorList(alias BaseVector, T) {
	BaseVector!T vector;
	BaseVector!bool empty;
	alias vector this;
	size_t length;
	LinkedList!size_t emptyEntries;
	size_t defaultLength = 1;
	this(size_t initialLength) {
		vector = BaseVector!T(initialLength);
		empty = BaseVector!bool(initialLength);
		if (initialLength != 0) {
			defaultLength = initialLength;
		} else {
			defaultLength = 1;
		}
	}
	auto ref clear() {
		//vector.renew(defaultLength);
		//empty.renew(defaultLength);
		vector = BaseVector!T(defaultLength);
		empty = BaseVector!bool(defaultLength);
		emptyEntries.clear();
		length = 0;
		return this;
	}
	ref T add() {
		if (emptyEntries.length == 0) {
			if (length >= vector.length) {
				if (vector.length == 0) {
					vector.resize(defaultLength);
					empty.resize(defaultLength);
				} else {
					vector.resize(vector.length * 2);
					empty.resize(vector.length * 2);
				}
			}
			length++;
			empty[length - 1] = false;
			return vector[length - 1];
		} else {
			size_t id = emptyEntries.get(0);
			emptyEntries.remove(0);
			empty[id] = false;
			return vector[id];
		}
	}
	ref T add(lazy T t) {
		if (emptyEntries.length == 0) {
			if (length >= vector.length) {
				if (vector.length == 0) {
					vector.resize(defaultLength);
					empty.resize(defaultLength);
				} else {
					vector.resize(vector.length * 2);
					empty.resize(vector.length * 2);
				}
			}
			length++;
			vector[length - 1] = t;
			empty[length - 1] = false;
			return vector[length - 1];
		} else {
			size_t id = emptyEntries.get(0);
			emptyEntries.remove(0);
			empty[id] = false;
			vector[id] = t;
			return vector[id];
		}
	}
	size_t addId() {
		if (emptyEntries.length == 0) {
			if (length >= vector.length) {
				if (vector.length == 0) {
					vector.resize(defaultLength);
					empty.resize(defaultLength);
				} else {
					vector.resize(vector.length * 2);
					empty.resize(vector.length * 2);
				}
			}
			length++;
			empty[length - 1] = false;
			return length - 1;
		} else {
			size_t id = emptyEntries.get(0);
			emptyEntries.remove(0);
			empty[id] = false;
			return id;
		}
	}
	size_t addId(lazy T t) {
		if (emptyEntries.length == 0) {
			if (length >= vector.length) {
				if (vector.length == 0) {
					vector.resize(defaultLength);
					empty.resize(defaultLength);
				} else {
					vector.resize(vector.length * 2);
					empty.resize(vector.length * 2);
				}
			}
			length++;
			vector[length - 1] = t;
			empty[length - 1] = false;
			return length - 1;
		} else {
			size_t id = emptyEntries.get(0);
			emptyEntries.remove(0);
			empty[id] = false;
			vector[id] = t;
			return id;
		}
	}
	size_t getId(T* t) {
		return vector.getId(t);
	}
	size_t getId(ref T t) {
		return getId(&t);
	}
	// zuerst soll getestet werden ob id das letzte element in der liste ist
	void remove(size_t id) {
		vector[id].destroy();
		if (id != length - 1) {
			emptyEntries.add(id);
		} else {
			length--;
		}
		empty[id] = true;
	}
	// nötig falls liste aus size_t's besteht, um die richtige remove funktion auszuwählen
	void removeById(size_t id) {
		vector[id].destroy();
		if (id != length - 1) {
			emptyEntries.add(id);
		} else {
			length--;
		}
		empty[id] = true;
	}
	void remove(T* t) {
		remove(getId(t));
	}
	void remove(ref T t) {
		remove(&t);
	}
	void compactify() {
		//size_t actualLength = length;
		/*while (empty[actualLength - 1] == true) {
			actualLength--;
		}*/
		//vector.resize(actualLength);
		//empty.resize(actualLength);
		//length = actualLength;

		ListElement!size_t* current = emptyEntries.first;
		while (current != null) {
			ListElement!size_t* next = current.next;

			length--;
            T dummy;
            memcpy(
                cast(void*)&vector[current.t],
                cast(void*)&vector[length],
                T.sizeof
            );
            memcpy(cast(void*)&vector[length], cast(void*)&dummy, T.sizeof);
			empty[length] = true;
			empty[current.t] = false;

			//if (current.t >= length) {
				emptyEntries.remove(current);
			//}
			current = next;
		}
	}
	static if ((__traits(hasMember, T, "opCmp") || __traits(isScalar, T)) && __traits(hasMember, BaseVector!T, "sort")) {
		void sort() {
			compactify();
			vector.sort(length);
		}
	}
	void sort(alias SortFunc)() {
		compactify();
		vector.sort!SortFunc(length);
	}
	int opApply(scope int delegate(ref T) dg) {
		foreach (i; 0 .. length) {
			if (!empty[i]) {
				int result = dg(vector[i]);
				if (result)
					return result;
			}
		}
		return 0;
	}
	int opApplyReverse(scope int delegate(ref T) dg) {
		foreach_reverse (i; 0 .. length) {
			if (!empty[i]) {
				int result = dg(vector[i]);
				if (result)
					return result;
			}
		}
		return 0;
	}
}

unittest {
	alias PartVector(T) = PartialVector!(T, 64);
	VectorList!(PartVector, int) vl = VectorList!(PartVector, int)(3);
	vl.add(1);
	vl.add(2);
	vl.add(3);
	vl.add(4);
	foreach (i; vl) {
		writeln(i);
	}
	foreach_reverse (i; vl) {
		writeln(i);
	}
	assert(vl.vector.length == 6);
}

struct Moved {
	size_t oldId;
	size_t newId;
}

struct CompactVectorList(alias BaseVector, T) {
	BaseVector!T vector;
	alias vector this;
	size_t length;
	size_t defaultLength = 1024;
	this(size_t initialLength) {
		vector = BaseVector!T(initialLength);
		defaultLength = initialLength;
		if (initialLength != 0) {
			defaultLength = initialLength;
		} else {
			defaultLength = 1;
		}
	}
	auto ref clear() {
		//vector.renew(defaultLength);
		vector = BaseVector!T(defaultLength);
		length = 0;
		return this;
	}
	ref T add() {
		if (length >= vector.length) {
			if (vector.length == 0) {
				vector.resize(defaultLength);
			} else {
				vector.resize(vector.length * 2);
			}
		}
		length++;
		return vector[length - 1];
	}
	ref T add(lazy T t) {
		if (length >= vector.length) {
			if (vector.length == 0) {
				vector.resize(defaultLength);
			} else {
				vector.resize(vector.length * 2);
			}
		}
		length++;
		vector[length - 1] = t;
		return vector[length - 1];
	}
	size_t addId() {
		if (length >= vector.length) {
			if (vector.length == 0) {
				vector.resize(defaultLength);
			} else {
				vector.resize(vector.length * 2);
			}
		}
		length++;
		return length - 1;
	}
	size_t addId(lazy T t) {
		if (length >= vector.length) {
			if (vector.length == 0) {
				vector.resize(defaultLength);
			} else {
				vector.resize(vector.length * 2);
			}
		}
		length++;
		vector[length - 1] = t;
		return length - 1;
	}
	size_t getId(T* t) {
		return vector.getId(t);
	}
	size_t getId(ref T t) {
		return getId(&t);
	}
	// returns new id of moved
	Moved remove(size_t id) {
		vector[id].destroy();
		if (id != length - 1) {
			memcpy(cast(void*)&vector[id], cast(void*)&vector[length-1], T.sizeof);
		}
		emplace(&vector[length-1]);
		length--;
		return Moved(length, id);
	}
	// nötig falls liste aus size_t's besteht, um die richtige remove funktion auszuwählen
	Moved removeById(size_t id) {
		vector[id].destroy();
		if (id != length - 1) {
			memcpy(cast(void*)&vector[id], cast(void*)&vector[length-1], T.sizeof);
		}
		emplace(&vector[length-1]);
		length--;
		return Moved(length, id);
	}
	Moved remove(T* t) {
		return remove(getId(t));
	}
	Moved remove(ref T t) {
		return remove(&t);
	}
	void compactify() {
		vector.resize(length);
	}
	int opApply(scope int delegate(ref T) dg) {
		foreach (i; 0 .. length) {
			int result = dg(vector[i]);
			if (result)
				return result;
		}
		return 0;
	}
	int opApplyReverse(scope int delegate(ref T) dg) {
		foreach_reverse (i; 0 .. length) {
			int result = dg(vector[i]);
			if (result)
				return result;
		}
		return 0;
	}
}

struct OrderedList(alias VectorListType, T) {
	VectorListType!T list;
	alias list this;
	
	ref auto sort() {
		list.sort();
		return this;
	}
	ref auto add(lazy T t) {
		list.add(t);
		return sort();
	}
	ref auto add(Args...)(lazy Args args) {
		static foreach (i; args.length) {
			list.add(args[i]);
		}
		return sort();
	}
	ref auto addNoSort(lazy T t) {
		list.add(t);
		return this;
	}
	// remove funktion noch nötig
	ref auto remove(size_t id) {
		list.remove(id);
		list.sort();
		return this;
	}
	ref T findUnique(T t) {
		size_t id = findIndex(t);
		assert(id != size_t.max);
		return list[id];
	}
	size_t findIndex(T t) {
		size_t lowerBound = 0;
		size_t upperBound = list.length;
		if (upperBound == 0) {
			return size_t.max;
		}
		while (lowerBound != upperBound - 1) {
			size_t index = lowerBound + (upperBound - lowerBound) / 2;
			bool lower = t < list[index];
			if (lower) {
				upperBound = index;
			} else {
				lowerBound = index;
			}
			//writeln(lowerBound, " ", upperBound);
		}
		if ((t < list[lowerBound]) == (list[lowerBound] < t)) {
			return lowerBound;
		} else {
			//writeln((t < list[lowerBound]), " ", (list[lowerBound] < t), " ", lowerBound, " ", upperBound);
			return size_t.max;
		}
	}
	int opApply(scope int delegate(ref T) dg) {
		return list.opApply(dg);
	}
	int opApplyReverse(scope int delegate(ref T) dg) {
		return list.opApplyReverse(dg);
	}
}

struct Unknown {
	@disable this(ref return scope Unknown rhs);
	void* data;
	// evt für debug
	//size_t size;
	//string s;
	void delegate() destructor = null;
	this(T)(lazy T t) {
		data = malloc(T.sizeof);
		*(cast(T*)data) = t;
		static if (__traits(hasMember, T, "__xdtor") && __traits(isSame, T, __traits(parent, (cast(T*)data).__xdtor))) {
			destructor = &((cast(T*)data).__xdtor);
		}
	}
	~this() {
		if (!(destructor is null)) {
			destructor();
		}
		if (data != null) {
			free(data);
		}
	}
	ref auto get(T)() {
		return *(cast(T*)data);
	}
}

/*struct String {
	char[] s;
	@disable this(ref return scope String rhs);
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
}*/

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
	size_t[countType!(T, Args)] findTypesImpl(T, Args...)() {
		StaticArray!(size_t, countType!(T, Args)) indices;
		size_t count = 0;
		static foreach (i; 0 .. Args.length) {
			static if (is(Args[i] == T)) {
				indices[count] = i;
				count++;
			}
		}
		return indices;
	}
	enum size_t[countType!(T, Args)] findTypes = findTypesImpl!(T, Args)();
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
	@disable this(ref return scope Box rhs);
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
		this.result = result;
		if (result != successType) {
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
	ListElement!T* nextCurrent = null;
	this(ListElement!T* e) {
		current = e;
		//nextCurrent = current.next;
	}
	@property bool empty() {
		return current == null;
	}
	@property ref T front() {
		nextCurrent = current.next;
		return current.t;
	}
	@property void popFront() {
		current = nextCurrent;
	}
	@property ref T back() {
		nextCurrent = current.previous;
		return current.t;
	}
	@property void popBack() {
		current = nextCurrent;
	}
}

struct LinkedList(T) {
	uint length;
	ListElement!T* first;
	ListElement!T* last;
	@disable this(ref return scope LinkedList!T rhs);
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
	ref LinkedList!T add(ListElement!T* current) {
		if (length == 0) {
			last = current;
			first = last;
		} else {
			last.next = current;
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
	ref LinkedList!T clear() {
		while (first != null) {
			auto next = first.next;
			destroy(*first);
			free(cast(void*)first);
			first = next;
		}
		last = null;
		length = 0;
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
	ref LinkedList!T removeButNotDelete(ListElement!T* current) {
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
			length--;
		}
		return this;
	}
	ref LinkedList!T insert(uint index, lazy T t) {
		assert(index < length);
		ListElement!T* current = first;
		for (int i = 0; i < cast(int)index - 1; i++) {
			current = current.next;
		}
		if (index == 0) {
			if (first != null) {
				insertBefore(first, t);
			} else {
				add(t);
			}
		} else {
			insertAfter(current, t);
		}
		/*
		if (current != first)
		{
		ListElement!T* previousElement = current.previous;
		previousElement.next = cast(ListElement!T*) malloc(ListElement!T.sizeof);
		emplace(previousElement.next);
		previousElement.next.t = t();
		previousElement.next.previous = previousElement;
		previousElement.next.next = current;
		current.previous = previousElement.next;
		}*/
		return this;
	}
	ref LinkedList!T insertBefore(ListElement!T* current, lazy T t) {
		/*ListElement!T* previousElement = current.previous;
		previousElement.next = cast(ListElement!T*) malloc(ListElement!T.sizeof);
		emplace(previousElement.next);
		previousElement.next.t = t();
		previousElement.next.previous = previousElement;
		previousElement.next.next = current;
		current.previous = previousElement.next;
		*/
		auto previous = current.previous;
		current.previous = cast(ListElement!T*) malloc(ListElement!T.sizeof);
		emplace(current.previous);
		current.previous.t = t();
		current.previous.next = current;
		current.previous.previous = previous;
		if (previous != null) {
			previous.next = current.previous;
		} else {
			first = current.previous;
		}
		return this;
	}
	ref LinkedList!T insertAfter(ListElement!T* current, lazy T t) {
		/*ListElement!T* nextElement = current.next;
		nextElement.previous = cast(ListElement!T*) malloc(ListElement!T.sizeof);
		emplace(nextElement.previous);
		nextElement.previous.t = t();
		nextElement.previous.previous = current;
		nextElement.previous.next = nextElement;
		current.next = nextElement.previous;
		*/
		auto next = current.next;
		current.next = cast(ListElement!T*) malloc(ListElement!T.sizeof);
		emplace(current.next);
		current.next.t = t();
		current.next.previous = current;
		current.next.next = next;
		if (next != null) {
			next.previous = current.next;
		} else {
			last = current.next;
		}
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
	enum size_t length = Args.length;
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