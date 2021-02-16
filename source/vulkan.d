module vk;

import utils;
import vulkan_core;
import std.stdio;

// erledigt --- todo: copy constructor für alle structs entfernen
// evt alle vk pointer durch die struct pointer ersetzen
// aber bei den parametern VkStructs statt den ref structs
// evt. alle hilfsstructs durch funktionen ersetzen falls möglich(dort wo kein typ gespeichert wertden muss). vlt auch am alle besten mit grossem anfangsbuchstaben, um nicht dauernd zwischen structs und funktionen unterscheiden zu müssen
// bei destructor testen ob object wirklich initialisiert (vlt nicht nötig, da dies wirklich nicht sein sollte. vlt als debug version und assert ausspucken wenn objekt schon gelöscht?)
// sparse resources (?)
// error checking: so machen dass falls fehler in konstruktor man den fehler als variable aufrufen kann. evt auch für generelle funktionen? würde sagen ja. dafür Result struct erstellen

// am besten code review machen, und alles was oben steht implementieren
// am schluss so viel wie möglich noch als variadic version

// überlegen wegen presentation(glfw macht das meiste, aber für den fall dass kein glfw)
// sonst: memory manager(nicht unbedingt nötig, mann kann auch einfach mehrere memory objects benutzen, zb eins für das/die gerenderte(n) bild(er), eins für statische objekte, und ein grosses für dynamische objekte, zb für ein level in einem game, wo dann das ganze memory object neu belegt wird. insgesamt hat man so nur 3 allocations), memory allocator und queue/feature auswähler, multi-gpu zeug, neue vulkan versionen + extensions
// dos and donts: https://developer.nvidia.com/blog/vulkan-dos-donts/
// bei window resize etc. deviceWaitIdle verwenden

/*
funktionennamen auf klein
variadic und aufräumen

utils:
vector klasse verbessern
threading
zeitmessungen

überlegen wegen dub.sdl und lokalen kopien
überlegen wegen automatisch generierten d files von header files
*/

extern(C) {
    VkBool32 vkGetPhysicalDeviceWin32PresentationSupportKHR(VkPhysicalDevice, uint);
    struct VkWin32SurfaceCreateInfoKHR {
        VkStructureType sType;
        void* pNext;
        uint flags; //VkWin32SurfaceCreateFlagsKHR
        void* hinstance; //HINSTANCE
        void* hwnd; //HWND
    }
    VkResult vkCreateWin32SurfaceKHR(VkInstance instance, VkWin32SurfaceCreateInfoKHR* pCreateInfo, VkAllocationCallbacks* pAllocator, VkSurfaceKHR* pSurface);
}

struct Result {
    this(VkResult result) {
        this.result = result;
    }
    bool success() immutable @property {
        return result == VkResult.VK_SUCCESS;
    }
    void reset() {
        result = VkResult.VK_SUCCESS;
    }
    ref Result opAssign(VkResult result) return {
        if (result != VkResult.VK_SUCCESS) {
            if (this.result == VkResult.VK_SUCCESS) {
                this.result = result;
            }
            if (!(onError is null)) {
                onError(result);
            }
        }
        return this;
    }
    VkResult result = VkResult.VK_SUCCESS;
    alias result this;
    void delegate(VkResult) onError;
}

Vector!VkLayerProperties getInstanceLayers() {
    uint instanceLayersCount;
    Vector!VkLayerProperties layers;
    vkEnumerateInstanceLayerProperties(&instanceLayersCount, null);
    if (instanceLayersCount != 0) {
        layers = Vector!VkLayerProperties(instanceLayersCount);
        vkEnumerateInstanceLayerProperties(&instanceLayersCount, layers.ptr);
    }
    return layers;
}
Vector!VkLayerProperties getInstanceLayers(ref Result result) {
    uint instanceLayersCount;
    Vector!VkLayerProperties layers;
    result = vkEnumerateInstanceLayerProperties(&instanceLayersCount, null);
    if (instanceLayersCount != 0) {
        layers = Vector!VkLayerProperties(instanceLayersCount);
        result = vkEnumerateInstanceLayerProperties(&instanceLayersCount, layers.ptr);
    }
    return layers;
}

Vector!VkExtensionProperties getInstanceExtensions() {
    uint instanceExtensionsCount;
    Vector!VkExtensionProperties extensions;
    vkEnumerateInstanceExtensionProperties(null, &instanceExtensionsCount, null);
    if (instanceExtensionsCount != 0) {
        extensions = Vector!VkExtensionProperties(instanceExtensionsCount);
        vkEnumerateInstanceExtensionProperties(null, &instanceExtensionsCount, extensions.ptr);
    }
    return extensions;
}
Vector!VkExtensionProperties getInstanceExtensions(ref Result result) {
    uint instanceExtensionsCount;
    Vector!VkExtensionProperties extensions;
    result = vkEnumerateInstanceExtensionProperties(null, &instanceExtensionsCount, null);
    if (instanceExtensionsCount != 0) {
        extensions = Vector!VkExtensionProperties(instanceExtensionsCount);
        result = vkEnumerateInstanceExtensionProperties(null, &instanceExtensionsCount, extensions.ptr);
    }
    return extensions;
}

struct PhysicalDevice {
    VkFormatProperties getFormatProperites(VkFormat format) {
        VkFormatProperties properties;
        vkGetPhysicalDeviceFormatProperties(physicalDevice, format, &properties);
        return properties;
    }
    VkImageFormatProperties getImageFormatProperties(VkFormat format, VkImageType type, VkImageTiling tiling, VkImageUsageFlags usage, VkImageCreateFlags flags) {
        VkImageFormatProperties properties;
        result = vkGetPhysicalDeviceImageFormatProperties(physicalDevice, format, type, tiling, usage, flags, &properties);
        return properties;
    }
    Vector!VkSparseImageFormatProperties getSparseImageFormatProperites(VkFormat format, VkImageType type, VkImageTiling tiling, VkImageUsageFlags usage, VkSampleCountFlagBits samples) {
        uint count;
        vkGetPhysicalDeviceSparseImageFormatProperties(physicalDevice, format, type, samples, usage, tiling, &count, null);
        auto ret = Vector!VkSparseImageFormatProperties(count);
        vkGetPhysicalDeviceSparseImageFormatProperties(physicalDevice, format, type, samples, usage, tiling, &count, ret.ptr);
        return ret;
    }
    uint chooseHeapFromFlags(VkMemoryRequirements req, VkMemoryPropertyFlags required, VkMemoryPropertyFlags preferred) {
        uint selectedType = int(-1);
        for (uint memoryType = 0; memoryType < 32; memoryType++) {
            if (req.memoryTypeBits & (1 << memoryType)) {
                if ((memprops.memoryTypes[memoryType].propertyFlags & preferred) == preferred) {
                    selectedType = memoryType;
                    break;
                }
            }
        }
        if (selectedType != int(-1)) {
            for (uint memoryType = 0; memoryType < 32; memoryType++) {
                if (req.memoryTypeBits & (1 << memoryType)) {
                    if ((memprops.memoryTypes[memoryType].propertyFlags & required) == required) {
                        selectedType = memoryType;
                        break;
                    }
                }
            }
        }
        return selectedType;
    }
    uint chooseHeapFromFlags(VkMemoryRequirements req, VkMemoryPropertyFlags required) {
        uint selectedType = int(-1);
        for (uint memoryType = 0; memoryType < 32; memoryType++) {
            if (req.memoryTypeBits & (1 << memoryType)) {
                if ((memprops.memoryTypes[memoryType].propertyFlags & required) == required) {
                    selectedType = memoryType;
                    break;
                }
            }
        }
        return selectedType;
    }
    version(Windows) {
        bool win32SurfaceSupport(uint familyIndex) {
            return vkGetPhysicalDeviceWin32PresentationSupportKHR(physicalDevice, familyIndex) == VK_TRUE;
        }
    }
    bool surfaceSupport(VkSurfaceKHR surface) {
        VkBool32 surfacesupport;
        result = vkGetPhysicalDeviceSurfaceSupportKHR(physicalDevice, 0, surface, &surfacesupport);
        return surfacesupport == VK_TRUE;
    }
    VkSurfaceCapabilitiesKHR getSurfaceCapabilities(VkSurfaceKHR surface) {
        VkSurfaceCapabilitiesKHR capabilities;
        result = vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physicalDevice, surface, &capabilities);
        return capabilities;
    }
    Vector!VkSurfaceFormatKHR getSurfaceFormats(VkSurfaceKHR surface) {
        uint formatCount;
        result = vkGetPhysicalDeviceSurfaceFormatsKHR(physicalDevice, surface, &formatCount, null);
        auto formats = Vector!VkSurfaceFormatKHR(formatCount);
        result = vkGetPhysicalDeviceSurfaceFormatsKHR(physicalDevice, surface, &formatCount, formats.ptr);
        return formats;
    }
    Result result;
    VkPhysicalDevice physicalDevice;
    alias physicalDevice this;
    Instance* instance;
	VkPhysicalDeviceProperties properties;
    VkPhysicalDeviceFeatures features;
    VkPhysicalDeviceMemoryProperties memprops;
    Vector!VkQueueFamilyProperties queueFamilyProperties;
    Vector!VkLayerProperties deviceLayerProperties;
    Vector!VkExtensionProperties deviceExtensionProperties;
}

// hier auch eine variadic version fpr layers und extensions?
struct Instance {
    this(string name, uint appVersion, uint apiVersion, const char*[] layers, const char*[] extensions) {
        VkApplicationInfo applicationInfo;
        applicationInfo.sType = VkStructureType.VK_STRUCTURE_TYPE_APPLICATION_INFO;
        applicationInfo.pApplicationName = name.ptr;
        applicationInfo.applicationVersion = appVersion;
        applicationInfo.apiVersion = apiVersion;
        VkInstanceCreateInfo instanceCreateInfo;
        instanceCreateInfo.sType = VkStructureType.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
        instanceCreateInfo.pApplicationInfo = &applicationInfo;
        instanceCreateInfo.enabledLayerCount = cast(uint) layers.length;
        instanceCreateInfo.ppEnabledLayerNames = layers.ptr;
        instanceCreateInfo.enabledExtensionCount = cast(uint) extensions.length;
        instanceCreateInfo.ppEnabledExtensionNames = extensions.ptr;
        result = vkCreateInstance(&instanceCreateInfo, null, &instance);
        writeln(result.result);

        uint physicalDeviceCount;
	    result = vkEnumeratePhysicalDevices(instance, &physicalDeviceCount, null);
        auto physDevices = Vector!VkPhysicalDevice(physicalDeviceCount);
        physicalDevices = Vector!PhysicalDevice(physicalDeviceCount);
        result = vkEnumeratePhysicalDevices(instance, &physicalDeviceCount, physDevices.ptr);
        foreach (i, physicalDevice; physDevices) {
            physicalDevices[i].physicalDevice = physicalDevice;
            vkGetPhysicalDeviceProperties(physicalDevice, &physicalDevices[i].properties);
		    vkGetPhysicalDeviceFeatures(physicalDevice, &physicalDevices[i].features);
            vkGetPhysicalDeviceMemoryProperties(physicalDevice, &physicalDevices[i].memprops);
            uint queueFamilyPropertiesCount;
            vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, &queueFamilyPropertiesCount, null);
            physicalDevices[i].queueFamilyProperties = Vector!VkQueueFamilyProperties(queueFamilyPropertiesCount);
            vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, &queueFamilyPropertiesCount, physicalDevices[i].queueFamilyProperties.ptr);
            uint deviceLayersCount;
            result = vkEnumerateDeviceLayerProperties(physicalDevice, &deviceLayersCount, null);
            physicalDevices[i].deviceLayerProperties = Vector!VkLayerProperties(deviceLayersCount);
            result = vkEnumerateDeviceLayerProperties(physicalDevice, &deviceLayersCount, physicalDevices[i].deviceLayerProperties.ptr);
            uint deviceExtensionsCount;
            result = vkEnumerateDeviceExtensionProperties(physicalDevice, null, &deviceExtensionsCount, null);
            physicalDevices[i].deviceExtensionProperties = Vector!VkExtensionProperties(deviceExtensionsCount);
            result = vkEnumerateDeviceExtensionProperties(physicalDevice, null, &deviceExtensionsCount, physicalDevices[i].deviceExtensionProperties.ptr);
            physicalDevices[i].instance = &this;
        }
    }
    @disable this(ref return scope Instance rhs);
    ~this() {
        vkDestroyInstance(instance, null);
    }
    Surface createSurface(VkSurfaceKHR surface) {
        return Surface(this, surface);
    }
    Result result;
    VkInstance instance;
    alias instance this;
    Vector!PhysicalDevice physicalDevices;
}

// hier noch prioritäten als argument
struct QueueCreateInfo {
    this(uint familyIndex, uint count) {
        deviceCreateQueueInfo.sType = VkStructureType.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
        deviceCreateQueueInfo.queueFamilyIndex = familyIndex;
        deviceCreateQueueInfo.queueCount = count;
        deviceCreateQueueInfo.pQueuePriorities = &priorities;
    }
    static const float priorities = 1.0f;
    VkDeviceQueueCreateInfo deviceCreateQueueInfo;
    alias deviceCreateQueueInfo this;
}

QueueCreateInfo createQueue(uint familyIndex, uint count) {
    return QueueCreateInfo(familyIndex, count);
}

VkSubmitInfo submitInfo(VkCommandBuffer[] cmdBuffers, VkSemaphore[] waitSemaphores, VkSemaphore[] signalSemaphores, VkPipelineStageFlags dstStageMask) {
    VkSubmitInfo info;
    info.sType = VkStructureType.VK_STRUCTURE_TYPE_SUBMIT_INFO;
    info.pNext = null;
    info.waitSemaphoreCount = cast(uint) waitSemaphores.length;
    info.pWaitSemaphores = waitSemaphores.ptr;
    info.pWaitDstStageMask = &dstStageMask;
    info.signalSemaphoreCount = cast(uint) signalSemaphores.length;
    info.pSignalSemaphores = signalSemaphores.ptr;
    info.commandBufferCount = cast(uint) cmdBuffers.length;
    info.pCommandBuffers = cmdBuffers.ptr;
    return info;
}

