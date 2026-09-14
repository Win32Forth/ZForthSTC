#include "kernel_api.h"
#include "zforth_host.h"

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdint.h>

static volatile int g_running = 0;

static char *g_load_buf = NULL;
static size_t g_load_len = 0;

static void host_emit(int c)
{
    zforth_emit((uint8_t)(c & 0xFF));
}

static void host_emit_buf(const char *buf, size_t n)
{
    zforth_type(buf, n);
}

static void free_load_buf(void)
{
    char *p = g_load_buf;
    g_load_buf = NULL;
    g_load_len = 0;
    free(p);
}

static int host_load_file(const char *path, size_t path_len,
                          const char **out_ptr, size_t *out_len)
{
    char pathz[1024];
    char filebuf[1 << 16];
    int32_t nread;

    free_load_buf();
    
    if (path_len == 0) {
        int32_t plen = zforth_open_panel(pathz, (int32_t)sizeof(pathz) - 1);
        if (plen <= 0) return -1;
        pathz[plen] = 0;
    } else {
        if (path_len >= sizeof(pathz)) return -1;
        memcpy(pathz, path, path_len);
        pathz[path_len] = 0;

        if (pathz[0] != '/') {
            char base[1024];
            char rel[1024];

            strncpy(rel, pathz, sizeof(rel) - 1);
            rel[sizeof(rel) - 1] = 0;

            int32_t blen = zforth_get_load_base(base, (int32_t)sizeof(base) - 1);
            if (blen <= 0) return -1;
            base[blen] = 0;
            snprintf(pathz, sizeof(pathz), "%s/%s", base, rel);
        }
    }
    
//    zforth_type("load: ", 6);
//    zforth_type(pathz, strlen(pathz));
//    zforth_cr();

    nread = zforth_load_file(pathz, filebuf, (int32_t)sizeof(filebuf));
    if (nread < 0) return -1;

    g_load_buf = malloc((size_t)nread);
    if (!g_load_buf) return -1;
    memcpy(g_load_buf, filebuf, (size_t)nread);
    g_load_len = (size_t)nread;

    *out_ptr = g_load_buf;
    *out_len = g_load_len;
    return 0;
}

void zforth_vm_start(void)
{
    g_running = 1;
    zforth_refresh();

    char line[256];
    char src[8192];

    kernel_set_emit(host_emit);
    kernel_set_emit_buf(host_emit_buf);
    kernel_set_load_file(host_load_file);
    kernel_set_fromlib(zforth_fromlib_arm);
    kernel_set_fromlib_clear(zforth_fromlib_clear);
    kernel_set_chdir(zforth_chdir_hook);
    kernel_set_pwd(zforth_pwd_hook);
    kernel_set_dir(zforth_dir_hook);
    kernel_cold_start();

    while (g_running) {
        zforth_type("ok> ", 4);
        zforth_refresh();

        int32_t n = zforth_accept(line, (int32_t)sizeof(line));
        if (n < 0) break;

        int32_t sn = zforth_take_source(src, (int32_t)sizeof(src));
        if (sn > 0) {
            kernel_eval(src, (size_t)sn);
            zforth_cr();
            free_load_buf();
            continue;
        }

        if (n == 3 && memcmp(line, "bye", 3) == 0) {
            zforth_request_quit();
            break;
        }
        if (n > 0) {
            kernel_eval(line, (size_t)n);
            zforth_cr();
        }
        free_load_buf();
    }
}

void zforth_vm_stop(void)
{
    g_running = 0;
}

static int g_agent_started = 0;

static void agent_install_hooks(void)
{
    kernel_set_emit(host_emit);
    kernel_set_emit_buf(host_emit_buf);
    kernel_set_load_file(host_load_file);
    kernel_set_fromlib(zforth_fromlib_arm);
    kernel_set_fromlib_clear(zforth_fromlib_clear);
    kernel_set_chdir(zforth_chdir_hook);
    kernel_set_pwd(zforth_pwd_hook);
    kernel_set_dir(zforth_dir_hook);
}

int zforth_agent_start(void)
{
    if (g_agent_started)
        return 0;
    agent_install_hooks();
    kernel_cold_start();
    g_agent_started = 1;
    return 0;
}

int zforth_agent_eval(const char *line, size_t n)
{
    int st;
    if (!g_agent_started)
        return -1;
    if (!line)
        return -1;
    st = kernel_eval(line, n);
    free_load_buf();
    return st;
}

int zforth_agent_depth(void)
{
    return kernel_data_depth();
}

/* last_cfa holds pointer to the CFA cell of the latest word. */
extern uint64_t last_cfa;

/* Dump machine code at LAST's CFA (STC body). Returns 0 ok. */
int zforth_agent_dump_tos_cfa(size_t n)
{
    uint64_t cfa;
    uint64_t code;
    char msg[80];
    int len;

    cfa = last_cfa;
    if (cfa == 0)
        return -1;
    kernel_jit_write_begin();
    code = *(uint64_t *)(uintptr_t)cfa;
    len = snprintf(msg, sizeof(msg), "cfa=%llx code=%llx\n",
                   (unsigned long long)cfa, (unsigned long long)code);
    if (len > 0)
        zforth_type(msg, (size_t)len);
    if (code == 0)
        return -2;
    zforth_agent_hexdump((const void *)(uintptr_t)code, n ? n : 64);
    return 0;
}

/* Debug: hex-dump n bytes at addr to host emit. */
void zforth_agent_hexdump(const void *addr, size_t n)
{
    static const char hex[] = "0123456789ABCDEF";
    const unsigned char *p = (const unsigned char *)addr;
    size_t i;
    char buf[96];
    size_t blen;

    if (!addr || n == 0)
        return;
    kernel_jit_write_begin();
    for (i = 0; i < n; i += 4) {
        unsigned int w = 0;
        size_t j;
        for (j = 0; j < 4 && i + j < n; j++)
            w |= (unsigned int)p[i + j] << (8 * j);
        blen = 0;
        buf[blen++] = hex[(w >> 28) & 0xF];
        buf[blen++] = hex[(w >> 24) & 0xF];
        buf[blen++] = hex[(w >> 20) & 0xF];
        buf[blen++] = hex[(w >> 16) & 0xF];
        buf[blen++] = hex[(w >> 12) & 0xF];
        buf[blen++] = hex[(w >> 8) & 0xF];
        buf[blen++] = hex[(w >> 4) & 0xF];
        buf[blen++] = hex[w & 0xF];
        buf[blen++] = ' ';
        zforth_type(buf, blen);
        if ((i & 15) == 12)
            zforth_cr();
    }
    zforth_cr();
}