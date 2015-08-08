//
//  SIAFAWSClient.m
//  Cloud Backup Agent
//
//  Created by Andreas Zöllner on 20.07.15.
//  Copyright (c) 2015 Studio Istanbul Medya Hiz. Tic. Ltd. Sti. All rights reserved.
//

#import "SIAFAWSClient.h"
#import "NSArray+listOfKeys.h"
#import "AFHTTPRequestOperation.h"
#import "NSString+urlencode.h"
#import "CryptoHelper.h"
#import "NSData+hexConv.h"
#import "XMLDictionary.h"
#import "SSKeychain.h"
#import "XQueryComponents.h"
#import "../Base64/Base64/MF_Base64Additions.h"

#define SIAFAWSemptyHash @"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

typedef void(^AWSFailureBlock)(AFHTTPRequestOperation *operation, NSError *error);
typedef void(^AWSCompBlock)(void);

@interface SIAFAWSClient () {
    BOOL keysFromKeychain;
}

@end

@implementation SIAFAWSClient
@synthesize secretKey = _secretKey, accessKey = _accessKey, bucket, delegate, syncWithKeychain, isBusy = _isBusy;

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
    [self.operationQueue setMaxConcurrentOperationCount:1];
    return self;
}

#pragma mark methods for S3 buckets

