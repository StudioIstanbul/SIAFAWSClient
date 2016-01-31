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

/** defines a valid AWS Region, please look up valid S3 regions at http://docs.aws.amazon.com/general/latest/gr/rande.html */
typedef NS_ENUM(NSInteger, SIAFAWSRegion) {
    /** Standard AWS Region (defaults to 'us-east-1') */
    SIAFAWSRegionUSStandard = 0,
    /** AWS Region US West Oregon */
    SIAFAWSRegionUSWestOregon = 1,
    /** AWS Region US West North California */
    SIAFAWSRegionUSWestNorthCalifornia = 2,
    /** AWS Region EU Ireland */
    SIAFAWSRegionEUIreland = 3,
    /** AWS Region EU Frankfurt */
    SIAFAWSRegionEUFrankfurt = 4,
    /** AWS Region AP Singapore */
    SIAFAWSRegionAPSingapore = 5,
    /** AWS Region AP Sydney */
    SIAFAWSRegionAPSydney = 6,
    /** AWS Region AP Tokyo */
    SIAFAWSRegionAPTokyo = 7,
    /** AWS Region AP Sao Paulo */
    SIAFAWSRegionAPSaoPaulo = 8
};

/** defines access rights to a S3 bucket, based on ACL bucket policy */
typedef NS_ENUM(NSInteger, SIAFAWSAccessRight) {
    /** Access is undefined or policy missing */
    SIAFAWSAccessUndefined,
    /** Full control */
    SIAFAWSFullControl,
    /** Write access to bucket */
    SIAFAWSWrite,
    /** Write access to bucket policy */
    SIAFAWSWriteACP,
    /** Read access to bucket */
    SIAFAWSRead,
    /** Read access to bucket policy */
    SIAFAWSReadACP
};
     
/** defines an AWS S3 storage class */
typedef NS_ENUM(NSInteger, SIAFAWSStorageClass) {
    /** Amazon S3 standard storage class */
    SIAFAWSStandard,
    /** Amazon S3 reduced redundancy storage class */
    SIAFAWSReducedRedundancy,
    /** Amazon Glacier storage class
     * This can't be set, only for response from AWS */
    SIAFAWSGlacier
};

#define SIAFAWSRegion(enum) [@[@"us-east-1", @"us-west-2", @"us-west-1", @"eu-west-1", @"eu-central-1", @"ap-southeast-1", @"ap-southeast-2", @"ap-northeast-1", @"sa-east-1"] objectAtIndex:enum]
#define SIAFAWSRegionForCode(regioncode) [@[@"us-east-1", @"us-west-2", @"us-west-1", @"eu-west-1", @"eu-central-1", @"ap-southeast-1", @"ap-southeast-2", @"ap-northeast-1", @"sa-east-1"] indexOfString:regioncode]
#define SIAFAWSRegionName(enum) [@[@"US Standard", @"US West Oregon", @"US West North California", @"EU Ireland", @"EU Frankfurt", @"AP Singapore", @"AP Sydney", @"AP Tokyo", @"AP Sao Paulo"] objectAtIndex:enum]
#define SIAFAWSRegionalBaseURL(enum) [@[@"s3.amazonaws.com", @"s3-us-west-2.amazonaws.com", @"s3-us-west-1.amazonaws.com", @"s3-eu-west-1.amazonaws.com", @"s3-eu-central-1.amazonaws.com", @"s3-ap-southeast-1.amazonaws.com", @"s3-ap-southeast-2.amazonaws.com", @"s3-ap-northeast-1.amazonaws.com", @"s3-sa-east-1.amazonaws.com"] objectAtIndex:enum]
#define SIAFAWSRegionCount 9
#define SIAFAWSRegionForBaseURL(url) [@[@"s3.amazonaws.com", @"s3-us-west-2.amazonaws.com", @"s3-us-west-1.amazonaws.com", @"s3-eu-west-1.amazonaws.com", @"s3-eu-central-1.amazonaws.com", @"s3-ap-southeast-1.amazonaws.com", @"s3-ap-southeast-2.amazonaws.com", @"s3-ap-northeast-1.amazonaws.com", @"s3-sa-east-1.amazonaws.com"] indexOfString:url]

