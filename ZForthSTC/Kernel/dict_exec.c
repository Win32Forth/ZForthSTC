#include <stddef.h>
#include <sys/mman.h>

void *kernel_alloc_dict(size_t n)
{
    void *p;

    if (n == 0)
        return NULL;

    /* M1: writable map. EXEC comes later (mprotect or MAP_JIT + write toggle). */
    p = mmap(NULL, n,
             PROT_READ | PROT_WRITE,
             MAP_ANON | MAP_PRIVATE,
             -1, 0);
    if (p == MAP_FAILED)
        return NULL;
    return p;
}
