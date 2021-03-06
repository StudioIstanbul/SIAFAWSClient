//
//  SIAFAWSClient.m
//  Cloud Backup Agent
//
//  Created by Andreas Zöllner on 20.07.15.
//  Copyright (c) 2015 Studio Istanbul Medya Hiz. Tic. Ltd. Sti. All rights reserved.
//

#import "AFHTTPRequestOperation.h"
#import "SIAFAWSClient.h"
#import "NSArray+listOfKeys.h"
#import "NSString+urlencode.h"
#import "CryptoHelper.h"
#import "NSData+hexConv.h"
#import "XMLDictionary.h"
#import "SSKeychain.h"
#import "XQueryComponents.h"
#import "../Base64/Base64/MF_Base64Additions.h"
#import "NSThread+Blocks.h"
#import "AFHTTPRequestOperationLogger.h"

#define SIAFAWSemptyHash @"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

typedef void(^AWSFailureBlock)(AFHTTPRequestOperation *operation, NSError *error);
typedef void(^AWSSuccessBlock)(AFHTTPRequestOperation *operation, id responseObject);
typedef void(^AWSCompBlock)(void);

@interface SIAFAWSClient () {
    BOOL keysFromKeychain;
}

@end

@interface AWSOperation ()
@property (nonatomic, strong) AWSSuccessBlock legacyCompletionBlock;

@end

@interface SIAFAWSClient () {
    NSDictionary* errorMessages;
}

@end

@implementation SIAFAWSClient
@synthesize secretKey = _secretKey, accessKey = _accessKey, bucket, delegate, syncWithKeychain, isBusy = _isBusy, lastErrorCode = _lastErrorCode, region = _region;

-(NSString*)host {
    return SIAFAWSRegionalBaseURL(self.region);
}

