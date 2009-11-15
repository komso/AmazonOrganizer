#import <Cocoa/Cocoa.h>


@interface Keychain : NSObject {
  SecKeychainRef keychain;
}
- (Keychain*) init: (SecKeychainRef) kc;
- (Keychain*) initWithNewKeychain: (NSString *) path;
- (void) cleanup;

- (void) addInternetPassword : (SecProtocolType) protocol Server:(NSString*) server Port: (UInt16) port Path: (NSString*) path Account: (NSString*) account Password: (NSString*) password;

- (NSString*) getPassword : (NSString*) email;
- (NSArray*) getAccounts;
- (void) setPassword : (NSString*) email Password: (NSString*) password;

@end