VkSparseBufferMemoryBindInfo sparseBufferBind(ref Buffer buffer, VkSparseMemoryBind[] binds) {
    VkSparseBufferMemoryBindInfo info;
    info.buffer = buffer.buffer;
    info.bindCount = cast(uint) binds.length;
    info.pBinds = binds.ptr;
    return info;
}

VkSparseImageOpaqueMemoryBindInfo sparseImageOpaqueBind(ref Image image, VkSparseMemoryBind[] binds) {
    VkSparseImageOpaqueMemoryBindInfo info;
    info.image = image.image;
    info.bindCount = cast(uint) binds.length;
    info.pBinds = binds.ptr;
    return info;
}

VkSparseImageMemoryBindInfo sparseImageBind(ref Image image, VkSparseImageMemoryBind[] binds) {
    VkSparseImageMemoryBindInfo info;
    info.image = image.image;
    info.bindCount = cast(uint) binds.length;
    info.pBinds = binds.ptr;
    return info;
}

VkBindSparseInfo bindSparse(VkSemaphore[] wait, VkSparseBufferMemoryBindInfo[] buffers, VkSparseImageOpaqueMemoryBindInfo[] opaques, VkSparseImageMemoryBindInfo[] images, VkSemaphore[] signal) {
    VkBindSparseInfo info;
    info.sType = VkStructureType.VK_STRUCTURE_TYPE_BIND_SPARSE_INFO;
    info.pNext = null;
    info.waitSemaphoreCount = cast(uint) wait.length;
    info.pWaitSemaphores = wait.ptr;
    info.bufferBindCount = cast(uint) buffers.length;
    info.pBufferBinds = buffers.ptr;
    info.imageOpaqueBindCount = cast(uint) opaques.length;
    info.pImageOpaqueBinds = opaques.ptr;
    info.imageBindCount = cast(uint) images.length;
    info.pImageBinds = images.ptr;
    info.signalSemaphoreCount = cast(uint) signal.length;
    info.pSignalSemaphores = signal.ptr;
    return info;
}

struct Queue {
    VkResult submit(VkSubmitInfo[] submitInfos, VkFence fence) {
        return result = vkQueueSubmit(queue, cast(uint) submitInfos.length, submitInfos.ptr, fence);
    }
    // für variadic parameter zuerst waitsemaphores, dann cmdBuffers, und danach signalsemaphores
    VkResult submit(VkCommandBuffer[] cmdBuffers, VkSemaphore[] waitSemaphores, VkSemaphore[] signalSemaphores, VkPipelineStageFlags dstStageMask, VkFence fence) {
        return submit(array(submitInfo(cmdBuffers, waitSemaphores, signalSemaphores, dstStageMask)), fence);
    }
    VkResult submit(Args...)(in Args args) {
        auto waitSemaphores = compatibleTypesToArrayInGroup!(VkSemaphore, 0, Args)(args);
        auto signalSemaphores = compatibleTypesToArrayInGroup!(VkSemaphore, 1, Args)(args);
        auto commandBuffers = compatibleTypesToArray!(VkCommandBuffer, Args)(args);
        auto fence = cast(VkFence) args[findCompatibleTypes!(VkFence, Args)[0]];
        static if (countType!(VkPipelineStageFlags, Args) != 0) {
            return submit(commandBuffers, waitSemaphores, signalSemaphores, args[findTypes!(VkPipelineStageFlags, Args)[0]], fence);
        } else {
            return submit(commandBuffers, waitSemaphores, signalSemaphores, cast(VkPipelineStageFlags) 0, fence);
        }
    }
    VkResult waitIdle() {
        return result = vkQueueWaitIdle(queue);
    }
    VkResult bindSparse(VkBindSparseInfo[] infos, ref Fence fence) {
        return result = vkQueueBindSparse(queue, cast(uint) infos.length, infos.ptr, fence.fence);
    }
    VkResult present(VkSemaphore[] waitSemaphores, VkSwapchainKHR[] swapchains, uint[] imageIndices) {
        VkPresentInfoKHR info;
        info.sType = VkStructureType.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
        info.pNext = null;
        info.waitSemaphoreCount = cast(uint) waitSemaphores.length;
        info.pWaitSemaphores = waitSemaphores.ptr;
        info.swapchainCount = cast(uint) swapchains.length;
        info.pSwapchains = swapchains.ptr;
        info.pImageIndices = imageIndices.ptr;
        // hier ist noch ein info.pResults zum auswerten
        return result = vkQueuePresentKHR(queue, &info);
    }
    VkResult present(Args...)(in Args args) {
        auto waitSemaphores = compatibleTypesToArray!(VkSemaphore, Args)(args);
        auto swapchains = compatibleTypesToArray!(VkSwapchainKHR, Args)(args);
        auto imageIndices = typesToArray!(uint, Args)(args);
        VkPresentInfoKHR info;
        info.sType = VkStructureType.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
        info.pNext = null;
        info.waitSemaphoreCount = cast(uint) waitSemaphores.length;
        info.pWaitSemaphores = waitSemaphores.ptr;
        info.swapchainCount = cast(uint) swapchains.length;
        info.pSwapchains = swapchains.ptr;
        info.pImageIndices = imageIndices.ptr;
        // hier ist noch ein info.pResults zum auswerten
        return result = vkQueuePresentKHR(queue, &info);
    }
    Result result;
    VkQueue queue;
    alias queue this;
    uint familyIndex;
    uint queueIndex;
}

struct Device {
    this(ref PhysicalDevice physicalDevice, VkPhysicalDeviceFeatures features, const char*[] layers, const char*[] extensions, QueueCreateInfo[] queueInfos) {
        VkDeviceCreateInfo deviceCreateInfo;
        deviceCreateInfo.sType = VkStructureType.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
        deviceCreateInfo.queueCreateInfoCount = cast(uint) queueInfos.length;
        deviceCreateInfo.pQueueCreateInfos = cast(VkDeviceQueueCreateInfo*) queueInfos.ptr;
        deviceCreateInfo.pEnabledFeatures = &features;
		deviceCreateInfo.enabledLayerCount = cast(uint) layers.length;
		deviceCreateInfo.ppEnabledLayerNames = layers.ptr;
        deviceCreateInfo.enabledExtensionCount = cast(uint) extensions.length;
		deviceCreateInfo.ppEnabledExtensionNames = extensions.ptr;
        result = vkCreateDevice(physicalDevice.physicalDevice, &deviceCreateInfo, null, &device);
        uint count = 0;
        foreach (i, queue; queueInfos) {
            count += queue.deviceCreateQueueInfo.queueCount;
        }
        queues = Vector!Queue(count);
        count = 0;
        foreach (queueInfo; queueInfos) {
            for (int i = 0; i < queueInfo.deviceCreateQueueInfo.queueCount; i++) {
                vkGetDeviceQueue(device, queueInfo.deviceCreateQueueInfo.queueFamilyIndex, i, &queues[count].queue);
                queues[count].familyIndex = queueInfo.deviceCreateQueueInfo.queueFamilyIndex;
                queues[count].queueIndex = i;
                count++;
            }
        }
        this.physicalDevice = &physicalDevice;
    }
    @disable this(ref return scope Device rhs);
    ~this() {
        vkDeviceWaitIdle(device);
        vkDestroyDevice(device, null);
    }
    CommandPool createCommandPool(uint queueFamilyIndex, VkCommandPoolCreateFlags flags) {
        return CommandPool(this, queueFamilyIndex, flags);
    }
    Buffer createBuffer(VkBufferCreateFlags flags, VkDeviceSize size, VkBufferUsageFlags usage, uint[] queueFamilies) {
        return Buffer(this, flags, size, usage, queueFamilies);
    }
    Buffer createBuffer(VkBufferCreateFlags flags, VkDeviceSize size, VkBufferUsageFlags usage) {
        return Buffer(this, flags, size, usage);
    }
    Image createImage(VkImageCreateFlags flags, VkImageType imageType, VkFormat format, VkExtent3D extent, uint mipLevels, uint arrayLayers, VkSampleCountFlagBits samples, VkImageTiling tiling, VkImageUsageFlags usage, VkImageLayout initialLayout, uint[] queueFamilies) {
        return Image(this, flags, imageType, format, extent, mipLevels, arrayLayers, samples, tiling, usage, initialLayout, queueFamilies);
    }
    Image createImage(VkImageCreateFlags flags, VkImageType imageType, VkFormat format, VkExtent3D extent, uint mipLevels, uint arrayLayers, VkSampleCountFlagBits samples, VkImageTiling tiling, VkImageUsageFlags usage, VkImageLayout initialLayout) {
        return Image(this, flags, imageType, format, extent, mipLevels, arrayLayers, samples, tiling, usage, initialLayout);
    }
    Memory allocateMemory(VkDeviceSize allocationSize, uint memoryTypeIndex) {
        return Memory(this, allocationSize, memoryTypeIndex);
    }
    void flush(VkMappedMemoryRange[] ranges) {
        result = vkFlushMappedMemoryRanges(device, cast(uint) ranges.length, cast(VkMappedMemoryRange*) ranges.ptr);
    }
    void invalidate(VkMappedMemoryRange[] ranges) {
        result = vkInvalidateMappedMemoryRanges(device, cast(uint) ranges.length, cast(VkMappedMemoryRange*) ranges.ptr);
    }
    Fence createFence(bool signaled) {
        return Fence(this, signaled);
    }
    Fence createFence() {
        return Fence(this);
    }
    VkResult waitForFences(VkFence[] fences, bool waitForAll, ulong timeout) {
        return result = vkWaitForFences(device, cast(uint) fences.length, cast(VkFence*) fences.ptr, waitForAll, timeout);
    }
    VkResult waitForFences(VkFence[] fences, bool waitForAll) {
        return waitForFences(fences, waitForAll, long(-1));
    }
    VkResult waitForFences(VkFence[] fences) {
        return waitForFences(fences, true, long(-1));
    }
    VkResult resetFences(VkFence[] fences) {
        return result = vkResetFences(device, cast(uint) fences.length, cast(VkFence*) fences.ptr);
    }
    Event createEvent() {
        return Event(this);
    }
    Semaphore createSemaphore() {
        return Semaphore(this);
    }
    Swapchain createSwapchain(ref Surface surface, uint minImageCount, VkFormat imageFormat, VkColorSpaceKHR imageColorSpace, VkExtent2D imageExtent, uint imageArrayLayers, VkImageUsageFlags imageUsage, VkSharingMode imageSharingMode, uint[] familyIndices, VkSurfaceTransformFlagBitsKHR preTransform, VkCompositeAlphaFlagBitsKHR compositeAlpha, VkPresentModeKHR presentMode, VkBool32 clipped, VkSwapchainKHR oldSwapchain) {
        return Swapchain(this, surface.surface, minImageCount, imageFormat, imageColorSpace, imageExtent, imageArrayLayers, imageUsage, imageSharingMode, familyIndices, preTransform, compositeAlpha, presentMode, clipped, oldSwapchain);
    }
    Swapchain createSwapchain(ref Surface surface, uint minImageCount, VkFormat imageFormat, VkColorSpaceKHR imageColorSpace, VkExtent2D imageExtent, uint imageArrayLayers, VkImageUsageFlags imageUsage, VkSharingMode imageSharingMode, uint[] familyIndices, VkSurfaceTransformFlagBitsKHR preTransform, VkCompositeAlphaFlagBitsKHR compositeAlpha, VkPresentModeKHR presentMode, VkBool32 clipped) {
        return Swapchain(this, surface.surface, minImageCount, imageFormat, imageColorSpace, imageExtent, imageArrayLayers, imageUsage, imageSharingMode, familyIndices, preTransform, compositeAlpha, presentMode, clipped);
    }
    Shader createShader(string code) {
        return Shader(this, code);
    }
    PipelineLayout createPipelineLayout(VkDescriptorSetLayout[] descriptorSetLayouts, VkPushConstantRange[] pushConstants) {
        return PipelineLayout(this, descriptorSetLayouts, pushConstants);
    }
    PipelineLayout createPipelineLayout(VkDescriptorSetLayout[] descriptorSetLayouts) {
        return PipelineLayout(this, descriptorSetLayouts);
    }
    ComputePipeline createComputePipeline(VkPipelineCache cache, VkShaderModule shader, string entry, VkPipelineLayout layout, VkSpecializationMapEntry[] spezialization, size_t dataSize, void* data) {
        return ComputePipeline(this, cache, shader, entry, layout, spezialization, dataSize, data);
    }
    ComputePipeline createComputePipeline(VkPipelineCache cache, VkShaderModule shader, string entry, VkPipelineLayout layout, VkSpecializationMapEntry[] spezialization, size_t dataSize, void* data, VkPipeline base) {
        return ComputePipeline(this, cache, shader, entry, layout, spezialization, dataSize, data, base);
    }
    ComputePipeline createComputePipeline(VkShaderModule shader, string entry, VkPipelineLayout layout, VkSpecializationMapEntry[] spezialization, size_t dataSize, void* data) {
        return ComputePipeline(this, shader, entry, layout, spezialization, dataSize, data);
    }
    ComputePipeline createComputePipeline(VkShaderModule shader, string entry, VkPipelineLayout layout, VkSpecializationMapEntry[] spezialization, size_t dataSize, void* data, VkPipeline base) {
        return ComputePipeline(this, shader, entry, layout, spezialization, dataSize, data, base);
    }
    ComputePipeline createComputePipeline(VkShaderModule shader, string entry, VkPipelineLayout layout) {
        return ComputePipeline(this, null, shader, entry, layout, [], 0, null, null);
    }
    ComputePipeline createComputePipeline(VkPipelineCache cache, VkShaderModule shader, string entry, VkPipelineLayout layout) {
        return ComputePipeline(this, cache, shader, entry, layout, [], 0, null, null);
    }
    ComputePipeline createComputePipeline(VkShaderModule shader, string entry, VkPipelineLayout layout, VkPipeline base) {
        return ComputePipeline(this, null, shader, entry, layout, [], 0, null, base);
    }
    ComputePipeline createComputePipeline(VkPipelineCache cache, VkShaderModule shader, string entry, VkPipelineLayout layout, VkPipeline base) {
        return ComputePipeline(this, cache, shader, entry, layout, [], 0, null, base);
    }
    // hier eine variadic version zur verfügung stellen, um ohne Vector auszukommen
    Vector!ComputePipeline createComputePipelines(VkPipelineCache cache, VkComputePipelineCreateInfo[] infos) {
        auto pipelines = Vector!ComputePipeline(infos.length);
        auto vkPipelines = Vector!VkPipeline(infos.length);
        result = vkCreateComputePipelines(device, cache, cast(uint) infos.length, infos.ptr, null, vkPipelines.ptr);
        for (int i = 0; i < infos.length; i++) {
            pipelines[i].device = &this;
            pipelines[i].pipeline = vkPipelines[i];
        }
        return pipelines;
    }
    Vector!ComputePipeline createComputePipelines(VkComputePipelineCreateInfo[] infos) {
        return createComputePipelines(null, infos);
    }
    DescriptorSetLayout createDescriptorSetLayout(VkDescriptorSetLayoutBinding[] bindings) {
        return DescriptorSetLayout(this, bindings);
    }
    DescriptorPool createDescriptorPool(VkDescriptorPoolCreateFlags flags, uint maxSets, VkDescriptorPoolSize[] poolSizes) {
        return DescriptorPool(this, flags, maxSets, poolSizes);
    }
    void updateDescriptorSets(VkWriteDescriptorSet[] writes, VkCopyDescriptorSet[] copies) {
        vkUpdateDescriptorSets(device, cast(uint) writes.length, writes.ptr, cast(uint) copies.length, copies.ptr);
    }
    PipelineCache createPipelineCache(string data) {
        return PipelineCache(this, data);
    }
    PipelineCache createPipelineCache() {
        return PipelineCache(this);
    }
    PipelineCache createPipelineCache(VkPipelineCache[] merge) {
        return PipelineCache(this, merge);
    }
    RenderPass createRenderPass(VkAttachmentDescription[] attachements, VkSubpassDescription[] subpasses, VkSubpassDependency[] dependencies) {
        return RenderPass(this, attachements, subpasses, dependencies);
    }
    // hier umgekehrt eine version zur verfügung stellen für runtime, also wie compute oben
    auto createGraphicsPipelines(Args...)(in Args args) {
        VkPipelineCache cache = null;
        static if (findCompatibleTypes!(VkPipelineCache, Args).length > 0) {
            cache = cast(VkPipelineCache) args[findCompatibleTypes!(VkPipelineCache, Args)[0]];
        }
        auto infos = typesToArray!VkGraphicsPipelineCreateInfo(args);
        //RenderPass*[countTypeCompatible!(RenderPass, Args)] renderPasses;
        VkPipeline[countTypeCompatible!(RenderPass, Args)] pipelines;
        static foreach (i, e; infos) {
            e.renderPass = args[findCompatibleTypes!(VkRenderPass, Args)[i]];
        }
        result = vkCreateGraphicsPipelines(device, cache, info.length, infos.ptr, null, pipelines.ptr);
        GraphicsPipeline[info.length] graphicsPipelines = void;
        static foreach (i, e; pipelines) {
            graphicsPipelines[i] = GraphicsPipeline(args[findTypes!(RenderPass, Args)[i]], e);
        }
        return graphicsPipelines;
    }
    Result result;
    VkDevice device;
    alias device this;
    Vector!Queue queues;
    PhysicalDevice* physicalDevice;
}