-(id)initWithBaseURL:(NSURL *)url {
    self = [super initWithBaseURL:url];
    [self setDefaultHeader:@"host" value:[self host]];
    syncWithKeychain = YES;
    keysFromKeychain = NO;
    for (NSDictionary* account in [SSKeychain accountsForService:@"Amazon Webservices S3 - SIAFAWS"]) {
        if ([[account valueForKey:kSSKeychainAccountKey] isEqualToString:@"Signing Key"]) {
            self.signingKey = [NSKeyedUnarchiver unarchiveObjectWithData:[SSKeychain passwordDataForService:@"Amazon Webservices S3 - SIAFAWS" account:[account valueForKey:kSSKeychainAccountKey]]];
        } else {
            //self.accessKey = [account valueForKey:kSSKeychainAccountKey];
            //self.secretKey = [SSKeychain passwordForService:@"Amazon Webservices S3 - SIAFAWS" account:[account valueForKey:kSSKeychainAccountKey]];
        }
        keysFromKeychain = YES;
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(checkFailure:) name:AFNetworkingOperationDidFinishNotification object:nil];
    [self.operationQueue setMaxConcurrentOperationCount:1];
    errorMessages = @{@"AccessDenied" :	NSLocalizedString(@"Access to the server resource has been denied. Please check your access key, security key and permissions on bucket and service via the Amazon AWS console on http://aws.amazon.com.", @"access denied AWS error"),
        @"AccountProblem": NSLocalizedString(@"There is a problem with your AWS account that prevents the operation from completing successfully. Please use Contact Amazon.", @"account problem AWS error"),
        @"AmbiguousGrantByEmailAddress": NSLocalizedString(@"The email address you provided is associated with more than one account.", @"AmbiguousGrantByEmailAddress AWS error"),
        @"BadDigest" : NSLocalizedString(@"The Content-MD5 you specified did not match what we received.", @"BadDigest AWS error"),
        @"BucketAlreadyExists" : NSLocalizedString(@"The requested bucket name is not available. The bucket namespace is shared by all users of the system. Please select a different name and try again.", @"BucketAlreadyExists AWS error"),
        @"BucketAlreadyOwnedByYou": NSLocalizedString(@"Your previous request to create the named bucket succeeded and you already own it. You get this error in all AWS regions except US East (N. Virginia) region, us-east-1. In us-east-1 region, you will get 200 OK, but it is no-op (if bucket exists it Amazon S3 will not do anything).", @"BucketAlreadyOwnedByYou AWS error"),
        @"BucketNotEmpty" :	NSLocalizedString(@"The bucket you tried to delete is not empty.", @"BucketNotEmpty AWS error"),
        @"CredentialsNotSupported": NSLocalizedString(@"This request does not support credentials.", @"CredentialsNotSupported AWS error"),
        @"CrossLocationLoggingProhibited" : NSLocalizedString(@"Cross-location logging not allowed. Buckets in one geographic location cannot log information to a bucket in another location.", @"CrossLocationLoggingProhibited"),
        @"EntityTooSmall" : NSLocalizedString(@"Your proposed upload is smaller than the minimum allowed object size.", @"EntityTooSmall AWS error"),
        @"EntityTooLarge": NSLocalizedString(@"Your proposed upload exceeds the maximum allowed object size.", @"EntityTooLarge aws error"),
        @"ExpiredToken" : NSLocalizedString(@"The provided token has expired.", @"ExpiredToken aws error"),
        @"IllegalVersioningConfigurationException": NSLocalizedString(@"Indicates that the versioning configuration specified in the request is invalid.", @"IllegalVersioningConfigurationException aws error"),
        @"IncompleteBody": NSLocalizedString(@"You did not provide the number of bytes specified by the Content-Length HTTP header.", @"IncompleteBody aws error"),
        @"IncorrectNumberOfFilesInPostRequest": NSLocalizedString(@"POST requires exactly one file upload per request.", @"IncorrectNumberOfFilesInPostRequest aws error"),
        @"InlineDataTooLarge": NSLocalizedString(@"Inline data exceeds the maximum allowed size.", @"InlineDataTooLarge aws error"),
        @"InternalError" : NSLocalizedString(@"AWS encountered an internal error. Please try again.", @"InternalError aws error"),
        @"InvalidAccessKeyId": NSLocalizedString(@"The AWS access key Id you provided does not exist in our records.", @"InvalidAccessKeyId aws error"),
        @"InvalidAddressingHeader": NSLocalizedString(@"You must specify the Anonymous role.", @"InvalidAddressingHeader aws error"),
        @"InvalidArgument": NSLocalizedString(@"Invalid Argument provided in bad request to AWS", @"InvalidArgument aws error"),
        @"InvalidBucketName": NSLocalizedString(@"The specified bucket is not valid.", @"InvalidBucketName aws error"),
        @"InvalidBucketState": NSLocalizedString(@"The request is not valid with the current state of the bucket.", @"InvalidBucketState aws error"),
        @"InvalidDigest": NSLocalizedString(@"The Content-MD5 you specified is not valid.", @"InvalidDigest aws error"),
        @"InvalidEncryptionAlgorithmError": NSLocalizedString(@"The encryption request you specified is not valid. The valid value is AES256.", @"InvalidEncryptionAlgorithmError aws error"),
        @"InvalidLocationConstraint": NSLocalizedString(@"The specified location constraint is not valid. For more information about regions, see How to Select a Region for Your Buckets.", @"InvalidLocationConstraint aws error"),
        @"InvalidObjectState": NSLocalizedString(@"The operation is not valid for the current state of the object.", @"InvalidObjectState aws error"),
        @"InvalidPart": NSLocalizedString(@"One or more of the specified parts could not be found. The part might not have been uploaded, or the specified entity tag might not have matched the part's entity tag.", @"InvalidPart aws error"),
        @"InvalidPartOrder": NSLocalizedString(@"The list of parts was not in ascending order. Parts list must specified in order by part number.", @"InvalidPartOrder aws error"),
        @"InvalidPayer": NSLocalizedString(@"All access to this object has been disabled.", @"InvalidPayer aws error"),
        @"InvalidPolicyDocument": NSLocalizedString(@"The content of the form does not meet the conditions specified in the policy document.", @"InvalidPolicyDocument aws error"),
        @"InvalidRange": NSLocalizedString(@"The requested range cannot be satisfied.", @"InvalidRange aws error"),
        @"InvalidRequest": NSLocalizedString(@"SOAP requests must be made over an HTTPS connection.", @"InvalidRequest aws error"),
        @"InvalidSecurity": NSLocalizedString(@"The provided security credentials are not valid.", @"InvalidSecurity aws error"),
        @"InvalidSOAPRequest": NSLocalizedString(@"The SOAP request body is invalid." , @"InvalidSOAPRequest aws error"),
        @"InvalidStorageClass": NSLocalizedString(@"The storage class you specified is not valid.", @"InvalidStorageClass aws error"),
        @"InvalidTargetBucketForLogging": NSLocalizedString(@"The target bucket for logging does not exist, is not owned by you, or does not have the appropriate grants for the log-delivery group.", @"InvalidTargetBucketForLogging aws error"),
        @"InvalidToken": NSLocalizedString(@"The provided token is malformed or otherwise invalid.", @"InvalidToken aws error"),
        @"InvalidURI": NSLocalizedString(@"Couldn't parse the specified URI.", @"InvalidURI aws error"),
        @"KeyTooLong": NSLocalizedString(@"Your key is too long.", @"KeyTooLong aws error"),
        @"MalformedACLError": NSLocalizedString(@"The XML you provided was not well-formed or did not validate against our published schema.", @"MalformedACLError"),
        @"MalformedPOSTRequest": NSLocalizedString(@"The body of your POST request is not well-formed multipart/form-data.", @"MalformedPOSTRequest aws error"),
        @"MalformedXML": NSLocalizedString(@"This happens when the user sends malformed xml (xml that doesn't conform to the published xsd) for the configuration. The error message is, \"The XML you provided was not well-formed or did not validate against our published schema.\".", @"MalformedXML aws error"),
        @"MaxMessageLengthExceeded": NSLocalizedString(@"Your request was too big.", @"MaxMessageLengthExceeded aws error"),
        @"MaxPostPreDataLengthExceededError": NSLocalizedString(@"Your POST request fields preceding the upload file were too large.", @"MaxPostPreDataLengthExceededError aws error"),
        @"MetadataTooLarge": NSLocalizedString(@"Your metadata headers exceed the maximum allowed metadata size.", @"MetadataTooLarge aws error"),
        @"MethodNotAllowed": NSLocalizedString(@"The specified method is not allowed against this resource.", @"MethodNotAllowed aws error"),
        @"MissingAttachment": NSLocalizedString(@"A SOAP attachment was expected, but none were found.", @"MissingAttachment aws error"),
        @"MissingContentLength": NSLocalizedString(@"You must provide the Content-Length HTTP header.", @"MissingContentLength aws error"),
        @"MissingRequestBodyError": NSLocalizedString(@"This happens when the user sends an empty xml document as a request. The error message is, \"Request body is empty.\".", @"MissingRequestBodyError aws error"),
        @"MissingSecurityElement": NSLocalizedString(@"The SOAP 1.1 request is missing a security element.", @"MissingSecurityElement aws error"),
        @"MissingSecurityHeader": NSLocalizedString(@"Your request is missing a required header.", @"MissingSecurityHeader aws error"),
        @"NoLoggingStatusForKey": NSLocalizedString(@"There is no such thing as a logging status subresource for a key.", @"NoLoggingStatusForKey"),
        @"NoSuchBucket": NSLocalizedString(@"The specified bucket does not exist.", @"NoSuchBucket aws error"),
        @"NoSuchKey": NSLocalizedString(@"The specified key does not exist.", @"NoSuchKey aws error"),
        @"NoSuchLifecycleConfiguration": NSLocalizedString(@"The lifecycle configuration does not exist.", @"NoSuchLifecycleConfiguration aws error"),
        @"NoSuchUpload": NSLocalizedString(@"The specified multipart upload does not exist. The upload ID might be invalid, or the multipart upload might have been aborted or completed.", @"NoSuchUpload aws error"),
        @"NoSuchVersion": NSLocalizedString(@"Indicates that the version ID specified in the request does not match an existing version.", @"NoSuchVersion aws error"),
        @"NotImplemented": NSLocalizedString(@"A header you provided implies functionality that is not implemented.", @"NotImplemented aws error"),
        @"NotSignedUp": NSLocalizedString(@"Your account is not signed up for the Amazon S3 service. You must sign up before you can use Amazon S3. You can sign up at the following URL: http://aws.amazon.com/s3", @"NotSignedUp aws error"),
        @"NoSuchBucketPolicy": NSLocalizedString(@"The specified bucket does not have a bucket policy.", @"NoSuchBucketPolicy aws error"),
        @"OperationAborted": NSLocalizedString(@"A conflicting conditional operation is currently in progress against this resource. Try again.", @"OperationAborted aws error"),
        @"PermanentRedirect": NSLocalizedString(@"The bucket you are attempting to access must be addressed using the specified endpoint. Send all future requests to this endpoint.", @"PermanentRedirect aws error"),
        @"PreconditionFailed": NSLocalizedString(@"At least one of the preconditions you specified did not hold.", @"PreconditionFailed aws error"),
        @"Redirect": NSLocalizedString(@"Temporary redirect.", @"Redirect aws error"),
        @"RestoreAlreadyInProgress": NSLocalizedString(@"Object restore is already in progress.", @"RestoreAlreadyInProgress aws error"),
        @"RequestIsNotMultiPartContent": NSLocalizedString(@"Bucket POST must be of the enclosure-type multipart/form-data.", @"RequestIsNotMultiPartContent aws error"),
        @"RequestTimeout": NSLocalizedString(@"Your socket connection to the server was not read from or written to within the timeout period.", @"RequestTimeout aws error"),
        @"RequestTimeTooSkewed": NSLocalizedString(@"The difference between the request time and the server's time is too large. Please check your Mac's time settings!", @"RequestTimeTooSkewed aws error"),
        @"RequestTorrentOfBucketError": NSLocalizedString(@"Requesting the torrent file of a bucket is not permitted.", @"RequestTorrentOfBucketError aws error"),
        @"SignatureDoesNotMatch": NSLocalizedString(@"The request signature AWS calculated does not match the signature you provided. Check your AWS secret access key and signing method.", @"SignatureDoesNotMatch aws error"),
        @"ServiceUnavailable": NSLocalizedString(@"Reduce your request rate.", @"ServiceUnavailable aws error"),
        @"SlowDown": NSLocalizedString(@"Reduce your request rate.", @"SlowDown aws error"),
        @"TemporaryRedirect": NSLocalizedString(@"You are being redirected to the bucket while DNS updates.", @"TemporaryRedirect aws error"),
        @"TokenRefreshRequired": NSLocalizedString(@"The provided token must be refreshed.", @"TokenRefreshRequired aws error"),
        @"TooManyBuckets": NSLocalizedString(@"You have attempted to create more buckets than allowed.", @"TooManyBuckets aws error"),
        @"UnexpectedContent": NSLocalizedString(@"This request does not support content.", @"UnexpectedContent aws error"),
        @"UnresolvableGrantByEmailAddress": NSLocalizedString(@"The email address you provided does not match any account on record.", @"UnresolvableGrantByEmailAddress aws error"),
                      @"UserKeyMustBeSpecified": NSLocalizedString(@"The bucket POST must contain the specified field name. If it is specified, check the order of the fields.", @"UserKeyMustBeSpecified aws error")};
#ifdef DEBUG
    [[AFHTTPRequestOperationLogger sharedLogger] setDelegate:self];
    [[AFHTTPRequestOperationLogger sharedLogger] startLogging];
    [[AFHTTPRequestOperationLogger sharedLogger] setLevel:AFLoggerLevelDebug];
#endif
    return self;
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark methods for S3 buckets

-(void)listBucket:(NSString *)bucketName {
    [self listBucket:bucketName withPreviuousContents:nil fromMarkerKey:nil];
}

-(void)listBucket:(NSString *)bucketName withPreviuousContents:(NSMutableArray*)xfileContents fromMarkerKey:(NSString*)markerKey {
    self.bucket = bucketName;
    NSMutableDictionary* operationParams = [NSMutableDictionary dictionaryWithObject:@"500" forKey:@"max-keys"];
    if (markerKey) [operationParams setValue:markerKey forKey:@"marker"];
    AWSOperation* listOperation = [self requestOperationWithMethod:@"GET" path:@"/" parameters:operationParams];
    __block NSMutableArray* fileContents = xfileContents;
    if (!fileContents) fileContents = [NSMutableArray new];
    [listOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary* responseDict = [NSDictionary dictionaryWithXMLData:responseObject];
        NSArray* contents;
        if ([[responseDict valueForKey:@"Contents"] isKindOfClass:[NSArray class]]) {
            contents = [responseDict valueForKey:@"Contents"];
        } else {
            if ([responseDict valueForKey:@"Contents"]) contents = [NSArray arrayWithObject:[responseDict valueForKey:@"Contents"]];
        }
        if (contents) {
            NSDateFormatter *rfc3339DateFormatter = [[NSDateFormatter alloc] init];
            NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            [rfc3339DateFormatter setLocale:enUSPOSIXLocale];
            [rfc3339DateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'.000Z'"];
            [rfc3339DateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
            for (NSDictionary* fileDict in contents) {
                AWSFile* newFile = [AWSFile new];
                newFile.bucket = [responseDict valueForKey:@"Name"];
                newFile.key = [fileDict valueForKey:@"Key"];
                newFile.etag = [fileDict valueForKey:@"ETag"];
                newFile.fileSize = [[fileDict valueForKey:@"Size"] integerValue];
                newFile.lastModified = [rfc3339DateFormatter dateFromString:[fileDict valueForKey:@"LastModified"]];
                newFile.storageClass = SIAFAWSStandard;
                if ([[fileDict valueForKey:@"StorageClass"] isEqualToString:@"GLACIER"]) newFile.storageClass = SIAFAWSGlacier;
                else if ([[fileDict valueForKey:@"StorageClass"] isEqualToString:@"REDUCED_REDUNDANCY"]) newFile.storageClass = SIAFAWSReducedRedundancy;
                [fileContents addObject:newFile];
            }
            if ([[responseDict valueForKey:@"IsTruncated"] isEqualToString:@"true"] && ![[responseDict valueForKey:@"Marker"] isEqualToString:((AWSFile*)fileContents.lastObject).key]) {
                [self listBucket:bucketName withPreviuousContents:fileContents fromMarkerKey:((AWSFile*)fileContents.lastObject).key];
            } else {
                if ([delegate respondsToSelector:@selector(awsclient:receivedBucketContentList:forBucket:)]) {
                    [delegate awsclient:self receivedBucketContentList:[fileContents sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"key" ascending:YES]]] forBucket:bucketName];
                }
            }
        }
        
    } failure:[self failureBlock]];
    __weak AFHTTPRequestOperation *weakOp = listOperation;
    [listOperation setRedirectResponseBlock:^NSURLRequest *(NSURLConnection *connection, NSURLRequest *request, NSURLResponse *redirectResponse) {
        if (nil == redirectResponse) {
            return request;
        }
        NSMutableURLRequest *r = [weakOp.request mutableCopy];
        [r setURL:request.URL];
        return r;
    }];
    [self enqueueHTTPRequestOperation:listOperation];
}

