SIAFAWSClient
=============

Client for Amazon AWS S3 based on AFNetworking. This class uses Amazon AWS Signature Version 4 for authentication purposes.

## Init

Init a new client with or without base URL. If no valid URL is provided URL is detected automatically based on selected region.

    _awsClient = [[SIAFAWSClient alloc] initWithBaseURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://%@", SIAFAWSRegionalBaseURL(SIAFAWSRegionEUFrankfurt)]]];
    _awsClient.delegate = self;
    
## Set credentials

Set credentials by setting the properties:

    _awsClient.accessKey = @"USER_ACCESSKEY";
    _awsClient.secretKey = @"USER_SECRETKEY";
    
## Fetch bucket list

To fetch a list of available buckets for the provided user just call:

    [_awsClient listBuckets];
    
If request is accepted by server your delegates
   
    -(void)awsclient:(SIAFAWSClient *)client receivedBucketList:(NSArray *)buckets
   
method will be called.

## Fetch keys for bucket

To fetch a list of keys stored in a bucket call

    [_awsClient listBucket:@"MY_BUCKET"];

If request is accepted your delegates

    -(void)awsclient:(SIAFAWSClient *)client receivedBucketContentList:(NSArray *)bucketContents forBucket:(NSString *)bucketName
    
method will be called providing a NSArray of AWSFile objects containing metadata. Please make sure to call

    [_awsClient metadataForKey:@"/AWSKEY" onBucket:@"MY_BUCKET" withSSECKey:nil];

to update file metadata if some data needed is missing as some information is not fetched during listing of available keys. If file is encrypted, make sure to include AES256 key as NSData object.

## Upload file

For uploading a local file just call

    [_awsClient uploadFileFromURL:[NSURL fileURLWithPath:@"/path/to/my/file"] toKey:@"/keyNameOnS3" onBucket:@"MY_BUCKET" withSSECKey:nil withStorageClass:SIAFAWSStandard andMetadata:nil];

If file shall be encrypted make sure to include AES256 key as NSData. Encryption will be performed on server side by Amazon AWS S3. You can choose between two different storage classes __SIAFAWSStandard__ and __SIAFAWSReducedRedundancy__ which will affect pricing for AWS S3 service. Upload to Glacier is not supported by Amazon, please use bucket life cycle in order to support Glacier.

The following methods on your delegate will be called:

    -(void)uploadProgress:(double)progress forURL:(NSURL*)localFileUrl; // continuously updates file upload progress
    
    -(void)awsclient:(SIAFAWSClient *)client finishedUploadForUrl:(NSURL*)localURL; // upload is finished

## Download file

To download a file you should call

    [_awsClient downloadFileFromKey:@"/myKeyOnS3" onBucket:@"MY_BUCKET" toURL:localURL nil];
    
If file has been encrypted on upload make sure to include AES256 key as NSData. Decryption will be performed on server side by Amazon AWS S3.

The following methods on your delegate will be called:

    -(void)downloadProgress:(double)progress forKey:(NSString*)key; // continuously updates file download progress

    -(void)awsclient:(SIAFAWSClient *)client finishedDownloadForKey:(NSString*)key toURL:(NSURL *)localURL  // download is finished

## Delete file

To delete a file call
    
    [_awsClient deleteKey:@"/myKeyOnS3" onBucket:@"MY_BUCKET"];

If versioning is not enabled on your bucket, deletion will be permanent.

## Restore file

If a file is currently only stored on Glacier due to life cycle configuration of your bucket you can restore it by calling

    SIAWSFile* myFile = // some AWSFile object returned by requesting metadata
    if (myFile.storageClass == SIAFAWSGlacier) { // make sure file is really on Glacier
        [_awsClient restoreFileFromKey:myFile.awsKey onBucket:myFile.awsBucket withExpiration:10*60*60*24]; // restore for 10 days
    }

The following delegates will be called, if file is already available:

    -(void)awsClient:(SIAFAWSClient*)client objectIsAvailableAtKey:(NSString*)key onBucket:(NSString*)bucket // object is available due to an earlier restore request

## Bucket life cycle

You can set a bucket lifecycle configuration by creating the according __AWSLifeCycle__ and __AWSLifeCycleRule__ objects and uploading them. This will overwrite any existing life cycle configuration for this bucket!

Example:

    AWSLifeCycle* lc = [AWSLifeCycle new];
    AWSLifeCycleRule* lcRule = [AWSLifeCycleRule new];
    lcRule.ID = @"myLifeCycleRuleID"; // ID required by AWS S3
    lcRule.prefix = @"";  // valid for all files
    lcRule.transitionInterval =  10*60*60*24; // transfer to Glacier after 10 days
    lcRule.exiprationInterval = 20*60*60*24; // delete after 20 days
    [lc addLiveCycleRule:lcRule]; // add rule to configuration
    [_awsClient setBucketLifecycle:lc forBucket:@"MY_BUCKET"]; // upload configuration
    
You can also read the current life cycle configuration by requesting it:

    [_awsClient lifecycleRulesForBucket:@"MY_BUCKET"];
    
The according delegate methods will be called when requests are successfull:

    -(void)awsClient:(SIAFAWSClient*)client receivedLifecycleConfiguration:(AWSLifeCycle*)lifeCycleConfiguration forBucket:(NSString*)bucketName; // life cycle configuration received
    
    -(void)awsClient:(SIAFAWSClient*)client changedLifeCycleForBucket:(NSString*)bucket; // life cycle configuration uploaded

## Error handling

Some parts of error handling are performed automatically. If any non-fixable error occurs your delegate method will be called:

    -(void)awsClient:(SIAFAWSClient*)client requestFailedWithError:(NSError*)error;
    
You can use the provided NSError object to get more information about the error or get an Error string from .lastErrorCode property. See Amazon AWS S3 Error codes for valid codes.

## Create bucket

You can also create a new bucket:

    [_awsClient createBucket:@"NEW_BUCKET"];
    
Make sure your bucket name is valid according to Amazon AWS S3 bucket name rules.

## Encryption

Server Side Encryption with Custom Key (SSEC) is supported by upload and download functions of this class. You have to supply a valid AES256 key on upload, download or metadata request if a key is encrypted.

## Signing key

This class supports connecting to S3 without supplying the user's secret key. You can also supply a valid AWS signing key to connect. Signing keys are valid for 7 days and bound to a specific service region. Signing keys have to be created using this classes helper functions but is created automatically if both access key and secret key are provided.

	NSData* signingKey = [_awsClient createSigningKeyForAccessKey:@"ACCESS_KEY" secretKey:@"SECRET_KEY" andRegion:SIAFAWSRegionStandard]; // create a valid signing key
    [_awsClient setSigningKey:signingKey];

See http://docs.aws.amazon.com/AmazonS3/latest/API/sig-v4-authenticating-requests.html#signing-request-intro for more information on signing keys.

## Documentation

Please see __/docs__ folder or header files for more information on functions and properties.

## License

__Apache License 2.0__ - Feel free to use this class in your own commercial or non-commercial projects. No attribution required but appreciated. Please share your changes or additions by filing a pull-request on github.

See LICENSE file for details.