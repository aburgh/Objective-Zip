//
//  ZipFileUnitTest.h
//  ZipFileUnitTest
//
//  Created by Aaron Burghardt on 11/10/12.
//
//

#import <SenTestingKit/SenTestingKit.h>

@class ZipFile;

@interface ZipFileUnitTest : SenTestCase

@property (copy) NSString *zipFilePath;
@property (copy) NSArray *filenames;
@property (copy) NSArray *hashes;

@end