-(void)listBucketsWithAccessPermissionCheck:(BOOL)checkPermission {
    self.bucket = nil;
    AWSOperation* bucketListOperation = [self requestOperationWithMethod:@"GET" path:@"/" parameters:nil];
    [bucketListOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary* responseDict = [NSDictionary dictionaryWithXMLData:responseObject];
        NSMutableArray* bucketList = [NSMutableArray new];
        NSDateFormatter *rfc3339DateFormatter = [[NSDateFormatter alloc] init];
        NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        [rfc3339DateFormatter setLocale:enUSPOSIXLocale];
        [rfc3339DateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'.000Z'"];
        [rfc3339DateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
        for (NSDictionary* bucketDict in [[responseDict valueForKey:@"Buckets"] valueForKey:@"Bucket"]) {
            AWSBucket* myBucket = [[AWSBucket alloc] initWithName:[bucketDict valueForKey:@"Name"] andCreationDate:[rfc3339DateFormatter dateFromString:[bucketDict valueForKey:@"CreationDate"]]];
            NSString* baseUrl = operation.request.URL.host;
            if ([baseUrl rangeOfString:@".s3"].location != NSNotFound) {
                baseUrl = [baseUrl substringFromIndex:[baseUrl rangeOfString:@".s3"].location+1];
            }
            myBucket.region = SIAFAWSRegionForBaseURL(baseUrl);
            if (checkPermission) {
                myBucket.region = -1;
                [self checkBucket:myBucket forPermissionWithBlock:^(SIAFAWSAccessRight accessRight) {
                    if (accessRight == SIAFAWSFullControl || accessRight == SIAFAWSRead || accessRight == SIAFAWSWrite) [bucketList addObject:myBucket];
                    if ([self.delegate respondsToSelector:@selector(awsclient:receivedBucketList:)]) {
                        [self.delegate awsclient:self receivedBucketList:[NSArray arrayWithArray:bucketList]];
                    }
                }];
            } else {
                [self regionForBucket:myBucket];
                [bucketList addObject:myBucket];
            }
        }
        if ([self.delegate respondsToSelector:@selector(awsclient:receivedBucketList:)]) {
            [self.delegate awsclient:self receivedBucketList:[NSArray arrayWithArray:bucketList]];
        }
    } failure:[self failureBlock]];
    [self enqueueHTTPRequestOperation:bucketListOperation];
}

-(void)listBuckets {
    [self listBucketsWithAccessPermissionCheck:NO];
}

-(void)validateCredentials {
    self.bucket = nil;
    if (self.accessKey && self.secretKey && self.accessKey.length > 0 && self.secretKey.length > 0) {
        AWSOperation* bucketListOperation = [self requestOperationWithMethod:@"GET" path:@"/" parameters:nil];
        __weak AWSOperation* thisOperation = bucketListOperation;
        [bucketListOperation setCompletionBlock:^{
            BOOL valid = NO;
            if (thisOperation.error) {
                valid = NO;
            } else {
                valid = YES;
            }
            if ([self.delegate respondsToSelector:@selector(credentialsValid:)]) {
                [self.delegate credentialsValid:valid];
            }
        }];
        [self enqueueHTTPRequestOperation:bucketListOperation];
    } else {
        if ([self.delegate respondsToSelector:@selector(credentialsValid:)]) {
            [self.delegate credentialsValid:NO];
        }
    }
}

-(void)regionForBucket:(AWSBucket *)bucketObject {
    [self regionForBucket:bucketObject forPermissionWithBlock:nil];
}

-(void)regionForBucket:(AWSBucket *)bucketObject forPermissionWithBlock:(void(^)(SIAFAWSAccessRight accessRight))block {
    self.bucket = bucketObject.name;
    AWSOperation* regionOperation = [self requestOperationWithMethod:@"GET" path:@"/" parameters:nil];
    NSURLComponents* urlcomps = [NSURLComponents componentsWithURL:regionOperation.request.URL resolvingAgainstBaseURL:YES];
    [urlcomps setQuery:@"location"];
    [regionOperation.request setURL:[urlcomps URL]];
    [regionOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary* responseDict = [NSDictionary dictionaryWithXMLData:responseObject];
        NSString* regionString = [responseDict valueForKey:@"__text"];
        if (!regionString || regionString.length == 0) regionString = @"us-east-1";
        if ([regionString isEqualToString:@"EU"]) regionString = @"eu-west-1";
        bucketObject.region = SIAFAWSRegionForCode(regionString);
        NSLog(@"aws region for bucket %li %@", bucketObject.region, regionString);
        if (block) {
            [self checkBucket:bucketObject forPermissionWithBlock:block];
        }
    } failure:[self failureBlock]];
    [self enqueueHTTPRequestOperation:regionOperation];
}

-(void)checkBucket:(AWSBucket*)checkBucket forPermissionWithBlock:(void(^)(SIAFAWSAccessRight accessRight))block {
    self.bucket = checkBucket.name;
    if (checkBucket.region == -1) {
        [self regionForBucket:checkBucket forPermissionWithBlock:block];
    } else {
        self.region = checkBucket.region;
        AWSOperation* aclOperation = [self requestOperationWithMethod:@"HEAD" path:@"/" parameters:nil];
        [aclOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
            checkBucket.accessRight = SIAFAWSFullControl;
            NSString* baseUrl = operation.request.URL.host;
            if (baseUrl) {
                if ([baseUrl rangeOfString:@".s3"].location != NSNotFound) {
                    baseUrl = [baseUrl substringFromIndex:[baseUrl rangeOfString:@".s3"].location+1];
                }
                if ([baseUrl rangeOfString:@"/"].location != NSNotFound) {
                    baseUrl = [baseUrl substringToIndex:[baseUrl rangeOfString:@"/"].location];
                }
                checkBucket.region = (int) SIAFAWSRegionForBaseURL(baseUrl);
                if (checkBucket.region > 8) checkBucket.region = self.region;
            }
            block(SIAFAWSFullControl);
        } failure:^(AFHTTPRequestOperation* operation, NSError* err) {
            NSLog(@"AWS Error: %li - %@", operation.response.statusCode, err.localizedRecoverySuggestion);
            if (operation.response.statusCode == 403) {
                block(SIAFAWSAccessUndefined);
            } else {
                [self failureBlock](operation, err);
            }
        }];
        [self enqueueHTTPRequestOperation:aclOperation];
    }
}

-(void)uploadFileFromURL:(NSURL *)url toKey:(NSString *)key onBucket:(NSString *)bucketName {
    [self uploadFileFromURL:url toKey:key onBucket:bucketName withSSECKey:nil];
}

-(void)uploadFileFromURL:(NSURL *)url toKey:(NSString *)key onBucket:(NSString *)bucketName withSSECKey:(NSData *)ssecKey {
    [self uploadFileFromURL:url toKey:key onBucket:bucketName withSSECKey:ssecKey withStorageClass:SIAFAWSStandard andMetadata:nil];
}

