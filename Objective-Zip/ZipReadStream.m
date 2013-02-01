//
//  ZipReadStream.m
//  Objective-Zip
//
//  Created by Gianluca Bertani on 28/12/09.
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

#import "ZipReadStream.h"

#include "unzip.h"

static NSString *ZipReadErrorDomain = @"ZipReadErrorDomain";

@implementation ZipReadStream

@synthesize fileNameInZip = _fileNameInZip;

+ (id)readStreamWithUnzFileStruct:(struct unzFile__ *)unzFile fileNameInZip:(NSString *)fileNameInZip
{
	return [[self alloc] initWithUnzFileStruct:unzFile fileNameInZip:fileNameInZip];
}

- (id) initWithUnzFileStruct:(struct unzFile__ *)unzFile fileNameInZip:(NSString *)fileNameInZip {
	if (self = [super init]) {
		_unzFile = unzFile;
		_fileNameInZip = [fileNameInZip copy];
	}
	
	return self;
}

- (NSData *)readDataOfLength:(NSUInteger)length error:(NSError **)readError
{
	NSMutableData *data = [NSMutableData dataWithLength:length];
	
	int result = unzReadCurrentFile(_unzFile, data.mutableBytes, (unsigned int)data.length);
	if (result < 0) {
		if (readError) {
			NSDictionary *errorDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
											 [NSString stringWithFormat:@"Error in reading '%@' in the zipfile", _fileNameInZip], NSLocalizedDescriptionKey, nil];
			*readError = [NSError errorWithDomain:ZipReadErrorDomain code:result userInfo:errorDictionary];
		}
		return nil;
	}
	
	[data setLength:result];
	return data;
}

- (BOOL)finishedReadingWithError:(NSError **)readError {
	int err = unzCloseCurrentFile(_unzFile);
	if (err != UNZ_OK) {
		if (readError) {
			NSDictionary *errorDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
											 [NSString stringWithFormat:@"Error in closing '%@' in the zipfile", _fileNameInZip], NSLocalizedDescriptionKey, nil];
			*readError = [NSError errorWithDomain:ZipReadErrorDomain code:err userInfo:errorDictionary];
		}
		return NO;
	}
	return YES;
}

@end
