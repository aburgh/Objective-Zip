//
//  ZipFileUnitTest.m
//  ZipFileUnitTest
//
//  Created by Aaron Burghardt on 11/10/12.
//
//

#import "ZipFileUnitTest.h"
#import "Objective-Zip.h"
#import <CommonCrypto/CommonDigest.h>
#import "unzip.h"

#define FILE_COUNT 10
#define FILE_SIZE_BASE  0x10000

@implementation ZipFileUnitTest

- (NSString *)tempFilenameWithRoot:(NSString *)root template:(NSString *)template
{
	char scratch[MAXPATHLEN];
	char *filename;

	NSString *templateString = [root stringByAppendingPathComponent:template];
	[templateString getFileSystemRepresentation:scratch maxLength:sizeof(scratch)];

	filename = mktemp(scratch);

	return [[NSFileManager defaultManager] stringWithFileSystemRepresentation:filename length:strlen(filename)];
}

- (NSString *)md5ForData:(NSData *)data
{
	unsigned char md[16];

	CC_MD5_CTX ctx;
	CC_MD5_Init(&ctx);
	CC_MD5_Update(&ctx, data.bytes, (CC_LONG) data.length);
	CC_MD5_Final(md, &ctx);

	NSMutableString *hash = [NSMutableString string];
	for (int i = 0; i < sizeof(md); i++)
		[hash appendFormat:@"%02hhx", md[i]];

	return hash;
}

- (void)setUp
{
	NSError *error;

    [super setUp];

	self.zipFilePath = [self tempFilenameWithRoot:NSTemporaryDirectory() template:@"ZipFileTest_XXXXXX"];
	NSLog(@"zipFilePath: %@", self.zipFilePath);
	
	// Insert 10 files and directories

	NSMutableString *dirPath  = [NSMutableString string];
	NSMutableArray *filenames = [NSMutableArray array];
	NSMutableArray *hashes    = [NSMutableArray array];
	ZipFile *zipFile = [[ZipFile alloc] initWithFileName:self.zipFilePath mode:ZipFileModeCreate];

	for (int i = 0; i < FILE_COUNT; i++) {

		long randomCount = random() % FILE_SIZE_BASE;
		long randomSize  = randomCount * sizeof(long);
		long *randomData = malloc(randomSize);

		for (int j = 0; j < randomCount; j++)
			randomData[j] = random();

		NSString *filename = [self tempFilenameWithRoot:dirPath template:@"file_XXX"];
		[filenames addObject:filename];

		ZipWriteStream *fileStream = [zipFile writeFileInZipWithName:filename compressionLevel:ZipCompressionLevelDefault error:&error];
		STAssertNotNil(fileStream, @"%@", error);

		NSData *data = [NSData dataWithBytesNoCopy:randomData length:randomSize freeWhenDone:YES];
		STAssertTrue([fileStream writeData:data error:&error], @"%@", [error localizedDescription]);
		STAssertTrue([fileStream finishedWritingWithError:&error], @"%@", [error localizedDescription]);

		[hashes addObject:[self md5ForData:data]];

		if ((i + 1) < FILE_COUNT) {
			[dirPath appendFormat:@"dir%d/", i];
			[filenames addObject:[NSString stringWithString:dirPath]];

			ZipWriteStream *dirStream = [zipFile writeFileInZipWithName:dirPath compressionLevel:ZipCompressionLevelNone error:&error];
			STAssertNotNil(dirStream, @"%@", error);

			STAssertTrue([dirStream finishedWritingWithError:&error], @"-[dirStream finishedWritingWithError:] failed: %@", error);

			[hashes addObject:[NSNull null]];
		}
	}
	[zipFile close];
	[zipFile release];

	self.filenames = filenames;
	self.hashes = hashes;
}

- (void)tearDown
{
	NSError *error;
	BOOL isOK = [[NSFileManager defaultManager] removeItemAtPath:self.zipFilePath error:&error];

	STAssertTrue(isOK, @"Failed to remove %@: \n", self.zipFilePath, error);

    [super tearDown];
}

- (void)testVerifyCount
{
	ZipFile *zipFile = [[ZipFile alloc] initWithFileName:self.zipFilePath mode:ZipFileModeUnzip];

	// Total file count includes the directories inserted between files
	STAssertTrue(zipFile.filesCount == (FILE_COUNT * 2 - 1), nil);

	[zipFile close];
	[zipFile release];
}

- (void)testVerifyFileNames
{
	ZipFile *zipFile = [[ZipFile alloc] initWithFileName:self.zipFilePath mode:ZipFileModeUnzip];

	NSArray *fileInfos = zipFile.containedFiles;

	STAssertTrue(fileInfos.count == self.filenames.count, nil);

	for (int i = 0; i < fileInfos.count; i++) {

		ZipFileInfo *fileInfo = [fileInfos objectAtIndex:i];

		STAssertEqualObjects([self.filenames objectAtIndex:i], fileInfo.name, @"at index %d.\n", i);
	}
	[zipFile close];
	[zipFile release];
}

- (void)testVerifyHashes
{
	NSError *error;

	ZipFile *zipFile = [[ZipFile alloc] initWithFileName:self.zipFilePath mode:ZipFileModeUnzip];
	ZipReadStream *readStream;
	NSData *data;

	// Total file count includes the directories inserted between files
	for (int i = 0; i < (FILE_COUNT * 2 - 1) ; i++) {

		@autoreleasepool {
			NSString *inputHash = [self.hashes objectAtIndex:i];

			if ([inputHash isEqual:[NSNull null]]) {
				STAssertTrue([zipFile goToNextFileInZip:&error] || error.code == UNZ_END_OF_LIST_OF_FILE, @"Error (%lld): %@", error.code, error.localizedDescription);

				if (error.code == UNZ_END_OF_LIST_OF_FILE)
					break;
				else
					continue;
			}

			readStream = [zipFile readCurrentFileInZip:&error];
			STAssertNotNil(readStream, @"%@", error.localizedDescription);

			data = [readStream readDataOfLength:(FILE_SIZE_BASE * 8) error:&error];
			STAssertNotNil(data, @"%@", error.localizedDescription);

			STAssertTrue([readStream finishedReadingWithError:&error], @"Error (%ld): %@", error.code, error.localizedDescription);

			STAssertEqualObjects(inputHash, [self md5ForData:data], @"at index %d.", i);

			STAssertTrue([zipFile goToNextFileInZip:&error] || error.code == UNZ_END_OF_LIST_OF_FILE, @"Error (%lld):%@", error.code, error.localizedDescription);
		}
	}
	[zipFile close];
	[zipFile release];
}

@end
