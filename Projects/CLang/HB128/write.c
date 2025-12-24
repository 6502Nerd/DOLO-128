#include <stdlib.h>
#include <errno.h>

extern void __fastcall__ hbputc(char c);

/* cc65 calls this for stdout/stderr writes */
int __fastcall__ write(int fd, const void* buf, unsigned count) {
    unsigned i;
    const char* p = (const char*)buf;
    for (i = 0; i < count; ++i) {
        hbputc(*p++);
    }
    return count;
}
