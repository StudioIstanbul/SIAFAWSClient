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

typedef enum {
    SIAFAWSRegionUSStandard,
    SIAFAWSRegionUSWestOregon,
    SIAFAWSRegionUSWestNorthCalifornia,
    SIAFAWSRegionEUIreland,
    SIAFAWSRegionEUFrankfurt,
    SIAFAWSRegionAPSingapore,
    SIAFAWSRegionAPSydney,
    SIAFAWSRegionAPTokyo,
    SIAFAWSRegionAPSaoPaulo
} SIAFAWSRegion;
#define SIAFAWSRegion(enum) [@[@"us-east-1", @"us-west-2", @"us-west-1", @"eu-west-1", @"eu-central-1", @"ap-southeast-1", @"ap-southeast-2", @"ap-northeast-1", @"sa-east-1"] objectAtIndex:enum]
#define SIAFAWSRegionalBaseURL(enum) [@[@"s3.amazonaws.com", @"s3-us-west-2.amazonaws.com", @"s3-us-west-1.amazonaws.com", @"s3-eu-west-1.amazonaws.com", @"s3-eu-central-1.amazonaws.com", @"s3-ap-southeast-1.amazonaws.com", @"s3-ap-southeast-2.amazonaws.com", @"s3-ap-northeast-1.amazonaws.com", @"s3-sa-east-1.amazonaws.com"] objectAtIndex:enum]

@class SIAFAWSClient;

@protocol SIAFAWSClientProtocol

@optional
-(void)awsclient:(SIAFAWSClient*)client receivedBucketContentList:(NSArray*)bucketContents forBucket:(NSString*)bucketName;
@end

@interface AWSSigningKey : NSObject <NSCoding>
@property (nonatomic, strong) NSData* key;
@property (nonatomic, strong) NSDate* keyDate;

-(id)initWithKey:(NSData*)keyContent andDate:(NSDate*)creationDate;
-(void)saveToKeychain;
@end

@interface SIAFAWSClient : AFHTTPClient

@property (nonatomic, retain) NSString* accessKey;
@property (nonatomic, retain) NSString* secretKey;
@property (nonatomic) SIAFAWSRegion region;
@property (nonatomic, retain) NSString* bucket;
@property (nonatomic, weak) NSObject<SIAFAWSClientProtocol> *delegate;
@property (nonatomic, retain) AWSSigningKey* signingKey;
@property (nonatomic) BOOL syncWithKeychain;

-(NSString*)host;

-(void)listBucket:(NSString*)bucketName;

@end

@interface AWSOperation : AFHTTPRequestOperation

@property (nonatomic, strong) NSURLRequest *request;

@end
