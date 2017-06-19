// Namespaced Header

#ifndef __NS_SYMBOL
// We need to have multiple levels of macros here so that __NAMESPACE_PREFIX_ is
// properly replaced by the time we concatenate the namespace prefix.
#define __NS_REWRITE(ns, symbol) ns ## _rewrite_ ## symbol
#define __NS_BRIDGE(ns, symbol) __NS_REWRITE(ns, symbol)
#define __NS_SYMBOL(symbol) __NS_BRIDGE(SIAFAWS, symbol)
#endif


// Classes
#ifndef AFHTTPBodyPart
#define AFHTTPBodyPart __NS_SYMBOL(AFHTTPBodyPart)
#endif

#ifndef AFHTTPClient
#define AFHTTPClient __NS_SYMBOL(AFHTTPClient)
#endif

#ifndef AFHTTPRequestOperation
#define AFHTTPRequestOperation __NS_SYMBOL(AFHTTPRequestOperation)
#endif

#ifndef AFImageRequestOperation
#define AFImageRequestOperation __NS_SYMBOL(AFImageRequestOperation)
#endif

#ifndef AFJSONRequestOperation
#define AFJSONRequestOperation __NS_SYMBOL(AFJSONRequestOperation)
#endif

#ifndef AFMultipartBodyStream
#define AFMultipartBodyStream __NS_SYMBOL(AFMultipartBodyStream)
#endif

#ifndef AFPropertyListRequestOperation
#define AFPropertyListRequestOperation __NS_SYMBOL(AFPropertyListRequestOperation)
#endif

#ifndef AFQueryStringPair
#define AFQueryStringPair __NS_SYMBOL(AFQueryStringPair)
#endif

#ifndef AFStreamingMultipartFormData
#define AFStreamingMultipartFormData __NS_SYMBOL(AFStreamingMultipartFormData)
#endif

#ifndef AFURLConnectionOperation
#define AFURLConnectionOperation __NS_SYMBOL(AFURLConnectionOperation)
#endif

#ifndef AFXMLRequestOperation
#define AFXMLRequestOperation __NS_SYMBOL(AFXMLRequestOperation)
#endif

#ifndef CryptoHelper
#define CryptoHelper __NS_SYMBOL(CryptoHelper)
#endif

#ifndef SSKeychain
#define SSKeychain __NS_SYMBOL(SSKeychain)
#endif

#ifndef XMLDictionaryParser
#define XMLDictionaryParser __NS_SYMBOL(XMLDictionaryParser)
#endif

// Functions
#ifndef AFQueryStringFromParametersWithEncoding
#define AFQueryStringFromParametersWithEncoding __NS_SYMBOL(AFQueryStringFromParametersWithEncoding)
#endif

#ifndef AFQueryStringPairsFromDictionary
#define AFQueryStringPairsFromDictionary __NS_SYMBOL(AFQueryStringPairsFromDictionary)
#endif

#ifndef AFQueryStringPairsFromKeyAndValue
#define AFQueryStringPairsFromKeyAndValue __NS_SYMBOL(AFQueryStringPairsFromKeyAndValue)
#endif

#ifndef AFContentTypesFromHTTPHeader
#define AFContentTypesFromHTTPHeader __NS_SYMBOL(AFContentTypesFromHTTPHeader)
#endif

// Externs
#ifndef kAFUploadStream3GSuggestedPacketSize
#define kAFUploadStream3GSuggestedPacketSize __NS_SYMBOL(kAFUploadStream3GSuggestedPacketSize)
#endif

#ifndef kAFUploadStream3GSuggestedDelay
#define kAFUploadStream3GSuggestedDelay __NS_SYMBOL(kAFUploadStream3GSuggestedDelay)
#endif

#ifndef kSSKeychainErrorDomain
#define kSSKeychainErrorDomain __NS_SYMBOL(kSSKeychainErrorDomain)
#endif

#ifndef kSSKeychainAccountKey
#define kSSKeychainAccountKey __NS_SYMBOL(kSSKeychainAccountKey)
#endif

#ifndef kSSKeychainCreatedAtKey
#define kSSKeychainCreatedAtKey __NS_SYMBOL(kSSKeychainCreatedAtKey)
#endif

#ifndef kSSKeychainClassKey
#define kSSKeychainClassKey __NS_SYMBOL(kSSKeychainClassKey)
#endif

#ifndef kSSKeychainDescriptionKey
#define kSSKeychainDescriptionKey __NS_SYMBOL(kSSKeychainDescriptionKey)
#endif

#ifndef kSSKeychainLabelKey
#define kSSKeychainLabelKey __NS_SYMBOL(kSSKeychainLabelKey)
#endif

#ifndef kSSKeychainLastModifiedKey
#define kSSKeychainLastModifiedKey __NS_SYMBOL(kSSKeychainLastModifiedKey)
#endif

#ifndef kSSKeychainWhereKey
#define kSSKeychainWhereKey __NS_SYMBOL(kSSKeychainWhereKey)
#endif

#ifndef AFNetworkingReachabilityDidChangeNotification
#define AFNetworkingReachabilityDidChangeNotification __NS_SYMBOL(AFNetworkingReachabilityDidChangeNotification)
#endif

#ifndef AFNetworkingReachabilityNotificationStatusItem
#define AFNetworkingReachabilityNotificationStatusItem __NS_SYMBOL(AFNetworkingReachabilityNotificationStatusItem)
#endif

#ifndef AFNetworkingErrorDomain
#define AFNetworkingErrorDomain __NS_SYMBOL(AFNetworkingErrorDomain)
#endif

#ifndef AFNetworkingOperationFailingURLRequestErrorKey
#define AFNetworkingOperationFailingURLRequestErrorKey __NS_SYMBOL(AFNetworkingOperationFailingURLRequestErrorKey)
#endif

#ifndef AFNetworkingOperationFailingURLResponseErrorKey
#define AFNetworkingOperationFailingURLResponseErrorKey __NS_SYMBOL(AFNetworkingOperationFailingURLResponseErrorKey)
#endif

#ifndef AFNetworkingOperationDidStartNotification
#define AFNetworkingOperationDidStartNotification __NS_SYMBOL(AFNetworkingOperationDidStartNotification)
#endif

#ifndef AFNetworkingOperationDidFinishNotification
#define AFNetworkingOperationDidFinishNotification __NS_SYMBOL(AFNetworkingOperationDidFinishNotification)
#endif

