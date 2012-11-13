//
//  ZipFileCURLUnitTest.h
//  Objective-Zip
//
//  Created by Aaron Burghardt on 11/12/12.
//
//

#import <SenTestingKit/SenTestingKit.h>

@interface ZipFileCURLUnitTest : SenTestCase

@property (nonatomic, copy) NSString *zipFileURL;
@property (nonatomic, copy) NSArray *filenames;
@property (nonatomic, copy) NSArray *hashes;

@end
