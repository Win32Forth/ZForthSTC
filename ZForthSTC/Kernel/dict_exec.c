#include <stddef.h>
#include <sys/mman.h>
#include <pthread.h>
#include <libkern/OSCacheControl.h>

void *kernel_alloc_dict(size_t n)
{
    void *p;

    if (n == 0)
        return NULL;

    p = mmap(NULL, n,
             PROT_READ | PROT_WRITE | PROT_EXEC,
             MAP_ANON | MAP_PRIVATE | MAP_JIT,
             -1, 0);
    if (p == MAP_FAILED)
        return NULL;
    return p;
}

void kernel_jit_write_begin(void)
{
    pthread_jit_write_protect_np(0);
}

void kernel_jit_write_end(void *addr, size_t len)
{
    pthread_jit_write_protect_np(1);
    if (addr && len)
        sys_icache_invalidate(addr, len);
}