struct Fence {
    this(ref Device device, bool signaled) {
        VkFenceCreateInfo info;
        info.sType = VkStructureType.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
        info.pNext = null;
        info.flags = signaled ? VkFenceCreateFlagBits.VK_FENCE_CREATE_SIGNALED_BIT : 0;
        result = vkCreateFence(device.device, &info, null, &fence);
        this.device = &device;
    }
    this(ref Device device) {
        this(device, false);
    }
    @disable this(ref return scope Fence rhs);
    ~this() {
        vkDestroyFence(device.device, fence, null);
    }
    bool isSignaled() {
        return vkGetFenceStatus(device.device, fence) == VkResult.VK_SUCCESS;
    }
    VkResult wait(ulong timeout) {
        return result = vkWaitForFences(device.device, 1, &fence, true, timeout);
    }
    VkResult wait() {
        return wait(long(-1));
    }
    VkResult reset() {
        return result = vkResetFences(device.device, 1, &fence);
    }
    Result result;
    VkFence fence;
    alias fence this;
    Device* device;
}

struct Event {
    this(ref Device device) {
        VkEventCreateInfo info;
        info.sType = VkStructureType.VK_STRUCTURE_TYPE_EVENT_CREATE_INFO;
        info.pNext = null;
        info.flags = 0;
        result = vkCreateEvent(device.device, &info, null, &event);
        this.device = &device;
    }
    @disable this(ref return scope Event rhs);
    ~this() {
        vkDestroyEvent(device.device, event, null);
    }
    VkResult set() {
        return result = vkSetEvent(device.device, event);
    }
    VkResult reset() {
        return result = vkResetEvent(device.device, event);
    }
    bool isSignaled() {
        return vkGetEventStatus(device.device, event) == VkResult.VK_SUCCESS;
    }
    Result result;
    VkEvent event;
    alias event this;
    Device* device;
}

struct Semaphore {
    this(ref Device device) {
        VkSemaphoreCreateInfo info;
        info.sType = VkStructureType.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;
        info.pNext = null;
        info.flags = 0;
        result = vkCreateSemaphore(device.device, &info, null, &semaphore);
        this.device = &device;
    }
    @disable this(ref return scope Semaphore rhs);
    ~this() {
        vkDestroySemaphore(device.device, semaphore, null);
    }
    Result result;
    VkSemaphore semaphore;
    alias semaphore this;
    Device* device;
}

struct CommandPool {
    this(ref Device device, uint queueFamilyIndex, VkCommandPoolCreateFlags flags) {
        VkCommandPoolCreateInfo createInfo;
        createInfo.sType = VkStructureType.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
        createInfo.pNext = null;
        createInfo.flags = flags;
        createInfo.queueFamilyIndex = queueFamilyIndex;
        result = vkCreateCommandPool(device.device, &createInfo, null, &commandPool);
        this.device = &device;
    }
    @disable this(ref return scope CommandPool rhs);
    ~this() {
        vkDestroyCommandPool(*device, commandPool, null);
    }
    Vector!CommandBuffer allocateCommandBuffers(uint count, VkCommandBufferLevel level) {
        Vector!CommandBuffer buffers = Vector!CommandBuffer(count);
        VkCommandBufferAllocateInfo allocateInfo;
        allocateInfo.sType = VkStructureType.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
        allocateInfo.pNext = null;
        allocateInfo.commandPool = commandPool;
        allocateInfo.level = level;
        allocateInfo.commandBufferCount = count;
        Vector!VkCommandBuffer vkBuffers = Vector!VkCommandBuffer(count);
        result = vkAllocateCommandBuffers(*device, &allocateInfo, vkBuffers.ptr);
        for (int i = 0; i < count; i++) {
            buffers[i].commandBuffer = vkBuffers[i];
            buffers[i].commandPool = &this;
        }
        return buffers;
    }
    CommandBuffer allocateCommandBuffer(VkCommandBufferLevel level) {
        return CommandBuffer(this, level);
    }
    void reset(VkCommandPoolResetFlags flags) {
        result = vkResetCommandPool(*device, commandPool, flags);
    }
    Result result;
    VkCommandPool commandPool;
    alias commandPool this;
    Device* device;
}

VkMemoryBarrier MemoryBarrier(VkAccessFlags srcAccessMask, VkAccessFlags dstAccessMask) {
    VkMemoryBarrier barrier;
    barrier.sType = VkStructureType.VK_STRUCTURE_TYPE_MEMORY_BARRIER;
    barrier.pNext = null;
    barrier.srcAccessMask = srcAccessMask;
    barrier.dstAccessMask = dstAccessMask;
    return barrier;
}

VkBufferMemoryBarrier BufferMemoryBarrier(VkAccessFlags srcAccessMask, VkAccessFlags dstAccessMask, uint srcQueueFamilyIndex, uint dstQueueFamilyIndex, ref Buffer buffer, VkDeviceSize offset, VkDeviceSize size) {
    VkBufferMemoryBarrier barrier;
    barrier.sType = VkStructureType.VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER;
    barrier.pNext = null;
    barrier.srcAccessMask = srcAccessMask;
    barrier.dstAccessMask = dstAccessMask;
    barrier.srcQueueFamilyIndex = srcQueueFamilyIndex;
    barrier.dstQueueFamilyIndex = dstQueueFamilyIndex;
    barrier.buffer = buffer.buffer;
    barrier.offset = offset;
    barrier.size = size;
    return barrier;
}
VkBufferMemoryBarrier BufferMemoryBarrier(VkAccessFlags srcAccessMask, VkAccessFlags dstAccessMask, uint srcQueueFamilyIndex, uint dstQueueFamilyIndex, ref Buffer buffer) {
    return BufferMemoryBarrier(srcAccessMask, dstAccessMask, srcQueueFamilyIndex, dstQueueFamilyIndex, buffer, 0, VK_WHOLE_SIZE);
}
VkBufferMemoryBarrier BufferMemoryBarrier(VkAccessFlags srcAccessMask, VkAccessFlags dstAccessMask, ref Buffer buffer) {
    return BufferMemoryBarrier(srcAccessMask, dstAccessMask, VK_QUEUE_FAMILY_IGNORED, VK_QUEUE_FAMILY_IGNORED, buffer, 0, VK_WHOLE_SIZE);
}

VkImageMemoryBarrier ImageMemoryBarrier(VkAccessFlags srcAccessMask, VkAccessFlags dstAccessMask, VkImageLayout oldLayout, VkImageLayout newLayout, uint srcQueueFamilyIndex, uint dstQueueFamilyIndex, VkImage image, VkImageSubresourceRange subresourceRange) {
    VkImageMemoryBarrier barrier;
    barrier.sType = VkStructureType.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
    barrier.pNext = null;
    barrier.srcAccessMask = srcAccessMask;
    barrier.dstAccessMask = dstAccessMask;
    barrier.oldLayout = oldLayout;
    barrier.newLayout = newLayout;
    barrier.srcQueueFamilyIndex = srcQueueFamilyIndex;
    barrier.dstQueueFamilyIndex = dstQueueFamilyIndex;
    barrier.image = image;
    barrier.subresourceRange = subresourceRange;
    return barrier;
}
VkImageMemoryBarrier ImageMemoryBarrier(VkAccessFlags srcAccessMask, VkAccessFlags dstAccessMask, VkImageLayout oldLayout, VkImageLayout newLayout, VkImage image, VkImageSubresourceRange subresourceRange) {
    return ImageMemoryBarrier(srcAccessMask, dstAccessMask, oldLayout, newLayout, VK_QUEUE_FAMILY_IGNORED, VK_QUEUE_FAMILY_IGNORED, image, subresourceRange);
}