@class SIAFAWSClient, AWSLifeCycle, AWSFile;

/**  Implement these SIAFAWSClientProtocol functions in order to respond to AWS API request updates.  */
@protocol SIAFAWSClientProtocol

@optional
/**
 will be called after receiving a content list of a S3 bucket
 @param client the client calling the delegate
 @param bucketContents NSArray of AWSFile objects representing the contents of a bucket
 @param bucketName name of the S3 bucket
 see listBucket:
 */
-(void)awsclient:(SIAFAWSClient*)client receivedBucketContentList:(NSArray*)bucketContents forBucket:(NSString*)bucketName;


/**
 will be called when list of available buckets for the user's account is received
 @param client the client calling the delegate
 @param buckets NSArray of AWSBucket objects representing the available buckets
 see listBuckets;
*/
-(void)awsclient:(SIAFAWSClient *)client receivedBucketList:(NSArray *)buckets;


/**
 will be called if client needs to provide an access key but access key has not been set.
 @param client the client calling the delegate
 @return delegate shall return NSString with user's access key
 see setAccessKey:
*/
-(NSString*)awsclientRequiresAccessKey:(SIAFAWSClient *)client;


/**
 will be called if client needs to provide an secret key but secret key has not been set.
 @param client the client calling the delegate
 @return delegate shall return NSString with user's secret key
 see secretKey
 */
-(NSString*)awsclientRequiresSecretKey:(SIAFAWSClient *)client;


/**
 will be called if client needs to provide an encryption key for SSEC file encryption
 but key has not been set.
 @param client the client calling the delegate
 @return delegate shall return NSString with user's access key
 */
-(NSData*)awsclientRequiresKeyData:(SIAFAWSClient *)client;


/**
 will be called when uploading a local file has successfully finished.
 @param client the client calling the delegate
 @param localURL the local file URL of the file uploaded
*/
-(void)awsclient:(SIAFAWSClient *)client finishedUploadForUrl:(NSURL*)localURL;

/**
 will be called when uploading a local file has successfully finished
 @param client the client calling the delegate
 @param localURL the local file URL of the file uploaded
 @param awsKey the key the file has been uploaded to
 */
-(void)awsclient:(SIAFAWSClient *)client finishedUploadForUrl:(NSURL*)localURL awsKey:(NSString*)awsKey;

/**
 will be called when downloading a file has been successfully downloaded
 @param client the client calling the delegate
 @param key the AWS S3 bucket's key the file has been downloaded from
 @param localURL the local file URL the file has been downloaded to
*/
-(void)awsclient:(SIAFAWSClient *)client finishedDownloadForKey:(NSString*)key toURL:(NSURL *)localURL;


/**
 periodically called to update upload progress for a single operation
 @param progress double value for new progress between 0 and 1
 @param localFileUrl local file URL for current upload operation
*/
-(void)uploadProgress:(double)progress forURL:(NSURL*)localFileUrl;


/**
 periodically called to update download progress for a single operation
 @param progress double value for new progress between 0 and 1
 @param key S3 bucket key for current download operation
*/
-(void)downloadProgress:(double)progress forKey:(NSString*)key;


/**
 will be called when metadata for AWS S3 file is received
 @param client the client calling the delegate
 @param fileMetadata AWSFile object with updated metadata
 @param key AWS S3 bucket's key for current file
 @param bucket name of current bucket
*/
-(void)awsClient:(SIAFAWSClient*)client receivedMetadata:(AWSFile*)fileMetadata forKey:(NSString*)key onBucket:(NSString*)bucket;


/**
 will be called when a request to AWS service fails
 @param client the client calling the delegate
 @param error NSError object describing the error
*/
-(void)awsClient:(SIAFAWSClient*)client requestFailedWithError:(NSError*)error;