-(void)uploadFileFromURL:(NSURL *)url toKey:(NSString *)key onBucket:(NSString *)bucketName withSSECKey:(NSData *)ssecKey withStorageClass:(SIAFAWSStorageClass)storageClass andMetadata:(NSDictionary *)metadata {
    key = [key urlencodeWithoutCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/+"]];
    self.bucket = bucketName;
    AWSOperation* uploadOperation = [self requestOperationWithMethod:@"PUT" path:key parameters:nil];
    [uploadOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        if ([self.delegate respondsToSelector:@selector(awsclient:finishedUploadForUrl:awsKey:)]) {
            [self.delegate awsclient:self finishedUploadForUrl:url awsKey:[key urldecode]];
        } else if ([self.delegate respondsToSelector:@selector(awsclient:finishedUploadForUrl:)]) {
            [self.delegate awsclient:self finishedUploadForUrl:url];
        }
    } failure:[self failureBlock]];
    NSData* data = [NSData dataWithContentsOfURL:url];
    uploadOperation.request.HTTPBody = data;
    [uploadOperation.request setValue:@"100-continue" forHTTPHeaderField:@"Expect"];
    [uploadOperation.request setValue:[NSString stringWithFormat:@"%li", data.length] forHTTPHeaderField:@"Content-Length"];
    if (storageClass == SIAFAWSGlacier) {
        NSLog(@"Error: Storage Class GLACIER not supported for file upload by AWS. Using STANDARD instead");
        storageClass = SIAFAWSStandard;
    }
    if (storageClass == SIAFAWSReducedRedundancy) [uploadOperation.request setValue:@"REDUCED_REDUNDANCY" forHTTPHeaderField:@"x-amz-storage-class"];
    if (metadata) {
        for (NSString* metadataKey in metadata.allKeys) {
            NSLog(@"metadata %@ = %@", metadataKey, [metadata valueForKey:metadataKey]);
            [uploadOperation.request setValue:[[metadata valueForKey:metadataKey] urlencode] forHTTPHeaderField:[NSString stringWithFormat:@"x-amz-meta-%@", [metadataKey urlencode]]];
        }
    }
    if (ssecKey) {
        NSLog(@"uploading encrypted!");
        [uploadOperation.request setValue:@"AES256" forHTTPHeaderField:@"x-amz-server-side-encryption-customer-algorithm"]; // x-amz-server-side​-encryption​-customer-algorithm
        [uploadOperation.request setValue:[ssecKey base64String] forHTTPHeaderField:@"x-amz-server-side-encryption-customer-key"]; //x-amz-server-side​-encryption​-customer-key
        [uploadOperation.request setValue:[CryptoHelper md5Base64StringFromData:ssecKey] forHTTPHeaderField:@"x-amz-server-side-encryption-customer-key-MD5"]; //x-amz-server-side​-encryption​-customer-key-MD5
    }
    [uploadOperation setUploadProgressBlock:^(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite) {
        if ([self.delegate respondsToSelector:@selector(uploadProgress:forURL:)]) [self.delegate uploadProgress:(double)totalBytesWritten/(double)totalBytesExpectedToWrite forURL:url];
    }];
    [self enqueueHTTPRequestOperation:uploadOperation];
}

-(void)metadataForKey:(NSString *)key onBucket:(NSString *)bucketName {
    [self metadataForKey:key onBucket:bucketName withSSECKey:nil];
}

-(void)metadataForKey:(NSString *)key onBucket:(NSString *)bucketName withSSECKey:(NSData *)ssecKey {
    self.bucket = bucketName;
    key = [key urlencodeWithoutCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/+"]];
    AWSOperation* metaDataOperation = [self requestOperationWithMethod:@"HEAD" path:key parameters:nil];
    if (ssecKey) {
        [metaDataOperation.request setValue:@"AES256" forHTTPHeaderField:@"x-amz-server-side-encryption-customer-algorithm"]; // x-amz-server-side​-encryption​-customer-algorithm
        [metaDataOperation.request setValue:[ssecKey base64String] forHTTPHeaderField:@"x-amz-server-side-encryption-customer-key"]; //x-amz-server-side​-encryption​-customer-key
        [metaDataOperation.request setValue:[CryptoHelper md5Base64StringFromData:ssecKey] forHTTPHeaderField:@"x-amz-server-side-encryption-customer-key-MD5"]; //x-amz-server-side​-encryption​-customer-key-MD5
    }
    [metaDataOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary* responseDict = operation.response.allHeaderFields;
        AWSFile* metadataFile = [AWSFile new];
        metadataFile.bucket = bucketName;
        metadataFile.key = key;
        metadataFile.etag = [responseDict valueForKey:@"ETag"];
        if ([metadataFile.etag rangeOfString:@"\""].location != NSNotFound) {
            metadataFile.etag = [metadataFile.etag substringWithRange:NSMakeRange(1, metadataFile.etag.length-2)];
        }
        metadataFile.fileSize = [[responseDict valueForKey:@"Content-Length"] integerValue];
        NSDateFormatter *rfc3339DateFormatter = [[NSDateFormatter alloc] init];
        NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        [rfc3339DateFormatter setLocale:enUSPOSIXLocale];
        [rfc3339DateFormatter setDateFormat:@"EEE', 'dd' 'MMM' 'yyyy' 'HH':'mm':'ss"];
        [rfc3339DateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
        metadataFile.lastModified = [rfc3339DateFormatter dateFromString:[responseDict valueForKey:@"Last-Modified"]];
        metadataFile.expirationDate = [rfc3339DateFormatter dateFromString:[[[responseDict valueForKey:@"x-amz-expiration"] componentsSeparatedByString:@"\""] objectAtIndex:1]];
        metadataFile.storageClass = SIAFAWSStandard;
        if ([[responseDict valueForKey:@"x-amz-storage-class"] isEqualToString:@"GLACIER"]) {
            metadataFile.storageClass = SIAFAWSGlacier;
            if ([responseDict valueForKey:@"x-amz-restore"]) {
                NSLog(@"restore info available");
                NSRegularExpression* operationRegex = [NSRegularExpression regularExpressionWithPattern:@"ongoing-request=\"(true|false)\"" options:0 error:nil];
                NSRange operationRange = [operationRegex rangeOfFirstMatchInString:[responseDict valueForKey:@"x-amz-restore"] options:0 range:NSMakeRange(0, [[responseDict valueForKey:@"x-amz-restore"] length])];
                NSString* operationString = [[responseDict valueForKey:@"x-amz-restore"] substringWithRange:operationRange];
                if ([operationString isEqualToString:@"true"]) {
                    NSLog(@"ongoing");
                    metadataFile.restoreInProgress = YES;
                    metadataFile.restoredKey = NO;
                } else {
                    NSLog(@"finished");
                    metadataFile.restoreInProgress = NO;
                    metadataFile.restoredKey = YES;
                }
            }
        } else if ([[responseDict valueForKey:@"x-amz-storage-class"] isEqualToString:@"REDUCED_REDUNDANCY"]) metadataFile.storageClass = SIAFAWSReducedRedundancy;
        NSMutableDictionary* metaDict = [NSMutableDictionary new];
        for (NSString* mkey in responseDict.allKeys) {
            if ([mkey rangeOfString:@"x-amz-meta-"].location == 0) {
                NSString* xmKey = [[mkey substringFromIndex:11] urldecode];
                [metaDict setValue:[[responseDict valueForKey:mkey] urldecode] forKey:xmKey];
            }
        }
        metadataFile.metadata = [NSDictionary dictionaryWithDictionary:metaDict];
        if ([self.delegate respondsToSelector:@selector(awsClient:receivedMetadata:forKey:onBucket:)]) [self.delegate awsClient:self receivedMetadata:metadataFile forKey:[key urldecode] onBucket:bucketName];
    } failure:[self failureBlock]];
    [self enqueueHTTPRequestOperation:metaDataOperation];
}

-(void)downloadFileFromKey:(NSString *)key onBucket:(NSString *)bucketName toURL:(NSURL *)fileURL {
    [self downloadFileFromKey:key onBucket:bucketName toURL:fileURL withSSECKey:nil];
}

-(void)downloadFileFromKey:(NSString *)key onBucket:(NSString *)bucketName toURL:(NSURL *)fileURL withSSECKey:(NSData *)ssecKey {
    self.bucket = bucketName;
    key = [key urlencodeWithoutCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/+"]];
    AWSOperation* downloadOperation = [self requestOperationWithMethod:@"GET" path:key parameters:nil];
    if (ssecKey) {
        [downloadOperation.request setValue:@"AES256" forHTTPHeaderField:@"x-amz-server-side-encryption-customer-algorithm"]; // x-amz-server-side​-encryption​-customer-algorithm
        [downloadOperation.request setValue:[ssecKey base64String] forHTTPHeaderField:@"x-amz-server-side-encryption-customer-key"]; //x-amz-server-side​-encryption​-customer-key
        [downloadOperation.request setValue:[CryptoHelper md5Base64StringFromData:ssecKey] forHTTPHeaderField:@"x-amz-server-side-encryption-customer-key-MD5"]; //x-amz-server-side​-encryption​-customer-key-MD5
    }
    [downloadOperation setDownloadProgressBlock:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
        if ([self.delegate respondsToSelector:@selector(downloadProgress:forKey:)]) {
            [self.delegate downloadProgress:(double)totalBytesRead/(double)totalBytesExpectedToRead forKey:[key urldecode]];
        }
    }];
    if (![[NSFileManager defaultManager] fileExistsAtPath:fileURL.path]) {
        [[NSFileManager defaultManager] createFileAtPath:fileURL.path contents:nil attributes:nil];
    }
    NSOutputStream* outputStream = [NSOutputStream outputStreamWithURL:fileURL append:NO];
    [downloadOperation setOutputStream:outputStream];
    [downloadOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        if ([self.delegate respondsToSelector:@selector(awsclient:finishedDownloadForKey:toURL:)]) [self.delegate awsclient:self finishedDownloadForKey:[key urldecode] toURL:fileURL];
    } failure:[self failureBlock]];
    [self enqueueHTTPRequestOperation:downloadOperation];
}