struct CommandBuffer {
    this(ref CommandPool commandPool, VkCommandBufferLevel level) {
        VkCommandBufferAllocateInfo allocateInfo;
        allocateInfo.sType = VkStructureType.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
        allocateInfo.pNext = null;
        allocateInfo.commandPool = commandPool.commandPool;
        allocateInfo.level = level;
        allocateInfo.commandBufferCount = 1;
        result = vkAllocateCommandBuffers(commandPool.device.device, &allocateInfo, &commandBuffer);
        this.commandPool = &commandPool;
    }
    @disable this(ref return scope CommandBuffer rhs);
    ~this() {
        //if sollte man entfernen können
        if (commandBuffer != VkCommandBuffer())
            vkFreeCommandBuffers(commandPool.device.device, commandPool.commandPool, 1, &commandBuffer);
    }
    void begin(VkCommandBufferUsageFlags flags, VkRenderPass renderPass, uint subpass, VkFramebuffer framebuffer, VkBool32 occlusionQueryEnable, VkQueryControlFlags queryFlags, VkQueryPipelineStatisticFlags pipelineStatistics) {
        VkCommandBufferInheritanceInfo inheritanceInfo = VkCommandBufferInheritanceInfo(
            VkStructureType.VK_STRUCTURE_TYPE_COMMAND_BUFFER_INHERITANCE_INFO,
            null,
            renderPass,
            subpass,
            framebuffer,
            occlusionQueryEnable,
            queryFlags,
            pipelineStatistics
        );
        VkCommandBufferBeginInfo info;
        info.sType = VkStructureType.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
        info.pNext = null;
        info.flags = flags;
        info.pInheritanceInfo = &inheritanceInfo;
        result = vkBeginCommandBuffer(commandBuffer, &info);
    }
    void begin(VkCommandBufferUsageFlags flags) {
        VkCommandBufferBeginInfo info;
        info.sType = VkStructureType.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
        info.pNext = null;
        info.flags = flags;
        result = vkBeginCommandBuffer(commandBuffer, &info);
    }
    void begin() {
        begin(0);
    }
    void end() {
        vkEndCommandBuffer(commandBuffer);
    }
    void reset(VkCommandBufferResetFlags flags) {
        result = vkResetCommandBuffer(commandBuffer, flags);
    }
    void reset() {
        result = vkResetCommandBuffer(commandBuffer, 0);
    }
    void copyBuffer(ref Buffer src, ref Buffer dst, VkBufferCopy[] copies) {
        vkCmdCopyBuffer(commandBuffer, src.buffer, dst.buffer, cast(uint) copies.length, copies.ptr);
    }
    void copyBuffer(ref Buffer src, VkDeviceSize srcOffset, ref Buffer dst, VkDeviceSize dstOffset, VkDeviceSize size) {
        VkBufferCopy region;
        region.srcOffset = srcOffset;
        region.dstOffset = dstOffset;
        region.size = size;
        vkCmdCopyBuffer(commandBuffer, src.buffer, dst.buffer, 1, &region);
    }
    void setEvent(ref Event event, VkPipelineStageFlags stageMask) {
        vkCmdSetEvent(commandBuffer, event.event, stageMask);
    }
    void resetEvent(ref Event event, VkPipelineStageFlags stageMask) {
        vkCmdResetEvent(commandBuffer, event.event, stageMask);
    }
    void waitEvents(VkEvent[] events, VkPipelineStageFlags srcStageMask, VkPipelineStageFlags dstStageMask, VkMemoryBarrier[] memoryBarriers, VkBufferMemoryBarrier[] bufferMemoryBarrier, VkImageMemoryBarrier[] imageMemoryBarrier) {
        vkCmdWaitEvents(commandBuffer, cast(uint) events.length, events.ptr, srcStageMask, dstStageMask, cast(uint) memoryBarriers.length, memoryBarriers.ptr, cast(uint) bufferMemoryBarrier.length, bufferMemoryBarrier.ptr, cast(uint) imageMemoryBarrier.length, imageMemoryBarrier.ptr);
    }
    void pipelineBarrier(VkPipelineStageFlags srcStageMask, VkPipelineStageFlags dstStageMask, VkDependencyFlags dependencyFlags, VkMemoryBarrier[] memoryBarriers, VkBufferMemoryBarrier[] bufferMemoryBarrier, VkImageMemoryBarrier[] imageMemoryBarrier) {
        vkCmdPipelineBarrier(commandBuffer, srcStageMask, dstStageMask, dependencyFlags, cast(uint) memoryBarriers.length, memoryBarriers.ptr, cast(uint) bufferMemoryBarrier.length, bufferMemoryBarrier.ptr, cast(uint) imageMemoryBarrier.length, imageMemoryBarrier.ptr);
    }
    void fillBuffer(ref Buffer buffer, VkDeviceSize dstOffset, VkDeviceSize size, uint data) {
        vkCmdFillBuffer(commandBuffer, buffer.buffer, dstOffset, size, data);
    }
    void fillBuffer(ref Buffer buffer, uint data) {
        vkCmdFillBuffer(commandBuffer, buffer.buffer, 0, VK_WHOLE_SIZE, data);
    }
    void fillBuffer(T)(ref Buffer buffer, VkDeviceSize dstOffset, VkDeviceSize size, T data) {
        vkCmdFillBuffer(commandBuffer, buffer.buffer, dstOffset, size, *(cast(uint*)&data));
    }
    void fillBuffer(T)(ref Buffer buffer, T data) {
        vkCmdFillBuffer(commandBuffer, buffer.buffer, 0, VK_WHOLE_SIZE, *(cast(uint*)&data));
    }
    // maximal 65'536 bytes
    void updateBuffer(ref Buffer buffer, VkDeviceSize dstOffset, VkDeviceSize size, uint* data) {
        vkCmdUpdateBuffer(commandBuffer, buffer.buffer, dstOffset, size, data);
    }
    void clearColorImage(VkImage image, VkImageLayout layout, VkClearColorValue color, VkImageSubresourceRange[] ranges) {
        vkCmdClearColorImage(commandBuffer, image, layout, &color, cast(uint) ranges.length, ranges.ptr);
    }
    void clearDepthStencilImage(ref Image image, VkImageLayout layout, VkClearDepthStencilValue value, VkImageSubresourceRange[] ranges) {
        vkCmdClearDepthStencilImage(commandBuffer, image.image, layout, &value, cast(uint) ranges.length, ranges.ptr);
    }
    void copyBufferToImage(ref Buffer buffer, ref Image image, VkImageLayout layout, VkBufferImageCopy[] regions) {
        vkCmdCopyBufferToImage(commandBuffer, buffer.buffer, image.image, layout, cast(uint) regions.length, regions.ptr);
    }
    void copyBufferToImage(ref Buffer buffer, ref Image image, VkImageLayout layout, VkDeviceSize bufferOffset, uint bufferRowLength, uint bufferImageHeight, VkImageSubresourceLayers subresource, VkOffset3D offset, VkExtent3D extent) {
        VkBufferImageCopy region;
        region.bufferOffset = bufferOffset;
        region.bufferRowLength = bufferRowLength;
        region.bufferImageHeight = bufferImageHeight;
        region.imageSubresource = subresource;
        region.imageOffset = offset;
        region.imageExtent = extent;
        vkCmdCopyBufferToImage(commandBuffer, buffer.buffer, image.image, layout, 1, &region);
    }
    void copyImageToBuffer(ref Image image, ref Buffer buffer, VkImageLayout layout, VkBufferImageCopy[] regions) {
        vkCmdCopyImageToBuffer(commandBuffer, image.image, layout, buffer.buffer, cast(uint) regions.length, regions.ptr);
    }
    void copyImageToBuffer(ref Image image, ref Buffer buffer, VkImageLayout layout, VkDeviceSize bufferOffset, uint bufferRowLength, uint bufferImageHeight, VkImageSubresourceLayers subresource, VkOffset3D offset, VkExtent3D extent) {
        VkBufferImageCopy region;
        region.bufferOffset = bufferOffset;
        region.bufferRowLength = bufferRowLength;
        region.bufferImageHeight = bufferImageHeight;
        region.imageSubresource = subresource;
        region.imageOffset = offset;
        region.imageExtent = extent;
        vkCmdCopyImageToBuffer(commandBuffer, image.image, layout, buffer.buffer, 1, &region);
    }
    void copyImage(ref Image src, ref Image dst, VkImageLayout srcLayout, VkImageLayout dstLayout, VkImageCopy[] regions) {
        vkCmdCopyImage(commandBuffer, src.image, srcLayout, dst.image, dstLayout, cast(uint) regions.length, regions.ptr);
    }
    void copyImage(ref Image src, ref Image dst, VkImageLayout srcLayout, VkImageLayout dstLayout, VkImageSubresourceLayers srcSub, VkOffset3D srcOff, VkImageSubresourceLayers dstSub, VkOffset3D dstOff, VkExtent3D extent) {
        VkImageCopy region;
        region.srcSubresource = srcSub;
        region.srcOffset = srcOff;
        region.dstSubresource = dstSub;
        region.dstOffset = dstOff;
        region.extent = extent;
        vkCmdCopyImage(commandBuffer, src.image, srcLayout, dst.image, dstLayout, 1, &region);
    }
    void blitImage(ref Image src, ref Image dst, VkImageLayout srcLayout, VkImageLayout dstLayout, VkImageBlit[] regions, VkFilter filter) {
        vkCmdBlitImage(commandBuffer, src, srcLayout, dst, dstLayout, cast(uint) regions.length, regions.ptr, filter);
    }
    void blitImage(ref Image src, ref Image dst, VkImageLayout srcLayout, VkImageLayout dstLayout, VkImageSubresourceLayers srcSub, VkOffset3D[2] srcOff, VkImageSubresourceLayers dstSub, VkOffset3D[2] dstOff, VkFilter filter) {
        VkImageBlit region;
        region.srcSubresource = srcSub;
        region.srcOffsets = srcOff;
        region.dstSubresource = dstSub;
        region.dstOffsets = dstOff;
        vkCmdBlitImage(commandBuffer, src, srcLayout, dst, dstLayout, 1, &region, filter);
    }
    void bindPipeline(VkPipeline pipeline, VkPipelineBindPoint bindPoint) {
        vkCmdBindPipeline(commandBuffer, bindPoint, pipeline);
    }
    void dispatch(uint x, uint y, uint z) {
        vkCmdDispatch(commandBuffer, x, y, z);
    }
    void dispatchIndirect(VkBuffer buffer, VkDeviceSize offset) {
        vkCmdDispatchIndirect(commandBuffer, buffer, offset);
    }
    void bindDescriptorSets(VkPipelineBindPoint bindPoint, VkPipelineLayout layout, uint firstSet, VkDescriptorSet[] sets, uint[] offsets) {
        vkCmdBindDescriptorSets(commandBuffer, bindPoint, layout, firstSet, cast(uint) sets.length, sets.ptr, cast(uint) offsets.length, offsets.ptr);
    }
    void bindDescriptorSets(VkPipelineBindPoint bindPoint, VkPipelineLayout layout, uint firstSet, VkDescriptorSet[] sets) {
        vkCmdBindDescriptorSets(commandBuffer, bindPoint, layout, firstSet, cast(uint) sets.length, sets.ptr, 0, null);
    }
    void bindDescriptorSets(VkPipelineBindPoint bindPoint, VkPipelineLayout layout, uint firstSet, VkDescriptorSet set) {
        vkCmdBindDescriptorSets(commandBuffer, bindPoint, layout, firstSet, 1, &set, 0, null);
    }
    void pushConstants(VkPipelineLayout layout, VkShaderStageFlags stageFlags, uint offset, uint size, void* data) {
        vkCmdPushConstants(commandBuffer, layout, stageFlags, offset, size, data);
    }
    void pushConstants(VkPipelineLayout layout, VkShaderStageFlags stageFlags, uint size, void* data) {
        vkCmdPushConstants(commandBuffer, layout, stageFlags, 0, size, data);
    }
    void executeCommands(VkCommandBuffer[] commandBuffers) {
        vkCmdExecuteCommands(commandBuffer, cast(uint) commandBuffers.length, commandBuffers.ptr);
    }
    void resetQueryPool(VkQueryPool pool, uint firstQuery, uint queryCount) {
        vkCmdResetQueryPool(commandBuffer, pool, firstQuery, queryCount);
    }
    void beginQuery(VkQueryPool pool, uint query, VkQueryControlFlags flags) {
        vkCmdBeginQuery(commandBuffer, pool, query, flags);
    }
    void endQuery(VkQueryPool pool, uint query, VkQueryControlFlags flags) {
        vkCmdEndQuery(commandBuffer, pool, query);
    }
    void copyQueryPoolResults(VkQueryPool pool, uint firstQuery, uint queryCount, VkBuffer dstBuffer, VkDeviceSize dstOffset, VkDeviceSize stride, VkQueryResultFlags flags) {
        vkCmdCopyQueryPoolResults(commandBuffer, pool, firstQuery, queryCount, dstBuffer, dstOffset, stride, flags);
    }
    void writeTimestamp(VkPipelineStageFlagBits pipelineStage, VkQueryPool pool, uint query) {
        vkCmdWriteTimestamp(commandBuffer, pipelineStage, pool, query);
    }
    void draw(uint vertexCount, uint instanceCount, uint firstVertex, uint firstInstance) {
        vkCmdDraw(commandBuffer, vertexCount, instanceCount, firstVertex, firstInstance);
    }
    Result result;
    VkCommandBuffer commandBuffer;
    alias commandBuffer this;
    CommandPool* commandPool;
}

struct Buffer {
    this(ref Device device, VkBufferCreateFlags flags, VkDeviceSize size, VkBufferUsageFlags usage, uint[] queueFamilies) {
        VkBufferCreateInfo info;
        info.sType = VkStructureType.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
        info.pNext = null;
        info.flags = flags;
        info.size = size;
        info.usage = usage;
        info.sharingMode = VkSharingMode.VK_SHARING_MODE_CONCURRENT; 
        info.queueFamilyIndexCount = cast(uint) queueFamilies.length;
        info.pQueueFamilyIndices = queueFamilies.ptr;
        result = vkCreateBuffer(device.device, &info, null, &buffer);
        this.device = &device;
    }
    this(ref Device device, VkBufferCreateFlags flags, VkDeviceSize size, VkBufferUsageFlags usage) {
        VkBufferCreateInfo info;
        info.sType = VkStructureType.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
        info.pNext = null;
        info.flags = flags;
        info.size = size;
        info.usage = usage;
        info.sharingMode = VkSharingMode.VK_SHARING_MODE_EXCLUSIVE; 
        info.queueFamilyIndexCount = 0;
        info.pQueueFamilyIndices = null;
        result = vkCreateBuffer(device.device, &info, null, &buffer);
        this.device = &device;
    }
    @disable this(ref return scope Buffer rhs);
    ~this() {
        vkDestroyBuffer(device.device, buffer, null);
    }
    BufferView createBufferView(VkFormat format, VkDeviceSize offset, VkDeviceSize range) {
        return BufferView(this, format, offset, range);
    }
    VkMemoryRequirements getMemoryRequirements() {
        VkMemoryRequirements req;
        vkGetBufferMemoryRequirements(device.device, buffer, &req);
        return req;
    }
    void bind(ref Memory memory, VkDeviceSize offset) {
        result = vkBindBufferMemory(device.device, buffer, memory.memory, offset);
    }
    uint chooseHeap(VkMemoryPropertyFlags required, VkMemoryPropertyFlags preferred) {
        return device.physicalDevice.chooseHeapFromFlags(getMemoryRequirements(), required, preferred);
    }
    uint chooseHeap(VkMemoryPropertyFlags required) {
        return device.physicalDevice.chooseHeapFromFlags(getMemoryRequirements(), required);
    }
    Result result;
    VkBuffer buffer;
    alias buffer this;
    Device* device;
}