/**
 will be called if setting life cycle operation is successfull
 @param client the client calling the delegate
 @param bucket name of the current bucket
*/
-(void)awsClient:(SIAFAWSClient*)client changedLifeCycleForBucket:(NSString*)bucket;


/**
 will be called if bucket lifecycle settings are received
 @param client the client calling the delegate
 @param lifeCycleConfiguration lifecycle configuration as AWSLifeCycle object for current bucket
 @param bucketName name of the current bucket
*/
-(void)awsClient:(SIAFAWSClient*)client receivedLifecycleConfiguration:(AWSLifeCycle*)lifeCycleConfiguration forBucket:(NSString*)bucketName;


/**
 will be called if a restore request fails because object is already available
 @param client the client calling the delegate
 @param key key of the requested object
 @param bucket name of the current bucketName
*/
-(void)awsClient:(SIAFAWSClient*)client objectIsAvailableAtKey:(NSString*)key onBucket:(NSString*)bucket;


/**
 will be called if an object has been deleted successfully
 @param client the client calling the delegate
 @param key key of the deleted object
 @param bucket name of the current bucketName
*/
-(void)awsClient:(SIAFAWSClient *)client deletedKey:(NSString*)key onBucket:(NSString *)bucket;


/**
 will be called if bucket has been successfully ceated
 @param client the client calling the delegate
 @param bucket name of the current bucketName
*/
-(void)awsClient:(SIAFAWSClient *)client successfullyCreatedBucket:(NSString *)bucket;
@end

/** A Amazon AWS signing key.
 This key object is used to sign all requests for max 7 days and is bound to the specified region.
 @see http://docs.aws.amazon.com/general/latest/gr/signature-version-4.html for more information.
 
 **Never set a key on your own, always use SIAFAWSClient's helper functions to create a valid key!**
*/
@interface AWSSigningKey : NSObject <NSCoding>
/** this property stores the actual signing key data used for signing requests to AWS. Never set this on your own, always use SIAFAWSClient's helper function to create a valid key! */
@property (nonatomic, strong) NSData* key;

/** this property stores the date this key has been created. Due to AWS security restrictions every key is valid for up to 7 days. */
@property (nonatomic, strong) NSDate* keyDate;

/** the AWS region this key has been bound to */
@property (nonatomic) SIAFAWSRegion region;

/** the AWS access key this key has been bound to */
@property (nonatomic, strong) NSString* accessKey;

/** initialising a new key object (not a new key!)
 @param keyContent the content data for this key
 @param creationDate the actual creation date of this key
*/
-(id)initWithKey:(NSData*)keyContent andDate:(NSDate*)creationDate;

/** helper method to save a signing key directly to the OS X keychain */
-(void)saveToKeychain;
@end

@class AWSBucket, AWSLifeCycle, AWSOperation;

/** The main object handling Amazon AWS S3 operations via AFNetworking. Use this class to do your operations.
*/
@interface SIAFAWSClient : AFHTTPClient
/** the base URL that should be used for this client. Normally set automatically by choosing a region */
@property (nonatomic, readwrite, retain) NSURL* baseURL;

/** the user's access key, part of the credentials used to login to Amazon AWS */
@property (nonatomic, retain) NSString* accessKey;

/** the user's secret key, part of the credentials used to login to Amazon AWS. This value is only needed if no signing key is provided. */
@property (nonatomic, retain) NSString* secretKey;

/** the AWS region to use for this client, automatically sets baseURLs and appropriate signing key if needed */
@property (nonatomic) SIAFAWSRegion region;

/** the name of the AWS S3 bucket to use for this client */
@property (nonatomic, retain) NSString* bucket;

/** the delegate to be informed about success or failure of requests */
@property (nonatomic, weak) NSObject<SIAFAWSClientProtocol> *delegate;

/** the signing key for AWS operations. Optional, will be populated automatically on the first request if .accessKey and .secretKey are provided */
@property (nonatomic, retain) AWSSigningKey* signingKey;

