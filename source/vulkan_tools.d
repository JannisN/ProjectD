module vulkan_tools;

import utils;
import vulkan_core;
import functions;
import vulkan;

struct AllocatorListEntry {
	VkDeviceSize offset;
	VkDeviceSize length;
}

struct AllocatorExtension {
	//string name;
	VkStructureType structureType;
	Vector!byte data;
	int opCmp(ref const AllocatorExtension ae) const {
		return structureType < ae.structureType;
        /*if (name.length == 0 || ae.name.length == 0) {
            return -1;
        }
        return strcmp(name.ptr, ae.name.ptr);*/
    }
}

struct AllocatorList {
	Memory memory;
	VkDeviceSize size;
	uint heap;
	LinkedList!AllocatorListEntry entries;
    alias ToList(T) = VectorList!(Vector, T);
	OrderedList!(ToList, AllocatorExtension) extensions;
	this(Nexts...)(lazy Memory memory, VkDeviceSize size, uint heap, Nexts nexts) {
		this.memory = memory;
		this.size = size;
		this.heap = heap;
		static foreach (i; 0 .. Nexts.length) {
			extensions.addNoSort(AllocatorExtension(nexts[i].sType, Vector!byte((cast(byte*)&nexts[i])[0 .. Nexts[i].sizeof])));
		}
		extensions.sort();
	}
	// return true = wurde allocated
	// aufteilen in zwei funktionen: zuerst bei allen AllocatorLists prüfen ob am schluss noch platz ist, sonst auf lücken überprüfen, wegen performance
	// vlt auch die gelöschten entries als geordnete(nach grösse) liste abspeichern um schnell einen platz zu finden,
	// macht dann keinen sinn mehr: // die indices sollten ersetzt werden durch pointer zu den entries für performance
	bool tryAllocate(VkDeviceSize requiredSize, VkDeviceSize alignment) {
		if (entries.last != null) {
			if (size - getCorrectOffset(entries.last.t.offset + entries.last.t.length, alignment) >= requiredSize) {
				entries.add(AllocatorListEntry(getCorrectOffset(entries.last.t.offset + entries.last.t.length, alignment), requiredSize));
				return true;
			}
			if (entries.first.offset >= requiredSize) {
				entries.insert(0, AllocatorListEntry(0, requiredSize));
				return true;
			}
			int i = 0;
			for (auto e = entries.iterate(); !e.empty; e.popFront) {
				i++;
				if (e.current != entries.last) {
					if (e.current.next.t.offset - getCorrectOffset(e.current.t.offset + e.current.t.length, alignment) >= requiredSize) {
						entries.insert(i, AllocatorListEntry(getCorrectOffset(e.current.t.offset + e.current.t.length, alignment), requiredSize));
						return true;
					}
				}
			}
			return false;
		} else {
			if (size >= requiredSize) {
				entries.add(AllocatorListEntry(0, requiredSize));
				return true;
			} else {
				return false;
			}
		}
	}
	bool tryAllocate(VkDeviceSize requiredSize, VkDeviceSize alignment, ref AllocatedMemory allocatedMemory) {
		if (entries.last != null) {
			if (size - getCorrectOffset(entries.last.t.offset + entries.last.t.length, alignment) >= requiredSize) {
				entries.add(AllocatorListEntry(getCorrectOffset(entries.last.t.offset + entries.last.t.length, alignment), requiredSize));
				allocatedMemory.allocatorList = &this;
				allocatedMemory.allocation = entries.last;
				return true;
			}
			if (entries.first.offset >= requiredSize) {
				entries.insert(0, AllocatorListEntry(0, requiredSize));
				allocatedMemory.allocatorList = &this;
				allocatedMemory.allocation = entries.first;
				return true;
			}
			int i = 0;
			for (auto e = entries.iterate(); !e.empty; e.popFront) {
				i++;
				if (e.current != entries.last) {
					if (e.current.next.t.offset - getCorrectOffset(e.current.t.offset + e.current.t.length, alignment) >= requiredSize) {
						//entries.insert(i, AllocatorListEntry(e.current.t.offset + e.current.t.length, requiredSize));
						entries.insertAfter(e.current, AllocatorListEntry(getCorrectOffset(e.current.t.offset + e.current.t.length, alignment), requiredSize));
						allocatedMemory.allocatorList = &this;
						//allocatedMemory.allocation = entries.get(i);
						allocatedMemory.allocation = e.current.next;
						return true;
					}
				}
			}
			return false;
		} else {
			if (size >= requiredSize) {
				entries.add(AllocatorListEntry(0, requiredSize));
				allocatedMemory.allocatorList = &this;
				allocatedMemory.allocation = entries.first;
				return true;
			} else {
				return false;
			}
		}
	}
	void deallocate(uint index) {
		entries.remove(index);
	}
	VkDeviceSize getCorrectOffset(VkDeviceSize offset, VkDeviceSize alignment) {
		if (offset % alignment == 0) {
			return offset;
		} else {
			return offset + alignment - (offset % alignment);
		}
	}
}