struct Image {
    this(ref Device device, VkImageCreateFlags flags, VkImageType imageType, VkFormat format, VkExtent3D extent, uint mipLevels, uint arrayLayers, VkSampleCountFlagBits samples, VkImageTiling tiling, VkImageUsageFlags usage, VkImageLayout initialLayout, uint[] queueFamilies) {
        VkImageCreateInfo info;
        info.sType = VkStructureType.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
        info.pNext = null;
        info.flags = flags;
        info.imageType = imageType;
        info.format = format;
        info.extent = extent;
        info.mipLevels = mipLevels;
        info.arrayLayers = arrayLayers;
        info.samples = samples;
        info.tiling = tiling;
        info.usage = usage;
        info.initialLayout = initialLayout;
        info.sharingMode = VkSharingMode.VK_SHARING_MODE_CONCURRENT;
        info.queueFamilyIndexCount = cast(uint) queueFamilies.length;
        info.pQueueFamilyIndices = queueFamilies.ptr;
        result = vkCreateImage(device.device, &info, null, &image);
        this.device = &device;
    }
    this(ref Device device, VkImageCreateFlags flags, VkImageType imageType, VkFormat format, VkExtent3D extent, uint mipLevels, uint arrayLayers, VkSampleCountFlagBits samples, VkImageTiling tiling, VkImageUsageFlags usage, VkImageLayout initialLayout) {
        VkImageCreateInfo info;
        info.sType = VkStructureType.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
        info.pNext = null;
        info.flags = flags;
        info.imageType = imageType;
        info.format = format;
        info.extent = extent;
        info.mipLevels = mipLevels;
        info.arrayLayers = arrayLayers;
        info.samples = samples;
        info.tiling = tiling;
        info.usage = usage;
        info.initialLayout = initialLayout;
        info.sharingMode = VkSharingMode.VK_SHARING_MODE_EXCLUSIVE; 
        info.queueFamilyIndexCount = 0;
        info.pQueueFamilyIndices = null;
        result = vkCreateImage(device.device, &info, null, &image);
        this.device = &device;
    }
    @disable this(ref return scope Image rhs);
    ~this() {
        vkDestroyImage(device.device, image, null);
    }
    VkSubresourceLayout getSubresourceLayout(VkImageAspectFlags aspectMask, uint mipLevel, uint arrayLayer) {
        VkImageSubresource subresource;
        subresource.aspectMask = aspectMask;
        subresource.mipLevel = mipLevel;
        subresource.arrayLayer = arrayLayer;
        VkSubresourceLayout layout;
        vkGetImageSubresourceLayout(device.device, image, &subresource, &layout);
        return layout;
    }
    ImageView createImageView(VkImageViewType viewType, VkFormat format, VkComponentMapping components, VkImageSubresourceRange subresourceRange) {
        return ImageView(this, viewType, format, components, subresourceRange);
    }
    VkMemoryRequirements getMemoryRequirements() {
        VkMemoryRequirements req;
        vkGetImageMemoryRequirements(device.device, image, &req);
        return req;
    }
    Vector!VkSparseImageMemoryRequirements getSparseMemoryRequirements() {
        uint count;
        vkGetImageSparseMemoryRequirements(device.device, image, &count, null);
        auto ret = Vector!VkSparseImageMemoryRequirements(count);
        vkGetImageSparseMemoryRequirements(device.device, image, &count, ret.ptr);
        return ret;
    }
    void bind(ref Memory memory, VkDeviceSize offset) {
        result = vkBindImageMemory(device.device, image, memory.memory, offset);
    }
    uint chooseHeap(VkMemoryPropertyFlags required, VkMemoryPropertyFlags preferred) {
        return device.physicalDevice.chooseHeapFromFlags(getMemoryRequirements(), required, preferred);
    }
    uint chooseHeap(VkMemoryPropertyFlags required) {
        return device.physicalDevice.chooseHeapFromFlags(getMemoryRequirements(), required);
    }
    Result result;
    VkImage image;
    alias image this;
    Device* device;
}

struct BufferView {
    this(ref Buffer buffer, VkFormat format, VkDeviceSize offset, VkDeviceSize range) {
        VkBufferViewCreateInfo info;
        info.sType = VkStructureType.VK_STRUCTURE_TYPE_BUFFER_VIEW_CREATE_INFO;
        info.pNext = null;
        info.flags = 0;
        info.buffer = buffer.buffer;
        info.format = format;
        info.offset = offset;
        info.range = range;
        result = vkCreateBufferView(buffer.device.device, &info, null, &bufferView);
        this.buffer = &buffer;
    }
    @disable this(ref return scope BufferView rhs);
    ~this() {
        vkDestroyBufferView(buffer.device.device, bufferView, null);
    }
    Result result;
    VkBufferView bufferView;
    alias bufferView this;
    Buffer* buffer;
}

struct ImageView {
    this(ref Image image, VkImageViewType viewType, VkFormat format, VkComponentMapping components, VkImageSubresourceRange subresourceRange) {
        VkImageViewCreateInfo info;
        info.sType = VkStructureType.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
        info.pNext = null;
        info.flags = 0;
        info.image = image.image;
        info.viewType = viewType;
        info.format = format;
        info.components = components;
        info.subresourceRange = subresourceRange;
        result = vkCreateImageView(image.device.device, &info, null, &imageView);
        this.image = &image;
    }
    @disable this(ref return scope ImageView rhs);
    ~this() {
        vkDestroyImageView(image.device.device, imageView, null);
    }
    Result result;
    VkImageView imageView;
    alias imageView this;
    Image* image;
}

VkMappedMemoryRange MappedMemoryRange(ref Memory memory, VkDeviceSize offset, VkDeviceSize size) {
    VkMappedMemoryRange range;
    range.sType = VkStructureType.VK_STRUCTURE_TYPE_MAPPED_MEMORY_RANGE;
    range.pNext = null;
    range.memory = memory.memory;
    range.offset = offset;
    range.size = size;
    return range;
}
VkMappedMemoryRange MappedMemoryRange(VkDeviceMemory memory, VkDeviceSize offset, VkDeviceSize size) {
    VkMappedMemoryRange range;
    range.sType = VkStructureType.VK_STRUCTURE_TYPE_MAPPED_MEMORY_RANGE;
    range.pNext = null;
    range.memory = memory;
    range.offset = offset;
    range.size = size;
    return range;
}
VkMappedMemoryRange MappedMemoryRange(VkDeviceSize offset, VkDeviceSize size) {
    VkMappedMemoryRange range;
    range.sType = VkStructureType.VK_STRUCTURE_TYPE_MAPPED_MEMORY_RANGE;
    range.pNext = null;
    range.offset = offset;
    range.size = size;
    return range;
}

struct Memory {
    this(ref Device device, VkDeviceSize allocationSize, uint memoryTypeIndex) {
        VkMemoryAllocateInfo info;
        info.sType = VkStructureType.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
        info.pNext = null;
        info.allocationSize = allocationSize;
        info.memoryTypeIndex = memoryTypeIndex;
        result = vkAllocateMemory(device.device, &info, null, &memory);
        this.device = &device;
    }
    @disable this(ref return scope Memory rhs);
    ~this() {
        vkFreeMemory(device.device, memory, null);
    }
    VkDeviceSize getCommitment() {
        VkDeviceSize commitment;
        vkGetDeviceMemoryCommitment(device.device, memory, &commitment);
        return commitment;
    }
    void* map(VkDeviceSize offset, VkDeviceSize size) {
        void* data;
        result = vkMapMemory(device.device, memory, offset, size, 0, &data);
        return data;
    }
    void unmap() {
        vkUnmapMemory(device.device, memory);
    }
    // nur nötig falls vk_memory_property_host_coherent_bit nicht gesetzt
    // muss synchronisiert werden mit barriers
    void flush(VkMappedMemoryRange[] ranges) {
        for (int i = 0; i < ranges.length; i++) {
            ranges[i].memory = memory;
        }
        result = vkFlushMappedMemoryRanges(device.device, cast(uint) ranges.length, cast(VkMappedMemoryRange*) ranges.ptr);
    }
    // damit host update vom device bekommt, also umgekehrt wie flush
    void invalidate(VkMappedMemoryRange[] ranges) {
        for (int i = 0; i < ranges.length; i++) {
            ranges[i].memory = memory;
        }
        result = vkInvalidateMappedMemoryRanges(device.device, cast(uint) ranges.length, cast(VkMappedMemoryRange*) ranges.ptr);
    }
    Result result;
    VkDeviceMemory memory;
    alias memory this;
    Device* device;
}

struct Surface {
    this(ref Instance instance, VkSurfaceKHR surface) {
        this.instance = &instance;
        this.surface = surface;
    }
    @disable this(ref return scope Surface rhs);
    ~this() {
        vkDestroySurfaceKHR(instance.instance, surface, null);
    }
    Result result;
    Instance* instance;
    VkSurfaceKHR surface;
    alias surface this;
}

struct Swapchain {
    // hier noch anpassen wegen sharingmode
    this(ref Device device, VkSurfaceKHR surface, uint minImageCount, VkFormat imageFormat, VkColorSpaceKHR imageColorSpace, VkExtent2D imageExtent, uint imageArrayLayers, VkImageUsageFlags imageUsage, VkSharingMode imageSharingMode, uint[] familyIndices, VkSurfaceTransformFlagBitsKHR preTransform, VkCompositeAlphaFlagBitsKHR compositeAlpha, VkPresentModeKHR presentMode, VkBool32 clipped, VkSwapchainKHR oldSwapchain) {
        VkSwapchainCreateInfoKHR info;
        info.sType = VkStructureType.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
        info.pNext = null;
        info.flags = 0;
        info.surface = surface;
        info.minImageCount = minImageCount;
        info.imageFormat = imageFormat;
        info.imageColorSpace = imageColorSpace;
        info.imageExtent = imageExtent;
        info.imageArrayLayers = imageArrayLayers;
        info.imageUsage = imageUsage;
        info.imageSharingMode = imageSharingMode;
        info.queueFamilyIndexCount = cast(uint) familyIndices.length;
        info.pQueueFamilyIndices = familyIndices.ptr;
        info.preTransform = preTransform;
        info.compositeAlpha = compositeAlpha;
        info.presentMode = presentMode;
        info.clipped = clipped;
        info.oldSwapchain = oldSwapchain;
        result = vkCreateSwapchainKHR(device.device, &info, null, &swapchain);
        this.device = &device;
        uint imageCount;
        result = vkGetSwapchainImagesKHR(device.device, swapchain, &imageCount, null);
        images = Vector!VkImage(imageCount);
        result = vkGetSwapchainImagesKHR(device.device, swapchain, &imageCount, images.ptr);
    }
    this(ref Device device, VkSurfaceKHR surface, uint minImageCount, VkFormat imageFormat, VkColorSpaceKHR imageColorSpace, VkExtent2D imageExtent, uint imageArrayLayers, VkImageUsageFlags imageUsage, VkSharingMode imageSharingMode, uint[] familyIndices, VkSurfaceTransformFlagBitsKHR preTransform, VkCompositeAlphaFlagBitsKHR compositeAlpha, VkPresentModeKHR presentMode, VkBool32 clipped) {
        this(device, surface, minImageCount, imageFormat, imageColorSpace, imageExtent, imageArrayLayers, imageUsage, imageSharingMode, familyIndices, preTransform, compositeAlpha, presentMode, clipped, swapchain);
    }
    @disable this(ref return scope Swapchain rhs);
    ~this() {
        vkDestroySwapchainKHR(device.device, swapchain, null);
    }
    uint aquireNextImage(ulong timeout, VkSemaphore semaphore, VkFence fence) {
        result = vkAcquireNextImageKHR(device.device, swapchain, timeout, semaphore, fence, &currentIndex);
        return currentIndex;
    }
    uint aquireNextImage(VkSemaphore semaphore, VkFence fence) {
        result = vkAcquireNextImageKHR(device.device, swapchain, cast(ulong) -1L, semaphore, fence, &currentIndex);
        return currentIndex;
    }
    Result result;
    VkSwapchainKHR swapchain;
    alias swapchain this;
    Device* device;
    Vector!VkImage images;
    uint currentIndex;
}

struct Shader {
    this(ref Device device, string code) {
        VkShaderModuleCreateInfo info;
        info.sType = VkStructureType.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
        info.pNext = null;
        info.flags = 0;
        info.codeSize = code.length; // in bytes
        info.pCode = cast(uint*) code.ptr;
        result = vkCreateShaderModule(device, &info, null, &shader);
        this.device = &device;
    }
    @disable this(ref return scope Shader rhs);
    ~this() {
        vkDestroyShaderModule(device.device, shader, null);
    }
    Result result;
    Device* device;
    VkShaderModule shader;
    alias shader this;
}

struct DescriptorSetLayout {
    this(ref Device device, VkDescriptorSetLayoutBinding[] bindings) {
        VkDescriptorSetLayoutCreateInfo info;
        info.sType = VkStructureType.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
        info.pNext = null;
        info.flags = 0;
        info.bindingCount = cast(uint) bindings.length;
        info.pBindings = bindings.ptr;
        result = vkCreateDescriptorSetLayout(device.device, &info, null, &descriptorSetLayout);
        this.device = &device;
    }
    @disable this(ref return scope DescriptorSetLayout rhs);
    ~this() {
        vkDestroyDescriptorSetLayout(device.device, descriptorSetLayout, null);
    }
    Result result;
    Device* device;
    VkDescriptorSetLayout descriptorSetLayout;
    alias descriptorSetLayout this;
}

struct PipelineLayout {
    this(ref Device device, VkDescriptorSetLayout[] descriptorSetLayouts, VkPushConstantRange[] pushConstants) {
        VkPipelineLayoutCreateInfo info;
        info.sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
        info.pNext = null;
        info.flags = 0;
        info.setLayoutCount = cast(uint) descriptorSetLayouts.length;
        info.pSetLayouts = descriptorSetLayouts.ptr;
        info.pushConstantRangeCount = cast(uint) pushConstants.length;
        info.pPushConstantRanges = pushConstants.ptr;
        result = vkCreatePipelineLayout(device.device, &info, null, &pipelineLayout);
        this.device = &device;
    }
    this(ref Device device, VkDescriptorSetLayout[] descriptorSetLayouts) {
        VkPipelineLayoutCreateInfo info;
        info.sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
        info.pNext = null;
        info.flags = 0;
        info.setLayoutCount = cast(uint) descriptorSetLayouts.length;
        info.pSetLayouts = descriptorSetLayouts.ptr;
        info.pushConstantRangeCount = 0;
        info.pPushConstantRanges = null;
        result = vkCreatePipelineLayout(device.device, &info, null, &pipelineLayout);
        this.device = &device;
    }
    @disable this(ref return scope PipelineLayout rhs);
    ~this() {
        vkDestroyPipelineLayout(device.device, pipelineLayout, null);
    }
    Result result;
    VkPipelineLayout pipelineLayout;
    Device* device;
    alias pipelineLayout this;
}

