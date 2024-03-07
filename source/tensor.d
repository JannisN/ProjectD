module tensor;

import utils;

struct Tensor(T, Args...) if (isValueCompatible!(size_t, Args)) {
	T[multiplyArgs!(Args)] data;
	ref T opCall(Args2...)(Args2 args) {
		static assert(args.length == Args.length);
		size_t index;
		static foreach (i; 0 .. args.length) {
			index += args[i] * multiplyArgs!(Args[i + 1 .. $]);
		}
		return data[index];
	}
}