enum AllocationStrategy {
	fast,
	dense
}

struct AllocatedMemory {
	AllocatorList* allocatorList;
	ListElement!AllocatorListEntry* allocation;
}

struct AllocatedResource(T) {
	T t;
	AllocatedMemory allocatedMemory;
	alias t this;
	@disable this(ref return scope AllocatedResource!T rhs);
	this(lazy T resource) {
		t = resource;
	}
	~this() {
		deallocate();
	}
	void deallocate() {
		if (allocatedMemory.allocatorList != null)
			allocatedMemory.allocatorList.entries.remove(allocatedMemory.allocation);
	}
}

// unbedingt auf fehler überprüfen, da speicher voll sein kann
// allocation strategy fast hinzufügen
struct MemoryAllocator {
	Device* device;
	AllocationStrategy allocationStrategy;
	LinkedList!AllocatorList allocations;
	VkDeviceSize defaultAllocationSize = 100_000_000;
	AllocatedMemory allocate(Nexts...)(uint heap, VkDeviceSize requiredSize, VkDeviceSize alignment, Nexts nexts) {
		AllocatedMemory allocatedMemory;
		AllocationsForeach: foreach (ref e; allocations.iterate()) {
			if (e.heap == heap) {
				if (Nexts.length == e.extensions.length) {
					static foreach (i; 0 .. Nexts.length) {
						size_t index = e.extensions.findIndex(AllocatorExtension(nexts[i].sType));
						if (index == size_t.max) {
							continue AllocationsForeach;
						}
						if (memcmp(cast(void*)e.extensions[index].data.ptr, cast(void*)&nexts[i], e.extensions[index].data.length) != 0) {
							continue AllocationsForeach;
						}
					}
					if (e.tryAllocate(requiredSize, alignment, allocatedMemory)) {
						return allocatedMemory;
					}
				}
			}
		}
		if (requiredSize <= defaultAllocationSize) {
			allocations.add(AllocatorList(device.allocateMemory(defaultAllocationSize, heap, nexts), defaultAllocationSize, heap, nexts));
			allocations.last.tryAllocate(requiredSize, alignment, allocatedMemory);
		} else {
			allocations.add(AllocatorList(device.allocateMemory(requiredSize, heap, nexts), requiredSize, heap, nexts));
			allocations.last.tryAllocate(requiredSize, alignment, allocatedMemory);
		}
		return allocatedMemory;
	}
	void allocate(Nexts...)(ref AllocatedResource!Buffer buffer, VkMemoryPropertyFlags flags, Nexts nexts) {
		buffer.allocatedMemory = allocate(buffer.chooseHeap(flags), buffer.getMemoryRequirements().size, buffer.getMemoryRequirements().alignment, nexts);
		buffer.bind(buffer.allocatedMemory.allocatorList.memory, buffer.allocatedMemory.allocation.t.offset);
	}
	void allocateAligned(Nexts...)(ref AllocatedResource!Buffer buffer, VkMemoryPropertyFlags flags, VkDeviceSize alignment, Nexts nexts) {
		if (alignment > buffer.getMemoryRequirements().alignment) {
			buffer.allocatedMemory = allocate(buffer.chooseHeap(flags), buffer.getMemoryRequirements().size, alignment, nexts);
		} else {
			buffer.allocatedMemory = allocate(buffer.chooseHeap(flags), buffer.getMemoryRequirements().size, buffer.getMemoryRequirements().alignment, nexts);
		}
		buffer.bind(buffer.allocatedMemory.allocatorList.memory, buffer.allocatedMemory.allocation.t.offset);
	}
	void allocate(Nexts...)(ref AllocatedResource!Image image, VkMemoryPropertyFlags flags, Nexts nexts) {
		image.allocatedMemory = allocate(image.chooseHeap(flags), image.getMemoryRequirements().size, image.getMemoryRequirements().alignment, nexts);
		image.bind(image.allocatedMemory.allocatorList.memory, image.allocatedMemory.allocation.t.offset);
	}
}