-(void)restoreFileFromKey:(NSString *)key onBucket:(NSString *)bucketName withExpiration:(NSTimeInterval)expiration {
    self.bucket = bucketName;
    key = [key urlencodeWithoutCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/+"]];
    AWSOperation* restoreOperation = [self requestOperationWithMethod:@"POST" path:key parameters:nil];
    [restoreOperation.request setURL:[NSURL URLWithString:@"?restore" relativeToURL:restoreOperation.request.URL]];
    NSMutableData* contentData = [NSMutableData new];
    NSDictionary* requestXML = @{@"RestoreRequest": @{@"Days": [NSString stringWithFormat:@"%0.0f", expiration/24/60/60]}};
    [contentData appendData:[[requestXML innerXML] dataUsingEncoding:NSUTF8StringEncoding]];
    restoreOperation.request.HTTPBody = contentData;
    [restoreOperation.request setValue:[CryptoHelper md5Base64StringFromData:contentData] forHTTPHeaderField:@"Content-MD5"];
    [restoreOperation.request setValue:[NSString stringWithFormat:@"%li", contentData.length] forHTTPHeaderField:@"Content-Length"];
    [restoreOperation.request setValue:@"application/xml" forHTTPHeaderField:@"Content-Type"];
    [restoreOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        if (operation.response.statusCode == 202) {
            NSLog(@"restore in progress");
        } else {
            if ([self.delegate respondsToSelector:@selector(awsClient:objectIsAvailableAtKey:onBucket:)]) [self.delegate awsClient:self objectIsAvailableAtKey:[key urldecode] onBucket:bucketName];
        }
    } failure:[self failureBlock]];
    [self enqueueHTTPRequestOperation:restoreOperation];
}

-(void)deleteKey:(NSString *)key onBucket:(NSString *)bucketName {
    self.bucket = bucketName;
    key = [key urlencodeWithoutCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/+"]];
    AWSOperation* deleteOperation = [self requestOperationWithMethod:@"DELETE" path:key parameters:nil];
    [deleteOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        if ([self.delegate respondsToSelector:@selector(awsClient:deletedKey:onBucket:)]) [self.delegate awsClient:self deletedKey:[key urldecode] onBucket:bucketName];
    } failure:[self failureBlock]];
    [self enqueueHTTPRequestOperation:deleteOperation];
}

-(void)setBucketLifecycle:(AWSLifeCycle *)awsLifecycle forBucket:(NSString *)bucketName {
    self.bucket = bucketName;
    if (awsLifecycle && awsLifecycle.rules.count > 0) {
        AWSOperation* lifeCycleOperation = [self requestOperationWithMethod:@"PUT" path:@"/" parameters:nil];
        [lifeCycleOperation.request setURL:[NSURL URLWithString:@"/?lifecycle" relativeToURL:lifeCycleOperation.request.URL]];
        NSData* lcData = awsLifecycle.siXMLData;
        if (lcData) {
            lifeCycleOperation.request.HTTPBody = lcData;
            [lifeCycleOperation.request setValue:[CryptoHelper md5Base64StringFromData:lcData] forHTTPHeaderField:@"Content-MD5"];
            [lifeCycleOperation.request setValue:[NSString stringWithFormat:@"%li", lcData.length] forHTTPHeaderField:@"Content-Length"];
            [lifeCycleOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
                if ([self.delegate respondsToSelector:@selector(awsClient:changedLifeCycleForBucket:)]) {
                    [self.delegate awsClient:self changedLifeCycleForBucket:bucketName];
                }
            } failure:[self failureBlock]];
            [self enqueueHTTPRequestOperation:lifeCycleOperation];
        } else {
            NSLog(@"no valid lifecycle data!");
        }
    } else {
        AWSOperation* lifeCycleOperation = [self requestOperationWithMethod:@"DELETE" path:@"/" parameters:nil];
        [lifeCycleOperation.request setURL:[NSURL URLWithString:@"/?lifecycle" relativeToURL:lifeCycleOperation.request.URL]];
        [lifeCycleOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
            if ([self.delegate respondsToSelector:@selector(awsClient:changedLifeCycleForBucket:)]) {
                [self.delegate awsClient:self changedLifeCycleForBucket:bucketName];
            }
        } failure:[self failureBlock]];
        [self enqueueHTTPRequestOperation:lifeCycleOperation];
    }
}

-(void)lifecycleRulesForBucket:(NSString *)bucketName {
    self.bucket = bucketName;
    AWSOperation* lifeCycleOperation = [self requestOperationWithMethod:@"GET" path:@"/" parameters:@{@"lifecycle": [NSNull null]}];
    [lifeCycleOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary* responseDict = [NSDictionary dictionaryWithXMLData:responseObject];
        AWSLifeCycle* lifeCycle = [[AWSLifeCycle alloc] init];
        NSArray* rules;
        if ([[responseDict valueForKey:@"Rule"] isKindOfClass:[NSArray class]]) rules = [responseDict valueForKey:@"Rule"]; else rules = @[[responseDict valueForKey:@"Rule"]];
        for (NSDictionary* rule in rules) {
            AWSLifeCycleRule* lcRule = [[AWSLifeCycleRule alloc] init];
            lcRule.ID = [rule valueForKey:@"ID"];
            lcRule.prefix = [rule valueForKey:@"Prefix"];
            if ([rule valueForKey:@"Transition"]) {
                lcRule.transitionInterval = [[[rule valueForKey:@"Transition"] valueForKey:@"Days"] integerValue] * 24 * 60 * 60;
            }
            if ([rule valueForKey:@"Expiration"]) {
                lcRule.exiprationInterval = [[[rule valueForKey:@"Expiration"] valueForKey:@"Days"] integerValue] * 24 * 60 * 60;
            }
            [lifeCycle addLiveCycleRule:lcRule];
        }
        if ([self.delegate respondsToSelector:@selector(awsClient:receivedLifecycleConfiguration:forBucket:)]) [self.delegate awsClient:self receivedLifecycleConfiguration:lifeCycle forBucket:bucketName];
    } failure:[self failureBlock]];
    [self enqueueHTTPRequestOperation:lifeCycleOperation];
}

-(void)createBucket:(NSString *)bucketName {
    SIAFAWSRegion bucketRegion = self.region;
    self.bucket = bucketName;
    self.region = SIAFAWSRegionUSStandard;
    AWSOperation* createBucketOperation = [self requestOperationWithMethod:@"PUT" path:@"/" parameters:nil];
    NSDictionary* requestXML = @{@"CreateBucketConfiguration": @{@"LocationConstraint": SIAFAWSRegion(bucketRegion)}};
    NSData* contentData = [[requestXML innerXML] dataUsingEncoding:NSUTF8StringEncoding];
    [createBucketOperation.request setHTTPBody:contentData];
    [createBucketOperation.request setValue:[NSString stringWithFormat:@"%li", contentData.length] forHTTPHeaderField:@"Content-Length"];
    [createBucketOperation.request setValue:@"application/xml" forHTTPHeaderField:@"Content-Type"];
    [createBucketOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        if ([self.delegate respondsToSelector:@selector(awsClient:successfullyCreatedBucket:)]) {
            [self.delegate awsClient:self successfullyCreatedBucket:bucketName];
        }
    } failure:[self failureBlock]];
    [self enqueueHTTPRequestOperation:createBucketOperation];
    self.region = bucketRegion;
}

#pragma mark setter methods for credentials
-(void)setAccessKey:(NSString *)accessKey {
    if (self.signingKey) {
        if (![accessKey isEqualToString:self.signingKey.accessKey]) {
            self.signingKey.keyDate = [NSDate distantPast];
        }
    }
    _accessKey = accessKey;
}

-(void)setRegion:(SIAFAWSRegion)region {
    if (region < 0 || region > SIAFAWSRegionCount) region = 0;
    if (self.signingKey) {
        if (region != self.signingKey.region) {
            self.signingKey.keyDate = [NSDate distantPast];
        }
    }
    _region = region;
}

#pragma mark Methods for signing according to AWS4

-(AWSOperation*)requestOperationWithMethod:(NSString*)method path:(NSString*)path parameters:(NSDictionary*)params {
    NSString* endpoint = @"";
    if (self.bucket) endpoint = [NSString stringWithFormat:@"%@.%@", self.bucket, SIAFAWSRegionalBaseURL(self.region)]; else endpoint = SIAFAWSRegionalBaseURL(self.region);
    return [self requestOperationWithMethod:method path:path parameters:params withEndpoint:endpoint];
}

