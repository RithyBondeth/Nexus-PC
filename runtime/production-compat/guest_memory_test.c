/* Exercise the protection adapter's public operation with deterministic mappings
 * and kernel failures. No real host memory permissions are changed. */
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
extern int nexus_test_mprotect(void *, size_t, int);
static int error_code, retry_prot, calls, kind, denied = -13;
static char map[1024];
static size_t cursor, file_cursor;
int *__errno_location(void) { return &error_code; }
long nexus_test_sys3(long n, long a, long b, long c) {
    if (n == 226) {
        calls++;
        if (calls == 1) return denied;
        retry_prot = (int)c;
        return 0;
    }
    if (n == 56) {
        if (!strcmp((char *)b, "/proc/self/maps")) { cursor = 0; return 3; }
        file_cursor = 0;
        return 4;
    }
    if (n == 63 && a == 3) {
        size_t len = strlen(map);
        size_t count = len - cursor;
        if (count > (size_t)c) count = (size_t)c;
        memcpy((void *)b, map + cursor, count);
        cursor += count;
        return (long)count;
    }
    if (n == 63 && a == 4) {
        unsigned char data[128] = {0};
        data[0] = 'M'; data[1] = 'Z'; data[60] = 64;
        data[64] = 'P'; data[65] = 'E'; data[68] = 0x64; data[69] = 0x86;
        if (kind == 1) data[0] = 0x7f; // native ELF or plain data must stay denied
        if (kind == 2) { data[68] = 0x64; data[69] = 0xaa; } // ARM64 PE
        if (kind == 3) data[60] = 0; // invalid PE offset
        if (kind == 4) return 2; // truncated header
        if (kind == 5) { data[68] = 0x4c; data[69] = 1; } // x86 PE
        size_t count = (size_t)c;
        if (file_cursor + count > sizeof(data)) return 0;
        memcpy((void *)b, data + file_cursor, count);
        file_cursor += count;
        return (long)count;
    }
    if (n == 62) { file_cursor = (size_t)b; return b; }
    if (n == 57) return 0;
    if (n == 64) return c;
    assert(0 && "Unexpected syscall"); return -1;
}
static void reset(const char *path) {
    snprintf(map, sizeof(map), "1000-3000 rw-p 00000000 00:00 123 %s\n", path);
    error_code = calls = retry_prot = kind = 0;
    denied = -13;
}
int main(void) {
    const char *guest = "/data/user/0/com.nexuspc.app/files/r/home/xuser/.wine/drive_c/windows/system32/winex11.drv";
    reset(guest);
    assert(nexus_test_mprotect((void *)0x1000, 0x2000, 5) == 0 && calls == 2 && retry_prot == 1);
    reset("/data/user/0/com.nexuspc.app/no_backup/library-v1/games/id/content/game.exe");
    kind = 5;
    assert(nexus_test_mprotect((void *)0x1000, 4096, 7) == 0 && retry_prot == 3);
    for (int invalid = 1; invalid <= 4; ++invalid) {
        reset(guest); kind = invalid;
        assert(nexus_test_mprotect((void *)0x1000, 4096, 5) == -1 && calls == 1 && error_code == 13);
    }
    reset("/data/app/package/lib/arm64/libnative.so");
    assert(nexus_test_mprotect((void *)0x1000, 4096, 5) == -1 && calls == 1);
    reset("/data/user/0/com.other.app/files/r/anything.exe");
    assert(nexus_test_mprotect((void *)0x1000, 4096, 5) == -1 && calls == 1);
    reset(guest); denied = -22;
    assert(nexus_test_mprotect((void *)0x1000, 4096, 5) == -1 && calls == 1 && error_code == 22);
    reset(guest); denied = 0;
    assert(nexus_test_mprotect((void *)0x1000, 4096, 5) == 0 && calls == 1);
    reset(guest);
    assert(nexus_test_mprotect((void *)0x1000, 4096, 3) == -1 && calls == 1);
    reset(guest);
    assert(nexus_test_mprotect((void *)(UINTPTR_MAX - 1), 4096, 5) == -1 && calls == 1);
    reset(guest);
    snprintf(map, sizeof(map), "1000-2000 rw-p 0 00:00 1 %s\n2000-3000 rw-p 0 00:00 1 %s\n", guest, guest);
    assert(nexus_test_mprotect((void *)0x1000, 8192, 5) == 0 && retry_prot == 1);
    reset(guest);
    snprintf(map, sizeof(map), "1000-2000 rw-p 0 00:00 1 %s\n2000-3000 rw-p 0 00:00 1 /data/app/native.so\n", guest);
    assert(nexus_test_mprotect((void *)0x1000, 8192, 5) == -1 && calls == 1);
    puts("PASS: guest PE adaptation, native/foreign/truncated rejection, range boundaries, and kernel errors");
}
