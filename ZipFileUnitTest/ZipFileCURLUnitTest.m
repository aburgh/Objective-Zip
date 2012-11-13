//
//  ZipFileCURLUnitTest.m
//  Objective-Zip
//
//  Created by Aaron Burghardt on 11/12/12.
//
//

#import "ZipFileCURLUnitTest.h"
#import <Objective-Zip/Objective-Zip.h>
#import <CommonCrypto/CommonDigest.h>

@implementation ZipFileCURLUnitTest

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
	[super setUp];
					// https://github.com/downloads/aburgh/Objective-Zip/CURL_Unit_Test_data.zip
	self.zipFileURL = @"http://cloud.github.com/downloads/aburgh/Objective-Zip/CURL_Unit_Test_data.zip";

	self.filenames = [NSArray arrayWithObjects:
					  @"file_Xwm",
					  @"dir0/",
					  @"dir0/file_IAW",
					  @"dir0/dir1/",
					  @"dir0/dir1/file_Z7f",
					  @"dir0/dir1/dir2/",
					  @"dir0/dir1/dir2/file_6my",
					  @"dir0/dir1/dir2/dir3/",
					  @"dir0/dir1/dir2/dir3/file_YAh",
					  @"dir0/dir1/dir2/dir3/dir4/",
					  @"dir0/dir1/dir2/dir3/dir4/file_DfW",
					  @"dir0/dir1/dir2/dir3/dir4/dir5/",
					  @"dir0/dir1/dir2/dir3/dir4/dir5/file_54t",
					  @"dir0/dir1/dir2/dir3/dir4/dir5/dir6/",
					  @"dir0/dir1/dir2/dir3/dir4/dir5/dir6/file_vgE",
					  @"dir0/dir1/dir2/dir3/dir4/dir5/dir6/dir7/",
					  @"dir0/dir1/dir2/dir3/dir4/dir5/dir6/dir7/file_45Z",
					  @"dir0/dir1/dir2/dir3/dir4/dir5/dir6/dir7/dir8/",
					  @"dir0/dir1/dir2/dir3/dir4/dir5/dir6/dir7/dir8/file_Tqd",
					  nil];

	self.hashes = [NSArray arrayWithObjects:
				   @"b584308a334db5cc2f3267ce77e28f02", [NSNull null],
				   @"9bc88fb816adb14c0678680c1996d3b9", [NSNull null],
				   @"2481696041dac7697f9bdd50ed65e483", [NSNull null],
				   @"a2e717d05366d6e96c2135bf2e916927", [NSNull null],
				   @"abee640a55abaa2b60e0e32571fbec19", [NSNull null],
				   @"80350f4458cb37c48e1401217dcaf76c", [NSNull null],
				   @"4921c1549767015a603e2f5f9af58843", [NSNull null],
				   @"e955ee15944f289127448728c7ff7337", [NSNull null],
				   @"01308e89c94651b5612e7bc81263cac4", [NSNull null],
				   @"d6df23fa961fa0d1546dccde9b5d56a8", nil];
}

- (void)tearDown
{
    [super tearDown];
}

// setUp/tearDown happens for each test, so disabling until performance improves
//- (void)testVerifySetup
//{
//	STAssertEquals(self.filenames.count, self.hashes.count, nil);
//}

- (void)testVerifyArchive
{
	NSError *error;

	ZipFile *zipFile = [ZipFile zipFileWithURL:[NSURL URLWithString:self.zipFileURL] mode:ZipFileModeUnzip error:&error];
	STAssertNotNil(zipFile, @"%@", error);

	NSArray *entries = [zipFile containedFiles];
	STAssertNotNil(entries, @"-[ZipFile containedFiles] returned nil");
	STAssertEquals(entries.count, self.filenames.count, nil);

	for (int i= 0; i < entries.count; i++) {

		@autoreleasepool {

			ZipFileInfo *info = [entries objectAtIndex:i];

			STAssertEqualObjects([self.filenames objectAtIndex:i], info.name, nil);

			if ([self.hashes objectAtIndex:i] == [NSNull null])
				continue;

			STAssertTrue([zipFile locateFileInZip:info.name error:&error], @"%@", error);

			ZipReadStream *stream = [zipFile readCurrentFileInZip:&error];
			STAssertNotNil(stream, @"%@", error);

			NSData *data = [stream readDataOfLength:info.length error:&error];
			STAssertNotNil(data, @"%@", error);

			NSString *hash = [self md5ForData:data];

			STAssertEqualObjects(hash, [self.hashes objectAtIndex:i], nil);
			
		}
	}
}

@end