-(void)listBucket:(NSString *)bucketName {
    self.bucket = bucketName;
    AWSOperation* listOperation = [self requestOperationWithMethod:@"GET" path:@"/" parameters:nil];
    [listOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary* responseDict = [NSDictionary dictionaryWithXMLData:responseObject];
        NSArray* contents;
        if ([[responseDict valueForKey:@"Contents"] isKindOfClass:[NSArray class]]) {
            contents = [responseDict valueForKey:@"Contents"];
        } else {
            contents = [NSArray arrayWithObject:[responseDict valueForKey:@"Contents"]];
        }
        if (contents) {
            NSDateFormatter *rfc3339DateFormatter = [[NSDateFormatter alloc] init];
            NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            [rfc3339DateFormatter setLocale:enUSPOSIXLocale];
            [rfc3339DateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'.000Z'"];
            [rfc3339DateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
            NSMutableArray* fileContents = [NSMutableArray new];
            for (NSDictionary* fileDict in contents) {
                AWSFile* newFile = [AWSFile new];
                newFile.bucket = [responseDict valueForKey:@"Name"];
                newFile.key = [fileDict valueForKey:@"Key"];
                newFile.etag = [fileDict valueForKey:@"ETag"];
                newFile.fileSize = [[fileDict valueForKey:@"Size"] integerValue];
                newFile.lastModified = [rfc3339DateFormatter dateFromString:[fileDict valueForKey:@"LastModified"]];
                [fileContents addObject:newFile];
            }
            if ([delegate respondsToSelector:@selector(awsclient:receivedBucketContentList:forBucket:)]) {
                [delegate awsclient:self receivedBucketContentList:[fileContents sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"key" ascending:YES]]] forBucket:bucketName];
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
                [self checkBucket:myBucket forPermissionWithBlock:^(SIAFAWSAccessRight accessRight) {
                    if (accessRight == SIAFAWSFullControl || accessRight == SIAFAWSRead || accessRight == SIAFAWSWrite) [bucketList addObject:myBucket];
                    if ([self.delegate respondsToSelector:@selector(awsclient:receivedBucketList:)]) {
                        [self.delegate awsclient:self receivedBucketList:[NSArray arrayWithArray:bucketList]];
                    }
                }];
            } else {
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

-(void)checkBucket:(AWSBucket*)checkBucket forPermissionWithBlock:(void(^)(SIAFAWSAccessRight accessRight))block {
    self.bucket = checkBucket.name;
    AWSOperation* aclOperation = [self requestOperationWithMethod:@"GET" path:@"/" parameters:@{@"acl":[NSNull null]}];
    [aclOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary* respDic = [NSDictionary dictionaryWithXMLData:responseObject];
        NSString* responseString = [[[respDic valueForKey:@"AccessControlList"] valueForKey:@"Grant"] valueForKey:@"Permission"];
        SIAFAWSAccessRight access = 0;
        if ([responseString isEqualToString:@"FULL_CONTROL"]) access = SIAFAWSFullControl;
        else if ([responseString isEqualToString:@"WRITE"]) access = SIAFAWSWrite;
        else if ([responseString isEqualToString:@"WRITE_ACP"]) access = SIAFAWSWriteACP;
        else if ([responseString isEqualToString:@"READ"]) access = SIAFAWSRead;
        else if ([responseString isEqualToString:@"READ_ACP"]) access = SIAFAWSReadACP;
        else access = SIAFAWSAccessUndefined;
        checkBucket.accessRight = access;
        block(access);
    } failure:[self failureBlock]];
    [self enqueueHTTPRequestOperation:aclOperation];
}

-(void)uploadFileFromURL:(NSURL *)url toKey:(NSString *)key onBucket:(NSString *)bucketName {
    [self uploadFileFromURL:url toKey:key onBucket:bucketName withSSECKey:nil];
}

-(void)uploadFileFromURL:(NSURL *)url toKey:(NSString *)key onBucket:(NSString *)bucketName withSSECKey:(NSData *)ssecKey {
    self.bucket = bucketName;
    AWSOperation* uploadOperation = [self requestOperationWithMethod:@"PUT" path:key parameters:nil];
    [uploadOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        if ([self.delegate respondsToSelector:@selector(awsclient:finishedUploadForUrl:)]) {
            [self.delegate awsclient:self finishedUploadForUrl:url];
        }
    } failure:[self failureBlock]];
    NSData* data = [NSData dataWithContentsOfURL:url];
    NSLog(@"uploading %li bytes", data.length);
    uploadOperation.request.HTTPBody = data;
    [uploadOperation.request setValue:[NSString stringWithFormat:@"%li", data.length] forHTTPHeaderField:@"Content-Length"];
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
    if ([baseUrl rangeOfString:@".s3"].location != NSNotFound) {
        baseUrl = [baseUrl substringFromIndex:[baseUrl rangeOfString:@".s3"].location+1];
    }
    SIAFAWSRegion requestRegion = (int) SIAFAWSRegionForBaseURL(baseUrl);
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
    NSString* paramsString;
    NSDictionary* paramsDict = [request.URL queryComponents];
    NSMutableArray* params = [NSMutableArray new];
    for (NSString* key in [paramsDict.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]) {
        [params addObject:[NSString stringWithFormat:@"%@=%@", key, [paramsDict valueForKey:key]]];
    }
    paramsString = [params commaSeparatedURIEncodedListWithSeparatorString:@"&" andQuoteString:@"" andUnencodedCharacters:[NSCharacterSet characterSetWithCharactersInString:@"="]];
    NSString* headerString = [request.allHTTPHeaderFields sortedCommaSeparatedLowerCaseListWithSeparatorString:@"\n" andQuoteString:@"" andValueAssignmentString:@":"];
    NSData* sha = [CryptoHelper sha256:request.HTTPBody];
    NSString* shaHex = [sha hexadecimalString];
    NSString* canonicalRequestString = [NSString stringWithFormat:@"%@\n%@\n%@\n%@\n\n%@\n%@", request.HTTPMethod, [resourceString urlencodeWithoutCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]], paramsString, headerString, [[request.allHTTPHeaderFields.allKeys sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)] commaSeparatedLowerCaseListWithSeparatorString:@";" andQuoteString:@""], shaHex];
    
    if (!self.signingKey || [self.signingKey.keyDate timeIntervalSinceNow] <= -(6*24*60*60) || self.signingKey.region != requestRegion) {
        NSLog(@"create new signing key");
        if (!self.accessKey && !self.signingKey.accessKey) {
            if ([self.delegate respondsToSelector:@selector(awsclientRequiresAccessKey:)]) {
                self.accessKey = [self.delegate awsclientRequiresAccessKey:self];
            } else {
                NSError* accessKeyError = [NSError errorWithDomain:@"SIAFAWSClient" code:100 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"No access key provided for Amazon S3", @"SIAFAWSError no access key")}];
                NSAlert* alert = [NSAlert alertWithError:accessKeyError];
                [alert runModal];
                return nil;
            }
        }
        if (!self.secretKey) {
            if ([self.delegate respondsToSelector:@selector(awsclientRequiresSecretKey:)]) {
                self.accessKey = [self.delegate awsclientRequiresSecretKey:self];
            } else {
                NSError* secretKeyError = [NSError errorWithDomain:@"SIAFAWSClient" code:101 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"No secret key provided for Amazon S3", @"SIAFAWSError no secret key")}];
                NSAlert* alert = [NSAlert alertWithError:secretKeyError];
                [alert runModal];
                return nil;
            }
        }
        NSString* secStr = [NSString stringWithFormat:@"AWS4%@", self.secretKey];
        NSData* dateKey = [CryptoHelper hmac:[dateFormatter stringFromDate:date] withDataKey:[NSData dataWithBytes:[secStr cStringUsingEncoding:NSASCIIStringEncoding] length:secStr.length]];
        NSData* dateRegionKey = [CryptoHelper hmac:SIAFAWSRegion(requestRegion) withDataKey:dateKey];
        NSData* dateRegionServiceKey = [CryptoHelper hmac:@"s3" withDataKey:dateRegionKey];
        NSData* signingKey = [CryptoHelper hmac:@"aws4_request" withDataKey:dateRegionServiceKey];
        AWSSigningKey* newSigningKey = [[AWSSigningKey alloc] initWithKey:signingKey andDate:date];
        self.signingKey = newSigningKey;
        newSigningKey.region = self.region;
        newSigningKey.accessKey = self.accessKey;
        if (self.syncWithKeychain) [newSigningKey saveToKeychain];
    }
    
    NSString* scope = [NSString stringWithFormat:@"%@/%@/s3/aws4_request", [dateFormatter stringFromDate:self.signingKey.keyDate], SIAFAWSRegion(requestRegion)];
    NSString* stringToSign = [NSString stringWithFormat:@"AWS4-HMAC-SHA256\n%@\n%@\n%@", [dateFormatter2 stringFromDate:date], scope, [[CryptoHelper sha256:[canonicalRequestString dataUsingEncoding:NSASCIIStringEncoding]] hexadecimalString]];

    
    NSData* signatureData = [CryptoHelper hmac:stringToSign withDataKey:self.signingKey.key];
    signature = [signatureData hexadecimalString];
    NSString* sigString = [NSString stringWithFormat:@"AWS4-HMAC-SHA256 Credential=%@/%@/%@/s3/aws4_request,SignedHeaders=%@,Signature=%@", self.signingKey.accessKey, [dateFormatter stringFromDate:self.signingKey.keyDate], SIAFAWSRegion(requestRegion), [request.allHTTPHeaderFields.allKeys commaSeparatedLowerCaseListWithSeparatorString:@";" andQuoteString:@""], signature];
    return sigString;
}

