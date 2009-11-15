#import <Security/Security.h>
#import <string.h>
#import "Keychain.h"

// FIXME : report error to the Ruby side (rather than NSLog it)
//         This will require major change in the interface.

static const char server[] = "www.amazon.co.jp";

static inline NSUInteger len(NSString* str) {
  return [str lengthOfBytesUsingEncoding: NSUTF8StringEncoding];
}

static inline const char* cstr(NSString* str) {
  return [str UTF8String];
}

@implementation Keychain
- (Keychain*) init: (SecKeychainRef) kc {
  keychain = kc;
  return self;
}

- (Keychain*) initWithNewKeychain : (NSString*) path {
  OSErr result;
  result = SecKeychainCreate ([path UTF8String],
			      8, "1#$39da;", FALSE,
			      NULL,
			      &keychain);
  return self;
}

- (void) cleanup {
  if(keychain != 0) {
    SecKeychainDelete(keychain);
    CFRelease(keychain);
  }
}

- (void) addInternetPassword : (SecProtocolType) protocol Server:(NSString*) server Port: (UInt16) port Path: (NSString*) path Account: (NSString*) account Password: (NSString*) password {
  OSErr result;
  result = SecKeychainAddInternetPassword(keychain,
					  len(server), cstr(server),
					  0, "", // security domain
					  len(account), cstr(account),
					  len(path), cstr(path),
					  port, // port
					  protocol,
					  kSecAuthenticationTypeHTMLForm,
					  len(password), cstr(password),
					  NULL // itermRef
					  );
}

- (NSString*) getPassword : (NSString*) email {
  UInt32 passwordLength;
  char *password = NULL;
  OSErr result;

  id passwordNSS = NULL;

  if(email == NULL) {
    return NULL;
  }

  result = SecKeychainFindInternetPassword(keychain,
					   strlen(server), server,
					   0, NULL,
					   strlen([email UTF8String]), [email UTF8String],
					   0, "",
					   0,
					   kSecProtocolTypeHTTPS,
					   kSecAuthenticationTypeHTMLForm,
					   &passwordLength, (void**)&password,
					   NULL);
  //					   kSecAuthenticationTypeDefault,
  if (result != noErr) {
    NSLog(@"Error Code : %d", result);
    return NULL;
  } 
  passwordNSS = [[NSString alloc] initWithBytes: (const void*)password length: passwordLength encoding:NSASCIIStringEncoding];
  SecKeychainItemFreeContent(NULL, password);
  return passwordNSS;
}

// FIXME : cleanup code duplicate with getAccounts
- (void) setPassword : (NSString*) email Password: (NSString*) password {
  SecKeychainAttribute attributes[1];
  SecKeychainAttributeList list;
  OSErr result;
  SecKeychainSearchRef search;
  SecKeychainItemRef item;

  SecKeychainAttributeInfo attrInfo;
  UInt32 tag = kSecAccountItemAttr;
  SecKeychainAttributeList *list2 = NULL;
  NSString *buf;

  if(email == NULL || password == NULL) {
    return;
  }
  
  attributes[0].tag = kSecServerItemAttr;
  attributes[0].data = "www.amazon.co.jp";
  attributes[0].length = strlen(attributes[0].data);
  
  list.count = 1;
  list.attr = attributes;

  result = SecKeychainSearchCreateFromAttributes(keychain, kSecInternetPasswordItemClass, &list, &search);
  if(result != noErr) {
    NSLog(@"Error SecKeychainSearchCreateFromAttributes: %d", result);
    return;
  }

  attrInfo.count = 1;
  attrInfo.tag = &tag;
  attrInfo.format = NULL;

  while((result = SecKeychainSearchCopyNext(search, &item)) == noErr && &item) {
    result = SecKeychainItemCopyAttributesAndData(item, &attrInfo, NULL, &list2, NULL, NULL);
    if(result != noErr) {
      NSLog(@"Error SecKeychainSearchCreateFromAttributes: %d", result);
      return;
    }

    buf = [[NSString alloc] initWithBytes: (const void*)list2->attr[0].data 
			    length: list2->attr[0].length encoding:NSASCIIStringEncoding];
    SecKeychainItemFreeAttributesAndData(list2, NULL);
    if([email isEqualToString: buf]) {
      break;
    }
    CFRelease(item);
  }

  if(item == NULL) {
    NSLog(@"Error account was not found");
    return;
  }
  result = SecKeychainItemModifyContent(item, NULL, len(password), cstr(password));
  if(result != noErr) {
    NSLog(@"Error SecKeychainItemModifyContent: %d", result);
    return;
  }
  CFRelease(item);
  CFRelease(search);
}

- (NSArray*) getAccounts {
  SecKeychainAttribute attributes[1];
  SecKeychainAttributeList list;
  OSErr result;
  SecKeychainSearchRef search;
  SecKeychainItemRef item;

  SecKeychainAttributeInfo attrInfo;
  UInt32 tag = kSecAccountItemAttr;
  SecKeychainAttributeList *list2 = NULL;
  NSMutableArray *ary;
  NSString *buf;

  
  attributes[0].tag = kSecServerItemAttr;
  attributes[0].data = "www.amazon.co.jp";
  attributes[0].length = strlen(attributes[0].data);
  
  list.count = 1;
  list.attr = attributes;

  result = SecKeychainSearchCreateFromAttributes(keychain, kSecInternetPasswordItemClass, &list, &search);
  if(result != noErr) {
    NSLog(@"Error SecKeychainSearchCreateFromAttributes: %d", result);
    return NULL;
  }

  attrInfo.count = 1;
  attrInfo.tag = &tag;
  attrInfo.format = NULL;

  ary = [NSMutableArray arrayWithCapacity: 1];

  while((result = SecKeychainSearchCopyNext(search, &item)) == noErr && &item) {
    result = SecKeychainItemCopyAttributesAndData(item, &attrInfo, NULL, &list2, NULL, NULL);
    if(result != noErr) {
      NSLog(@"Error SecKeychainSearchCreateFromAttributes: %d", result);
      return NULL;
    }

    buf = [[NSString alloc] initWithBytes: (const void*)list2->attr[0].data 
			    length: list2->attr[0].length encoding:NSASCIIStringEncoding];
    [ary addObject: buf];
    SecKeychainItemFreeAttributesAndData(list2, NULL);
    CFRelease(item);
  }
  /*  err(result, "SecKeychainSearchCopyNext"); */

  CFRelease(search);
  return ary;
}
@end
