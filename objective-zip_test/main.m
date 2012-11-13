//
//  main.m
//  objective-zip_test
//
//  Created by Aaron Burghardt on 11/12/12.
//

#import <Foundation/Foundation.h>
#import <Objective-Zip/Objective-Zip.h>
#import <CommonCrypto/CommonDigest.h>
#import <err.h>

NSArray * _filenames(void) {
	return [NSArray arrayWithObjects:
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
}

NSArray * _hashes(void)
{
	return [NSArray arrayWithObjects:
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

NSString * md5ForData(NSData *data)
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
int main(int argc, const char * argv[])
{

	@autoreleasepool {

		NSError *error;

		printf("Start: %s\n", [[[NSDate date] description] UTF8String]);

//		NSString *url = @"htt ps://github.com/downloads/aburgh/Objective-Zip/CURL_Unit_Test_data.zip";
		NSString *url = @"http://cloud.github.com/downloads/aburgh/Objective-Zip/CURL_Unit_Test_data.zip";

		ZipFile *zipFile = [ZipFile zipFileWithURL:[NSURL URLWithString:url] mode:ZipFileModeUnzip error:&error];
		if (!zipFile)
			errx(EXIT_FAILURE, "%s", error.description.UTF8String);

		BOOL atEnd = NO;
		NSArray *filenames = _filenames();
		NSArray *hashes = _hashes();

		for (int i = 0; !atEnd; i++) {

			@autoreleasepool {

				ZipFileInfo *info = [zipFile getCurrentFileInZipInfo:&error];
				if (!info)
					errx(EXIT_FAILURE, "getCurrentFileInfoInZip: %s", error.localizedDescription.UTF8String);

				printf("%s: %s\n", [[[NSDate date] description] UTF8String], info.name.UTF8String);
				
				NSString *filename = [filenames objectAtIndex:i];
				if ([info.name isEqual:filename] == NO)
					errx(EXIT_FAILURE, "%s != %s", info.name.UTF8String, filename.UTF8String);

				id expectedHash = [hashes objectAtIndex:i];

				if (expectedHash == [NSNull null]) {
					// do nothing
				}
				else {

					ZipReadStream *stream = [zipFile readCurrentFileInZip:&error];
					if (!stream)
						errx(EXIT_FAILURE, "readCurrentFileInZip: %s", error.localizedDescription.UTF8String);

					NSData *data = [stream readDataOfLength:info.length error:&error];
					if (!data)
						errx(EXIT_FAILURE, "readDataOfLength: %s", error.localizedDescription.UTF8String);

					NSString *dataHash = md5ForData(data);

					if ([dataHash isEqual:expectedHash] == NO)
						errx(EXIT_FAILURE, "%s != %s", dataHash.UTF8String, [(NSString *)expectedHash UTF8String]);

					[stream finishedReadingWithError:&error];

				}
				atEnd = ![zipFile goToNextFileInZip:&error];
			}
		}
		printf("  End: %s\n", [[[NSDate date] description] UTF8String]);
	}
	return 0;
}

