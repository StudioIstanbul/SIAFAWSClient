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

typedef enum {
    SIAFAWSStandard,
    SIAFAWSReducedRedundancy,
    SIAFAWSGlacier
} SIAFAWSStorageClass;

#define SIAFAWSRegion(enum) [@[@"us-east-1", @"us-west-2", @"us-west-1", @"eu-west-1", @"eu-central-1", @"ap-southeast-1", @"ap-southeast-2", @"ap-northeast-1", @"sa-east-1"] objectAtIndex:enum]
#define SIAFAWSRegionName(enum) [@[@"US Standard", @"US West Oregon", @"US West North California", @"EU Ireland", @"EU Frankfurt", @"AP Singapore", @"AP Sydney", @"AP Tokyo", @"AP Sao Paulo"] objectAtIndex:enum]
#define SIAFAWSRegionalBaseURL(enum) [@[@"s3.amazonaws.com", @"s3-us-west-2.amazonaws.com", @"s3-us-west-1.amazonaws.com", @"s3-eu-west-1.amazonaws.com", @"s3-eu-central-1.amazonaws.com", @"s3-ap-southeast-1.amazonaws.com", @"s3-ap-southeast-2.amazonaws.com", @"s3-ap-northeast-1.amazonaws.com", @"s3-sa-east-1.amazonaws.com"] objectAtIndex:enum]
#define SIAFAWSReginCount 9
#define SIAFAWSRegionForBaseURL(url) [@[@"s3.amazonaws.com", @"s3-us-west-2.amazonaws.com", @"s3-us-west-1.amazonaws.com", @"s3-eu-west-1.amazonaws.com", @"s3-eu-central-1.amazonaws.com", @"s3-ap-southeast-1.amazonaws.com", @"s3-ap-southeast-2.amazonaws.com", @"s3-ap-northeast-1.amazonaws.com", @"s3-sa-east-1.amazonaws.com"] indexOfString:url]

@class SIAFAWSClient, AWSLifeCycle, AWSFile;

@protocol SIAFAWSClientProtocol

@optional
-(void)awsclient:(SIAFAWSClient*)client receivedBucketContentList:(NSArray*)bucketContents forBucket:(NSString*)bucketName;
-(void)awsclient:(SIAFAWSClient *)client receivedBucketList:(NSArray *)buckets;
-(NSString*)awsclientRequiresAccessKey:(SIAFAWSClient *)client;
-(NSString*)awsclientRequiresSecretKey:(SIAFAWSClient *)client;
-(NSData*)awsclientRequiresKeyData:(SIAFAWSClient *)client;
-(void)awsclient:(SIAFAWSClient *)client finishedUploadForUrl:(NSURL*)localURL;
-(void)awsclient:(SIAFAWSClient *)client finishedDownloadForKey:(NSString*)key toURL:(NSURL *)localURL;
-(void)uploadProgress:(double)progress forURL:(NSURL*)localFileUrl;
-(void)downloadProgress:(double)progress forKey:(NSString*)key;
-(void)awsClient:(SIAFAWSClient*)client receivedMetadata:(AWSFile*)fileMetadata forKey:(NSString*)key onBucket:(NSString*)bucket;
-(void)awsClient:(SIAFAWSClient*)client requestFailedWithError:(NSError*)error;
-(void)awsClient:(SIAFAWSClient*)client changedLifeCycleForBucket:(NSString*)bucket;
-(void)awsClient:(SIAFAWSClient*)client receivedLifecycleConfiguration:(AWSLifeCycle*)lifeCycleConfiguration forBucket:(NSString*)bucketName;
@end

@interface AWSSigningKey : NSObject <NSCoding>
@property (nonatomic, strong) NSData* key;
@property (nonatomic, strong) NSDate* keyDate;
@property (nonatomic) SIAFAWSRegion region;
@property (nonatomic, strong) NSString* accessKey;

-(id)initWithKey:(NSData*)keyContent andDate:(NSDate*)creationDate;
-(void)saveToKeychain;
@end

@class AWSBucket, AWSLifeCycle, AWSOperation;

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
@property (nonatomic, strong) NSThread* callBackThread;

-(NSString*)host;

-(void)listBuckets;
-(void)listBucketsWithAccessPermissionCheck:(BOOL)checkPermission;
-(void)listBucket:(NSString*)bucketName;

-(void)uploadFileFromURL:(NSURL*)url toKey:(NSString*)key onBucket:(NSString*)bucketName;
-(void)uploadFileFromURL:(NSURL *)url toKey:(NSString *)key onBucket:(NSString *)bucketName withSSECKey:(NSData*)ssecKey;
-(void)uploadFileFromURL:(NSURL *)url toKey:(NSString *)key onBucket:(NSString *)bucketName withSSECKey:(NSData *)ssecKey withStorageClass:(SIAFAWSStorageClass)storageClass andMetadata:(NSDictionary*)metadata;

-(void)downloadFileFromKey:(NSString*)key onBucket:(NSString*)bucketName toURL:(NSURL*)fileURL;
-(void)downloadFileFromKey:(NSString*)key onBucket:(NSString*)bucketName toURL:(NSURL*)fileURL withSSECKey:(NSData*)ssecKey;

-(void)restoreFileFromKey:(NSString*)key onBucket:(NSString*)bucketName withExpiration:(NSTimeInterval)expiration;

-(void)metadataForKey:(NSString*)key onBucket:(NSString*)bucketName;
-(void)metadataForKey:(NSString*)key onBucket:(NSString*)bucketName withSSECKey:(NSData *)ssecKey;

-(void)checkBucket:(AWSBucket*)checkBucket forPermissionWithBlock:(void(^)(SIAFAWSAccessRight accessRight))block;

-(void)setBucketLifecycle:(AWSLifeCycle*)awsLifecycle forBucket:(NSString*)bucketName;
-(void)lifecycleRulesForBucket:(NSString*)bucketName;
@end

@interface AWSOperation : AFHTTPRequestOperation

@property (nonatomic, strong) NSMutableURLRequest *request;
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

@interface AWSFile : NSObject

@property (nonatomic, strong) NSString* key;
@property (nonatomic, strong) NSDate* lastModified;
@property (nonatomic, strong) NSDate* expirationDate;
@property (nonatomic, assign) NSInteger fileSize;
@property (nonatomic, strong) NSString* etag;
@property (nonatomic, strong) NSString* bucket;
@property (nonatomic, assign) SIAFAWSStorageClass storageClass;
@property (nonatomic, strong) NSString* ssecMD5;
@property (nonatomic, strong) NSDictionary* metadata;
@property (nonatomic, assign) BOOL restoredKey;
@property (nonatomic, assign) BOOL restoreInProgress;

@end

@interface AWSLifeCycleRule : NSObject
@property (strong, nonatomic) NSString* ID;
@property (strong, nonatomic) NSString* prefix;
@property (assign, nonatomic) NSTimeInterval exiprationInterval;
@property (assign, nonatomic) NSTimeInterval transitionInterval;
@property (assign, nonatomic) BOOL transition;
@property (assign, nonatomic) BOOL expiration;

@end

@interface AWSLifeCycle : NSObject

@property (readonly, nonatomic) NSArray* rules;

-(void) addLiveCycleRule:(AWSLifeCycleRule*)rule;
-(NSData*) xmlData;

@end