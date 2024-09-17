module tensor;

import utils;

struct Tensor(T, Args...) if (isValueCompatible!(size_t, Args)) {
	this(Args2...)(Args2 args) {
		static foreach (i; 0 .. args.length) {
			data[i] = args[i];
		}
	}
	T[multiplyArgs!(Args)] data;
	ref T opCall(Args2...)(Args2 args) const {
		static assert(args.length == Args.length);
		size_t index;
		static foreach (i; 0 .. args.length) {
			index += args[i] * multiplyArgs!(Args[i + 1 .. $]);
		}
		return cast(T)data[index];
	}
}