struct ComputePipelineInfo {
    this(VkShaderModule shader, char* entry, VkPipelineLayout layout, VkSpecializationMapEntry[] spezialization, size_t dataSize, void* data) {
        specInfo.mapEntryCount = cast(uint) spezialization.length;
        specInfo.pMapEntries = spezialization.ptr;
        specInfo.dataSize = dataSize;
        specInfo.pData = data;
        VkPipelineShaderStageCreateInfo stageInfo;
        stageInfo.sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        stageInfo.pNext = null;
        stageInfo.flags = 0;
        stageInfo.stage = VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT;
        stageInfo.module_ = shader;
        stageInfo.pName = entry;
        stageInfo.pSpecializationInfo = &specInfo;
        info.sType = VkStructureType.VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO;
        info.pNext = null;
        info.flags = 0; // https://www.khronos.org/registry/vulkan/specs/1.2-extensions/html/vkspec.html#pipelines-pipeline-derivatives
        info.stage = stageInfo;
        info.layout = layout;
    }
    this(VkShaderModule shader, char* entry, VkPipelineLayout layout, VkSpecializationMapEntry[] spezialization, size_t dataSize, void* data, VkPipeline base) {
        specInfo.mapEntryCount = cast(uint) spezialization.length;
        specInfo.pMapEntries = spezialization.ptr;
        specInfo.dataSize = dataSize;
        specInfo.pData = data;
        VkPipelineShaderStageCreateInfo stageInfo;
        stageInfo.sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        stageInfo.pNext = null;
        stageInfo.flags = 0;
        stageInfo.stage = VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT;
        stageInfo.module_ = shader;
        stageInfo.pName = entry;
        stageInfo.pSpecializationInfo = &specInfo;
        info.sType = VkStructureType.VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO;
        info.pNext = null;
        info.flags = VkPipelineCreateFlagBits.VK_PIPELINE_CREATE_DERIVATIVE_BIT;
        info.stage = stageInfo;
        info.layout = layout;
        info.basePipelineHandle = base;
    }
    this(VkShaderModule shader, char* entry, VkPipelineLayout layout, VkSpecializationMapEntry[] spezialization, size_t dataSize, void* data, uint base) {
        specInfo.mapEntryCount = cast(uint) spezialization.length;
        specInfo.pMapEntries = spezialization.ptr;
        specInfo.dataSize = dataSize;
        specInfo.pData = data;
        VkPipelineShaderStageCreateInfo stageInfo;
        stageInfo.sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        stageInfo.pNext = null;
        stageInfo.flags = 0;
        stageInfo.stage = VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT;
        stageInfo.module_ = shader;
        stageInfo.pName = entry;
        stageInfo.pSpecializationInfo = &specInfo;
        info.sType = VkStructureType.VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO;
        info.pNext = null;
        info.flags = VkPipelineCreateFlagBits.VK_PIPELINE_CREATE_DERIVATIVE_BIT;
        info.stage = stageInfo;
        info.layout = layout;
        info.basePipelineIndex = base;
    }
    VkSpecializationInfo specInfo;
    VkComputePipelineCreateInfo info;
    alias info this;
}

struct ComputePipeline {
    this(ref Device device, VkPipelineCache cache, VkShaderModule shader, string entry, VkPipelineLayout layout, VkSpecializationMapEntry[] spezialization, size_t dataSize, void* data) {
        VkSpecializationInfo specInfo;
        specInfo.mapEntryCount = cast(uint) spezialization.length;
        specInfo.pMapEntries = spezialization.ptr;
        specInfo.dataSize = dataSize;
        specInfo.pData = data;
        VkPipelineShaderStageCreateInfo stageInfo;
        stageInfo.sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        stageInfo.pNext = null;
        stageInfo.flags = 0;
        stageInfo.stage = VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT;
        stageInfo.module_ = shader;
        stageInfo.pName = entry.ptr;
        stageInfo.pSpecializationInfo = &specInfo;
        VkComputePipelineCreateInfo info;
        info.sType = VkStructureType.VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO;
        info.pNext = null;
        info.flags = 0; // https://www.khronos.org/registry/vulkan/specs/1.2-extensions/html/vkspec.html#pipelines-pipeline-derivatives
        info.stage = stageInfo;
        info.layout = layout;
        //info.basePipelineHandle;
        //info.basePipelineIndex;
        result = vkCreateComputePipelines(device.device, null, 1, &info, null, &pipeline);// todo
        this.device = &device;
    }
    this(ref Device device, VkPipelineCache cache, VkShaderModule shader, string entry, VkPipelineLayout layout, VkSpecializationMapEntry[] spezialization, size_t dataSize, void* data, VkPipeline base) {
        VkSpecializationInfo specInfo;
        specInfo.mapEntryCount = cast(uint) spezialization.length;
        specInfo.pMapEntries = spezialization.ptr;
        specInfo.dataSize = dataSize;
        specInfo.pData = data;
        VkPipelineShaderStageCreateInfo stageInfo;
        stageInfo.sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        stageInfo.pNext = null;
        stageInfo.flags = 0;
        stageInfo.stage = VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT;
        stageInfo.module_ = shader;
        stageInfo.pName = entry.ptr;
        stageInfo.pSpecializationInfo = &specInfo;
        VkComputePipelineCreateInfo info;
        info.sType = VkStructureType.VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO;
        info.pNext = null;
        info.flags = VkPipelineCreateFlagBits.VK_PIPELINE_CREATE_DERIVATIVE_BIT;
        info.stage = stageInfo;
        info.layout = layout;
        info.basePipelineHandle = base;
        //info.basePipelineIndex;
        result = vkCreateComputePipelines(device.device, null, 1, &info, null, &pipeline);// todo
        this.device = &device;
    }
    this(ref Device device, VkShaderModule shader, string entry, VkPipelineLayout layout, VkSpecializationMapEntry[] spezialization, size_t dataSize, void* data) {
        this(device, null, shader, entry, layout, spezialization, dataSize, data);
    }
    this(ref Device device, VkShaderModule shader, string entry, VkPipelineLayout layout, VkSpecializationMapEntry[] spezialization, size_t dataSize, void* data, VkPipeline base) {
        this(device, null, shader, entry, layout, spezialization, dataSize, data, base);
    }
    @disable this(ref return scope ComputePipeline rhs);
    ~this() {
        vkDestroyPipeline(device.device, pipeline, null);
    }
    Result result;
    Device* device;
    alias pipeline this;
    VkPipeline pipeline;
}

struct DescriptorPool {
    this(ref Device device, VkDescriptorPoolCreateFlags flags, uint maxSets, VkDescriptorPoolSize[] poolSizes) {
        VkDescriptorPoolCreateInfo info;
        info.sType = VkStructureType.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO;
        info.pNext = null;
        info.flags = flags;
        info.maxSets = maxSets;
        info.poolSizeCount = cast(uint) poolSizes.length;
        info.pPoolSizes = poolSizes.ptr;
        result = vkCreateDescriptorPool(device.device, &info, null, &descriptorPool);
        this.device = &device;
        setsFreeable = (flags & VkDescriptorPoolCreateFlagBits.VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT) == VkDescriptorPoolCreateFlagBits.VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT;
    }
    @disable this(ref return scope DescriptorPool rhs);
    ~this() {
        vkDestroyDescriptorPool(device.device, descriptorPool, null);
    }
    Vector!DescriptorSet allocateSets(VkDescriptorSetLayout[] layouts) {
        VkDescriptorSetAllocateInfo info;
        info.sType = VkStructureType.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO;
        info.pNext = null;
        info.descriptorPool = descriptorPool;
        info.descriptorSetCount = cast(uint) layouts.length;
        info.pSetLayouts = layouts.ptr;
        auto vkSets = Vector!VkDescriptorSet(layouts.length);
        result = vkAllocateDescriptorSets(device.device, &info, vkSets.ptr);
        auto sets = Vector!DescriptorSet(layouts.length);
        for (int i = 0; i < layouts.length; i++) {
            sets[i].descriptorPool = &this;
            sets[i].descriptorSet = vkSets[i];
        }
        return sets;
    }
    DescriptorSet allocateSet(VkDescriptorSetLayout layout) {
        return DescriptorSet(this, layout);
    }
    VkResult reset() {
        return vkResetDescriptorPool(device.device, descriptorPool, 0);
    }
    Result result;
    Device* device;
    VkDescriptorPool descriptorPool;
    alias descriptorPool this;
    bool setsFreeable;
}

VkCopyDescriptorSet CopyDescriptorSet(VkDescriptorSet srcSet, uint srcIndex, uint srcArrayElement, VkDescriptorSet dstSet, uint dstIndex, uint dstArrayElement, uint descriptorCount) {
    VkCopyDescriptorSet copyDescriptorSet;
    copyDescriptorSet.sType = VkStructureType.VK_STRUCTURE_TYPE_COPY_DESCRIPTOR_SET;
    copyDescriptorSet.pNext = null;
    copyDescriptorSet.srcSet = srcSet;
    copyDescriptorSet.srcBinding = srcIndex;
    copyDescriptorSet.srcArrayElement = srcArrayElement;
    copyDescriptorSet.dstSet = dstSet;
    copyDescriptorSet.dstBinding = dstIndex;
    copyDescriptorSet.dstArrayElement = dstArrayElement;
    copyDescriptorSet.descriptorCount = descriptorCount;
    return copyDescriptorSet;
}
VkCopyDescriptorSet CopyDescriptorSet(VkDescriptorSet srcSet, uint srcIndex, VkDescriptorSet dstSet, uint dstIndex) {
    return CopyDescriptorSet(srcSet, srcIndex, 0, dstSet, dstIndex, 0, 1);
}

// hier unbedingt variadic parameter verwenden
struct WriteDescriptorSet {
    this(VkDescriptorSet set, uint index, uint arrayStart, uint count, VkDescriptorType type, VkSampler sampler, VkImageView view, VkImageLayout layout) {
        imageInfo.sampler = sampler;
        imageInfo.imageView = view;
        imageInfo.imageLayout = layout;
        writeDescriptorSet.sType = VkStructureType.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writeDescriptorSet.pNext = null;
        writeDescriptorSet.dstSet = set;
        writeDescriptorSet.dstBinding = index;
        writeDescriptorSet.dstArrayElement = arrayStart;
        writeDescriptorSet.descriptorCount = count;
        writeDescriptorSet.descriptorType = type;
        writeDescriptorSet.pImageInfo = &imageInfo;
    }
    this(VkDescriptorSet set, uint index, uint arrayStart, uint count, VkDescriptorType type, VkBuffer buffer, VkDeviceSize offset, VkDeviceSize range) {
        bufferInfo.buffer = buffer;
        bufferInfo.offset = offset;
        bufferInfo.range = range;
        writeDescriptorSet.sType = VkStructureType.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writeDescriptorSet.pNext = null;
        writeDescriptorSet.dstSet = set;
        writeDescriptorSet.dstBinding = index;
        writeDescriptorSet.dstArrayElement = arrayStart;
        writeDescriptorSet.descriptorCount = count;
        writeDescriptorSet.descriptorType = type;
        writeDescriptorSet.pBufferInfo = &bufferInfo;
    }
    this(VkDescriptorSet set, uint index, uint arrayStart, uint count, VkDescriptorType type, VkBufferView view) {
        writeDescriptorSet.sType = VkStructureType.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        writeDescriptorSet.pNext = null;
        writeDescriptorSet.dstSet = set;
        writeDescriptorSet.dstBinding = index;
        writeDescriptorSet.dstArrayElement = arrayStart;
        writeDescriptorSet.descriptorCount = count;
        writeDescriptorSet.descriptorType = type;
        writeDescriptorSet.pTexelBufferView = &view;
    }
    this(VkDescriptorSet set, uint index, uint arrayStart, uint count, VkDescriptorType type, VkImageView view, VkImageLayout layout) {
        this(set, index, arrayStart, count, type, null, view, layout);
    }
    this(VkDescriptorSet set, uint index, uint arrayStart, uint count, VkDescriptorType type, VkBuffer buffer) {
        this(set, index, arrayStart, count, type, buffer, 0, VK_WHOLE_SIZE);
    }
    this(VkDescriptorSet set, uint index, VkDescriptorType type, VkSampler sampler, VkImageView view, VkImageLayout layout) {
        this(set, index, 0, 1, type, sampler, view, layout);
    }
    this(VkDescriptorSet set, uint index, VkDescriptorType type, VkImageView view, VkImageLayout layout) {
        this(set, index, 0, 1, type, null, view, layout);
    }
    this(VkDescriptorSet set, uint index, VkDescriptorType type, VkBuffer buffer, VkDeviceSize offset, VkDeviceSize range) {
        this(set, index, 0, 1, type, buffer, offset, range);
    }
    this(VkDescriptorSet set, uint index, VkDescriptorType type, VkBuffer buffer) {
        this(set, index, 0, 1, type, buffer, 0, VK_WHOLE_SIZE);
    }
    this(VkDescriptorSet set, uint index, VkDescriptorType type, VkBufferView view) {
        this(set, index, 0, 1, type, view);
    }
    this(uint index, uint arrayStart, uint count, VkDescriptorType type, VkSampler sampler, VkImageView view, VkImageLayout layout) {
        this(null, index, arrayStart, count, type, sampler, view, layout);
    }
    this(uint index, uint arrayStart, uint count, VkDescriptorType type, VkBuffer buffer, VkDeviceSize offset, VkDeviceSize range) {
        this(null, index, arrayStart, count, type, buffer, offset, range);
    }
    this(uint index, uint arrayStart, uint count, VkDescriptorType type, VkBufferView view) {
        this(null, index, arrayStart, count, type, view);
    }
    this(uint index, uint arrayStart, uint count, VkDescriptorType type, VkImageView view, VkImageLayout layout) {
        this(null, index, arrayStart, count, type, null, view, layout);
    }
    this(uint index, uint arrayStart, uint count, VkDescriptorType type, VkBuffer buffer) {
        this(null, index, arrayStart, count, type, buffer, 0, VK_WHOLE_SIZE);
    }
    this(uint index, VkDescriptorType type, VkSampler sampler, VkImageView view, VkImageLayout layout) {
        this(null, index, 0, 1, type, sampler, view, layout);
    }
    this(uint index, VkDescriptorType type, VkImageView view, VkImageLayout layout) {
        this(null, index, 0, 1, type, null, view, layout);
    }
    this(uint index, VkDescriptorType type, VkBuffer buffer, VkDeviceSize offset, VkDeviceSize range) {
        this(null, index, 0, 1, type, buffer, offset, range);
    }
    this(uint index, VkDescriptorType type, VkBuffer buffer) {
        this(null, index, 0, 1, type, buffer, 0, VK_WHOLE_SIZE);
    }
    this(uint index, VkDescriptorType type, VkBufferView view) {
        this(null, index, 0, 1, type, view);
    }
    VkDescriptorImageInfo imageInfo;
    VkDescriptorBufferInfo bufferInfo;
    VkWriteDescriptorSet writeDescriptorSet;
    alias writeDescriptorSet this;
}