/** set to YES if you want credentials to be stored and retrieved from OS X keychain */
@property (nonatomic) BOOL syncWithKeychain;

/** will be YES if operation is currently executed
 @return YES if busy
*/
@property (nonatomic, readonly) BOOL isBusy;

/** the NSThread to be used for delegate callbacks */
@property (nonatomic, strong) NSThread* callBackThread;

/** AWS error code of the last error.
 @see http://docs.aws.amazon.com/AmazonS3/latest/API/ErrorResponses.html for more details on possible values.
*/
@property (nonatomic, readonly) NSString* lastErrorCode;

/** returning the current hostname for operations
 @return hostname
*/
-(NSString*)host;

/** list all buckets for user with credentials provided */
-(void)listBuckets;

/** list all buckets for user with credentials provided but check if bucket policy allowes access if set to YES. This operation might be time consuming if a huge number of buckets is available!
 @param checkPermission set to YES for ACL check
 */
-(void)listBucketsWithAccessPermissionCheck:(BOOL)checkPermission;

/** list the contents of a bucket
 @param bucketName name of the bucket to list contents
*/
-(void)listBucket:(NSString*)bucketName;

/** upload file to AWS S3
 @param url local file URL
 @param key remote AWS key to upload to. If key already exists it will be overwritten without further notice or a new version will be created if versioning is enabled in the bucket settings. Always provide an absolut key path.
 @param bucketName name of the bucket to upload to
*/
-(void)uploadFileFromURL:(NSURL*)url toKey:(NSString*)key onBucket:(NSString*)bucketName;

/** upload a file to AWS S3 using a custom key for server side encryption. The uploaded file will only be restorable if you provide this key again. Encryption is performed **remote** by Amazon AWS.
 @see http://docs.aws.amazon.com/AmazonS3/latest/dev/ServerSideEncryptionCustomerKeys.html for more information on server side encryption
 @param url local file URL
 @param key remote AWS key to upload to. If key already exists it will be overwritten without further notice or a new version will be created if versioning is enabled in the bucket settings. Always provide an absolut key path.
 @param bucketName name of the bucket to upload to
 @param ssecKey key used to encrypt data, has to be 256 bit and AES256 compatible or nil if upload shall not be encrypted
*/
-(void)uploadFileFromURL:(NSURL *)url toKey:(NSString *)key onBucket:(NSString *)bucketName withSSECKey:(NSData*)ssecKey;

/** upload a file to AWS S3 using a custom key for server side encryption and with metadata. Metadata will be stored in AWS S3 key metadata headers.
 @see uploadFileFromURL:toKey:onBucket:withSSECKey:
 @param url local file URL
 @param key remote AWS key to upload to. If key already exists it will be overwritten without further notice or a new version will be created if versioning is enabled in the bucket settings. Always provide an absolut key path.
 @param bucketName name of the bucket to upload to
 @param ssecKey key used to encrypt data, has to be 256 bit and AES256 compatible or nil if upload shall not be encrypted
 @param metadata NSDictionary containing metadata as strings. NSDictionary keys must not include special characters or white spaces.
 @param storageClass AWS Storage class to be used. May be SIAFAWSStandard or SIAFAWSReducedRedundancy. Direct put to Glacier is not supported by AWS. Set up a lifecycle rule if you want to use Glacier. @see SIAFAWSStorageClass
*/
-(void)uploadFileFromURL:(NSURL *)url toKey:(NSString *)key onBucket:(NSString *)bucketName withSSECKey:(NSData *)ssecKey withStorageClass:(SIAFAWSStorageClass)storageClass andMetadata:(NSDictionary*)metadata;

/** download an unencrypted file from AWS S3 bucket key
 @param key key to download
 @param bucketName name of bucket to download from
 @param fileURL local file URL to store downloaded file to
*/
-(void)downloadFileFromKey:(NSString*)key onBucket:(NSString*)bucketName toURL:(NSURL*)fileURL;

