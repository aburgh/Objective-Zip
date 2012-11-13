//
//  ZipFile.m
//  Objective-Zip
//
//  Created by Gianluca Bertani on 25/12/09.
//  Copyright 2009-10 Flying Dolphin Studio. All rights reserved.
//	Modified by Geoff Pado on 29/10/10.
//
//  Redistribution and use in source and binary forms, with or without 
//  modification, are permitted provided that the following conditions 
//  are met:
//
//  * Redistributions of source code must retain the above copyright notice, 
//    this list of conditions and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice, 
//    this list of conditions and the following disclaimer in the documentation 
//    and/or other materials provided with the distribution.
//  * Neither the name of Gianluca Bertani nor the names of its contributors 
//    may be used to endorse or promote products derived from this software 
//    without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
//  POSSIBILITY OF SUCH DAMAGE.
//

#import "ZipFile.h"
#include "zip.h"
#include "unzip.h"
#include "curl_io.h"
#import "ZipReadStream.h"
#import "ZipWriteStream.h"
#import "ZipFileInfo.h"
#import <curl/curl.h>

#define FILE_IN_ZIP_MAX_NAME_LENGTH (256)

static NSString *ZipFileErrorDomain = @"ZipFileErrorDomain";

@implementation ZipFile

@synthesize fileName = _fileName;
@synthesize mode = _mode;

+ (id)zipFileWithFileName:(NSString *)fileName mode:(ZipFileMode)mode error:(NSError **)outError
{
	return [[[self alloc] initWithFileName:fileName mode:mode error:outError] autorelease];
}

+ (id)zipFileWithURL:(NSURL *)url mode:(ZipFileMode)mode error:(NSError **)outError
{
	return [[[self alloc] initWithURL:url mode:mode error:outError] autorelease];
}

- (id)initWithFileName:(NSString *)fileName mode:(ZipFileMode)mode
{
	return [self initWithFileName:fileName mode:mode error:NULL];
}

- (id)initWithFileName:(NSString *)fileName mode:(ZipFileMode)mode error:(NSError **)outError
{
	if (self = [super init]) {
		_fileName = [fileName copy];
		_mode = mode;

		switch (_mode) {
			case ZipFileModeUnzip:
				//open an file to unzip
				_unzFile = unzOpen(_fileName.UTF8String);
				break;
				
			case ZipFileModeCreate:
				//open a file to create a new zip
				_zipFile = zipOpen(_fileName.UTF8String, APPEND_STATUS_CREATE);
				break;
				
			case ZipFileModeAppend:
				//open a file to append to an existing zip
				_zipFile = zipOpen(_fileName.UTF8String, APPEND_STATUS_ADDINZIP);
				break;
				
			default:
				break;
		}
		if (!_unzFile && !_zipFile) {
			if (outError) {
				NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
										  [NSString stringWithFormat:@"Error opening '%@'", fileName], NSLocalizedDescriptionKey, nil];
				*outError = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:userInfo];
			}
			[self release];
			self = nil;
		}
	}
	
	return self;
}

- (id)initWithURL:(NSURL *)url mode:(ZipFileMode)mode error:(NSError **)outError
{
	if ([url isFileURL])
		return [self initWithFileName:url.path mode:mode error:outError];
	else {
		if (mode != ZipFileModeUnzip) {
			if (outError) {
				NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
										  @"Writing to archives via URLs is not supported", NSLocalizedDescriptionKey, nil];
				*outError = [NSError errorWithDomain:ZipFileErrorDomain code:10 userInfo:userInfo];
			}
			[self release];
			self = nil;
			return nil;
		}

		self = [super init];
		if (self) {
			_fileName = [url.absoluteString copy];
			_mode = mode;
			_unzFile = zlib_curl_unzOpen(_fileName.UTF8String);

			if (!_unzFile) {
				if (outError) {
					NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
											  [NSString stringWithFormat:@"Error opening '%@'", _fileName], NSLocalizedDescriptionKey,
											  [NSString stringWithFormat:@"%s", curl_easy_strerror(errno)], NSLocalizedRecoverySuggestionErrorKey, nil];
					*outError = [NSError errorWithDomain:@"CURLErrorDomain" code:errno userInfo:userInfo];
				}
				[self release];
				self = nil;
			}
		}
	}
	return self;
}

