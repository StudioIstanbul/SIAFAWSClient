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

#define SIAFAWSemptyHash @"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

@interface SIAFAWSClient () {
    BOOL keysFromKeychain;
}

@end

@implementation SIAFAWSClient
@synthesize secretKey, accessKey, bucket, delegate, syncWithKeychain;

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
            NSLog(@"imported signing key");
        } else {
            self.accessKey = [account valueForKey:kSSKeychainAccountKey];
            self.secretKey = [SSKeychain passwordForService:@"Amazon Webservices S3 - SIAFAWS" account:[account valueForKey:kSSKeychainAccountKey]];
        }
    }
    return self;
}

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
        if ([delegate respondsToSelector:@selector(awsclient:receivedBucketContentList:forBucket:)]) {
            [delegate awsclient:self receivedBucketContentList:contents forBucket:self.bucket];
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"error code: %li - %@ (%@)", error.code, error.localizedDescription, error.localizedRecoverySuggestion);
        if (error.code == -1011) {
            NSDictionary* recoverDict = [NSDictionary dictionaryWithXMLString:error.localizedRecoverySuggestion];
            if ([recoverDict valueForKey:@"Endpoint"]) {
                NSLog(@"redirect to endpoint %@", [recoverDict valueForKey:@"Endpoint"]);
                self.baseURL = [NSURL URLWithString:[recoverDict valueForKey:@"Endpoint"]];
            }
        } else {
        }
    }];
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

-(AWSOperation*)requestOperationWithMethod:(NSString*)method path:(NSString*)path parameters:(NSDictionary*)params {
    [self setDefaultHeader:@"host" value:[NSString stringWithFormat:@"%@.%@", self.bucket, SIAFAWSRegionalBaseURL(self.region)]];
    NSMutableURLRequest* request = [self requestWithMethod:method path:path parameters:params];
    request.URL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@.%@%@", self.bucket, SIAFAWSRegionalBaseURL(self.region), path]];
    return [[AWSOperation alloc] initWithRequest:request];
}

-(NSString*)AuthorizationHeaderStringForRequest:(NSMutableURLRequest*)request {;
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
    if ([[[request URL] absoluteString] rangeOfString:@"?"].location != NSNotFound) paramsString = [[[request URL] absoluteString] substringFromIndex:[[[request URL] absoluteString] rangeOfString:@"?"].location+1]; else paramsString = @"";
    NSArray* params = [paramsString componentsSeparatedByString:@"&"];
    params = [params sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    paramsString = [params commaSeparatedURIEncodedListWithSeparatorString:@"&" andQuoteString:@"" andUnencodedCharacters:[NSCharacterSet characterSetWithCharactersInString:@"="]];
    NSString* headerString = [request.allHTTPHeaderFields sortedCommaSeparatedLowerCaseListWithSeparatorString:@"\n" andQuoteString:@"" andValueAssignmentString:@":"];
    NSData* sha = [CryptoHelper sha256:request.HTTPBody];
    NSString* shaHex = [sha hexadecimalString];
    NSString* canonicalRequestString = [NSString stringWithFormat:@"%@\n%@\n%@\n%@\n\n%@\n%@", request.HTTPMethod, [resourceString urlencodeWithoutCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]], paramsString, headerString, [[request.allHTTPHeaderFields.allKeys sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)] commaSeparatedLowerCaseListWithSeparatorString:@";" andQuoteString:@""], shaHex];
    NSString* scope = [NSString stringWithFormat:@"%@/%@/s3/aws4_request", [dateFormatter stringFromDate:date], SIAFAWSRegion(self.region)];
    NSString* stringToSign = [NSString stringWithFormat:@"AWS4-HMAC-SHA256\n%@\n%@\n%@", [dateFormatter2 stringFromDate:date], scope, [[CryptoHelper sha256:[canonicalRequestString dataUsingEncoding:NSASCIIStringEncoding]] hexadecimalString]];
    
    if (!self.signingKey || [self.signingKey.keyDate timeIntervalSinceNow] <= -(6*24*60*60)) {
        NSString* secStr = [NSString stringWithFormat:@"AWS4%@", self.secretKey];
        NSData* dateKey = [CryptoHelper hmac:[dateFormatter stringFromDate:date] withDataKey:[NSData dataWithBytes:[secStr cStringUsingEncoding:NSASCIIStringEncoding] length:secStr.length]];
        NSData* dateRegionKey = [CryptoHelper hmac:SIAFAWSRegion(self.region) withDataKey:dateKey];
        NSData* dateRegionServiceKey = [CryptoHelper hmac:@"s3" withDataKey:dateRegionKey];
        NSData* signingKey = [CryptoHelper hmac:@"aws4_request" withDataKey:dateRegionServiceKey];
        AWSSigningKey* newSigningKey = [[AWSSigningKey alloc] initWithKey:signingKey andDate:date];
        self.signingKey = newSigningKey;
        if (self.syncWithKeychain) [newSigningKey saveToKeychain];
    }
    
    NSData* signatureData = [CryptoHelper hmac:stringToSign withDataKey:self.signingKey.key];
    signature = [signatureData hexadecimalString];
    NSString* sigString = [NSString stringWithFormat:@"AWS4-HMAC-SHA256 Credential=%@/%@/%@/s3/aws4_request,SignedHeaders=%@,Signature=%@", self.accessKey, [dateFormatter stringFromDate:self.signingKey.keyDate], SIAFAWSRegion(self.region), [request.allHTTPHeaderFields.allKeys commaSeparatedLowerCaseListWithSeparatorString:@";" andQuoteString:@""], signature];
    return sigString;
}

-(void)enqueueHTTPRequestOperation:(AWSOperation *)operation {
    NSMutableURLRequest* request = [operation.request mutableCopy];
    [request setValue:SIAFAWSemptyHash forHTTPHeaderField:@"x-amz-content-sha256"];
    NSString* authHeader = [self AuthorizationHeaderStringForRequest:request];
    [request setValue:authHeader forHTTPHeaderField:@"Authorization"];
    operation.request = request;
    [super enqueueHTTPRequestOperation:operation];
}

@end

@implementation AWSOperation

@synthesize request;

@end

@implementation AWSSigningKey
@synthesize key, keyDate;

-(id)initWithKey:(NSData *)keyContent andDate:(NSDate *)creationDate {
    self = [self init];
    self.key = keyContent;
    self.keyDate = creationDate;
    return self;
}

-(void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.key forKey:@"key"];
    [aCoder encodeObject:self.keyDate forKey:@"keyDate"];
}

-(id)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self) {
        self.key = [aDecoder decodeObjectForKey:@"key"];
        self.keyDate = [aDecoder decodeObjectForKey:@"keyDate"];
    }
    return self;
}

-(void)saveToKeychain {
    NSData* objectData = [NSKeyedArchiver archivedDataWithRootObject:self];
    [SSKeychain setPasswordData:objectData forService:@"Amazon Webservices S3 - SIAFAWS" account:@"Signing Key"];
}

@end
