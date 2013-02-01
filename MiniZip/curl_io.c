//
//  curl_io.c
//
//  Created by Aaron Burghardt on 11/11/12.
//

#include "curl_io.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/errno.h>
#include <curl/curl.h>


typedef struct zlib_curl {
	struct CURL *curl;
	size_t length;
	off_t  offset;
	void *download_buffer;
	off_t download_buffer_pos;
	size_t download_buffer_size;
	const char *errstr;
	CURLcode err;
} zlib_curl;

#pragma mark Prototypes

size_t data_callback(void *ptr, size_t size, size_t nmemb, zlib_curl_t userdata);
void fill_curl_filefunc (zlib_filefunc_def *funcs);

size_t data_callback(void *ptr, size_t size, size_t nmemb, zlib_curl_t stream)
{
	size_t chunk_size = size * nmemb;

	if ((stream->download_buffer_pos + chunk_size) > stream->download_buffer_size)
		return -1;

	memcpy(stream->download_buffer + stream->download_buffer_pos, ptr, chunk_size);
	stream->download_buffer_pos += chunk_size;

	return chunk_size;
}

unzFile zlib_curl_unzOpen(const char *url)
{
	zlib_filefunc_def funcs;
	fill_curl_filefunc(&funcs);

	return unzOpen2(url, &funcs);
}

voidpf zlib_curl_open(voidpf opaque, const char *url, int mode)
{
	CURLcode curl_result;
	zlib_curl_t zcurl = calloc(1, sizeof(struct zlib_curl));
	zcurl->curl = curl_easy_init();

	curl_easy_setopt(zcurl->curl, CURLOPT_URL, url);
	curl_easy_setopt(zcurl->curl, CURLOPT_VERBOSE, 0);
	curl_easy_setopt(zcurl->curl, CURLOPT_NOBODY, 1);

	curl_result = curl_easy_perform(zcurl->curl);
	if (curl_result != CURLE_OK) {
		curl_easy_cleanup(zcurl->curl);
		free(zcurl);
		errno = curl_result;
		return NULL;
	}
	double length;
	curl_easy_getinfo(zcurl->curl, CURLINFO_CONTENT_LENGTH_DOWNLOAD, &length);
	zcurl->length = length;

	curl_easy_setopt(zcurl->curl, CURLOPT_HEADER, 0);
	curl_easy_setopt(zcurl->curl, CURLOPT_NOBODY, 0);
	curl_easy_setopt(zcurl->curl, CURLOPT_WRITEFUNCTION, data_callback);
	curl_easy_setopt(zcurl->curl, CURLOPT_WRITEDATA, zcurl);
	
	return zcurl;
}

uLong zlib_curl_read(voidpf opaque, voidpf stream, void *buf, uLong size)
{
	zlib_curl_t zcurl = stream;
	char range[30];

	 if ((zcurl->offset + size) > zcurl->length) {
		 zcurl->err = CURLE_BAD_FUNCTION_ARGUMENT;
		 zcurl->errstr = "read past EOF";
		return -1;
	}
	zcurl->download_buffer = buf;
	zcurl->download_buffer_pos = 0;
	zcurl->download_buffer_size = size;

	snprintf(range, sizeof(range), "%lld-%lld", zcurl->offset, (zcurl->offset + size - 1));
	curl_easy_setopt(zcurl->curl, CURLOPT_RANGE, range);

	CURLcode result = curl_easy_perform(zcurl->curl);
	if (result != CURLE_OK) {
		zcurl->err = result;
		zcurl->errstr = curl_easy_strerror(result);
		return -1;
	}
	zcurl->offset += size;
	return size;
}

uLong zlib_curl_write(voidpf opaque, voidpf stream, const void *buf, uLong size)
{
	zlib_curl_t zcurl = stream;

	zcurl->err = CURLE_WRITE_ERROR;
	zcurl->errstr = "writing unsupported";
	return -1;
}

long zlib_curl_tell(voidpf opaque, voidpf stream)
{
	zlib_curl_t zcurl = stream;
	return zcurl->offset;
}

long zlib_curl_seek(voidpf opaque, voidpf stream, uLong offset, int origin)
{
	zlib_curl_t zcurl = stream;
	off_t newpos = 0;

	switch (origin) {
		case ZLIB_FILEFUNC_SEEK_CUR:
			newpos = zcurl->offset + offset;
			break;

		case ZLIB_FILEFUNC_SEEK_END:
			newpos = zcurl->length - offset;
			break;

		case ZLIB_FILEFUNC_SEEK_SET:
			newpos = offset;
			break;

		default:
			break;
	}
	if (newpos < 0 || newpos > zcurl->length) {
		zcurl->err = CURLE_BAD_FUNCTION_ARGUMENT;
		zcurl->errstr = "seeking out of bounds";
		return -1;
	}
	zcurl->offset = newpos;

	return 0;
}

int zlib_curl_close(voidpf opaque, voidpf stream)
{
	zlib_curl_t zcurl = stream;

	curl_easy_cleanup(zcurl->curl);
	free(stream);

	return 0;
}

int zlib_curl_testerror(voidpf opaque, voidpf stream)
{
	zlib_curl_t zcurl = stream;

	return zcurl->err;
}

void fill_curl_filefunc (zlib_filefunc_def *funcs)
{
    funcs->zopen_file = zlib_curl_open;
    funcs->zread_file = zlib_curl_read;
    funcs->zwrite_file = zlib_curl_write;
    funcs->ztell_file = zlib_curl_tell;
    funcs->zseek_file = zlib_curl_seek;
    funcs->zclose_file = zlib_curl_close;
    funcs->zerror_file = zlib_curl_testerror;
    funcs->opaque = NULL;
}
