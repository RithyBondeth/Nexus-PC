#include <jni.h>
#include <vulkan/vulkan.h>
#include <string>
#include <vector>

extern "C" JNIEXPORT jobjectArray JNICALL
Java_com_nexuspc_app_NativeCore_gpuInfo(JNIEnv* env, jobject) {
    std::string renderer, version;
    VkInstance instance = VK_NULL_HANDLE;
    VkApplicationInfo app{};
    app.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
    app.pApplicationName = "Nexus-PC device profile";
    app.apiVersion = VK_API_VERSION_1_0;
    VkInstanceCreateInfo create{};
    create.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    create.pApplicationInfo = &app;
    if (vkCreateInstance(&create, nullptr, &instance) == VK_SUCCESS) {
        uint32_t count = 0;
        if (vkEnumeratePhysicalDevices(instance, &count, nullptr) == VK_SUCCESS && count > 0) {
            std::vector<VkPhysicalDevice> devices(count);
            if (vkEnumeratePhysicalDevices(instance, &count, devices.data()) == VK_SUCCESS && count > 0) {
                VkPhysicalDeviceProperties properties{};
                vkGetPhysicalDeviceProperties(devices[0], &properties);
                renderer = properties.deviceName;
                version = std::to_string(VK_VERSION_MAJOR(properties.apiVersion)) + "." +
                    std::to_string(VK_VERSION_MINOR(properties.apiVersion)) + "." +
                    std::to_string(VK_VERSION_PATCH(properties.apiVersion));
            }
        }
        vkDestroyInstance(instance, nullptr);
    }
    jclass stringClass = env->FindClass("java/lang/String");
    auto result = env->NewObjectArray(2, stringClass, nullptr);
    auto name = env->NewStringUTF(renderer.c_str());
    auto api = env->NewStringUTF(version.c_str());
    env->SetObjectArrayElement(result, 0, name);
    env->SetObjectArrayElement(result, 1, api);
    env->DeleteLocalRef(name);
    env->DeleteLocalRef(api);
    env->DeleteLocalRef(stringClass);
    return result;
}