-(AWSOperation*)requestOperationWithMethod:(NSString*)method path:(NSString*)path parameters:(NSDictionary*)params withEndpoint:(NSString*)endpoint {
    [self setDefaultHeader:@"host" value:endpoint];
    NSMutableURLRequest* request = [self requestWithMethod:method path:path parameters:params];
    NSString* pathString = [NSString stringWithFormat:@"https://%@%@", endpoint, path];
    if (request.URL.query) {
        pathString = [pathString stringByAppendingFormat:@"?%@", request.URL.query];
    }
    request.URL = [NSURL URLWithString:pathString];
    return [[AWSOperation alloc] initWithRequest:request];
}

-(AWSOperation*)requestMultipartOperationWithMethod:(NSString*)method path:(NSString*)path parameters:(NSDictionary*)params andConstructingBlock:(void(^)(id<AFMultipartFormData>formData))block {
    NSString* endpoint = @"";
    if (self.bucket) endpoint = [NSString stringWithFormat:@"%@.%@", self.bucket, SIAFAWSRegionalBaseURL(self.region)]; else endpoint = SIAFAWSRegionalBaseURL(self.region);
    return [self requestMultipartOperationWithMethod:method path:path parameters:params withEndpoint:endpoint andConstructingBlock:block];
}

-(AWSOperation*)requestMultipartOperationWithMethod:(NSString*)method path:(NSString*)path parameters:(NSDictionary*)params withEndpoint:(NSString*)endpoint andConstructingBlock:(void(^)(id<AFMultipartFormData>formData))block {
    NSMutableURLRequest* request = [self multipartFormRequestWithMethod:method path:path parameters:params constructingBodyWithBlock:block];
    NSString* pathString = [NSString stringWithFormat:@"https://%@%@", endpoint, path];
    if (request.URL.query) {
        pathString = [pathString stringByAppendingFormat:@"?%@", request.URL.query];
    }
    request.URL = [NSURL URLWithString:pathString];
    return [[AWSOperation alloc] initWithRequest:request];
}

-(NSString*)AuthorizationHeaderStringForRequest:(NSMutableURLRequest*)request {
    NSString* baseUrl = request.URL.host;
    SIAFAWSRegion requestRegion = self.region;
    if (baseUrl) {
        if ([baseUrl rangeOfString:@".s3"].location != NSNotFound) {
            baseUrl = [baseUrl substringFromIndex:[baseUrl rangeOfString:@".s3"].location+1];
        }
        if ([baseUrl rangeOfString:@"/"].location != NSNotFound) {
            baseUrl = [baseUrl substringToIndex:[baseUrl rangeOfString:@"/"].location];
        }
        //NSLog(@"base url %@ - region %@ (%li)", baseUrl, SIAFAWSRegionName(SIAFAWSRegionForBaseURL(baseUrl)),SIAFAWSRegionForBaseURL(baseUrl));
        requestRegion = (int) SIAFAWSRegionForBaseURL(baseUrl);
        if (requestRegion > 8) requestRegion = self.region;
    }
    NSDate* date = [NSDate date];
    NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyyMMdd"];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    NSDateFormatter* dateFormatter2 = [[NSDateFormatter alloc] init];
    [dateFormatter2 setDateFormat:@"yyyyMMdd'T'HHmmss'Z'"];
    [dateFormatter2 setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    [request setValue:[dateFormatter2 stringFromDate:date] forHTTPHeaderField:@"x-amz-date"];
    NSString* signature;
    NSString* resourceString = [[request URL] path];
    resourceString = [resourceString stringByReplacingOccurrencesOfString:@"+" withString:@" "];
    NSMutableCharacterSet* charset = [NSMutableCharacterSet whitespaceCharacterSet];
    [charset addCharactersInString:@"/"];
    resourceString = [resourceString urlencodeWithoutCharactersInSet:charset];
    resourceString = [resourceString stringByReplacingOccurrencesOfString:@" " withString:@"%20"];
    NSString* paramsString;
    NSDictionary* paramsDict = [request.URL queryComponents];
    NSMutableArray* params = [NSMutableArray new];
    for (NSString* key in [paramsDict.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]) {
        [params addObject:[NSString stringWithFormat:@"%@=%@", key, [paramsDict valueForKey:key]]];
    }
    paramsString = [params commaSeparatedURIEncodedListWithSeparatorString:@"&" andQuoteString:@"" andUnencodedCharacters:[NSCharacterSet characterSetWithCharactersInString:@"=&;"]];
    //paramsString = [paramsString stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
    NSString* headerString = [request.allHTTPHeaderFields sortedCommaSeparatedLowerCaseListWithSeparatorString:@"\n" andQuoteString:@"" andValueAssignmentString:@":"];
    NSData* sha = [CryptoHelper sha256:request.HTTPBody];
    NSString* shaHex = [sha hexadecimalString];
    NSString* canonicalRequestString = [NSString stringWithFormat:@"%@\n%@\n%@\n%@\n\n%@\n%@", request.HTTPMethod, resourceString, paramsString, headerString, [[request.allHTTPHeaderFields.allKeys sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)] commaSeparatedLowerCaseListWithSeparatorString:@";" andQuoteString:@""], shaHex];
    
    if (!self.signingKey || [self.signingKey.keyDate timeIntervalSinceNow] <= -(6*24*60*60) || self.signingKey.region != requestRegion) {
        if (!self.accessKey && !self.signingKey.accessKey) {
            if ([self.delegate respondsToSelector:@selector(awsclientRequiresAccessKey:)]) {
                self.accessKey = [self.delegate awsclientRequiresAccessKey:self];
            } else {
                NSError* accessKeyError = [NSError errorWithDomain:@"SIAFAWSClient" code:100 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"No access key provided for Amazon S3", @"SIAFAWSError no access key")}];
                if ([self.delegate respondsToSelector:@selector(awsClient:requestFailedWithError:)]) {
                    [self.delegate awsClient:self requestFailedWithError:accessKeyError];
                } else {
                    NSAlert* alert = [NSAlert alertWithError:accessKeyError];
                    [alert runModal];
                }
                return nil;
            }
        }
        if (!self.secretKey) {
            if ([self.delegate respondsToSelector:@selector(awsclientRequiresSecretKey:)]) {
                self.accessKey = [self.delegate awsclientRequiresSecretKey:self];
            } else {
                NSError* secretKeyError = [NSError errorWithDomain:@"SIAFAWSClient" code:101 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"No secret key provided for Amazon S3", @"SIAFAWSError no secret key")}];
                if ([self.delegate respondsToSelector:@selector(awsClient:requestFailedWithError:)]) {
                    [self.delegate awsClient:self requestFailedWithError:secretKeyError];
                } else {
                    NSAlert* alert = [NSAlert alertWithError:secretKeyError];
                    [alert runModal];
                }
                return nil;
            }
        }
        AWSSigningKey* newSigningKey = [self createSigningKeyForAccessKey:self.accessKey secretKey:self.secretKey andRegion:requestRegion];
        self.signingKey = newSigningKey;
        if (self.syncWithKeychain) [newSigningKey saveToKeychain];
    }
    
    NSString* scope = [NSString stringWithFormat:@"%@/%@/s3/aws4_request", [dateFormatter stringFromDate:self.signingKey.keyDate], SIAFAWSRegion(requestRegion)];
    NSString* stringToSign = [NSString stringWithFormat:@"AWS4-HMAC-SHA256\n%@\n%@\n%@", [dateFormatter2 stringFromDate:date], scope, [[CryptoHelper sha256:[canonicalRequestString dataUsingEncoding:NSASCIIStringEncoding]] hexadecimalString]];

    NSLog(@"canonical request: %@", canonicalRequestString);
    NSData* signatureData = [CryptoHelper hmac:stringToSign withDataKey:self.signingKey.key];
    signature = [signatureData hexadecimalString];
    NSString* sigString = [NSString stringWithFormat:@"AWS4-HMAC-SHA256 Credential=%@/%@/%@/s3/aws4_request,SignedHeaders=%@,Signature=%@", self.signingKey.accessKey, [dateFormatter stringFromDate:self.signingKey.keyDate], SIAFAWSRegion(requestRegion), [request.allHTTPHeaderFields.allKeys commaSeparatedLowerCaseListWithSeparatorString:@";" andQuoteString:@""], signature];
    NSLog(@"sigString: %@", sigString);
    return sigString;
}

