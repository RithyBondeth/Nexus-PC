#pragma once
#include <android/native_window.h>
#include <vulkan/vulkan.h>
#include <algorithm>
#include <limits>
#include <stdexcept>
#include <string>
#include <vector>

// One-shot diagnostic: all resources belong to this surface callback. No handles
// survive resize, pause or surface replacement. This is not the runtime renderer.
namespace nexus {
inline void check(VkResult result, const char* operation) {
    if (result != VK_SUCCESS && result != VK_SUBOPTIMAL_KHR)
        throw std::runtime_error(std::string(operation) + ": " + std::to_string(result));
}
struct FrameResources {
    VkDevice device = VK_NULL_HANDLE;
    VkSwapchainKHR swapchain = VK_NULL_HANDLE;
    VkCommandPool pool = VK_NULL_HANDLE;
    VkSemaphore acquired = VK_NULL_HANDLE, ready = VK_NULL_HANDLE;
    ~FrameResources() {
        if (!device) return;
        vkDeviceWaitIdle(device);
        if (pool) vkDestroyCommandPool(device, pool, nullptr);
        if (ready) vkDestroySemaphore(device, ready, nullptr);
        if (acquired) vkDestroySemaphore(device, acquired, nullptr);
        if (swapchain) vkDestroySwapchainKHR(device, swapchain, nullptr);
        vkDestroyDevice(device, nullptr);
    }
};
inline std::string presentFrame(VkPhysicalDevice physical, VkSurfaceKHR surface,
                               uint32_t family, ANativeWindow* window) {
    FrameResources r;
    try {
        float priority = 1.f;
        VkDeviceQueueCreateInfo queueInfo{};
        queueInfo.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
        queueInfo.queueFamilyIndex = family;
        queueInfo.queueCount = 1;
        queueInfo.pQueuePriorities = &priority;
        const char* extension = VK_KHR_SWAPCHAIN_EXTENSION_NAME;
        VkDeviceCreateInfo deviceInfo{};
        deviceInfo.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
        deviceInfo.queueCreateInfoCount = 1;
        deviceInfo.pQueueCreateInfos = &queueInfo;
        deviceInfo.enabledExtensionCount = 1;
        deviceInfo.ppEnabledExtensionNames = &extension;
        check(vkCreateDevice(physical, &deviceInfo, nullptr, &r.device), "Create device");
        VkQueue queue;
        vkGetDeviceQueue(r.device, family, 0, &queue);
        VkSurfaceCapabilitiesKHR caps{};
        check(vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physical, surface, &caps), "Surface capabilities");
        if (!(caps.supportedUsageFlags & VK_IMAGE_USAGE_TRANSFER_DST_BIT))
            throw std::runtime_error("Surface does not support transfer clear");
        uint32_t count = 0;
        check(vkGetPhysicalDeviceSurfaceFormatsKHR(physical, surface, &count, nullptr), "Format count");
        if (!count) throw std::runtime_error("No surface formats");
        std::vector<VkSurfaceFormatKHR> formats(count);
        check(vkGetPhysicalDeviceSurfaceFormatsKHR(physical, surface, &count, formats.data()), "Formats");
        VkSurfaceFormatKHR format = formats.front();
        if (format.format == VK_FORMAT_UNDEFINED) format.format = VK_FORMAT_R8G8B8A8_UNORM;
        VkFormatProperties formatProperties{};
        vkGetPhysicalDeviceFormatProperties(physical, format.format, &formatProperties);
        if (!(formatProperties.optimalTilingFeatures & VK_FORMAT_FEATURE_TRANSFER_DST_BIT))
            throw std::runtime_error("Format does not support transfer clear");
        VkExtent2D extent = caps.currentExtent;
        if (extent.width == std::numeric_limits<uint32_t>::max()) {
            extent.width = std::clamp(uint32_t(ANativeWindow_getWidth(window)), caps.minImageExtent.width, caps.maxImageExtent.width);
            extent.height = std::clamp(uint32_t(ANativeWindow_getHeight(window)), caps.minImageExtent.height, caps.maxImageExtent.height);
        }
        if (!extent.width || !extent.height) throw std::runtime_error("Zero surface extent");
        uint32_t imageCount = caps.minImageCount + 1;
        if (caps.maxImageCount) imageCount = std::min(imageCount, caps.maxImageCount);
        VkCompositeAlphaFlagBitsKHR alpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
        for (auto candidate : {VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR, VK_COMPOSITE_ALPHA_PRE_MULTIPLIED_BIT_KHR,
                               VK_COMPOSITE_ALPHA_POST_MULTIPLIED_BIT_KHR, VK_COMPOSITE_ALPHA_INHERIT_BIT_KHR}) {
            if (caps.supportedCompositeAlpha & candidate) { alpha = candidate; break; }
        }
        VkSwapchainCreateInfoKHR swapInfo{};
        swapInfo.sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
        swapInfo.surface = surface;
        swapInfo.minImageCount = imageCount;
        swapInfo.imageFormat = format.format;
        swapInfo.imageColorSpace = format.colorSpace;
        swapInfo.imageExtent = extent;
        swapInfo.imageArrayLayers = 1;
        swapInfo.imageUsage = VK_IMAGE_USAGE_TRANSFER_DST_BIT;
        swapInfo.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;
        swapInfo.preTransform = caps.currentTransform;
        swapInfo.compositeAlpha = alpha;
        swapInfo.presentMode = VK_PRESENT_MODE_FIFO_KHR;
        swapInfo.clipped = VK_TRUE;
        check(vkCreateSwapchainKHR(r.device, &swapInfo, nullptr, &r.swapchain), "Create swapchain");
        check(vkGetSwapchainImagesKHR(r.device, r.swapchain, &count, nullptr), "Image count");
        std::vector<VkImage> images(count);
        check(vkGetSwapchainImagesKHR(r.device, r.swapchain, &count, images.data()), "Images");
        VkSemaphoreCreateInfo semaphoreInfo{};
        semaphoreInfo.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;
        check(vkCreateSemaphore(r.device, &semaphoreInfo, nullptr, &r.acquired), "Acquire semaphore");
        check(vkCreateSemaphore(r.device, &semaphoreInfo, nullptr, &r.ready), "Present semaphore");
        uint32_t index = 0;
        check(vkAcquireNextImageKHR(r.device, r.swapchain, 3000000000ULL, r.acquired, VK_NULL_HANDLE, &index), "Acquire image");
        VkCommandPoolCreateInfo poolInfo{};
        poolInfo.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
        poolInfo.queueFamilyIndex = family;
        check(vkCreateCommandPool(r.device, &poolInfo, nullptr, &r.pool), "Command pool");
        VkCommandBufferAllocateInfo alloc{};
        alloc.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
        alloc.commandPool = r.pool;
        alloc.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
        alloc.commandBufferCount = 1;
        VkCommandBuffer command;
        check(vkAllocateCommandBuffers(r.device, &alloc, &command), "Command buffer");
        VkCommandBufferBeginInfo begin{};
        begin.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
        begin.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
        check(vkBeginCommandBuffer(command, &begin), "Begin commands");
        VkImageMemoryBarrier barrier{};
        barrier.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
        barrier.oldLayout = VK_IMAGE_LAYOUT_UNDEFINED;
        barrier.newLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
        barrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        barrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        barrier.image = images[index];
        barrier.subresourceRange = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1};
        barrier.dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
        vkCmdPipelineBarrier(command, VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT, VK_PIPELINE_STAGE_TRANSFER_BIT,
                             0, 0, nullptr, 0, nullptr, 1, &barrier);
        VkClearColorValue color = {{0.05f, 0.35f, 0.8f, 1.f}};
        vkCmdClearColorImage(command, images[index], VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                             &color, 1, &barrier.subresourceRange);
        barrier.oldLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
        barrier.newLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;
        barrier.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
        barrier.dstAccessMask = 0;
        vkCmdPipelineBarrier(command, VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
                             0, 0, nullptr, 0, nullptr, 1, &barrier);
        check(vkEndCommandBuffer(command), "End commands");
        VkPipelineStageFlags stage = VK_PIPELINE_STAGE_TRANSFER_BIT;
        VkSubmitInfo submit{};
        submit.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
        submit.waitSemaphoreCount = 1;
        submit.pWaitSemaphores = &r.acquired;
        submit.pWaitDstStageMask = &stage;
        submit.commandBufferCount = 1;
        submit.pCommandBuffers = &command;
        submit.signalSemaphoreCount = 1;
        submit.pSignalSemaphores = &r.ready;
        check(vkQueueSubmit(queue, 1, &submit, VK_NULL_HANDLE), "Submit");
        VkPresentInfoKHR present{};
        present.sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
        present.waitSemaphoreCount = 1;
        present.pWaitSemaphores = &r.ready;
        present.swapchainCount = 1;
        present.pSwapchains = &r.swapchain;
        present.pImageIndices = &index;
        check(vkQueuePresentKHR(queue, &present), "Present");
        check(vkQueueWaitIdle(queue), "Queue idle");
        return "Frame presentation: PASS (blue clear, stock Vulkan driver)\n";
    } catch (const std::exception& error) {
        return std::string("Frame presentation: FAIL ") + error.what() + '\n';
    }
}
}