/** download encrypted file from AWS S3 bucket key
 @param key key to download
 @param bucketName name of bucket to download from
 @param fileURL local file URL to store downloaded file to
 @param ssecKey key used to encrypt data, has to be 256 bit and AES256 compatible or nil if key to download is not encrypted
*/
-(void)downloadFileFromKey:(NSString*)key onBucket:(NSString*)bucketName toURL:(NSURL*)fileURL withSSECKey:(NSData*)ssecKey;

/** restore a file from AWS Glacier that has been transfered due to lifecycle configuration.
 @param key key to restore, must be an existing key. Key to be restored must have been uploaded to S3 bucket at some time previously.
 @param bucketName bucket name for restore operation
 @param expiration time intervall to keep restored key on S3. NSTimeInterval for convinience but using full days on server side.
*/
-(void)restoreFileFromKey:(NSString*)key onBucket:(NSString*)bucketName withExpiration:(NSTimeInterval)expiration;

/** delete a file from Amazon AWS S3 and/or Glacier. This can't be undone if bucket versioning is not enabled on bucket.
 @param key key of file to delete
 @param bucketName name of bucket for delete operation
*/
-(void)deleteKey:(NSString*)key onBucket:(NSString*)bucketName;

/** fetch metadata for unencrypted file. This method fetches an AWSFile object with updated values for all properties including metadata dictionary. @see AWSFile for more information on available properties. This method fails if file is encrypted.
 @param key key to fetch metadata for
 @param bucketName bucket name for metadata operation
*/
-(void)metadataForKey:(NSString*)key onBucket:(NSString*)bucketName;

/** fetch metadata for a file. This method fetches an AWSFile object with updated values for all properties including metadata dictionary. @see AWSFile for more information on available properties.
 @param key key to fetch metadata for
 @param bucketName bucket name for metadata operation
 @param ssecKey key used to encrypt data, has to be 256 bit and AES256 compatible or nil if key is not encrypted
*/
-(void)metadataForKey:(NSString*)key onBucket:(NSString*)bucketName withSSECKey:(NSData *)ssecKey;

/** perform a block with access rights property on a bucket
 @param checkBucket bucket to check
 @param block block to execute
*/
-(void)checkBucket:(AWSBucket*)checkBucket forPermissionWithBlock:(void(^)(SIAFAWSAccessRight accessRight))block;

/** set a lifecycle for bucket. This method is overriding any existing bucket lifecycle. Create a AWSLifecycle object and set properties on it first.
 @see AWSLifeCycle and @see AWSLifeCycleRule for more information on lifecycle configuration.
 @param awsLifecycle lifecycle to set, pass nil to delete lifecycle
 @param bucketName bucket name to set lifecycle
*/
-(void)setBucketLifecycle:(AWSLifeCycle*)awsLifecycle forBucket:(NSString*)bucketName;

/** fetch lifecycle configuration for Amazon AWS bucket.
 @see AWSLifeCycle and @see AWSLifeCycleRule for more information on lifecycle configuration.
 @param bucketName bucket name to fetch lifecycle
*/
-(void)lifecycleRulesForBucket:(NSString*)bucketName;

/** refresh region info on bucket object
@param bucketObject bucket object to refresh
*/
-(void)regionForBucket:(AWSBucket*)bucketObject;

/** create a bucket in current user's account.
 @param bucketName name of the new bucket
*/
-(void)createBucket:(NSString*)bucketName;

/** create a new signing key with the credentials provided. This signing key is bound to S3 service and the provided region and valid for 7 days. This method is called automatically if no valid signing key is detected but accessKey and secretKey exist or are provided by the delegate class.
 @param accessKey access key of the user
 @param secretKey secret key of the user
 @param region AWSRegion to use for this signing key
 */
-(AWSSigningKey*)createSigningKeyForAccessKey:(NSString*)accessKey secretKey:(NSString*)secretKey andRegion:(SIAFAWSRegion)region;
@end

