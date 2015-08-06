//
//  SIAFAWSClient.h
//  Cloud Backup Agent
//
//  Created by Andreas Zöllner on 20.07.15.
//  Copyright (c) 2015 Studio Istanbul Medya Hiz. Tic. Ltd. Sti. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AFHTTPClient.h"
#import "AFHTTPRequestOperation.h"
#import "NSArray+containsString.h"

typedef enum {
    SIAFAWSRegionUSStandard = 0,
    SIAFAWSRegionUSWestOregon = 1,
    SIAFAWSRegionUSWestNorthCalifornia = 2,
    SIAFAWSRegionEUIreland = 3,
    SIAFAWSRegionEUFrankfurt = 4,
    SIAFAWSRegionAPSingapore = 5,
    SIAFAWSRegionAPSydney = 6,
    SIAFAWSRegionAPTokyo = 7,
    SIAFAWSRegionAPSaoPaulo = 8
} SIAFAWSRegion;

typedef enum {
    SIAFAWSAccessUndefined,
    SIAFAWSFullControl,
    SIAFAWSWrite,
    SIAFAWSWriteACP,
    SIAFAWSRead,
    SIAFAWSReadACP
} SIAFAWSAccessRight;

#define SIAFAWSRegion(enum) [@[@"us-east-1", @"us-west-2", @"us-west-1", @"eu-west-1", @"eu-central-1", @"ap-southeast-1", @"ap-southeast-2", @"ap-northeast-1", @"sa-east-1"] objectAtIndex:enum]
#define SIAFAWSRegionName(enum) [@[@"US Standard", @"US West Oregon", @"US West North California", @"EU Ireland", @"EU Frankfurt", @"AP Singapore", @"AP Sydney", @"AP Tokyo", @"AP Sao Paulo"] objectAtIndex:enum]
#define SIAFAWSRegionalBaseURL(enum) [@[@"s3.amazonaws.com", @"s3-us-west-2.amazonaws.com", @"s3-us-west-1.amazonaws.com", @"s3-eu-west-1.amazonaws.com", @"s3-eu-central-1.amazonaws.com", @"s3-ap-southeast-1.amazonaws.com", @"s3-ap-southeast-2.amazonaws.com", @"s3-ap-northeast-1.amazonaws.com", @"s3-sa-east-1.amazonaws.com"] objectAtIndex:enum]
#define SIAFAWSReginCount 9
#define SIAFAWSRegionForBaseURL(url) [@[@"s3.amazonaws.com", @"s3-us-west-2.amazonaws.com", @"s3-us-west-1.amazonaws.com", @"s3-eu-west-1.amazonaws.com", @"s3-eu-central-1.amazonaws.com", @"s3-ap-southeast-1.amazonaws.com", @"s3-ap-southeast-2.amazonaws.com", @"s3-ap-northeast-1.amazonaws.com", @"s3-sa-east-1.amazonaws.com"] indexOfString:url]

@class SIAFAWSClient;

@protocol SIAFAWSClientProtocol

@optional
-(void)awsclient:(SIAFAWSClient*)client receivedBucketContentList:(NSArray*)bucketContents forBucket:(NSString*)bucketName;
-(void)awsclient:(SIAFAWSClient *)client receivedBucketList:(NSArray *)buckets;
-(NSString*)awsclientRequiresAccessKey:(SIAFAWSClient *)client;
-(NSString*)awsclientRequiresSecretKey:(SIAFAWSClient *)client;
@end

@interface AWSSigningKey : NSObject <NSCoding>
@property (nonatomic, strong) NSData* key;
@property (nonatomic, strong) NSDate* keyDate;
@property (nonatomic) SIAFAWSRegion region;
@property (nonatomic, strong) NSString* accessKey;

-(id)initWithKey:(NSData*)keyContent andDate:(NSDate*)creationDate;
-(void)saveToKeychain;
@end

@class AWSBucket;

@interface SIAFAWSClient : AFHTTPClient

@property (nonatomic, readwrite, retain) NSURL* baseURL;
@property (nonatomic, retain) NSString* accessKey;
@property (nonatomic, retain) NSString* secretKey;
@property (nonatomic) SIAFAWSRegion region;
@property (nonatomic, retain) NSString* bucket;
@property (nonatomic, weak) NSObject<SIAFAWSClientProtocol> *delegate;
@property (nonatomic, retain) AWSSigningKey* signingKey;
@property (nonatomic) BOOL syncWithKeychain;
@property (nonatomic, readonly) BOOL isBusy;

-(NSString*)host;

-(void)listBuckets;
-(void)listBucketsWithAccessPermissionCheck:(BOOL)checkPermission;
-(void)listBucket:(NSString*)bucketName;

-(void)checkBucket:(AWSBucket*)checkBucket forPermissionWithBlock:(void(^)(SIAFAWSAccessRight accessRight))block;
@end

@interface AWSOperation : AFHTTPRequestOperation

@property (nonatomic, strong) NSURLRequest *request;

@end

@interface AWSBucket : NSObject

@property (nonatomic, assign) SIAFAWSAccessRight accessRight;
@property (nonatomic, strong) NSString* name;
@property (nonatomic, readonly) NSDate* creationDate;
@property (nonatomic, assign) SIAFAWSRegion region;
@property (nonatomic, readonly) NSString* regionName;
@property (nonatomic, strong) SIAFAWSClient* awsClient;

-(id)initWithName:(NSString*)name andCreationDate:(NSDate*)date;

@end