-(AWSSigningKey*)createSigningKeyForAccessKey:(NSString *)accessKey secretKey:(NSString *)secretKey andRegion:(SIAFAWSRegion)region {
    if (region <= 8) {
        NSDate* date = [NSDate date];
        NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyyMMdd"];
        [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
        NSString* secStr = [NSString stringWithFormat:@"AWS4%@", secretKey];
        NSData* dateKey = [CryptoHelper hmac:[dateFormatter stringFromDate:date] withDataKey:[NSData dataWithBytes:[secStr cStringUsingEncoding:NSASCIIStringEncoding] length:secStr.length]];
        NSData* dateRegionKey = [CryptoHelper hmac:SIAFAWSRegion(region) withDataKey:dateKey];
        NSData* dateRegionServiceKey = [CryptoHelper hmac:@"s3" withDataKey:dateRegionKey];
        NSData* signingKey = [CryptoHelper hmac:@"aws4_request" withDataKey:dateRegionServiceKey];
        AWSSigningKey* newSigningKey = [[AWSSigningKey alloc] initWithKey:signingKey andDate:date];
        newSigningKey.region = region;
        newSigningKey.accessKey = accessKey;
        return newSigningKey;
    } else {
        NSLog(@"AWS Region not valid!");
    }
    return nil;
}

-(void)enqueueHTTPRequestOperation:(AWSOperation *)operation {
    _lastErrorCode = nil;
    NSMutableURLRequest* request = operation.request;
    [request setValue:[CryptoHelper sha256HexString:request.HTTPBody] forHTTPHeaderField:@"x-amz-content-sha256"];
    NSString* authHeader = [self AuthorizationHeaderStringForRequest:request];
    [request setValue:authHeader forHTTPHeaderField:@"Authorization"];
    operation.request = request;
    if (!_isBusy) {
        [self willChangeValueForKey:@"isBusy"];
        _isBusy = YES;
        [self didChangeValueForKey:@"isBusy"];
    }
    __block AWSCompBlock compBlock = [operation.completionBlock copy];
    __weak AWSOperation* thisOperation = operation;
    [operation setCompletionBlock:^{
        if (!compBlock) {
            NSLog(@"no completion block!");
        }
        if (self.callBackThread && !self.callBackThread.isFinished && !self.callBackThread.isCancelled && self.callBackThread.isExecuting) {
            [self.callBackThread performBlock:^{
                if (compBlock) compBlock();
            } waitUntilDone:NO];
        } else {
            if (compBlock) compBlock();
        }
        if (self.operationQueue.operationCount <= 0 || (self.operationQueue.operationCount == 1 && [self.operationQueue.operations objectAtIndex:0] == thisOperation)) {
            [self willChangeValueForKey:@"isBusy"];
            _isBusy = NO;
            [self didChangeValueForKey:@"isBusy"];
        }
    }];
    if (operation.willRedirect) {
        operation.isRedirected = YES;
        operation.willRedirect = NO;
    }
    if (self.accessKey && self.secretKey && self.accessKey.length > 0 && self.secretKey > 0) [super enqueueHTTPRequestOperation:operation]; else {
        if ([self.delegate respondsToSelector:@selector(awsClient:requestFailedWithError:)]) {
            NSError* keyError = [NSError errorWithDomain:@"siafawsclient" code:101 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Credentials missing", @"key error"), NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Your AWS access key and/or secret key are missing. Please provide these keys.", @"keys missing error")}];
            [self.delegate awsClient:self requestFailedWithError:keyError];
        }
    }
}

#pragma mark error handler methods

-(void)checkFailure:(NSNotification*)notification {
    AWSOperation *operation = (AWSOperation *)[notification object];

    if(![operation isKindOfClass:[AWSOperation class]]) {
        return;
    }
    BOOL switchRegion = NO;
    if (operation.error.localizedRecoverySuggestion) {
        NSDictionary* recoverDict = [NSDictionary dictionaryWithXMLString:operation.error.localizedRecoverySuggestion];
        _lastErrorCode = [recoverDict valueForKey:@"Code"];
        if ([recoverDict valueForKey:@"Region"]) {
            self.region = SIAFAWSRegionForCode([recoverDict valueForKey:@"Region"]);
            NSLog(@"switching region to %@ (%li)", [recoverDict valueForKey:@"Region"], self.region);
            switchRegion = YES;
        }
        NSLog(@"error code: %@", _lastErrorCode);
    }
        
    if((400 == [operation.response statusCode] && (([self.delegate respondsToSelector:@selector(awsclientRequiresKeyData:)] && [_lastErrorCode isEqualToString:@"UserKeyMustBeSpecified"]) || [_lastErrorCode isEqualToString:@"AuthorizationHeaderMalformed"])) || 301 == [operation.response statusCode]) {
        NSString* endpoint = operation.request.URL.host;
        NSData* keyData;
        if (301 == [operation.response statusCode] || switchRegion) {
            endpoint = SIAFAWSRegionalBaseURL(self.region);
            NSDictionary* recoverDict = [NSDictionary dictionaryWithXMLString:operation.error.localizedRecoverySuggestion];
            if ([recoverDict valueForKey:@"Endpoint"]) endpoint = [recoverDict valueForKey:@"Endpoint"];
            NSString* bucketName = [[operation.request.URL.host componentsSeparatedByString:@"."] objectAtIndex:0];
            if ([recoverDict valueForKey:@"Bucket"]) bucketName = [recoverDict valueForKey:@"Bucket"];
            NSString* baseUrl = [recoverDict valueForKey:@"Endpoint"];
            if ([baseUrl rangeOfString:@".s3"].location != NSNotFound) {
                baseUrl = [baseUrl substringFromIndex:[baseUrl rangeOfString:@".s3"].location+1];
            }
            SIAFAWSRegion newRegion = (int) SIAFAWSRegionForBaseURL(baseUrl);
            if (newRegion != self.region)  {
                self.region = newRegion;
            }
            if ([endpoint rangeOfString:@"s3"].location == 0) endpoint = [NSString stringWithFormat:@"%@.%@", bucketName, endpoint];
            NSLog(@"redirect to: %@", endpoint);
            operation.willRedirect = YES;
        }
        if ([operation.request valueForHTTPHeaderField:@"x-amz-server-side-encryption-customer-key"]) keyData = [self.delegate awsclientRequiresKeyData:self];
        AWSOperation* redirOp = [self requestOperationWithMethod:operation.request.HTTPMethod path:operation.request.URL.path parameters:[operation.request.URL.parameterString dictionaryFromQueryComponents] withEndpoint:endpoint];
        if ([operation.request.URL queryComponents].allKeys.count > 0) {
            NSMutableDictionary* queryDict = [operation.request.URL queryComponents];
            NSString* paramString = queryDict.allKeys.lastObject;
            NSLog(@"param found: %@", paramString);
            NSURLComponents* urlComps = [NSURLComponents componentsWithURL:redirOp.request.URL resolvingAgainstBaseURL:YES];
            [urlComps setQuery:paramString];
            [redirOp.request setURL:urlComps.URL];
        }
        if (keyData) {
            [redirOp.request setValue:@"AES256" forHTTPHeaderField:@"x-amz-server-side-encryption-customer-algorithm"]; // x-amz-server-side​-encryption​-customer-algorithm
            [redirOp.request setValue:[keyData base64String] forHTTPHeaderField:@"x-amz-server-side-encryption-customer-key"]; //x-amz-server-side​-encryption​-customer-key
            [redirOp.request setValue:[CryptoHelper md5Base64StringFromData:keyData] forHTTPHeaderField:@"x-amz-server-side-encryption-customer-key-MD5"]; //x-amz-server-side​-encryption​-customer-key-MD5
        }
        if (!operation.legacyCompletionBlock) NSLog(@"no completion block!");
        __block AWSSuccessBlock compBlock = [operation.legacyCompletionBlock copy];
        [redirOp setCompletionBlockWithSuccess:compBlock failure:[self failureBlock]];
        [operation setCompletionBlock:nil];
        [self enqueueHTTPRequestOperation:redirOp];
    }
    if (404 == [operation.response statusCode] && [self.delegate respondsToSelector:@selector(awsClient:deletedKey:onBucket:)] && [_lastErrorCode isEqualToString:@"NoSuchKey"]) {
        [self.delegate awsClient:self deletedKey:operation.request.URL.path onBucket:[[operation.request.URL.host componentsSeparatedByString:@"."] objectAtIndex:0]];
        [operation setCompletionBlock:nil];
    } else if (404 == [operation.response statusCode]  && [self.delegate respondsToSelector:@selector(awsClient:requestFailedWithError:)] && [_lastErrorCode isEqualToString:@"NoSuchBucket"]) {
        NSString* message = NSLocalizedString(@"Bucket does not exist!", @"bucket does not exist error message");
        NSString* desc = NSLocalizedString(@"The bucket you selected does not exist on Amazon AWS S3 anymore. Please recreate it or select a different bucket.", @"bucket error description");
        NSError* bucketError = [NSError errorWithDomain:@"siaws" code:operation.response.statusCode userInfo:@{NSLocalizedDescriptionKey: message, NSLocalizedRecoverySuggestionErrorKey: desc}];
        [self.delegate awsClient:self requestFailedWithError:bucketError];
        [operation setCompletionBlock:nil];
    }
}