/** an AWS Operation, this class is mainly used private but namespace exported to use it for debug
 or error handling reasons
*/
@interface AWSOperation : AFHTTPRequestOperation
/** mutable request */
@property (nonatomic, strong) NSMutableURLRequest *request;
@end

/** decribes an AWS S3 bucket and access rights to it*/
@interface AWSBucket : NSObject
/** access rights according to bucket's ACL */
@property (nonatomic, assign) SIAFAWSAccessRight accessRight;
/** name of the bucket */
@property (nonatomic, strong) NSString* name;
/** date of creation for this bucket */
@property (nonatomic, readonly) NSDate* creationDate;
/** AWS region this bucket is stored */
@property (nonatomic, assign) SIAFAWSRegion region;
/** NSString to access AWS region name */
@property (nonatomic, readonly) NSString* regionName;
/** client this bucket belongs to */
@property (nonatomic, strong) SIAFAWSClient* awsClient;

/** create a new bucket object to represent AWS S3 bucket (not creating a remote bucket!)
 @param name bucket name
 @param date creation date for this bucket
 @return bucket object
*/
-(id)initWithName:(NSString*)name andCreationDate:(NSDate*)date;

@end

/** describes a file in an AWS S3 bucket */
@interface AWSFile : NSObject
/** remote AWS S3 key used to store this file */
@property (nonatomic, strong) NSString* key;
/** last modification date for remote representation of this file */
@property (nonatomic, strong) NSDate* lastModified;
/** expiration date when this file will be deleted according to lifecycle configuration. @see setBucketLifeCycle:forBucket: */
@property (nonatomic, strong) NSDate* expirationDate;
/** size of remote representation for this file in bytes, excluding metadata */
@property (nonatomic, assign) NSInteger fileSize;
/** etag property of remote file. Equals MD5 checksum only if file is not encrypted! */
@property (nonatomic, strong) NSString* etag;
/** bucket name this file belongs to */
@property (nonatomic, strong) NSString* bucket;
/** storage class of this file. @see SIAFAWSStorageClass for possible values. */
@property (nonatomic, assign) SIAFAWSStorageClass storageClass;
/** MD5 checksum of the key data that has been used to encrypt this file. Store to check for correct key data later. */
@property (nonatomic, strong) NSString* ssecMD5;
/** dictionary with custom metadata provided on upload */
@property (nonatomic, strong) NSDictionary* metadata;
/** YES if the file has been restored from Glacier and is available */
@property (nonatomic, assign) BOOL restoredKey;
/** YES if this file is currently to be stored from Glacier but operation has not finished yet. */
@property (nonatomic, assign) BOOL restoreInProgress;

@end

/** describes a lifecycle rule defined for a bucket */
@interface AWSLifeCycleRule : NSObject
/** ID of lifecycle rule, set to anything you want */
@property (strong, nonatomic) NSString* ID;
/** prefix for keys affected by this rule */
@property (strong, nonatomic) NSString* prefix;
/** timeinterval for delete of affected keys,rounding to days on server side! */
@property (assign, nonatomic) NSTimeInterval exiprationInterval;
/** timeinterval for transition to Glacier for affected keys */
@property (assign, nonatomic) NSTimeInterval transitionInterval;
/** transition active in rule */
@property (assign, nonatomic) BOOL transition;
/** delete active in rule */
@property (assign, nonatomic) BOOL expiration;

@end

/** describes the lifecycle configuration of a bucket */
@interface AWSLifeCycle : NSObject
/** array of lifecycle rules for bucket, do not modify this array! @see addLiveCycleRule: instead */
@property (readonly, nonatomic) NSArray* rules;

/** 
 add a lifecycle rule to configuration
 @param rule lifecycle rule to add to configuration
 */
-(void) addLiveCycleRule:(AWSLifeCycleRule*)rule;
/** XML data for lifecycle configuration */
-(NSData*) siXMLData;

@end