struct DescriptorSet {
    this(ref DescriptorPool descriptorPool, VkDescriptorSetLayout layout) {
        VkDescriptorSetAllocateInfo info;
        info.sType = VkStructureType.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO;
        info.pNext = null;
        info.descriptorPool = descriptorPool.descriptorPool;
        info.descriptorSetCount = 1;
        info.pSetLayouts = &layout;
        result = vkAllocateDescriptorSets(descriptorPool.device.device, &info, &descriptorSet);
        this.descriptorPool = &descriptorPool;
    }
    @disable this(ref return scope DescriptorSet rhs);
    ~this() {
        if (descriptorPool.setsFreeable && descriptorSet != null) {
            vkFreeDescriptorSets(descriptorPool.device.device, descriptorPool.descriptorPool, 1, &descriptorSet);
        }
    }
    void write(VkWriteDescriptorSet[] writes) {
        for (int i = 0; i < writes.length; i++) {
            writes[i].dstSet = descriptorSet;
        }
        vkUpdateDescriptorSets(descriptorPool.device.device, cast(uint) writes.length, writes.ptr, 0, null);
    }
    void write(VkWriteDescriptorSet write) {
        write.dstSet = descriptorSet;
        vkUpdateDescriptorSets(descriptorPool.device.device, 1, &write, 0, null);
    }
    Result result;
    DescriptorPool* descriptorPool;
    VkDescriptorSet descriptorSet;
    alias descriptorSet this;
}

struct PipelineCache {
    this(ref Device device, string data) {
        VkPipelineCacheCreateInfo info;
        info.sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_CACHE_CREATE_INFO;
        info.pNext = null;
        info.flags = 0;
        info.initialDataSize = data.length;
        info.pInitialData = data.ptr;
        result = vkCreatePipelineCache(device.device, &info, null, &pipelineCache);
        this.device = &device;
    }
    this(ref Device device) {
        VkPipelineCacheCreateInfo info;
        info.sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_CACHE_CREATE_INFO;
        info.pNext = null;
        info.flags = 0;
        info.initialDataSize = 0;
        info.pInitialData = null;
        result = vkCreatePipelineCache(device.device, &info, null, &pipelineCache);
        this.device = &device;
    }
    this(ref Device device, VkPipelineCache[] merge) {
        this(device);
        result = vkMergePipelineCaches(device.device, pipelineCache, cast(uint) merge.length, merge.ptr);
    }
    @disable this(ref return scope PipelineCache rhs);
    ~this() {
        vkDestroyPipelineCache(device.device, pipelineCache, null);
    }
    String getData() {
        size_t size;
        result = vkGetPipelineCacheData(device.device, pipelineCache, &size, null);
        String ret = String(size);
        result = vkGetPipelineCacheData(device.device, pipelineCache, &size, cast(void*) ret.ptr);
        return ret;
    }
    VkResult merge(VkPipelineCache[] merge) {
        return result = vkMergePipelineCaches(device.device, pipelineCache, cast(uint) merge.length, merge.ptr);
    }
    Result result;
    Device* device;
    VkPipelineCache pipelineCache;
    alias pipelineCache this;
}

struct Sampler {
    this(
        ref Device device,
        VkFilter magFilter,
        VkFilter minFilter,
        VkSamplerMipmapMode mipmapMode,
        VkSamplerAddressMode addressModeU,
        VkSamplerAddressMode addressModeV,
        VkSamplerAddressMode addressModeW,
        float mipLodBias,
        VkBool32 anisotropyEnable,
        float maxAnisotropy,
        VkBool32 compareEnable,
        VkCompareOp compareOp,
        float minLod,
        float maxLod,
        VkBorderColor borderColor,
        VkBool32 unnormalizedCoordinate
    ) {
        this.device = &device;
        VkSamplerCreateInfo info = VkSamplerCreateInfo(
            VkStructureType.VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
            null,
            0,
            magFilter,
            minFilter,
            mipmapMode,
            addressModeU,
            addressModeV,
            addressModeW,
            mipLodBias,
            anisotropyEnable,
            maxAnisotropy,
            compareEnable,
            compareOp,
            minLod,
            maxLod,
            borderColor,
            unnormalizedCoordinate
        );
        result = vkCreateSampler(device.device, &info, null, &sampler);
    }
    @disable this(ref return scope Sampler rhs);
    ~this() {
        vkDestroySampler(device.device, sampler, null);
    }
    Result result;
    Device* device;
    VkSampler sampler;
    alias sampler this;
}

struct QueryPool {
    this(ref Device device, VkQueryType queryType, uint queryCount, VkQueryPipelineStatisticFlags pipelineStatistics) {
        VkQueryPoolCreateInfo info;
        info.sType = VkStructureType.VK_STRUCTURE_TYPE_QUERY_POOL_CREATE_INFO;
        info.pNext = null;
        info.flags = 0;
        info.queryType = queryType;
        info.queryCount = queryCount;
        info.pipelineStatistics = pipelineStatistics;
        result = vkCreateQueryPool(device.device, &info, null, &queryPool);
        this.device = &device;
    }
    @disable this(ref return scope QueryPool rhs);
    ~this() {
        vkDestroyQueryPool(device.device, queryPool, null);
    }
    VkResult getResults(uint firstQuery, uint queryCount, size_t dataSize, void* data, VkDeviceSize stride, VkQueryResultFlags flags) {
        return result = vkGetQueryPoolResults(device.device, queryPool, firstQuery, queryCount, dataSize, data, stride, flags);
    }
    String getResults(uint firstQuery, uint queryCount, size_t dataSize, VkDeviceSize stride, VkQueryResultFlags flags) {
        String ret = String(dataSize);
        result = vkGetQueryPoolResults(device.device, queryPool, firstQuery, queryCount, dataSize, cast(void*) ret.ptr, stride, flags);
        return ret;
    }
    Result result;
    Device* device;
    VkQueryPool queryPool;
    alias queryPool this;
}

struct RenderPass {
    this(ref Device device, VkAttachmentDescription[] attachements, VkSubpassDescription[] subpasses, VkSubpassDependency[] dependencies) {
        VkRenderPassCreateInfo info;
        info.sType = VkStructureType.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
        info.pNext = null;
        info.flags = 0;
        info.attachmentCount = cast(uint) attachements.length;
        info.pAttachments = attachements.ptr;
        info.subpassCount = cast(uint) subpasses.length;
        info.pSubpasses = subpasses.ptr;
        info.dependencyCount = cast(uint) dependencies.length;
        info.pDependencies = dependencies.ptr;
        result = vkCreateRenderPass(device.device, &info, null, &renderPass);
        this.device = &device;
    }
    @disable this(ref return scope RenderPass rhs);
    ~this() {
        vkDestroyRenderPass(device.device, renderPass, null);
    }
    Framebuffer createFramebuffer(VkImageView[] views, uint width, uint height, uint layers) {
        return Framebuffer(this, views, width, height, layers);
    }
    GraphicsPipeline createGraphicsPipeline(Args...)(in Args args) {
        return GraphicsPipeline(this, args);
    }
    Result result;
    Device* device;
    VkRenderPass renderPass;
    alias renderPass this;
}

struct Framebuffer {
    this(ref RenderPass renderPass, VkImageView[] views, uint width, uint height, uint layers) {
        VkFramebufferCreateInfo info;
        info.sType = VkStructureType.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
        info.pNext = null;
        info.flags = 0;
        info.renderPass = renderPass.renderPass;
        info.attachmentCount = cast(uint) views.length;
        info.pAttachments = views.ptr;
        info.width = width;
        info.height = height;
        info.layers = layers;
        result = vkCreateFramebuffer(renderPass.device.device, &info, null, &framebuffer);
        this.renderPass = &renderPass;
    }
    @disable this(ref return scope Framebuffer rhs);
    ~this() {
        vkDestroyFramebuffer(renderPass.device.device, framebuffer, null);
    }
    Result result;
    RenderPass* renderPass;
    VkFramebuffer framebuffer;
    alias framebuffer this;
}

VkSubpassDescription SubpassDescription(VkAttachmentReference[] inputAttachments, VkAttachmentReference[] colorAttachments, VkAttachmentReference[] resolveAttachments, VkAttachmentReference depthStencilAttachment, uint[] preserveAttachments) {
    VkSubpassDescription description;
    description.flags = 0;
    description.pipelineBindPoint = VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS;
    description.inputAttachmentCount = cast(uint) inputAttachments.length;
    description.pInputAttachments = inputAttachments.ptr;
    description.colorAttachmentCount = cast(uint) colorAttachments.length;
    description.pColorAttachments = colorAttachments.ptr;
    description.pResolveAttachments = resolveAttachments.ptr;
    description.pDepthStencilAttachment = &depthStencilAttachment;
    description.preserveAttachmentCount = cast(uint) preserveAttachments.length;
    description.pPreserveAttachments = preserveAttachments.ptr;
    return description;
}
VkSubpassDescription SubpassDescription(VkAttachmentReference[] inputAttachments, VkAttachmentReference[] colorAttachments, VkAttachmentReference[] resolveAttachments, uint[] preserveAttachments) {
    VkSubpassDescription description;
    description.flags = 0;
    description.pipelineBindPoint = VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS;
    description.inputAttachmentCount = cast(uint) inputAttachments.length;
    description.pInputAttachments = inputAttachments.ptr;
    description.colorAttachmentCount = cast(uint) colorAttachments.length;
    description.pColorAttachments = colorAttachments.ptr;
    description.pResolveAttachments = resolveAttachments.ptr;
    description.pDepthStencilAttachment = null;
    description.preserveAttachmentCount = cast(uint) preserveAttachments.length;
    description.pPreserveAttachments = preserveAttachments.ptr;
    return description;
}

struct GraphicsPipelineCreateInfo(Args...) {
    this(in Args args) {
        stages = compatibleTypesToArray!VkPipelineShaderStageCreateInfo(args);
        VkPipelineVertexInputStateCreateInfo* vertexInput;
        VkPipelineInputAssemblyCreateInfo* inputAssembly;
        VkPipelineTessellationStateCreateInfo* tessellation;
        VkPipelineViewportStateCreateInfo* viewport;
        VkPipelineRasterizationStateCreateInfo* rasterization;
        VkPipelineMultisampleStateCreateInfo* multisample;
        VkPipelineDepthStencilStateCreateInfo* depthStencil;
        VkPipelineColorBlendStateCreateInfo* colorBlend;
        VkPipelineDynamicStateCreateInfo* dynamic;
        static if (countTypeCompatible!(VkPipelineVertexInputStateCreateInfo, Args) > 0)
            vertexInput = &args[findCompatibleTypes!(VkPipelineVertexInputStateCreateInfo, Args)[0]];
        static if (countTypeCompatible!(VkPipelineInputAssemblyCreateInfo, Args) > 0)
            inputAssembly = &args[findCompatibleTypes!(VkPipelineInputAssemblyCreateInfo, Args)[0]];
        static if (countTypeCompatible!(VkPipelineTessellationStateCreateInfo, Args) > 0)
            tessellation = &args[findCompatibleTypes!(VkPipelineTessellationStateCreateInfo, Args)[0]];
        static if (countTypeCompatible!(VkPipelineViewportStateCreateInfo, Args) > 0)
            viewport = &args[findCompatibleTypes!(VkPipelineViewportStateCreateInfo, Args)[0]];
        static if (countTypeCompatible!(VkPipelineRasterizationStateCreateInfo, Args) > 0)
            rasterization = &args[findCompatibleTypes!(VkPipelineRasterizationStateCreateInfo, Args)[0]];
        static if (countTypeCompatible!(VkPipelineMultisampleStateCreateInfo, Args) > 0)
            multisample = &args[findCompatibleTypes!(VkPipelineMultisampleStateCreateInfo, Args)[0]];
        static if (countTypeCompatible!(VkPipelineDepthStencilStateCreateInfo, Args) > 0)
            depthStencil = &args[findCompatibleTypes!(VkPipelineDepthStencilStateCreateInfo, Args)[0]];
        static if (countTypeCompatible!(VkPipelineColorBlendStateCreateInfo, Args) > 0)
            colorBlend = &args[findCompatibleTypes!(VkPipelineColorBlendStateCreateInfo, Args)[0]];
        static if (countTypeCompatible!(VkPipelineDynamicStateCreateInfo, Args) > 0)
            dynamic = &args[findCompatibleTypes!(VkPipelineDynamicStateCreateInfo, Args)[0]];
        VkPipelineLayout layout = args[findTypes!(VkPipelineLayout, Args)[0]];
        VkRenderPass renderPass = args[findTypes!(VkRenderPass, Args)[0]];
        VkPipelineCreateFlags flags = 0;
        enum auto flagsCount = findTypes!(VkPipelineCreateFlags, Args).length;
        static if (flagsCount > 0) {
            flags = args[findTypes!(VkPipelineCreateFlags, Args)[0]];
        }
        uint subpass = 0;
        //vorsicht, VkPipelineCreateFlags ist ein uint; muss noch getestet werden
        static if (findCompatibleTypes!(uint, Args).length > 0 + flagsCount) {
            subpass = cast(uint) args[findTypes!(uint, Args)[0 + flagsCount]];
        }
        VkPipeline basePipelineHandle = null;
        static if (findCompatibleTypes!(VkPipeline, Args).length > 0) {
            basePipelineHandle = cast(VkPipeline) args[findTypes!(VkPipeline, Args)[0]];
        }
        int basePipelineIndex = 0;
        static if (findCompatibleTypes!(int, Args).length > 1 + flagsCount) {
            basePipelineIndex = cast(int) args[findTypes!(int, Args)[1 + flagsCount]];
        }
        info.sType = VkStructureType.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
        info.pNext = null;
        info.flags = flags;
        info.stageCount = cast(uint) stages.length;
        info.pStages = stages.ptr;
        info.pVertexInputState = vertexInput.ptr;
        info.pInputAssemblyState = inputAssembly.ptr;
        info.pTessellationState = tessellation.ptr;
        info.pViewportState = viewport.ptr;
        info.pRasterizationState = rasterization.ptr;
        info.pMultisampleState = multisample.ptr;
        info.pDepthStencilState = depthStencil.ptr;
        info.pColorBlendState = colorBlend.ptr;
        info.pDynamicState = dynamic.ptr;
        info.layout = layout;
        info.renderPass = renderPass;
        info.subpass = subpass;
        info.basePipelineHandle = basePipelineHandle;
        info.basePipelineIndex = basePipelineIndex;
    }
    VkPipelineShaderStageCreateInfo[countTypeCompatible!(VkPipelineShaderStageCreateInfo, Args)] shaderStages;
    VkGraphicsPipelineCreateInfo info;
    alias info this;
}