-(AWSFailureBlock)failureBlock {
    AWSFailureBlock block = ^(AFHTTPRequestOperation *xoperation, NSError *error) {
        AWSOperation* operation = (AWSOperation*)xoperation;
        if (error.code != -999 && operation.response.statusCode != 301 && operation.response.statusCode != 404 && (!(operation.response.statusCode == 403) || [self.lastErrorCode isEqualToString:@"AccessDenied"])) {
            NSLog(@"error for URL %@ code: %li - %@ (%@)", operation.request.URL, operation.response.statusCode, error.localizedDescription, error.localizedRecoverySuggestion);
            if ([self.delegate respondsToSelector:@selector(awsClient:requestFailedWithError:)] && [[NSDictionary dictionaryWithXMLString:error.localizedRecoverySuggestion] valueForKey:@"Message"]) {
                if (!operation.willRedirect) {
                    NSString* statusCode = [[NSDictionary dictionaryWithXMLString:error.localizedRecoverySuggestion] valueForKey:@"Code"];
                    NSString* message = [errorMessages valueForKey:statusCode];
                    if (!message || message.length <= 0) message = [[NSDictionary dictionaryWithXMLString:error.localizedRecoverySuggestion] valueForKey:@"Message"];
                    NSError* awsError = [NSError errorWithDomain:@"siaws" code:operation.response.statusCode userInfo:@{NSLocalizedDescriptionKey: message}];
                    [self.delegate awsClient:self requestFailedWithError:awsError];
                }
            } else if ([self.delegate respondsToSelector:@selector(awsClient:requestFailedWithError:)] && operation.response.statusCode == 400) {
                if (!operation.willRedirect) {
                    NSError* awsError = [NSError errorWithDomain:@"siaws" code:operation.response.statusCode userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Bad request most possibly due to wrong encryption key.", @"wrong key message"), @"awsKey": [operation.request.URL.path urldecode], @"awsOperation": operation}];
                    [self.delegate awsClient:self requestFailedWithError:awsError];
                }
            } else if ([self.delegate respondsToSelector:@selector(awsClient:requestFailedWithError:)]) {
                if (!operation.willRedirect) {
                    [self.operationQueue cancelAllOperations];
                    [self.delegate awsClient:self requestFailedWithError:error];
                }
            }
        }
    };
    return block;
}

#pragma mark Logging
-(void)AFHTTPRequestOperationLoggerLog:(NSString *)logString {
    NSError *error;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"Authorization = \"AWS4-HMAC-SHA256 Credential=(.*/.*/.*)/s3/aws4_request,SignedHeaders=(.*),Signature=.*\"" options:NSRegularExpressionCaseInsensitive error:&error];
    NSRegularExpression *regex2 = [NSRegularExpression regularExpressionWithPattern:@"x-amz-server-side-encryption-customer-key = \".*\"" options:NSRegularExpressionCaseInsensitive error:&error];
    NSString *modifiedString = [regex stringByReplacingMatchesInString:logString options:0 range:NSMakeRange(0, [logString length]) withTemplate:@"Authorization = \"AWS4-HMAC-SHA256 Credential=$1/s3/aws4_request,SignedHeaders=$2,Signature=HIDDEN\""];
    modifiedString = [regex2 stringByReplacingMatchesInString:modifiedString options:0 range:NSMakeRange(0, modifiedString.length) withTemplate:@"x-amz-server-side-encryption-customer-key = \"HIDDEN\""];
#ifdef AZLogger
    [[AZLogger sharedLogger] log:modifiedString];
#else
    NSLog(@"%@", modifiedString);
#endif
}

@end

@implementation AWSOperation

@synthesize request, isRedirected, willRedirect;

-(id)init {
    self = [super init];
    if (self) {
        isRedirected = NO;
        willRedirect = NO;
    }
    return self;
}

/*-(void)setCompletionBlock:(void (^)(void))block {
    if (block) self.legacyCompletionBlock = [block copy];
    [super setCompletionBlock:block];
}*/

-(void)setCompletionBlockWithSuccess:(void (^)(AFHTTPRequestOperation *, id))success failure:(void (^)(AFHTTPRequestOperation *, NSError *))failure {
    self.legacyCompletionBlock = [success copy];
    [super setCompletionBlockWithSuccess:success failure:failure];
}

@end

@implementation AWSSigningKey
@synthesize key, keyDate, accessKey, region;

-(id)initWithKey:(NSData *)keyContent andDate:(NSDate *)creationDate {
    self = [self init];
    self.key = keyContent;
    self.keyDate = creationDate;
    return self;
}

-(void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.key forKey:@"key"];
    [aCoder encodeObject:self.keyDate forKey:@"keyDate"];
    [aCoder encodeInt:self.region forKey:@"region"];
    [aCoder encodeObject:self.accessKey forKey:@"accessKey"];
}

-(id)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self) {
        self.key = [aDecoder decodeObjectForKey:@"key"];
        self.keyDate = [aDecoder decodeObjectForKey:@"keyDate"];
        self.region = [aDecoder decodeIntForKey:@"region"];
        self.accessKey = [aDecoder decodeObjectForKey:@"accessKey"];
    }
    return self;
}

-(void)saveToKeychain {
    NSData* objectData = [NSKeyedArchiver archivedDataWithRootObject:self];
    [SSKeychain setPasswordData:objectData forService:@"Amazon Webservices S3 - SIAFAWS" account:@"Signing Key"];
}

@end

@implementation AWSBucket
@synthesize accessRight = _accessRight, name = _name, creationDate = _creationDate, region = _region, awsClient;

-(id)init {
    self = [super init];
    if (self) {
        _accessRight = SIAFAWSAccessUndefined;
        _creationDate = [NSDate date];
    }
    return self;
}

-(id)initWithName:(NSString*)name andCreationDate:(NSDate*)date {
    self = [super init];
    _creationDate = date;
    _name = name;
    return self;
}

-(SIAFAWSAccessRight)accessRight {
    if (_accessRight == SIAFAWSAccessUndefined && self.awsClient) {
        [self.awsClient checkBucket:self forPermissionWithBlock:nil];
    }
    return _accessRight;
}

-(NSString*)regionName {
    return SIAFAWSRegionName(self.region);
}

@end

@implementation AWSFile
@synthesize etag, key = _key, fileSize, lastModified, bucket, restoredKey = _restoredKey, restoreInProgress = _restoreInProgress, expirationDate;

-(id)init {
    self = [super init];
    if (self) {
        _restoreInProgress = NO;
        _restoredKey = NO;
    }
    return self;
}

-(void)setKey:(NSString *)key {
    if ([key rangeOfString:@"/"].location != 0) {
        _key = [NSString stringWithFormat:@"/%@", key];
    } else {
        _key = key;
    }
}

@end

@implementation AWSLifeCycle {
    NSMutableArray* _rules;
}

@synthesize rules;

-(id)init {
    self = [super init];
    if (self) {
        _rules = [NSMutableArray array];
    }
    return self;
}

-(NSArray*)rules {
    return [NSArray arrayWithArray:_rules];
}

-(void)addLiveCycleRule:(AWSLifeCycleRule *)rule {
    if (rule.exiprationInterval > 0 || rule.transitionInterval > 0) [_rules addObject:rule];
}

-(NSData*)siXMLData {
    NSMutableDictionary* valueDict = [NSMutableDictionary dictionary];
    NSMutableArray* valueArray = [NSMutableArray arrayWithCapacity:_rules.count];
    for (AWSLifeCycleRule* rule in _rules) {
        NSMutableDictionary* ruleDict = [NSMutableDictionary dictionary];
        NSMutableDictionary* ruleVals = [NSMutableDictionary dictionary];
        [ruleVals setValue:rule.ID forKey:@"ID"];
        [ruleVals setValue:rule.prefix forKey:@"Prefix"];
        [ruleVals setValue:@"Enabled" forKey:@"Status"];
        if (rule.transition) {
            NSLog(@"transition %f", rule.transitionInterval);
            [ruleVals setValue:@{@"Days": [NSString stringWithFormat:@"%0.0f", rule.transitionInterval / 24 / 60 / 60], @"StorageClass": @"GLACIER"} forKey:@"Transition"];
        }
        if (rule.expiration) {
            NSLog(@"exipration %f", rule.exiprationInterval);
            [ruleVals setValue:@{@"Days": [NSString stringWithFormat:@"%0.0f", rule.exiprationInterval / 24 / 60 / 60]} forKey:@"Expiration"];
            
        }
        [ruleDict setValue:ruleVals forKey:@"Rule"];
        [valueArray addObject:ruleDict];
    }
    [valueDict setValue:valueArray forKey:@"LifecycleConfiguration"];
    NSString* xmlString = [valueDict innerXML];

    NSData* xmlData = [xmlString dataUsingEncoding:NSUTF8StringEncoding];
    return xmlData;
}

@end

@implementation AWSLifeCycleRule

@synthesize ID, transition, transitionInterval = _transitionInterval, exiprationInterval = _exiprationInterval, prefix, expiration;

-(void)setExiprationInterval:(NSTimeInterval)exiprationInterval {
    self.expiration = YES;
    _exiprationInterval = exiprationInterval;
}

-(void)setTransitionInterval:(NSTimeInterval)transitionInterval {
    self.transition = YES;
    _transitionInterval = transitionInterval;
}

@end