- (ZipWriteStream *)writeFileInZipWithName:(NSString *)fileNameInZip compressionLevel:(ZipCompressionLevel)compressionLevel error:(NSError **)writeFileError
{
	return [self writeFileInZipWithName:fileNameInZip fileDate:[NSDate date] compressionLevel:compressionLevel password:NULL crc32:0 error:writeFileError];
}

- (ZipWriteStream *)writeFileInZipWithName:(NSString *)fileNameInZip fileDate:(NSDate *)fileDate compressionLevel:(ZipCompressionLevel)compressionLevel error:(NSError **)writeFileError
{
	return [self writeFileInZipWithName:fileNameInZip fileDate:fileDate compressionLevel:compressionLevel password:NULL crc32:0 error:writeFileError];
}

- (ZipWriteStream *)writeFileInZipWithName:(NSString *)fileNameInZip fileDate:(NSDate *)fileDate compressionLevel:(ZipCompressionLevel)compressionLevel password:(NSString *)password crc32:(NSUInteger)crc32 error:(NSError **)writeFileError
{
	if (_mode == ZipFileModeUnzip) {
		if (writeFileError) {
		NSDictionary *errorDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
										 [NSString stringWithFormat:@"Operation not permitted with Unzip mode"], NSLocalizedDescriptionKey, nil];
		*writeFileError = [NSError errorWithDomain:ZipFileErrorDomain code:1 userInfo:errorDictionary];
		}
		return nil;
	}
	
	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSDateComponents *date = [calendar components:(NSSecondCalendarUnit | NSMinuteCalendarUnit | NSHourCalendarUnit | NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit) fromDate:fileDate];
	zip_fileinfo zi;
	zi.tmz_date.tm_sec = (uInt) [date second];
	zi.tmz_date.tm_min = (uInt) [date minute];
	zi.tmz_date.tm_hour = (uInt) [date hour];
	zi.tmz_date.tm_mday = (uInt) [date day];
	zi.tmz_date.tm_mon = (uInt) [date month] -1;
	zi.tmz_date.tm_year = (uInt) [date year];
	zi.internal_fa = 0;
	zi.external_fa = 0;
	zi.dosDate = 0;
	
	int err = zipOpenNewFileInZip3(_zipFile, fileNameInZip.UTF8String, &zi, NULL, 0, NULL, 0, NULL, (compressionLevel != ZipCompressionLevelNone) ? Z_DEFLATED : 0, compressionLevel, 0, -MAX_WBITS, DEF_MEM_LEVEL, Z_DEFAULT_STRATEGY, password.UTF8String, crc32);
	if (err != ZIP_OK) {
		if (writeFileError) {
			NSDictionary *errorDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
											 [NSString stringWithFormat:@"Error in opening '%@' in zip file", fileNameInZip], NSLocalizedDescriptionKey, nil];
			*writeFileError = [NSError errorWithDomain:ZipFileErrorDomain code:2 userInfo:errorDictionary];
		}
		return nil;
	}
	
	return [ZipWriteStream writeStreamWithZipFileStruct:_zipFile fileNameInZip:fileNameInZip];
}

- (NSUInteger)filesCount
{
	if (_mode != ZipFileModeUnzip)
		return -1;

	unz_global_info gi;
	int err = unzGetGlobalInfo(_unzFile, &gi);
	if (err != UNZ_OK)
		return -1;
	
	return gi.number_entry;
}

- (NSArray *)containedFiles
{
	NSUInteger num = [self filesCount];
	if (num < 1)
		return [NSArray array];
	
	NSMutableArray *files = [NSMutableArray arrayWithCapacity:num];

	[self goToFirstFileInZip:nil];
	for (NSUInteger i = 0; i < num; i++) {
		ZipFileInfo *info = [self getCurrentFileInZipInfo:nil];
		[files addObject:info];

		if ((i + 1) < num)
			[self goToNextFileInZip:nil];
	}

	return files;
}

