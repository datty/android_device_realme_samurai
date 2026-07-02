#include <android-base/file.h>
#include <android-base/unique_fd.h>
#include <string>

namespace android {
namespace base {

bool WriteStringToFd(const std::string& content, borrowed_fd fd) {
    return WriteStringToFd(std::string_view(content), fd);
}

} // namespace base
} // namespace android
