//
//  curl_io.h
//
//  Created by Aaron Burghardt on 11/11/12.
//

#ifndef _ZLIBCURL_IO_H
#define _ZLIBCURL_IO_H

#include "unzip.h"
#include "ioapi.h"
#include <sys/types.h>

struct CURL;
typedef struct zlib_curl * zlib_curl_t;

unzFile zlib_curl_unzOpen(const char *url);

voidpf zlib_curl_open(voidpf opaque, const char *filename, int mode);

uLong zlib_curl_read(voidpf opaque, voidpf stream, void *buf, uLong size);

uLong zlib_curl_write(voidpf opaque, voidpf stream, const void *buf, uLong size);

long zlib_curl_tell(voidpf opaque, voidpf stream);

long zlib_curl_seek(voidpf opaque, voidpf stream, uLong offset, int origin);

int zlib_curl_close(voidpf opaque, voidpf stream);

int zlib_curl_testerror(voidpf opaque, voidpf stream);

void fill_curl_filefunc (zlib_filefunc_def *pzlib_filefunc_def);

#endif