- (BOOL)goToFirstFileInZip:(NSError **)readFileError
{
	if (_mode != ZipFileModeUnzip) {
		if (readFileError) {
			NSDictionary *errorDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
											 [NSString stringWithFormat:@"Operation not permitted without Unzip mode"], NSLocalizedDescriptionKey, nil];
			*readFileError = [NSError errorWithDomain:ZipFileErrorDomain code:10 userInfo:errorDictionary];
		}
		return NO;
	}
	
	int err = unzGoToFirstFile(_unzFile);
	if (err != UNZ_OK) {
		if (readFileError) {
			NSDictionary *errorDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
											 [NSString stringWithFormat:@"Error in going to first file in zip in '%@'", _fileName], NSLocalizedDescriptionKey, nil];
			*readFileError = [NSError errorWithDomain:ZipFileErrorDomain code:11 userInfo:errorDictionary];
		}
		return NO;
	}

	return YES;
}

- (BOOL)goToNextFileInZip:(NSError **)readFileError
{
	if (_mode != ZipFileModeUnzip) {
		if (readFileError) {
			NSDictionary *errorDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
											 [NSString stringWithFormat:@"Operation not permitted without Unzip mode"], NSLocalizedDescriptionKey, nil];
			*readFileError = [NSError errorWithDomain:ZipFileErrorDomain code:10 userInfo:errorDictionary];
		}
		return NO;
	}
	
	int err = unzGoToNextFile(_unzFile);

	if (err == UNZ_END_OF_LIST_OF_FILE) {
		if (readFileError) {
			NSString *message = [NSString stringWithFormat:@"No more files in '%@'", _fileName];
			NSDictionary *errorDictionary = [NSDictionary dictionaryWithObjectsAndKeys:message, NSLocalizedDescriptionKey, nil];
			*readFileError = [NSError errorWithDomain:ZipFileErrorDomain code:UNZ_END_OF_LIST_OF_FILE userInfo:errorDictionary];
		}
		return NO;
	}
	if (err != UNZ_OK) {
		if (readFileError) {
			NSDictionary *errorDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
											 [NSString stringWithFormat:@"Error in going to next file in zip in '%@'", _fileName], NSLocalizedDescriptionKey, nil];
			*readFileError = [NSError errorWithDomain:ZipFileErrorDomain code:12 userInfo:errorDictionary];
		}
		return NO;
	}
	
	return YES;
}

- (BOOL)locateFileInZip:(NSString *)fileNameInZip error:(NSError **)readFileError
{
	if (_mode != ZipFileModeUnzip) {
		if (readFileError) {
			NSDictionary *errorDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
											 [NSString stringWithFormat:@"Operation not permitted without Unzip mode"], NSLocalizedDescriptionKey, nil];
			*readFileError = [NSError errorWithDomain:ZipFileErrorDomain code:10 userInfo:errorDictionary];
		}
		return NO;
	}
	
	int err = unzLocateFile(_unzFile, fileNameInZip.UTF8String, 1);
	if (err == UNZ_END_OF_LIST_OF_FILE) {
		if (readFileError) {
			NSString *message = [NSString stringWithFormat:@"File '%@' not found in zip file '%@'", fileNameInZip, _fileName];
			NSDictionary *errorDictionary = [NSDictionary dictionaryWithObjectsAndKeys:message, NSLocalizedDescriptionKey, nil];
			*readFileError = [NSError errorWithDomain:ZipFileErrorDomain code:UNZ_END_OF_LIST_OF_FILE userInfo:errorDictionary];
		}
		return NO;
	}

	if (err != UNZ_OK) {
		if (readFileError) {
			NSDictionary *errorDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
											 [NSString stringWithFormat:@"Error in going to next file in zip in '%@'", _fileName], NSLocalizedDescriptionKey, nil];
			*readFileError = [NSError errorWithDomain:ZipFileErrorDomain code:12 userInfo:errorDictionary];
		}
		return NO;
	}
	
	return YES;
}

