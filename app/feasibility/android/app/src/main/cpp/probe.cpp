#include <jni.h>
#include <android/native_window_jni.h>
#include <vulkan/vulkan.h>
#include <sstream>
#include <vector>

extern "C" JNIEXPORT jstring JNICALL
Java_com_nexuspc_nexus_1probe_SurfaceProbeActivity_probeSurface(
    JNIEnv* env, jobject, jobject surface) {
    ANativeWindow* window = ANativeWindow_fromSurface(env, surface);
    if (!window) return env->NewStringUTF("Native window unavailable");
    VkInstance instance = VK_NULL_HANDLE;
    VkSurfaceKHR vkSurface = VK_NULL_HANDLE;
    std::ostringstream report;
    const char* extensions[] = {VK_KHR_SURFACE_EXTENSION_NAME,
                               VK_KHR_ANDROID_SURFACE_EXTENSION_NAME};
    VkApplicationInfo app{};
    app.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
    app.pApplicationName = "Nexus-PC probe";
    app.apiVersion = VK_API_VERSION_1_0;
    VkInstanceCreateInfo info{};
    info.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    info.pApplicationInfo = &app;
    info.enabledExtensionCount = 2;
    info.ppEnabledExtensionNames = extensions;
    VkResult result = vkCreateInstance(&info, nullptr, &instance);
    report << "vkCreateInstance: " << result << '\n';
    if (result == VK_SUCCESS) {
        VkAndroidSurfaceCreateInfoKHR surfaceInfo{};
        surfaceInfo.sType = VK_STRUCTURE_TYPE_ANDROID_SURFACE_CREATE_INFO_KHR;
        surfaceInfo.window = window;
        result = vkCreateAndroidSurfaceKHR(instance, &surfaceInfo, nullptr, &vkSurface);
        report << "vkCreateAndroidSurfaceKHR: " << result << '\n';
        if (result == VK_SUCCESS) {
            uint32_t count = 0;
            result = vkEnumeratePhysicalDevices(instance, &count, nullptr);
            report << "Device enumeration: " << result << '\n';
            if (result == VK_SUCCESS && count > 0) {
                std::vector<VkPhysicalDevice> devices(count);
                result = vkEnumeratePhysicalDevices(instance, &count, devices.data());
                if (result == VK_SUCCESS) {
                    devices.resize(count);
                    for (auto device : devices) {
                        VkPhysicalDeviceProperties properties{};
                        vkGetPhysicalDeviceProperties(device, &properties);
                        report << "GPU: " << properties.deviceName << " Vulkan "
                               << VK_VERSION_MAJOR(properties.apiVersion) << '.'
                               << VK_VERSION_MINOR(properties.apiVersion) << '\n';
                        uint32_t queues = 0;
                        vkGetPhysicalDeviceQueueFamilyProperties(device, &queues, nullptr);
                        std::vector<VkQueueFamilyProperties> families(queues);
                        vkGetPhysicalDeviceQueueFamilyProperties(device, &queues, families.data());
                        for (uint32_t i = 0; i < queues; ++i) {
                            VkBool32 supported = VK_FALSE;
                            result = vkGetPhysicalDeviceSurfaceSupportKHR(device, i, vkSurface, &supported);
                            report << "Queue " << i << " graphics="
                                   << bool(families[i].queueFlags & VK_QUEUE_GRAPHICS_BIT)
                                   << " present=" << supported << " result=" << result << '\n';
                        }
                    }
                } else report << "Device enumeration failed: " << result << '\n';
            }
        }
    }
    if (vkSurface) vkDestroySurfaceKHR(instance, vkSurface, nullptr);
    if (instance) vkDestroyInstance(instance, nullptr);
    ANativeWindow_release(window);
    report << "Frame rendering and Windows game execution: NOT VALIDATED";
    return env->NewStringUTF(report.str().c_str());
}
