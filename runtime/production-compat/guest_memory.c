/* The kernel never executes x86 PE bytes. Box64 keeps guest EXEC metadata;
 * this adapter removes only a denied native EXEC permission on validated PE
 * mappings in this package's runtime/library. Native ARM64 and anonymous JIT
 * mappings retain their original behavior. No SELinux or device settings change.
 */
#include <stddef.h>
#include <stdint.h>
extern int *__errno_location(void);
#ifdef NEXUS_GUEST_MEMORY_TEST
extern long nexus_test_sys3(long, long, long, long);
#define sys3 nexus_test_sys3
#define mprotect nexus_test_mprotect
#else
static long sys3(long n, long a, long b, long c) {
    register long x0 __asm__("x0") = a;
    register long x1 __asm__("x1") = b;
    register long x2 __asm__("x2") = c;
    register long x8 __asm__("x8") = n;
    __asm__ volatile("svc #0" : "+r"(x0) : "r"(x1), "r"(x2), "r"(x8) : "memory", "cc");
    return x0;
}
#endif
static long open_read(const char *path) { return sys3(56, -100, (long)path, 0); }
static int contains(const char *s, const char *part) {
    for (; *s; ++s) {
        size_t i = 0;
        while (part[i] && part[i] == s[i]) ++i;
        if (!part[i]) return 1;
    }
    return 0;
}
static int guest_file(const char *path) {
    if (!contains(path, "/com.nexuspc.app/") ||
        !(contains(path, "/files/r/") || contains(path, "/no_backup/library-v1/games/"))) return 0;
    long fd = open_read(path);
    if (fd < 0) return 0;
    unsigned char header[64], pe[6];
    long n = sys3(63, fd, (long)header, sizeof(header));
    int valid = 0;
    if (n == 64 && header[0] == 'M' && header[1] == 'Z') {
        uint32_t offset = (uint32_t)header[60] | ((uint32_t)header[61] << 8) |
            ((uint32_t)header[62] << 16) | ((uint32_t)header[63] << 24);
        if (offset >= 64 && offset < 16 * 1024 * 1024 && sys3(62, fd, offset, 0) == offset &&
            sys3(63, fd, (long)pe, sizeof(pe)) == 6) {
            valid = pe[0] == 'P' && pe[1] == 'E' && pe[2] == 0 && pe[3] == 0 &&
                ((pe[4] == 0x64 && pe[5] == 0x86) || (pe[4] == 0x4c && pe[5] == 1));
        }
    }
    sys3(57, fd, 0, 0);
    return valid;
}
static uintptr_t hex(const char **p) {
    uintptr_t v = 0;
    while ((**p >= '0' && **p <= '9') || (**p >= 'a' && **p <= 'f')) {
        unsigned c = *(*p)++;
        v = v * 16 + (c <= '9' ? c - '0' : c - 'a' + 10);
    }
    return v;
}
static int guest_range(uintptr_t addr, size_t len) {
    if (!len || addr + len < addr) return 0;
    long fd = open_read("/proc/self/maps");
    if (fd < 0) return 0;
    uintptr_t cursor = addr, limit = addr + len;
    char line[8192], chunk[4096];
    size_t used = 0;
    int overflow = 0, accepted = 0;
    long n;
    while ((n = sys3(63, fd, (long)chunk, sizeof(chunk))) > 0) {
        for (long i = 0; i < n; ++i) {
            char c = chunk[i];
            if (c != '\n') {
                if (used < sizeof(line)-1) line[used++] = c;
                else overflow = 1;
                continue;
            }
            line[used] = 0;
            if (!overflow) {
                const char *p = line;
                uintptr_t begin = hex(&p);
                if (*p == '-') ++p;
                uintptr_t end = hex(&p);
                if (begin <= cursor && end > cursor) {
                    // Skip permissions, offset, device, inode to the pathname.
                    for (int field = 0; field < 4; ++field) {
                        while (*p == ' ') ++p;
                        while (*p && *p != ' ') ++p;
                    }
                    while (*p == ' ') ++p;
                    if (!guest_file(p)) goto done;
                    cursor = end;
                    if (cursor >= limit) { accepted = 1; goto done; }
                }
            }
            used = 0; overflow = 0;
        }
    }
done:
    sys3(57, fd, 0, 0);
    return accepted;
}
int mprotect(void *addr, size_t len, int prot) {
    long result = sys3(226, (long)addr, (long)len, prot);
    if ((result == -13 || result == -1) && (prot & 4) && guest_range((uintptr_t)addr, len)) {
        result = sys3(226, (long)addr, (long)len, prot & ~4);
        if (!result) {
            static unsigned logged;
            if (__atomic_fetch_add(&logged, 1, __ATOMIC_RELAXED) < 4) {
                static const char message[] = "NEXUS_GUEST_PROTECTION_ADAPTED\n";
                sys3(64, 2, (long)message, sizeof(message)-1);
            }
        }
    }
    if (result < 0) { *__errno_location() = (int)-result; return -1; }
    return 0;
}