-(void)enqueueHTTPRequestOperation:(AWSOperation *)operation {
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
    [operation setCompletionBlock:^{
        if (compBlock) compBlock();
        if (self.operationQueue.operationCount <= 0) {
            [self willChangeValueForKey:@"isBusy"];
            _isBusy = NO;
            [self didChangeValueForKey:@"isBusy"];
        }
    }];
    [super enqueueHTTPRequestOperation:operation];
}

#pragma mark error handler methods

-(AWSFailureBlock)failureBlock {
    AWSFailureBlock block = ^(AFHTTPRequestOperation *operation, NSError *error) {
        if (error.code == -1011 && operation.response.statusCode == 301) {
            NSDictionary* recoverDict = [NSDictionary dictionaryWithXMLString:error.localizedRecoverySuggestion];
            if ([recoverDict valueForKey:@"Endpoint"]) {
                AWSOperation* redirOp = [self requestOperationWithMethod:operation.request.HTTPMethod path:operation.request.URL.path parameters:[operation.request.URL.parameterString dictionaryFromQueryComponents] withEndpoint:[recoverDict valueForKey:@"Endpoint"]];
                [redirOp setCompletionBlock:[operation completionBlock]];
                NSString* baseUrl = [recoverDict valueForKey:@"Endpoint"];
                if ([baseUrl rangeOfString:@".s3"].location != NSNotFound) {
                    baseUrl = [baseUrl substringFromIndex:[baseUrl rangeOfString:@".s3"].location+1];
                }
                SIAFAWSRegion newRegion = (int) SIAFAWSRegionForBaseURL(baseUrl);
                if (newRegion != self.region)  {
                    self.region = newRegion;
                }
                [self enqueueHTTPRequestOperation:redirOp];
            }
        } else {
            NSLog(@"error for URL %@ code: %li - %@ (%@)", operation.request.URL, operation.response.statusCode, error.localizedDescription, error.localizedRecoverySuggestion);
        }
    };
    return block;
}

@end

@implementation AWSOperation

@synthesize request;

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
@synthesize etag, key = _key, fileSize, lastModified, bucket;

-(void)setKey:(NSString *)key {
    if ([key rangeOfString:@"/"].location != 0) {
        _key = [NSString stringWithFormat:@"/%@", key];
    } else {
        _key = key;
    }
}

@end
