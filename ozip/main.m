//
//  main.m
//  ozip
//
//  Created by Aaron Burghardt on 2/1/13.
//
//

#import <Foundation/Foundation.h>
#import "Objective-Zip.h"
#import <err.h>
#import <fnmatch.h>
#import <getopt.h>
#import <syslog.h>

typedef enum {
	kOZOperationZip,
	kOZOperationAppend,
	kOZOperationUnzip,
	kOZOperationList
} OZOperationType;

BOOL patterns_contains_filename(NSArray *patterns, NSString *path)
{
	for (NSString *pattern in patterns)
		if (fnmatch(pattern.UTF8String, path.UTF8String, FNM_PATHNAME) == 0)
			return YES;
	return NO;
}

void cmd_list(ZipFile *zipFile)
{
	NSError *error;
	ZipFileInfo *info;
	NSDateFormatter *formatter = [NSDateFormatter new];
	NSString *formattedTimestamp;
	NSInteger i;
	NSInteger totalBytes = 0;
	
	formatter.formatterBehavior = NSDateFormatterBehavior10_4;
	formatter.dateFormat = @"MM-dd-yyyy HH:mm";

	if ([zipFile goToFirstFileInZip:&error] == NO)
		errx(EXIT_FAILURE, "goto first file: (%ld) %s", error.code, error.localizedDescription.UTF8String);

	printf("   Length      Date    Time    Name\n");
	printf("  --------  ---------- -----   ----\n");

	for (i = 0; i < zipFile.filesCount; ) {

		info = [zipFile getCurrentFileInZipInfo:&error];
		if (!info)
			errx(EXIT_FAILURE, "get file info: (%ld) %s", error.code, error.localizedDescription.UTF8String);

		if (++i < zipFile.filesCount) {
			if ([zipFile goToNextFileInZip:&error] == NO)
				errx(EXIT_FAILURE, "goto next file: (%ld) %s", error.code, error.localizedDescription.UTF8String);
		}

		formattedTimestamp = [formatter stringFromDate:info.date];
		printf("%10ld  %s   %s\n",info.length, formattedTimestamp.UTF8String, info.name.UTF8String);
		
		totalBytes += info.length;
	}
	printf("  --------                     -------\n");
	printf("%10ld                     %ld files\n", totalBytes, i);
}

void cmd_zip(void)
{

}

#pragma mark - Unzip

static BOOL cmd_unzip_current_file(ZipFile *zipFile, ZipFileInfo *info)
{
	NSError *error;
	ZipReadStream *stream;
	NSFileHandle *outputHandle;
	NSData *data;
	int fd;
	NSFileManager *fm = [NSFileManager defaultManager];

	NSDictionary *attrs = @{NSFileModificationDate: info.date};

	if ([info.name hasSuffix:@"/"]) {

		if ([fm createDirectoryAtPath:info.name withIntermediateDirectories:YES attributes:attrs error:&error] == NO) {
			warnx("%s: error creating directory:\n%s", info.name.UTF8String, error.localizedDescription.UTF8String);
			return NO;
		}
	}
	else {
		// Ensure output path exists, maybe be redundant
		NSString *dirPath = [info.name stringByDeletingLastPathComponent];
		if (dirPath.pathComponents.count > 0) {
			if ([fm createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:attrs error:&error] == NO) {
				warnx("%s: error creating directory:\n%s", info.name.UTF8String, error.localizedDescription.UTF8String);
				return NO;
			}
		}

		// Extract the content
		stream = [zipFile readCurrentFileInZip:&error];
		if (!stream) {
			warnx("%s: error opening file in zip file:\n%s", info.name.UTF8String, error.localizedDescription.UTF8String);
			return NO;
		}

		fd = open(info.name.fileSystemRepresentation, O_WRONLY | O_CREAT | O_TRUNC);
		if (fd < 0) {
			warn("error creating %s", info.name.UTF8String);
			return NO;
		}
		outputHandle = [[NSFileHandle alloc] initWithFileDescriptor:fd];

		do {
			@autoreleasepool {
				data = [stream readDataOfLength:0x100000 error:&error];
				if (!data) {
					warnx("%s: error reading file:\n%s", info.name.UTF8String, error.localizedDescription.UTF8String);
					break;
				}
				[outputHandle writeData:data];
			}
		} while (data && data.length > 0);

		[outputHandle closeFile];

		if ([stream finishedReadingWithError:&error] == NO) {
			warnx("%s: error closing file:\n%s", info.name.UTF8String, error.localizedDescription.UTF8String);
			return NO;
		}

		if ([fm setAttributes:attrs ofItemAtPath:info.name error:&error] == NO)
			warn("set mod date on %s", info.name.UTF8String);
	}
	return YES;
}

void cmd_unzip_patterns(ZipFile *zipFile, NSArray *patterns)
{
	NSError *error;

	NSArray *containedFiles = zipFile.containedFiles;
	if (!containedFiles) {
		err(EXIT_FAILURE, "error reading central directory");
	}
	for (ZipFileInfo *info in containedFiles) {

		if (patterns.count == 0 || patterns_contains_filename(patterns, info.name)) {

			if ([zipFile locateFileInZip:info.name error:&error] == NO) {
				warnx("%s: error locating file:\n%s", info.name.UTF8String, error.localizedDescription.UTF8String);
				continue;
			}
			cmd_unzip_current_file(zipFile, info);
		}
	}
}

