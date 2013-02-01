//
//  ZipWriteStream.m
//  Objective-Zip
//
//  Created by Gianluca Bertani on 25/12/09.
//  Copyright 2009-10 Flying Dolphin Studio. All rights reserved.
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

#import "ZipWriteStream.h"

#include "zip.h"

static NSString *ZipWriteErrorDomain = @"ZipWriteErrorDomain";

@implementation ZipWriteStream

@synthesize fileNameInZip = _fileNameInZip;

+ (id)writeStreamWithZipFileStruct:(struct zipFile__ *)zipFile fileNameInZip:(NSString *)fileNameInZip
{
	return [[self alloc] initWithZipFileStruct:zipFile fileNameInZip:fileNameInZip];
}

- (id) initWithZipFileStruct:(struct zipFile__ *)zipFile fileNameInZip:(NSString *)fileNameInZip
{
	if (self = [super init]) {
		_zipFile = zipFile;
		_fileNameInZip = [fileNameInZip copy];
	}
	
	return self;
}

- (BOOL)writeData:(NSData *)data error:(NSError **)writeError
{
	int err = zipWriteInFileInZip(_zipFile, [data bytes], (unsigned) [data length]);
	if (err < 0) {
		if (writeError) {
			NSDictionary *errorDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
											 [NSString stringWithFormat:@"Error in writing '%@' in the zipfile", _fileNameInZip], NSLocalizedDescriptionKey, nil];
			*writeError = [NSError errorWithDomain:ZipWriteErrorDomain code:1 userInfo:errorDictionary];
		}
		return NO;
	}
	return YES;
}

- (BOOL)finishedWritingWithError:(NSError **)writeError
{
	int err = zipCloseFileInZip(_zipFile);
	if (err != ZIP_OK) {
		if (writeError) {
			NSDictionary *errorDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
											 [NSString stringWithFormat:@"Error in closing '%@' in the zipfile", _fileNameInZip], NSLocalizedDescriptionKey, nil];
			*writeError = [NSError errorWithDomain:ZipWriteErrorDomain code:0 userInfo:errorDictionary];
		}
		return NO;
	}
	return YES;
}

@end