- (ZipFileInfo *)getCurrentFileInZipInfo:(NSError **)readFileError
{
	if (_mode != ZipFileModeUnzip) {
		if (readFileError) {
			NSDictionary *errorDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
											 [NSString stringWithFormat:@"Operation not permitted without Unzip mode"], NSLocalizedDescriptionKey, nil];
			*readFileError = [NSError errorWithDomain:ZipFileErrorDomain code:10 userInfo:errorDictionary];
		}
		return nil;
	}

	char filename_inzip[FILE_IN_ZIP_MAX_NAME_LENGTH];
	unz_file_info file_info;
	
	int err = unzGetCurrentFileInfo(_unzFile, &file_info, filename_inzip, sizeof(filename_inzip), NULL, 0, NULL, 0);
	if (err != UNZ_OK) {
		if (readFileError) {
			NSDictionary *errorDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
											 [NSString stringWithFormat:@"Error in getting current file info in '%@'", _fileName], NSLocalizedDescriptionKey, nil];
			*readFileError = [NSError errorWithDomain:ZipFileErrorDomain code:13 userInfo:errorDictionary];
		}
		return nil;
	}
	
	NSString *name = [NSString stringWithCString:filename_inzip encoding:NSUTF8StringEncoding];
	
	ZipCompressionLevel level = ZipCompressionLevelNone;
	if (file_info.compression_method != 0) {
		switch ((file_info.flag & 0x6) / 2) {
			case 0:
				level = ZipCompressionLevelDefault;
				break;
				
			case 1:
				level = ZipCompressionLevelBest;
				break;
				
			default:
				level = ZipCompressionLevelFastest;
				break;
		}
	}
	
	BOOL crypted = ((file_info.flag & 1) != 0);
	
	NSDateComponents *components = [[[NSDateComponents alloc] init] autorelease];
	[components setDay:file_info.tmu_date.tm_mday];
	[components setMonth:file_info.tmu_date.tm_mon +1];
	[components setYear:file_info.tmu_date.tm_year];
	[components setHour:file_info.tmu_date.tm_hour];
	[components setMinute:file_info.tmu_date.tm_min];
	[components setSecond:file_info.tmu_date.tm_sec];
	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSDate *date = [calendar dateFromComponents:components];
	
	return [ZipFileInfo fileInfoWithName:name length:file_info.uncompressed_size level:level crypted:crypted size:file_info.compressed_size date:date crc32:file_info.crc];
}

- (ZipReadStream *)readCurrentFileInZip:(NSError **)readFileError
{
	return [self readCurrentFileInZipWithPassword:nil error:readFileError];
}

- (ZipReadStream *)readCurrentFileInZipWithPassword:(NSString *)password error:(NSError **)readFileError
{
	if (_mode != ZipFileModeUnzip) {
		if (readFileError) {
			NSDictionary *errorDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
											 [NSString stringWithFormat:@"Operation not permitted without Unzip mode"], NSLocalizedDescriptionKey, nil];
			*readFileError = [NSError errorWithDomain:ZipFileErrorDomain code:10 userInfo:errorDictionary];
		}
		return nil;
	}
	
	char filename_inzip[FILE_IN_ZIP_MAX_NAME_LENGTH];
	unz_file_info file_info;
	
	int err = unzGetCurrentFileInfo(_unzFile, &file_info, filename_inzip, sizeof(filename_inzip), NULL, 0, NULL, 0);
	if (err != UNZ_OK) {
		if (readFileError) {
			NSDictionary *errorDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
											 [NSString stringWithFormat:@"Error in getting current file info in '%@'", _fileName], NSLocalizedDescriptionKey, nil];
			*readFileError = [NSError errorWithDomain:ZipFileErrorDomain code:13 userInfo:errorDictionary];
		}
		return nil;
	}
	
	NSString *fileNameInZip = [NSString stringWithCString:filename_inzip encoding:NSUTF8StringEncoding];
	
	err = unzOpenCurrentFilePassword(_unzFile, password.UTF8String);
	if (err != UNZ_OK) {
		if (readFileError) {
			NSDictionary *errorDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
											 [NSString stringWithFormat:@"Error in opening current file in '%@'", _fileName], NSLocalizedDescriptionKey, nil];
			*readFileError = [NSError errorWithDomain:ZipFileErrorDomain code:14 userInfo:errorDictionary];
		}
		return nil;
	}
	
	return [ZipReadStream readStreamWithUnzFileStruct:_unzFile fileNameInZip:fileNameInZip];
}

- (void)close
{
	if (_unzFile) {
		unzClose(_unzFile);
		_unzFile = NULL;
	}
	if (_zipFile) {
		zipClose(_zipFile, NULL);
		_zipFile = NULL;
	}
}

- (void)dealloc
{
	[self close]; // No harm in calling twice
	[_fileName release];
	[super dealloc];
}

@end