struct ShaderListIndex(T) {
	uint index;
}
// auch eine version später wo die elemente verlinkt sind, zb. für ein lattice um raytracing zu beschleunigen pro gitterelemt eine referenz zur einer liste im buffer
// der unterschied zu dieser version wäre dann zb. dass beim löschen eines elements ein neuer link erzeugt werden muss
// vlt später auch die option statt uint ulong, falls 64 bit auf gpu nötig
struct ShaderList(T, bool withCount = true) {
	static if (withCount) {
		enum size_t countOffset = uint.sizeof;
	} else {
		enum size_t countOffset = 0;
	}
	Device* device;
	MemoryAllocator* memoryAllocator;
	uint maxLength;
	uint length;
	AllocatedResource!Buffer cpuBuffer;
	AllocatedResource!Buffer gpuBuffer;
	Memory* cpuMemory;
	Memory* gpuMemory;
	Vector!size_t entities = void;
	VkBufferUsageFlags localFlags;
	VkBufferUsageFlags deviceFlags;
	VkMemoryAllocateFlagsInfo* localAllocFlags;
	VkMemoryAllocateFlagsInfo* deviceAllocFlags;
	AllocatedResource!Buffer oldGpuBuffer;
	this(ref Device device, ref MemoryAllocator memoryAllocator, uint maxLength) {
		this(device, memoryAllocator, maxLength, 0, 0, null, null);
	}
	this(ref Device device, ref MemoryAllocator memoryAllocator, uint maxLength, VkBufferUsageFlags localFlags, VkBufferUsageFlags deviceFlags, VkMemoryAllocateFlagsInfo* localAllocFlags, VkMemoryAllocateFlagsInfo* deviceAllocFlags) {
		this.device = &device;
		this.memoryAllocator = &memoryAllocator;
		this.maxLength = maxLength;
		entities = Vector!size_t(maxLength);
		cpuBuffer = AllocatedResource!Buffer(device.createBuffer(0, getMemorySize(), localFlags | VkBufferUsageFlagBits.VK_BUFFER_USAGE_TRANSFER_SRC_BIT));
		gpuBuffer = AllocatedResource!Buffer(device.createBuffer(0, getMemorySize(), deviceFlags | VkBufferUsageFlagBits.VK_BUFFER_USAGE_TRANSFER_DST_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_TRANSFER_SRC_BIT));

		this.localFlags = localFlags;
		this.deviceFlags = deviceFlags;
		this.localAllocFlags = localAllocFlags;
		this.deviceAllocFlags = deviceAllocFlags;
		if (localAllocFlags == null) {
			memoryAllocator.allocate(cpuBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT);
		} else {
			memoryAllocator.allocate(cpuBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT, *localAllocFlags);
		}
		if (deviceAllocFlags == null) {
			// aligned für VkDeviceAddress
			memoryAllocator.allocateAligned(gpuBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, cast(VkDeviceSize)16);
		} else {
			memoryAllocator.allocateAligned(gpuBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, cast(VkDeviceSize)16, *deviceAllocFlags);
		}
		cpuMemory = &cpuBuffer.allocatedMemory.allocatorList.memory;
		gpuMemory = &gpuBuffer.allocatedMemory.allocatorList.memory;
	}
	VkDeviceSize getMemorySize() {
		return T.sizeof * maxLength + countOffset;
	}
	VkDeviceSize getOffset(string member)() {
		T t;
		mixin("return -&t + &" ~ "t." ~ member ~ ";");
	}
	VkDeviceSize getSize(string member)() {
		mixin("return typeof(t." ~ member ~ ").sizeof");
	}
	void update(Ecs)(ref Ecs ecs, ref CommandBuffer cmdBuffer) {
		// wichtig: es muss nicht alles gemapt und geupdatet werden, nur das was verändert wurde! oder ist das schon so richtig wie es jetzt ist?
		// vlt. sollte man auch überprüfen wegen 2 updates beim gleichen element in bezug auf editUpdateList. oder ist das auch schon korrekt, da die updates auch vom element her verlinkt sind?
		void* mappedMemory = cpuMemory.map(cpuBuffer.allocatedMemory.allocation.offset, getMemorySize());
		uint updateRangeCount = 0;
		uint* tCount = cast(uint*) mappedMemory;
		T* t = cast(T*) (mappedMemory + uint.sizeof);
		size_t oldLength = length;
		static if (ecs.hasRemoveUpdateList!T) {
			foreach (ref e; ecs.getRemoveUpdateList!T.iterate()) {
				// könnte problem geben wenn id für ein neues objekt verwendet wird
				if (ecs.entities[e.id].has!(ShaderListIndex!T)()) {
					ecs.entities[e.id].remove!(ShaderListIndex!T)();
				}
			}
		}
		static if (ecs.hasAddUpdateList!T) {
			foreach (e; ecs.getAddUpdateList!T.iterate()) {
				ecs.entities[e].add!(ShaderListIndex!T)(ShaderListIndex!T(length));
				t[length] = ecs.entities[e].getWithoutUpdate!T();
				entities[length] = e;
				length++;
				updateRangeCount++;
			}
		}
		static if (ecs.hasEditUpdateList!T) {
			foreach (e; ecs.getEditUpdateList!T.iterate()) {
				uint shaderListIndex = ecs.entities[e].get!(ShaderListIndex!T)().index;
				t[shaderListIndex] = ecs.entities[e].getWithoutUpdate!T();
				updateRangeCount++;
			}
		}
		static foreach (E; typeof(ecs).GetUpdatesOfType!T) {
			foreach (ref e; ecs.getUpdateList!(T, E[1]).iterate()) {
				uint shaderListIndex = ecs.entities[e].get!(ShaderListIndex!T)().index;
				//t[shaderListIndex] = ecs.entities[e].getWithoutUpdate!T();
				mixin("t[shaderListIndex]." ~ E[1] ~ " = ecs.entities[e].getWithoutUpdate!T()." ~ E[1] ~ ";");
				updateRangeCount++;
			}
		}
		static if (ecs.hasRemoveUpdateList!(ShaderListIndex!T)) {
			foreach (ref e; ecs.getRemoveUpdateList!(ShaderListIndex!T).iterate()) {
				uint shaderListIndex = e.get().index;
				if (shaderListIndex != length - 1) {
					t[shaderListIndex] = t[length - 1];
					entities[shaderListIndex] = entities[length - 1];
					ecs.entities[entities[shaderListIndex]].get!(ShaderListIndex!T).index = shaderListIndex;
					updateRangeCount++;
				}
				length--;
			}
		}
		static if (withCount) {
			*tCount = length;
		}
		cpuMemory.flush(array(mappedMemoryRange(*cpuMemory, cpuBuffer.allocatedMemory.allocation.offset, VK_WHOLE_SIZE)));
		cpuMemory.unmap();
		Vector!VkBufferCopy copies = Vector!VkBufferCopy(updateRangeCount);
		size_t copyIndex = 0;
		static if (ecs.hasAddUpdateList!T) {
			foreach (e; ecs.getAddUpdateList!T.iterate()) {
				uint shaderListIndex = ecs.entities[e].get!(ShaderListIndex!T)().index;
				copies[copyIndex] = VkBufferCopy(uint.sizeof + T.sizeof * shaderListIndex, uint.sizeof + T.sizeof * shaderListIndex, T.sizeof);
				copyIndex++;
			}
		}
		static if (ecs.hasEditUpdateList!T) {
			foreach (e; ecs.getEditUpdateList!T.iterate()) {
				uint shaderListIndex = ecs.entities[e].get!(ShaderListIndex!T)().index;
				copies[copyIndex] = VkBufferCopy(uint.sizeof + T.sizeof * shaderListIndex, uint.sizeof + T.sizeof * shaderListIndex, T.sizeof);
				copyIndex++;
			}
		}
		// noch ungetestet
		static foreach (E; typeof(ecs).GetUpdatesOfType!T) {
			foreach (ref e; ecs.getUpdateList!(T, E[1]).iterate()) {
				uint shaderListIndex = ecs.entities[e].get!(ShaderListIndex!T)().index;
				copies[copyIndex] = VkBufferCopy(uint.sizeof + T.sizeof * shaderListIndex + getOffset!(E[1])(), uint.sizeof + T.sizeof * shaderListIndex + getOffset!(E[1])(), getSize!(E[1])());
				copyIndex++;
			}
		}
		static if (ecs.hasRemoveUpdateList!(ShaderListIndex!T)) {
			foreach (ref e; ecs.getRemoveUpdateList!(ShaderListIndex!T).iterate()) {
				uint shaderListIndex = e.get().index;
				if (shaderListIndex < length) {
					copies[copyIndex] = VkBufferCopy(uint.sizeof + T.sizeof * shaderListIndex, uint.sizeof + T.sizeof * shaderListIndex, T.sizeof);
					copyIndex++;
				}
			}
		}
		static if (withCount) {
			if (oldLength != length) {
				cmdBuffer.copyBuffer(cpuBuffer, 0, gpuBuffer, 0, uint.sizeof);
			}
		}
		if (updateRangeCount > 0) {
			cmdBuffer.copyBuffer(cpuBuffer, gpuBuffer, copies);
		}
		static if (ecs.hasAddUpdateList!T) {
			ecs.clearAddUpdateList!T();
		}
		static if (ecs.hasEditUpdateList!T) {
			ecs.clearEditUpdateList!T();
		}
		static if (ecs.hasRemoveUpdateList!T) {
			ecs.clearRemoveUpdateList!T();
		}
		static if (ecs.hasRemoveUpdateList!(ShaderListIndex!T)) {
			ecs.clearRemoveUpdateList!(ShaderListIndex!T)();
		}
		static foreach (E; typeof(ecs).GetUpdatesOfType!T) {
			ecs.clearUpdateList!(T, E[1])();
		}
	}
	void update2(Ecs)(ref Ecs ecs, ref CommandBuffer cmdBuffer, bool clearLists = true) {
		oldGpuBuffer.destroy();
		void* mappedMemory = cpuMemory.map(cpuBuffer.allocatedMemory.allocation.offset, getMemorySize());
		uint updateRangeCount = 0;
		uint* tCount = cast(uint*) mappedMemory;
		T* t = cast(T*) (mappedMemory + countOffset);
		size_t oldLength = length;
		static if (ecs.hasAddUpdateList!T()) {
			int newLength;
			static if (ecs.hasRemoveUpdateList!T) {
				newLength = length + cast(uint) ecs.getAddUpdateList!T().length - cast(uint) ecs.getRemoveUpdateList!T().length;
			} else {
				newLength = length + cast(uint) ecs.getAddUpdateList!T().length;
			}
			if (newLength > maxLength) {
				uint newMaxLength = newLength * 2;
				VkDeviceSize newBufferSize = T.sizeof * newMaxLength + countOffset;
				auto newCpuBuffer = AllocatedResource!Buffer(device.createBuffer(0, newBufferSize, localFlags | VkBufferUsageFlagBits.VK_BUFFER_USAGE_TRANSFER_SRC_BIT));
				auto newGpuBuffer = AllocatedResource!Buffer(device.createBuffer(0, newBufferSize, deviceFlags | VkBufferUsageFlagBits.VK_BUFFER_USAGE_TRANSFER_DST_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_TRANSFER_SRC_BIT));

				if (localAllocFlags == null) {
					memoryAllocator.allocate(newCpuBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT);
				} else {
					memoryAllocator.allocate(newCpuBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT, *localAllocFlags);
				}
				if (deviceAllocFlags == null) {
					memoryAllocator.allocate(newGpuBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
				} else {
					memoryAllocator.allocate(newGpuBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, *deviceAllocFlags);
				}

				// beide buffer kopieren
				Vector!byte cp = Vector!byte(cast(size_t) getMemorySize());
				memcpy(cast(void*)cp.data(), mappedMemory, getMemorySize());
				cpuMemory.unmap();
				cpuMemory = &newCpuBuffer.allocatedMemory.allocatorList.memory;
				mappedMemory = cpuMemory.map(newCpuBuffer.allocatedMemory.allocation.offset, newBufferSize);
				memcpy(mappedMemory, cast(void*)cp.data(), getMemorySize());
				cmdBuffer.copyBuffer(gpuBuffer, 0, newGpuBuffer, 0, getMemorySize());
				gpuMemory = &newGpuBuffer.allocatedMemory.allocatorList.memory;

				oldGpuBuffer = move(gpuBuffer);
				gpuBuffer = move(newGpuBuffer);
				cpuBuffer = move(newCpuBuffer);
				maxLength = newMaxLength;
				entities.resize(newMaxLength);

				tCount = cast(uint*) mappedMemory;
				t = cast(T*) (mappedMemory + countOffset);
				// sicherstellen dass gpubuffer fertig kopiert ist bevor der nächste buffer kopiert wird, pipelinebarrier nötig?
			}
		}
		// was passiert wenn man zwischen updates ein element hinzufügt und wieder entfernt? sollte überprüft werden
		static if (ecs.hasRemoveUpdateList!T()) {
			foreach (id; ecs.getRemoveIdsList!T()) {
				// ? könnte problem geben wenn id für ein neues objekt verwendet wird
				if (ecs.entityHas!(ShaderListIndex!T)(id)) {
					ecs.removeComponent!(ShaderListIndex!T)(id);
				}
			}
		}
		static if (ecs.hasRemoveUpdateList!(ShaderListIndex!T)()) {
			foreach (e; ecs.getRemoveUpdateList!(ShaderListIndex!T)()) {
				uint shaderListIndex = e.index;
				if (shaderListIndex != length - 1) {
					t[shaderListIndex] = t[length - 1];
					entities[shaderListIndex] = entities[length - 1];
					if (ecs.entityHas!(ShaderListIndex!T)(entities[shaderListIndex])) {
						ecs.getComponent!(ShaderListIndex!T)(entities[shaderListIndex]).index = shaderListIndex;
					}
					updateRangeCount++;
				}
				length--;
			}
		}
		static if (ecs.hasAddUpdateList!T()) {
			foreach (id; ecs.getAddUpdateList!T()) {
				ecs.addComponent!(ShaderListIndex!T)(id, ShaderListIndex!T(length));
				t[length] = ecs.getForced!T(id);
				entities[length] = id;
				length++;
				updateRangeCount++;
			}
		}
		static if (ecs.hasGeneralUpdateList!T()) {
			foreach (id; ecs.getGeneralUpdateList!T()) {
				uint shaderListIndex = ecs.getComponent!(ShaderListIndex!T)(id).index;
				t[shaderListIndex] = ecs.getForced!T(id);
				updateRangeCount++;
			}
		}
		// noch ungetestet
		static foreach (i, Component; typeof(ecs).SpecificUpdatesOnlyComponents) {
			static if (is (typeof(ecs).SpecificUpdatesOnlyComponents[i] == T)) {
				foreach (id; ecs.specificUpdates[i]) {
					uint shaderListIndex = ecs.getComponent!(ShaderListIndex!T)(id).index;
					//t[shaderListIndex] = ecs.entities[e].getWithoutUpdate!T();
					mixin("t[shaderListIndex]." ~ typeof(ecs).TemplateSpecificUpdates.TypeSeq[i].TypeSeq[1] ~ " = ecs.getForced!T(" ~ "id" ~ ")." ~ typeof(ecs).TemplateSpecificUpdates.TypeSeq[i].TypeSeq[1] ~ ";");
					updateRangeCount++;
				}
			}
		}
		static if (withCount) {
			*tCount = length;
		}
		// hier vlt nicht whole size? oder ist das egal wegen performance?
		cpuMemory.flush(array(mappedMemoryRange(*cpuMemory, cpuBuffer.allocatedMemory.allocation.offset, VK_WHOLE_SIZE)));
		cpuMemory.unmap();
		Vector!VkBufferCopy copies = Vector!VkBufferCopy(updateRangeCount);
		size_t copyIndex = 0;
		static if (ecs.hasAddUpdateList!T()) {
			foreach (id; ecs.getAddUpdateList!T()) {
				uint shaderListIndex = ecs.getComponent!(ShaderListIndex!T)(id).index;
				copies[copyIndex] = VkBufferCopy(countOffset + T.sizeof * shaderListIndex, countOffset + T.sizeof * shaderListIndex, T.sizeof);
				copyIndex++;
			}
		}
		static if (ecs.hasGeneralUpdateList!T()) {
			foreach (id; ecs.getGeneralUpdateList!T()) {
				uint shaderListIndex = ecs.getComponent!(ShaderListIndex!T)(id).index;
				copies[copyIndex] = VkBufferCopy(countOffset + T.sizeof * shaderListIndex, countOffset + T.sizeof * shaderListIndex, T.sizeof);
				copyIndex++;
			}
		}
		// noch ungetestet
		static foreach (i, Component; typeof(ecs).SpecificUpdatesOnlyComponents) {
			static if (is (typeof(ecs).SpecificUpdatesOnlyComponents[i] == T)) {
				foreach (id; ecs.specificUpdates[i]) {
					uint shaderListIndex = ecs.getComponent!(ShaderListIndex!T)(id).index;
					copies[copyIndex] = VkBufferCopy(countOffset + T.sizeof * shaderListIndex + getOffset!(typeof(ecs).TemplateSpecificUpdates.TypeSeq[i].TypeSeq[1])(), countOffset + T.sizeof * shaderListIndex + getOffset!(typeof(ecs).TemplateSpecificUpdates.TypeSeq[i].TypeSeq[1])(), getSize!(typeof(ecs).TemplateSpecificUpdates.TypeSeq[i].TypeSeq[1])());
				}
			}
		}
		static if (ecs.hasRemoveUpdateList!(ShaderListIndex!T)()) {
			foreach (e; ecs.getRemoveUpdateList!(ShaderListIndex!T)()) {
				uint shaderListIndex = e.index;
				if (shaderListIndex < length) {
					copies[copyIndex] = VkBufferCopy(countOffset + T.sizeof * shaderListIndex, countOffset + T.sizeof * shaderListIndex, T.sizeof);
					copyIndex++;
				}
			}
		}
		static if (withCount) {
			if (oldLength != length) {
				cmdBuffer.copyBuffer(cpuBuffer, 0, gpuBuffer, 0, uint.sizeof);
			}
		}
		if (updateRangeCount > 0) {
			cmdBuffer.copyBuffer(cpuBuffer, gpuBuffer, copies);
		}
		if (clearLists) {
			static if (ecs.hasAddUpdateList!T()) {
				ecs.clearAddUpdateList!T();
			}
			static if (ecs.hasGeneralUpdateList!T()) {
				ecs.clearGeneralUpdateList!T();
			}
			static if (ecs.hasRemoveUpdateList!T()) {
				ecs.clearRemoveUpdateList!T();
			}
			static foreach (i, Component; typeof(ecs).SpecificUpdatesOnlyComponents) {
				static if (is (typeof(ecs).SpecificUpdatesOnlyComponents[i] == T)) {
					ecs.clearSpecificUpdateList!(T, typeof(ecs).TemplateSpecificUpdates.TypeSeq[i].TypeSeq[1]);
				}
			}
		}
		static if (ecs.hasRemoveUpdateList!(ShaderListIndex!T)()) {
			ecs.clearRemoveUpdateList!(ShaderListIndex!T)();
		}
	}
}

struct Tlas {
	AllocatedResource!Buffer tlasBuffer;
	AccelerationStructure tlas;
	AllocatedResource!Buffer scratchBuffer;
	Device* device;
	MemoryAllocator* memoryAllocator;
	this(ref Device device, ref MemoryAllocator memoryAllocator) {
		this.device = &device;
		this.memoryAllocator = &memoryAllocator;
	}
	void create(VkDeviceAddress address, uint length) {
		VkAccelerationStructureGeometryInstancesDataKHR instancesData;
		instancesData.sType = VkStructureType.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_INSTANCES_DATA_KHR;
		instancesData.arrayOfPointers = VK_FALSE;
		instancesData.data.deviceAddress = address;

		VkAccelerationStructureGeometryKHR geometry;
		geometry.sType = VkStructureType.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_KHR;
		geometry.geometryType = VkGeometryTypeKHR.VK_GEOMETRY_TYPE_INSTANCES_KHR;
		geometry.geometry.instances = instancesData;

		VkAccelerationStructureBuildGeometryInfoKHR buildInfo;
		buildInfo.sType = VkStructureType.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_BUILD_GEOMETRY_INFO_KHR;
		buildInfo.flags = VkBuildAccelerationStructureFlagBitsKHR.VK_BUILD_ACCELERATION_STRUCTURE_PREFER_FAST_TRACE_BIT_KHR | VkBuildAccelerationStructureFlagBitsKHR.VK_BUILD_ACCELERATION_STRUCTURE_ALLOW_UPDATE_BIT_KHR;
		buildInfo.geometryCount = 1;
		buildInfo.pGeometries = &geometry;
		buildInfo.mode = VkBuildAccelerationStructureModeKHR.VK_BUILD_ACCELERATION_STRUCTURE_MODE_BUILD_KHR;
		buildInfo.type = VkAccelerationStructureTypeKHR.VK_ACCELERATION_STRUCTURE_TYPE_TOP_LEVEL_KHR;
		buildInfo.srcAccelerationStructure = cast(VkAccelerationStructureKHR_T*)VK_NULL_HANDLE;

		VkAccelerationStructureBuildRangeInfoKHR rangeInfo;
		rangeInfo.firstVertex = 0;
		rangeInfo.primitiveCount = length;
		rangeInfo.primitiveOffset = 0;
		rangeInfo.transformOffset = 0;

		VkAccelerationStructureBuildSizesInfoKHR sizeInfo = device.getAccelerationStructureBuildSizesKHR(
			VkAccelerationStructureBuildTypeKHR.VK_ACCELERATION_STRUCTURE_BUILD_TYPE_DEVICE_KHR,
			&buildInfo,
			&rangeInfo.primitiveCount
		);
		tlasBuffer = AllocatedResource!Buffer(device.createBuffer(0, sizeInfo.accelerationStructureSize, VkBufferUsageFlagBits.VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_STORAGE_BIT_KHR));
		VkMemoryAllocateFlagsInfo flagsInfo;
		flagsInfo.sType = VkStructureType.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_FLAGS_INFO;
		flagsInfo.flags = VkMemoryAllocateFlagBits.VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT;
		memoryAllocator.allocate(tlasBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, flagsInfo);
		tlas = device.createAccelerationStructure(buildInfo.type, sizeInfo.accelerationStructureSize, 0, tlasBuffer.buffer, 0);

		VkPhysicalDeviceAccelerationStructurePropertiesKHR accProperties;
		accProperties.sType = VkStructureType.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ACCELERATION_STRUCTURE_PROPERTIES_KHR;
		VkPhysicalDeviceProperties2 properties;
		properties.sType = VkStructureType.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2;
		properties.pNext = cast(void*) &accProperties;
		device.physicalDevice.getProperties(&properties);
		scratchBuffer = AllocatedResource!Buffer(device.createBuffer(0, sizeInfo.buildScratchSize + accProperties.minAccelerationStructureScratchOffsetAlignment, VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT));
		memoryAllocator.allocate(scratchBuffer, VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, flagsInfo);
	}
	void recreate(VkDeviceAddress address, uint length) {
		tlas.destroy();
		tlasBuffer.destroy();
		this.create(address, length);
	}
	void build(VkDeviceAddress address, uint length, ref CommandBuffer cmdBuffer) {
		VkAccelerationStructureGeometryInstancesDataKHR instancesData;
		instancesData.sType = VkStructureType.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_INSTANCES_DATA_KHR;
		instancesData.arrayOfPointers = VK_FALSE;
		instancesData.data.deviceAddress = address;

		VkAccelerationStructureGeometryKHR geometry;
		geometry.sType = VkStructureType.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_KHR;
		geometry.geometryType = VkGeometryTypeKHR.VK_GEOMETRY_TYPE_INSTANCES_KHR;
		geometry.geometry.instances = instancesData;

		VkAccelerationStructureBuildGeometryInfoKHR buildInfo;
		buildInfo.sType = VkStructureType.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_BUILD_GEOMETRY_INFO_KHR;
		buildInfo.flags = VkBuildAccelerationStructureFlagBitsKHR.VK_BUILD_ACCELERATION_STRUCTURE_PREFER_FAST_TRACE_BIT_KHR | VkBuildAccelerationStructureFlagBitsKHR.VK_BUILD_ACCELERATION_STRUCTURE_ALLOW_UPDATE_BIT_KHR;
		buildInfo.geometryCount = 1;
		buildInfo.pGeometries = &geometry;
		buildInfo.mode = VkBuildAccelerationStructureModeKHR.VK_BUILD_ACCELERATION_STRUCTURE_MODE_BUILD_KHR;
		buildInfo.type = VkAccelerationStructureTypeKHR.VK_ACCELERATION_STRUCTURE_TYPE_TOP_LEVEL_KHR;
		buildInfo.srcAccelerationStructure = cast(VkAccelerationStructureKHR_T*)VK_NULL_HANDLE;
		buildInfo.dstAccelerationStructure = tlas;

		VkAccelerationStructureBuildRangeInfoKHR rangeInfo;
		rangeInfo.firstVertex = 0;
		rangeInfo.primitiveCount = length;
		rangeInfo.primitiveOffset = 0;
		rangeInfo.transformOffset = 0;

		VkPhysicalDeviceAccelerationStructurePropertiesKHR accProperties;
		accProperties.sType = VkStructureType.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ACCELERATION_STRUCTURE_PROPERTIES_KHR;
		VkPhysicalDeviceProperties2 properties;
		properties.sType = VkStructureType.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2;
		properties.pNext = cast(void*) &accProperties;
		device.physicalDevice.getProperties(&properties);
		VkDeviceAddress da = scratchBuffer.getDeviceAddress();
		size_t daOffset = (accProperties.minAccelerationStructureScratchOffsetAlignment - (da % accProperties.minAccelerationStructureScratchOffsetAlignment)) % accProperties.minAccelerationStructureScratchOffsetAlignment;
		buildInfo.scratchData.deviceAddress = scratchBuffer.getDeviceAddress() + daOffset;

		cmdBuffer.buildAccelerationStructures((&buildInfo)[0..1], array(&rangeInfo));
	}
	void update(VkDeviceAddress address, uint length, ref CommandBuffer cmdBuffer) {
		VkAccelerationStructureGeometryInstancesDataKHR instancesData;
		instancesData.sType = VkStructureType.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_INSTANCES_DATA_KHR;
		instancesData.arrayOfPointers = VK_FALSE;
		instancesData.data.deviceAddress = address;

		VkAccelerationStructureGeometryKHR geometry;
		geometry.sType = VkStructureType.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_KHR;
		geometry.geometryType = VkGeometryTypeKHR.VK_GEOMETRY_TYPE_INSTANCES_KHR;
		geometry.geometry.instances = instancesData;

		VkAccelerationStructureBuildGeometryInfoKHR buildInfo;
		buildInfo.sType = VkStructureType.VK_STRUCTURE_TYPE_ACCELERATION_STRUCTURE_BUILD_GEOMETRY_INFO_KHR;
		buildInfo.flags = VkBuildAccelerationStructureFlagBitsKHR.VK_BUILD_ACCELERATION_STRUCTURE_PREFER_FAST_TRACE_BIT_KHR | VkBuildAccelerationStructureFlagBitsKHR.VK_BUILD_ACCELERATION_STRUCTURE_ALLOW_UPDATE_BIT_KHR;
		buildInfo.geometryCount = 1;
		buildInfo.pGeometries = &geometry;
		buildInfo.mode = VkBuildAccelerationStructureModeKHR.VK_BUILD_ACCELERATION_STRUCTURE_MODE_UPDATE_KHR;
		buildInfo.type = VkAccelerationStructureTypeKHR.VK_ACCELERATION_STRUCTURE_TYPE_TOP_LEVEL_KHR;
		buildInfo.srcAccelerationStructure = tlas;
		buildInfo.dstAccelerationStructure = tlas;

		VkAccelerationStructureBuildRangeInfoKHR rangeInfo;
		rangeInfo.firstVertex = 0;
		rangeInfo.primitiveCount = length;
		rangeInfo.primitiveOffset = 0;
		rangeInfo.transformOffset = 0;

		VkPhysicalDeviceAccelerationStructurePropertiesKHR accProperties;
		accProperties.sType = VkStructureType.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ACCELERATION_STRUCTURE_PROPERTIES_KHR;
		VkPhysicalDeviceProperties2 properties;
		properties.sType = VkStructureType.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2;
		properties.pNext = cast(void*) &accProperties;
		device.physicalDevice.getProperties(&properties);
		VkDeviceAddress da = scratchBuffer.getDeviceAddress();
		size_t daOffset = (accProperties.minAccelerationStructureScratchOffsetAlignment - (da % accProperties.minAccelerationStructureScratchOffsetAlignment)) % accProperties.minAccelerationStructureScratchOffsetAlignment;
		buildInfo.scratchData.deviceAddress = scratchBuffer.getDeviceAddress() + daOffset;

		cmdBuffer.buildAccelerationStructures((&buildInfo)[0..1], array(&rangeInfo));
	}
}