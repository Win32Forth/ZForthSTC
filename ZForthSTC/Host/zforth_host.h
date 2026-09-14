#ifndef ZFORTH_HOST_H
#define ZFORTH_HOST_H

/*
 Add this to .c Forth files
 #include "zforth_host.h"
 */

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void zforth_emit(uint8_t c);
void zforth_type(const char *addr, size_t u);
void zforth_cr(void);
void zforth_page(void);
void zforth_refresh(void);
void zforth_chdir_hook(const char *path, size_t n);
void zforth_pwd_hook(void);
void zforth_dir_hook(const char *path, size_t n);
void zforth_edit_hook(const char *path, size_t n);
void zforth_fromlib_arm(void);
void zforth_fromlib_clear(void);
void zforth_request_quit(void);
int32_t zforth_get_load_base(char *out, int32_t maxcount);

int32_t zforth_accept(char *addr, int32_t maxcount);
int32_t zforth_key(void);

/* Returns path length, or 0 if cancelled. Blocks. path_out is not NUL-terminated
   unless you add one yourself after the returned count. */
int32_t zforth_open_panel(char *path_out, int32_t maxcount);
int32_t zforth_save_panel(char *path_out, int32_t maxcount, const char *suggested);

/* Returns byte count, or -1 on error. */
int32_t zforth_load_file(const char *path, char *addr, int32_t maxcount);
int32_t zforth_save_file(const char *path, const char *addr, int32_t count);

/* Copies pending editor/source text. Returns 0 if none. Does not block. */
int32_t zforth_take_source(char *addr, int32_t maxcount);

/* Runs the stand-in outer interpreter. Call from a background thread. */
void zforth_vm_start(void);
void zforth_vm_stop(void);

/* Headless agent channel: cold start once, then kernel_eval without ACCEPT. */
int zforth_agent_start(void);
int zforth_agent_eval(const char *line, size_t n);
int zforth_agent_depth(void);
void zforth_agent_hexdump(const void *addr, size_t n);
int zforth_agent_dump_tos_cfa(size_t n);

#ifdef __cplusplus
}
#endif

#endif