auto graphicsPipelineCreateInfo(Args...)(in Args args) {
    return GraphicsPipelineCreateInfo(args);
}

struct GraphicsPipeline {
    this(ref RenderPass renderPass, VkPipeline pipeline) {
        this.renderPass = &renderPass;
        this.pipeline = pipeline;
    }
    this(Args...)(ref RenderPass renderPass, in Args args) {
        this.renderPass = &renderPass;
        auto info = graphicsPipelineCreateInfo(renderPass, args);
        VkPipelineCache cache = null;
        static if (findCompatibleTypes!(VkPipelineCache, Args).length > 0) {
            cache = cast(VkPipelineCache) args[findCompatibleTypes!(VkPipelineCache, Args)[0]];
        }
        result = vkCreateGraphicsPipelines(renderPass.device.device, cache, 1, &info, null, &pipeline);
    }
    @disable this(ref return scope GraphicsPipeline rhs);
    ~this() {
        vkDestroyPipeline(renderPass.device.device, pipeline, null);
    }
    Result result;
    RenderPass* renderPass;
    VkPipeline pipeline;
    alias pipeline this;
}

// ----------------------------------------------------------

int* testret(int[] a) {
    return a.ptr;
}
string testsource = import("test2.spv");

void main() {
    auto layers = getInstanceLayers();
    foreach (l; layers) {
        writeln(l.layerName);
    }
    auto extensions = getInstanceExtensions();
    foreach (e; extensions) {
        writeln(e.extensionName);
    }
    version(Windows) {
        // hier könnte man auch ein string array verlangen
        auto instance = Instance("test", 1, VK_API_VERSION_1_0, array!(char*)("VK_LAYER_KHRONOS_validation"), array!(char*)("VK_KHR_surface", "VK_KHR_win32_surface"));
    }
    version(OSX) {
        //"$PACKAGE_DIR/lib/vulkan"
        auto instance = Instance("test", 1, VK_API_VERSION_1_0, array!(char*)("VK_LAYER_KHRONOS_validation"), array!(char*)("VK_KHR_surface", "VK_EXT_metal_surface"/*, "VK_MVK_macos_surface"*/));
        //auto instance = Instance("test", 1, VK_API_VERSION_1_0, array!(char*)("VK_LAYER_KHRONOS_validation"), array!(char*)("VK_KHR_surface", "VK_MVK_macos_surface"));
    }
    version(linux) {
        auto instance = Instance("test", 1, VK_API_VERSION_1_0, array!(char*)("VK_LAYER_KHRONOS_validation"), array!(char*)("VK_KHR_surface", "VK_KHR_xcb_surface"));
    }
    for (uint i = 0; i < instance.physicalDevices[0].memprops.memoryTypeCount; i++) {
        writeln(instance.physicalDevices[0].memprops.memoryTypes[i].propertyFlags, " ", instance.physicalDevices[0].memprops.memoryTypes[i].heapIndex);
    }
    writeln("heap:");
    for (uint i = 0; i < instance.physicalDevices[0].memprops.memoryHeapCount; i++) {
        writeln(instance.physicalDevices[0].memprops.memoryHeaps[i].flags, " ", instance.physicalDevices[0].memprops.memoryHeaps[i].size);
    }
    writeln("queue family properties:");
    foreach (e; instance.physicalDevices[0].queueFamilyProperties) {
        writeln(e.queueFlags, " ", e.queueCount);
    }
    foreach (e; instance.physicalDevices[0].deviceLayerProperties) {
        writeln(e.layerName);
    }
    foreach (e; instance.physicalDevices[0].deviceExtensionProperties) {
        writeln(e.extensionName);
    }
    
    writeln("max allocations", instance.physicalDevices[0].properties.limits.maxMemoryAllocationCount);

    auto device = Device(instance.physicalDevices[0], VkPhysicalDeviceFeatures(), array!(char*)("VK_LAYER_KHRONOS_validation"), array!(char*)("VK_KHR_swapchain"), array(QueueCreateInfo(0, 1)));

    auto commandPool = device.createCommandPool(0, VkCommandPoolCreateFlagBits.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT);
    //auto commandBuffer = move(commandPool.allocateCommandBuffers(1, VkCommandBufferLevel.VK_COMMAND_BUFFER_LEVEL_PRIMARY)[0]);
    CommandBuffer cmdBuffer = commandPool.allocateCommandBuffer(VkCommandBufferLevel.VK_COMMAND_BUFFER_LEVEL_PRIMARY);

    auto buffer = device.createBuffer(0, 1024, VkBufferUsageFlagBits.VK_BUFFER_USAGE_TRANSFER_SRC_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_TRANSFER_DST_BIT | VkBufferUsageFlagBits.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT);
    
    auto memory = device.allocateMemory(buffer.getMemoryRequirements().size, buffer.chooseHeap(VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT));

    buffer.bind(memory, 0);

    auto fence = device.createFence();
    cmdBuffer.begin(0);
    cmdBuffer.fillBuffer(buffer, 69);
    cmdBuffer.end();
    Queue* queue = &device.queues[0];
    queue.submit(array(cmdBuffer), [], [], 0, fence);
    fence.wait();
    auto ptr = memory.map(0, 1024);
    writeln(*(cast(uint*)ptr));
    memory.unmap();

    // -------------------------------------------------------------

    auto shader = Shader(device, testsource);
    auto descriptorSetLayout = device.createDescriptorSetLayout(array(VkDescriptorSetLayoutBinding(
        0,
        VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
        1,
        VkShaderStageFlagBits.VK_SHADER_STAGE_COMPUTE_BIT,
        null
    )));
    auto pipelineLayout = device.createPipelineLayout(array(descriptorSetLayout));
    auto computePipeline = device.createComputePipeline(shader, "main", pipelineLayout);
    auto descriptorPool = device.createDescriptorPool(0, 1, array(VkDescriptorPoolSize(
        VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
        1
    )));
    DescriptorSet descriptorSet = descriptorPool.allocateSet(descriptorSetLayout);

    ptr = memory.map(0, 1024);
    (cast(uint*)ptr)[1] = 123;
    (cast(uint*)ptr)[2] = 456;
    memory.unmap();
    // wichtig: eigentlich sollte der buffer VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT haben für den shader, erhöht massiv performance(ein anderer host visible buffer zum kopieren von daten nötig)
    descriptorSet.write(WriteDescriptorSet(0, VkDescriptorType.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, buffer));
    cmdBuffer.reset();
    cmdBuffer.begin();
    cmdBuffer.bindPipeline(computePipeline, VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_COMPUTE);
    cmdBuffer.bindDescriptorSets(VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_COMPUTE, pipelineLayout, 0, descriptorSet);
    cmdBuffer.dispatch(1, 1, 1);
    cmdBuffer.end();
    fence.reset();
    queue.submit(cmdBuffer, fence);
    fence.wait();
    ptr = memory.map(0, 1024);
    writeln(*(cast(uint*)ptr));
    memory.unmap();

    // -------------------------------------------------------------

    import glfw;
    glfwInit();
    // GLFW_CLIENT_API, GLFW_NO_API
    glfwWindowHint(0x00022001, 0);
    auto window = glfwCreateWindow(640, 480, "Hello", null, null);
    uint reqcount;
    char** requiredExtensions = glfwGetRequiredInstanceExtensions(&reqcount);
    import core.stdc.stdio;
    for (int i = 0; i < reqcount; i++) {
        printf(*(requiredExtensions + i));
    }
    VkSurfaceKHR vksurface;
    auto res = glfwCreateWindowSurface(instance, window, null, &vksurface);
    writeln(res);

    Surface surface = instance.createSurface(vksurface);
    bool surfacesupport = instance.physicalDevices[0].surfaceSupport(surface);
    VkSurfaceCapabilitiesKHR capabilities = instance.physicalDevices[0].getSurfaceCapabilities(surface);
    auto surfaceformats = instance.physicalDevices[0].getSurfaceFormats(surface);

    // vlt eher surface.createSwapchain
    Swapchain swapchain = device.createSwapchain(
        surface,
        2,
        VkFormat.VK_FORMAT_B8G8R8A8_UNORM,
        VkColorSpaceKHR.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR,
        capabilities.currentExtent,
        1,
        VkImageUsageFlagBits.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VkImageUsageFlagBits.VK_IMAGE_USAGE_TRANSFER_DST_BIT,
        VkSharingMode.VK_SHARING_MODE_EXCLUSIVE,
        [],
        VkSurfaceTransformFlagBitsKHR.VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR,
        VkCompositeAlphaFlagBitsKHR.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
        VkPresentModeKHR.VK_PRESENT_MODE_IMMEDIATE_KHR,
        true
    );
    auto semaphore = device.createSemaphore();
    fence.reset();
    // timeout angeben wäre wichtig
    uint imageIndex = swapchain.aquireNextImage(null, fence);
    fence.wait();
    cmdBuffer.reset(0);
    cmdBuffer.begin(0);
    cmdBuffer.pipelineBarrier(
        VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        VkPipelineStageFlagBits.VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
        0, [], [],
        array(ImageMemoryBarrier(
            VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
            VkAccessFlagBits.VK_ACCESS_MEMORY_READ_BIT,
            VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
            VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
            swapchain.images[imageIndex],
            VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
        ))
    );
    cmdBuffer.clearColorImage(
        swapchain.images[imageIndex],
        VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
        VkClearColorValue([1.0, 1.0, 0.0, 1.0]),
        array(VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1))
    );
    cmdBuffer.pipelineBarrier(
        VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        VkPipelineStageFlagBits.VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
        0, [], [],
        array(ImageMemoryBarrier(
            VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
            VkAccessFlagBits.VK_ACCESS_MEMORY_READ_BIT,
            VkImageLayout.VK_IMAGE_LAYOUT_GENERAL,
            VkImageLayout.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
            swapchain.images[imageIndex],
            VkImageSubresourceRange(VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1)
        ))
    );
    cmdBuffer.end();
    fence.reset();
    //queue.submit(array(cmdBuffer), [], [], 0, fence);
    queue.submit(cmdBuffer, fence);
    //queue.present([], array!VkSwapchainKHR(swapchain), array(imageIndex));
    queue.present(swapchain, imageIndex);
    auto testarray123 = array(swapchain);
    pragma(msg, typeof(testarray123));
    fence.wait();

    auto renderPass = device.createRenderPass(
        array(
            VkAttachmentDescription(
                0,
                VkFormat.VK_FORMAT_R8G8B8A8_UNORM,
                VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT,
                VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_CLEAR,
                VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_STORE,
                VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
                VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_DONT_CARE,
                VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
                VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
            )
        ),
        array(
            SubpassDescription(
                [],
                array(
                    VkAttachmentReference(
                        0,
                        VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
                    )
                ),
                [],
                []
            )
        ),
        []
    );
    auto image = device.createImage(
        0,
        VkImageType.VK_IMAGE_TYPE_2D,
        VkFormat.VK_FORMAT_R8G8B8A8_UNORM,
        VkExtent3D(1024, 1024, 1),
        1,
        1,
        VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT,
        VkImageTiling.VK_IMAGE_TILING_OPTIMAL,
        VkImageUsageFlagBits.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
        VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED
    );
    auto memory2 = device.allocateMemory(image.getMemoryRequirements().size, image.chooseHeap(VkMemoryPropertyFlagBits.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT));
    image.bind(memory2, 0);
    auto imageView = image.createImageView(
        VkImageViewType.VK_IMAGE_VIEW_TYPE_2D,
        VkFormat.VK_FORMAT_R8G8B8A8_UNORM,
        VkComponentMapping(
            VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
            VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
            VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
            VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY
        ),
        VkImageSubresourceRange(
            VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT,
            0,
            1,
            0,
            1
        )
    );
    auto framebuffer = renderPass.createFramebuffer(array(imageView), 1024, 1024, 1);

    writeln(typesToArrayInGroup!(int, 0)(1, 2, 3, "bla", 3, 2, 1));
    writeln(typesToArrayInGroup!(int, 1)(1, 2, 3, "bla", 3, 2, 1));

    // scheint zu funktionieren
    int* testval = testret(array(1, 2, 3));
    int* testval2 = testret(array(11, 21, 31));
    writeln(*(testval + 1));

    import core.memory : GC;
    writeln(GC.stats().allocatedInCurrentThread);

    while (!glfwWindowShouldClose(window)) {
        glfwPollEvents();
    }
}

extern(C) __gshared bool rt_cmdline_enabled = false;
extern(C) __gshared string[] rt_options = ["gcopt=gc:manual disable:1"];