/* cmd_unzip_files might appear to be more efficient than cmd_unzip_patterns 
 * because it locates each requested file rather than reading the entire TOC,
 * but the underlying implementation scans the central directory in order. 
 * cmd_unzip_file probably only wins when selecting an early entry in a large
 * central directory.
 */
void cmd_unzip_files(ZipFile *zipFile, NSArray *filePaths)
{
	NSError *error;
	ZipFileInfo *info;

	for (NSString *path in filePaths) {

		if ([zipFile locateFileInZip:path error:&error] == NO) {
			warnx("%s: error locating file:\n%s", path.UTF8String, error.localizedDescription.UTF8String);
			continue;
		}

		info = [zipFile getCurrentFileInZipInfo:&error];
		if (!info) {
			warnx("%s: error reading file info:\n%s", path.UTF8String, error.localizedDescription.UTF8String);
			continue;
		}
		cmd_unzip_current_file(zipFile, info);
	}
}

void cmd_unzip_all(ZipFile *zipFile)
{
	cmd_unzip_patterns(zipFile, [NSArray array]);
}

#pragma mark - Main

void cmd_print_usage(void)
{
	char *lines[] = {
		"usage: ozip [-l|--list] [-c|--create] [-u|--unzip] [-d output_dir] \n",
		"            [-w|--no-wildcards] [-v|--verbose] \n"
		"            <zipfile> [<file> ...] \n",
		NULL
	};
	int i = 0;

	while (lines[i])
		printf("%s", lines[i++]);

	exit(EXIT_SUCCESS);
}

int main(int argc, char * const argv[])
{
	openlog("ozip", LOG_CONS | LOG_PERROR, LOG_USER);

	@autoreleasepool {

		NSString *path = nil;
		NSMutableArray *pathArgs = [NSMutableArray array];

		ZipFile *zipFile = nil;
		ZipFileMode mode = ZipFileModeCreate;
		OZOperationType operation = kOZOperationList;
		BOOL useLiteralMatch = NO;
		NSString *arg, *argParam;

		// Process arguments
		
		NSArray *args = [[NSProcessInfo processInfo] arguments];

		if (args.count == 1)
			cmd_print_usage();
		
		for (int i = 1; i < args.count; i++) {

			arg = args[i];

			if ([arg isEqual:@"-l"] || [arg isEqual:@"--list"]) {

				mode = ZipFileModeUnzip;
				operation = kOZOperationList;
			}
			else if ([arg isEqual:@"-c"] || [arg isEqual:@"--create"]) {

				mode = ZipFileModeCreate;
				operation = kOZOperationZip;
			}
			else if ([arg isEqual:@"-u"] || [arg isEqual:@"--unzip"]) {

				mode = ZipFileModeUnzip;
				operation = kOZOperationUnzip;
			}
			else if ([arg isEqual:@"-d"] || [arg isEqual:@"--directory"]) {

				if (args.count <= i)
					errno = EINVAL, err(EXIT_FAILURE, "-d");
				argParam = args[i+1];
				i++;

				if ([[NSFileManager defaultManager] changeCurrentDirectoryPath:argParam] == NO) {

					/* errno = ENOENT, */
					err(EXIT_FAILURE, "%s", argParam.UTF8String);
				}
			}
			else if ([arg isEqual:@"-w"] || [arg isEqual:@"--no-wildcards"]) {
				useLiteralMatch = YES;
			}
			else if ([arg isEqual:@"-v"] || [arg isEqual:@"--verbose"]) {

				setlogmask(LOG_DEBUG);
			}
			else if (!path) {
				path = arg;
			}
			else {
				[pathArgs addObject:arg];
			}

		}

		// Execute operation
		
		NSError *error;
		NSTimeInterval startInterval = [NSDate timeIntervalSinceReferenceDate];

		if (!path)
			errx(EXIT_FAILURE, "no path specified");

		if ([path hasPrefix:@"http://"])
			zipFile = [ZipFile zipFileWithURL:[NSURL URLWithString:path] mode:mode error:&error];
		else
			zipFile = [ZipFile zipFileWithFileName:path mode:mode error:&error];
		
		if (!zipFile)
			err(EXIT_FAILURE, "%s: error opening file: %s", path.UTF8String, error.localizedDescription.UTF8String);

		printf("Archive: %s\n", path.UTF8String);

		switch (operation) {
			case kOZOperationList:
				cmd_list(zipFile);
				break;

			case kOZOperationUnzip:
				if (pathArgs.count > 0) {
					if (useLiteralMatch)
						cmd_unzip_files(zipFile, pathArgs);
					else
						cmd_unzip_patterns(zipFile, pathArgs);
				}
				else
					cmd_unzip_all(zipFile);
				break;

			case kOZOperationZip:
				break;
			default:
				errx(EXIT_FAILURE, "internal error, illegal OZoperation");
				break;
		}
		[zipFile close];

		syslog(LOG_DEBUG, "total time: %g sec\n", [NSDate timeIntervalSinceReferenceDate] - startInterval);
	}

	closelog();
	
    return EXIT_SUCCESS;
}
