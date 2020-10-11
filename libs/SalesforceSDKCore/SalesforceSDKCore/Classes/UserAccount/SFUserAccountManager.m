/*
 Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.

 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
#import "SFUserAccountManager+Internal.h"
#import "SFUserAccount+Internal.h"
#import "SFIdentityData+Internal.h"
#import "SFDefaultUserAccountPersister.h"
#import "SFOAuthCredentials+Internal.h"
#import "SFSDKAuthPreferences.h"
#import "SFSDKURLHandlerManager.h"
#import "SFSDKIDPConstants.h"
#import "SFSDKAuthRequest.h"
#import "SFOAuthCoordinator+Internal.h"
#import "SFIdentityCoordinator+Internal.h"
#import <SalesforceSDKCommon/NSUserDefaults+SFAdditions.h>
#import <SalesforceSDKCommon/SFSDKDatasharingHelper.h>
#import "SFSDKAuthRootController.h"
#import "SFSDKWindowContainer.h"
#import "SFSDKIDPAuthHelper.h"
#import "SFSDKLoginFlowSelectionViewController.h"
#import "SFSDKUserSelectionNavViewController.h"
#import "SFRestAPI+Blocks.h"
#import "NSString+SFAdditions.h"
#import "SFSDKAppFeatureMarkers.h"
#import "SFSDKWebViewStateManager.h"
#import "SFSDKWindowManager.h"
#import "SFPushNotificationManager.h"
#import "SFSDKAlertMessage.h"
#import "SFSDKAlertView.h"
#import "SFSDKAlertMessageBuilder.h"
#import "SFSDKLoginHostListViewController.h"
#import "SFSDKResourceUtils.h"
#import "SFSDKNavigationController.h"
#import "SFSDKLoginHost.h"
#import "SFSDKLoginHostStorage.h"
#import "SFSDKEventBuilderHelper.h"
#import "SFPasscodeManager.h"
#import "SFNetwork.h"
#import "SFSDKSalesforceAnalyticsManager.h"

// Notifications
NSNotificationName SFUserAccountManagerDidChangeUserNotification       = @"SFUserAccountManagerDidChangeUserNotification";
NSNotificationName SFUserAccountManagerDidChangeUserDataNotification   = @"SFUserAccountManagerDidChangeUserDataNotification";
NSNotificationName SFUserAccountManagerDidFinishUserInitNotification   = @"SFUserAccountManagerDidFinishUserInitNotification";

//login & logout notifications
NSNotificationName kSFNotificationUserWillLogIn  = @"SFNotificationUserWillLogIn";
NSNotificationName kSFNotificationUserDidLogIn   = @"SFNotificationUserDidLogIn";
NSNotificationName kSFNotificationUserWillLogout = @"SFNotificationUserWillLogout";
NSNotificationName kSFNotificationUserDidLogout  = @"SFNotificationUserDidLogout";
NSNotificationName kSFNotificationOrgDidLogout   = @"SFNotificationOrgDidLogout";
NSNotificationName kSFNotificationUserDidRefreshToken   = @"SFNotificationOAuthUserDidRefreshToken";

NSNotificationName kSFNotificationUserWillSwitch  = @"SFNotificationUserWillSwitch";
NSNotificationName kSFNotificationUserDidSwitch   = @"SFNotificationUserDidSwitch";
NSNotificationName kSFNotificationDidChangeLoginHost = @"SFNotificationDidChangeLoginHost";

//Auth Display Notification
NSNotificationName kSFNotificationUserWillShowAuthView = @"SFNotificationUserWillShowAuthView";
NSNotificationName kSFNotificationUserCancelledAuth = @"SFNotificationUserCanceledAuthentication";
//IDP-SP flow Notifications
NSNotificationName kSFNotificationUserWillSendIDPRequest      = @"SFNotificationUserWillSendIDPRequest";
NSNotificationName kSFNotificationUserWillSendIDPResponse     = @"kSFNotificationUserWillSendIDPResponse";
NSNotificationName kSFNotificationUserDidReceiveIDPRequest    = @"SFNotificationUserDidReceiveIDPRequest";
NSNotificationName kSFNotificationUserDidReceiveIDPResponse   = @"SFNotificationUserDidReceiveIDPResponse";
NSNotificationName kSFNotificationUserIDPInitDidLogIn       = @"SFNotificationUserIDPInitDidLogIn";

//keys used in notifications
NSString * const kSFNotificationUserInfoAccountKey      = @"account";
NSString * const kSFNotificationUserInfoCredentialsKey  = @"credentials";
NSString * const kSFNotificationUserInfoAuthTypeKey     = @"authType";
NSString * const kSFNotificationPreviousLoginHost     = @"prevLoginHost";
NSString * const kSFNotificationCurrentLoginHost     = @"currentLoginHost";
NSString * const kSFUserInfoAddlOptionsKey     = @"options";
NSString * const kSFNotificationUserInfoKey    = @"sfuserInfo";
NSString * const kSFNotificationFromUserKey    = @"fromUser";
NSString * const kSFNotificationToUserKey      = @"toUser";
NSString * const SFUserAccountManagerUserChangeKey      = @"change";
NSString * const SFUserAccountManagerUserChangeUserKey      = @"user";

// Persistence Keys
static NSString * const kUserDefaultsLastUserIdentityKey = @"LastUserIdentity";
static NSString * const kUserDefaultsLastUserCommunityIdKey = @"LastUserCommunityId";
static NSString * const kSFAppFeatureMultiUser   = @"MU";
static NSString * const kAlertErrorTitleKey = @"authAlertErrorTitle";
static NSString * const kAlertOkButtonKey = @"authAlertOkButton";
static NSString * const kAlertRetryButtonKey = @"authAlertRetryButton";
static NSString * const kAlertDismissButtonKey = @"authAlertDismissButton";
static NSString * const kAlertConnectionErrorFormatStringKey = @"authAlertConnectionErrorFormatString";
static NSString * const kAlertVersionMismatchErrorKey = @"authAlertVersionMismatchError";
static NSString *const kErroredClientKey = @"SFErroredOAuthClientKey";
static NSString * const kSFSPAppFeatureIDPLogin   = @"SP";
static NSString * const kSFIDPAppFeatureIDPLogin   = @"IP";
static NSString *const  kOptionsClientKey          = @"clientIdentifier";

NSString * const kSFSDKUserAccountManagerErrorDomain = @"com.salesforce.mobilesdk.SFUserAccountManager";

static NSString * const kSFInvalidCredentialsAuthErrorHandler = @"InvalidCredentialsErrorHandler";
static NSString * const kSFConnectedAppVersionAuthErrorHandler = @"ConnectedAppVersionErrorHandler";
static NSString * const kSFNetworkFailureAuthErrorHandler = @"NetworkFailureErrorHandler";
static NSString * const kSFGenericFailureAuthErrorHandler = @"GenericFailureErrorHandler";

@interface SFNotificationUserInfo()
- (instancetype) initWithUser:(SFUserAccount *)user;
@end

@implementation SFNotificationUserInfo : NSObject
- (instancetype) initWithUser:(SFUserAccount *)user {
    self = [super init];
    if (self) {
        _accountIdentity = user.accountIdentity;
        _communityId = user.credentials.communityId;
    }
    return self;
}
@end

@implementation SFUserAccountManager

@synthesize currentUser = _currentUser;
@synthesize userAccountMap = _userAccountMap;
@synthesize accountPersister = _accountPersister;
@synthesize loginViewControllerConfig = _loginViewControllerConfig;
@synthesize appLockViewControllerConfig = _appLockViewControllerConfig;

+ (instancetype)sharedInstance {
    static dispatch_once_t pred;
    static SFUserAccountManager *userAccountManager = nil;
    __block BOOL isFirstRun = NO;
    dispatch_once(&pred, ^{
        userAccountManager = [[self alloc] init];
        isFirstRun = YES;
    });
    if (isFirstRun) {
        [[NSNotificationCenter defaultCenter] postNotificationName:SFUserAccountManagerDidFinishUserInitNotification object:nil];
    };
    return userAccountManager;
}

- (id)init {
	self = [super init];
	if (self) {
        self.delegates = [NSHashTable weakObjectsHashTable];
        _accountPersister = [SFDefaultUserAccountPersister new];
        [self migrateUserDefaults];
        _accountsLock = [NSRecursiveLock new];
        _authPreferences = [SFSDKAuthPreferences  new];
        _errorManager = [[SFSDKAuthErrorManager alloc] init];
        __weak typeof (self) weakSelf = self;
        SFSDK_USE_DEPRECATED_BEGIN // TODO: Remove in Mobile SDK 9.0
        self.alertDisplayBlock = ^(SFSDKAlertMessage * message, SFSDKWindowContainer *window) {
            __strong typeof (weakSelf) strongSelf = weakSelf;
            strongSelf.alertView = [[SFSDKAlertView alloc] initWithMessage:message window:window];
            [strongSelf.alertView presentViewController:NO completion:nil];
        };
        SFSDK_USE_DEPRECATED_END
        _authClient = ^(void){
            static  id<SFSDKOAuthProtocol> authClient = nil;
            static dispatch_once_t authClientPred;
            
            dispatch_once(&authClientPred, ^{
                authClient = [[SFSDKOAuth2 alloc] init];
            });
            return authClient;
        };
        
       _idpUserSelectionAction = ^UIViewController<SFSDKUserSelectionView> * _Nonnull{
            SFSDKUserSelectionNavViewController *controller = [[SFSDKUserSelectionNavViewController alloc] init];
            controller.userSelectionDelegate = [SFUserAccountManager sharedInstance];
            return controller;
        };
        
        _idpLoginFlowSelectionAction = ^UIViewController<SFSDKLoginFlowSelectionView> * _Nonnull{
            SFSDKLoginFlowSelectionViewController *controller = [[SFSDKLoginFlowSelectionViewController alloc] init];
            controller.selectionFlowDelegate = [SFUserAccountManager sharedInstance];
            return controller;
        };

        _authViewHandler = [[SFSDKAuthViewHandler alloc]
        initWithDisplayBlock:^(SFSDKAuthViewHolder *viewHandler) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf presentLoginView:viewHandler];
        } dismissBlock:^() {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf dismissAuthViewControllerIfPresent];
        }];
        
        [self populateErrorHandlers];
     }
	return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - persistent properties

- (void)setLoginHost:(NSString*)host {
    self.authPreferences.loginHost = host;
}

- (NSString *)loginHost {
    return self.authPreferences.loginHost;
}

- (NSSet *)scopes
{
    return self.authPreferences.scopes;
}

- (void)setScopes:(NSSet *)newScopes
{
    self.authPreferences.scopes = newScopes;
}

- (NSString *)oauthCompletionUrl
{
    return self.authPreferences.oauthCompletionUrl;
}

- (void)setOauthCompletionUrl:(NSString *)newRedirectUri
{
    self.authPreferences.oauthCompletionUrl = newRedirectUri;
}

- (NSString *)oauthClientId
{
    return self.authPreferences.oauthClientId;
}

- (void)setOauthClientId:(NSString *)newClientId
{
    self.authPreferences.oauthClientId = newClientId;
}

- (BOOL)isIdentityProvider {
    return self.authPreferences.isIdentityProvider;
}

- (void)setIsIdentityProvider:(BOOL)isIdentityProvider {
    if (isIdentityProvider) {
        [SFSDKAppFeatureMarkers registerAppFeature:kSFIDPAppFeatureIDPLogin];
    }else {
        [SFSDKAppFeatureMarkers unregisterAppFeature:kSFIDPAppFeatureIDPLogin];
    }
    self.authPreferences.isIdentityProvider = isIdentityProvider;
}

- (BOOL)idpEnabled {
    return self.authPreferences.idpEnabled;
}

- (NSString *)appDisplayName {
    return self.authPreferences.appDisplayName;
}

- (void)setAppDisplayName:(NSString *)appDisplayName {
    self.authPreferences.appDisplayName = appDisplayName;
}

- (NSString *)idpAppURIScheme {
    return self.authPreferences.idpAppURIScheme;
}

- (BOOL)useBrowserAuth {
     return self.authPreferences.requireBrowserAuthentication;
}

- (void)setUseBrowserAuth:(BOOL)useBrowserAuth {
     self.authPreferences.requireBrowserAuthentication = useBrowserAuth;
}

- (void)setIdpAppURIScheme:(NSString *)idpAppURIScheme {
    if (idpAppURIScheme && [idpAppURIScheme trim].length > 0) {
        [SFSDKAppFeatureMarkers registerAppFeature:kSFSPAppFeatureIDPLogin];
    } else {
        [SFSDKAppFeatureMarkers unregisterAppFeature:kSFSPAppFeatureIDPLogin];
    }
    self.authPreferences.idpAppURIScheme = idpAppURIScheme;
}

- (SFSDKLoginViewControllerConfig *) loginViewControllerConfig {
    if (!_loginViewControllerConfig) {
        _loginViewControllerConfig = [[SFSDKLoginViewControllerConfig alloc] init];
    }
    return _loginViewControllerConfig;
}

- (void) setLoginViewControllerConfig:(SFSDKLoginViewControllerConfig *)config {
    if (_loginViewControllerConfig != config) {
        _loginViewControllerConfig = config;
    }
}

- (SFSDKAppLockViewConfig *) appLockViewControllerConfig {
    if (!_appLockViewControllerConfig) {
        _appLockViewControllerConfig = [SFSDKAppLockViewConfig createDefaultConfig];
    }
    return _appLockViewControllerConfig;
}

- (void) setAppLockViewControllerConfig:(SFSDKAppLockViewConfig *)config {
    if (_appLockViewControllerConfig != config) {
        _appLockViewControllerConfig = config;
        [SFSecurityLockout setPasscodeViewConfig:config];
    }
}


#pragma  mark - login & logout

- (BOOL)handleIDPAuthenticationResponse:(NSURL *)appUrlResponse options:(nonnull NSDictionary *)options {
    [SFSDKCoreLogger d:[self class] format:@"handleIDPAuthenticationResponse %@",[appUrlResponse description]];
    BOOL result = [[SFSDKURLHandlerManager sharedInstance] canHandleRequest:appUrlResponse options:options];
    if (result) {
        result = [[SFSDKURLHandlerManager sharedInstance] processRequest:appUrlResponse  options:options];
    }
    return result;
}

- (BOOL)loginWithCompletion:(SFUserAccountManagerSuccessCallbackBlock)completionBlock failure:(SFUserAccountManagerFailureCallbackBlock)failureBlock {
    return [self authenticateWithCompletion:completionBlock failure:failureBlock];
}

- (BOOL)refreshCredentials:(SFOAuthCredentials *)credentials completion:(SFUserAccountManagerSuccessCallbackBlock)completionBlock failure:(SFUserAccountManagerFailureCallbackBlock)failureBlock {
    NSAssert(credentials.refreshToken.length > 0, @"Refresh token required to refresh credentials.");
    
    SFSDKOAuthTokenEndpointRequest *request = [[SFSDKOAuthTokenEndpointRequest alloc] init];
    request.additionalOAuthParameterKeys = self.additionalOAuthParameterKeys;
    request.additionalTokenRefreshParams = self.additionalTokenRefreshParams;
    request.clientID = credentials.clientId;
    request.refreshToken = credentials.refreshToken;
    request.redirectURI = credentials.redirectUri;
    request.serverURL = [credentials overrideDomainIfNeeded];
    
    __weak typeof(self) weakSelf = self;
    id<SFSDKOAuthProtocol> authClient = self.authClient();
    [authClient accessTokenForRefresh:request completion:^(SFSDKOAuthTokenEndpointResponse * response) {
        __strong typeof (weakSelf) strongSelf = weakSelf;
        SFOAuthInfo *authInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeRefresh];
        if (response.hasError) {
            if (failureBlock) {
                failureBlock(authInfo,response.error.error);
            }
        } else {
            [credentials updateCredentials:[response asDictionary]];
            if (response.additionalOAuthFields)
                credentials.additionalOAuthFields = response.additionalOAuthFields;
            SFUserAccount *userAccount = [strongSelf accountForCredentials:credentials];
            if (!userAccount) {
                SFSDK_USE_DEPRECATED_BEGIN // TODO: Remove in Mobile SDK 9.0
                userAccount = [self applyCredentials:credentials];
                SFSDK_USE_DEPRECATED_END
            }
            [self retrieveUserPhotoIfNeeded:userAccount];
            NSDictionary *userInfo = @{kSFNotificationUserInfoAccountKey: userAccount,
                                       kSFNotificationUserInfoAuthTypeKey: authInfo};
            [[NSNotificationCenter defaultCenter] postNotificationName:kSFNotificationUserDidRefreshToken
                                                                object:strongSelf
                                                              userInfo:userInfo];
            if (completionBlock) {
                completionBlock(authInfo,userAccount);
            }
        }
    }];
    return YES;
}

- (void)stopCurrentAuthentication:(void (^)(BOOL))completionBlock {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self stopCurrentAuthentication:completionBlock];
        });
        return;
    }
    BOOL result = NO;
    if (self.authSession && self.authSession.isAuthenticating) {
        [self resetAuthentication];
        result = YES;
    } else {
        [SFSDKCoreLogger e:[self class] format:@"Authentication has already been stopped."];
    }
    
    if (completionBlock) {
        [self dismissAuthViewControllerIfPresent:^{
            completionBlock(result);
        }];
    }
  
}

- (BOOL)authenticateWithCompletion:(SFUserAccountManagerSuccessCallbackBlock)completionBlock failure:(SFUserAccountManagerFailureCallbackBlock)failureBlock {
    if (_authSession && _authSession.isAuthenticating) {
        [SFSDKCoreLogger e:[self class] format:@"Login has already been called. Stop current authentication using SFUserAccountmanger::stopAuthentication and then retry."];
        return NO;
    }
    SFSDKAuthRequest *request = [self defaultAuthRequest];
    if (request.ipdEnabled) {
       return [self authenticateUsingIDP:request completion:completionBlock failure:failureBlock];
    }
    return [self authenticateWithRequest:request completion:completionBlock failure:failureBlock];
}

-(SFSDKAuthRequest *)defaultAuthRequest {
    SFSDKAuthRequest *request = [[SFSDKAuthRequest alloc] init];
    request.loginHost = self.loginHost;
    request.additionalOAuthParameterKeys = self.additionalOAuthParameterKeys;
    request.appLockViewControllerConfig = self.appLockViewControllerConfig;
    request.loginViewControllerConfig = self.loginViewControllerConfig;
    request.brandLoginPath = self.brandLoginPath;
    request.oauthClientId = self.oauthClientId;
    request.oauthCompletionUrl = self.oauthCompletionUrl;
    request.scopes = self.scopes;
    request.retryLoginAfterFailure = self.retryLoginAfterFailure;
    request.useBrowserAuth = self.useBrowserAuth;
    request.spAppLoginFlowSelectionAction = self.idpLoginFlowSelectionAction;
    request.idpAppURIScheme = self.idpAppURIScheme;
    return request;
}

- (BOOL)authenticateWithRequest:(SFSDKAuthRequest *)request completion:(SFUserAccountManagerSuccessCallbackBlock)completionBlock failure:(SFUserAccountManagerFailureCallbackBlock)failureBlock {
    SFSDKAuthSession *authSession = [[SFSDKAuthSession alloc] initWith:request credentials:nil];
    authSession.isAuthenticating = YES;
    authSession.authFailureCallback = failureBlock;
    authSession.authSuccessCallback = completionBlock;
    authSession.oauthCoordinator.delegate = self;
    self.authSession = authSession;
    dispatch_async(dispatch_get_main_queue(), ^{
        [SFSDKWebViewStateManager removeSession];
        [authSession.oauthCoordinator authenticate];
    });
    return self.authSession.isAuthenticating;
}

- (BOOL)authenticateWithRequestOnBehalfOfSpApp:(SFSDKAuthRequest *)request spAppCredentials:(SFOAuthCredentials *)spAppCrendetials completion:(SFUserAccountManagerSuccessCallbackBlock)completionBlock failure:(SFUserAccountManagerFailureCallbackBlock)failureBlock {
    SFSDKAuthSession *authSession = [[SFSDKAuthSession alloc] initWith:request credentials:nil  spAppCredentials:spAppCrendetials];
    authSession.isAuthenticating = YES;
    authSession.authFailureCallback = failureBlock;
    authSession.authSuccessCallback = completionBlock;
    authSession.oauthCoordinator.delegate = self;
    self.authSession = authSession;
    dispatch_async(dispatch_get_main_queue(), ^{
        [SFSDKWebViewStateManager removeSession];
        [authSession.oauthCoordinator authenticate];
    });
    return self.authSession.isAuthenticating;
}

- (BOOL)loginWithJwtToken:(NSString *)jwtToken completion:(SFUserAccountManagerSuccessCallbackBlock)completionBlock failure:(SFUserAccountManagerFailureCallbackBlock)failureBlock {
    NSAssert(jwtToken.length > 0, @"JWT token value required.");
    SFSDKAuthRequest *request = [self defaultAuthRequest];
    request.jwtToken = jwtToken;
    return [self authenticateWithRequest:request completion:completionBlock failure:failureBlock];
}

- (void)logout {
    [self logoutUser:[SFUserAccountManager sharedInstance].currentUser];
}

- (void)logoutUser:(SFUserAccount *)user {
  
    // No-op, if the user is not valid.
    if (user == nil) {
        [SFSDKCoreLogger i:[self class] format:@"logoutUser: user is nil. No action taken."];
        return;
    }
    BOOL loggingOutTransitionSucceeded = [user transitionToLoginState:SFUserAccountLoginStateLoggingOut];
    if (!loggingOutTransitionSucceeded) {

        // SFUserAccount already logs the transition failure.
        return;
    }
    
    // Before starting actual logout (which will tear down SFRestAPI), first unregister from push notifications if needed
    __weak typeof(self) weakSelf = self;
    [[SFPushNotificationManager sharedInstance] unregisterSalesforceNotificationsWithCompletionBlock:user completionBlock:^void() {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf postPushUnregistration:user];
    }];
}

- (void)restartAuthentication {
    [self restartAuthentication:self.authSession];
}

- (void)restartAuthentication:(SFSDKAuthSession *)session {
    [session.oauthCoordinator stopAuthentication];
    __weak typeof(self) weakSelf = self;
    [self dismissAuthViewControllerIfPresent:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        strongSelf.authSession.isAuthenticating = NO;
        [strongSelf authenticateWithRequest:session.oauthRequest completion:session.authSuccessCallback failure:session.authFailureCallback];
    }];
    
}

- (void)postPushUnregistration:(SFUserAccount *)user {
    
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self postPushUnregistration:user];
        });
        return;
    }

    [SFSDKCoreLogger d:[self class] format:@"Logging out user '%@'.", user.idData.username];
    
    //save for use with didLogout notification
    NSString *userId = user.credentials.userId;
    NSString *orgId = user.credentials.organizationId;
    NSString *communityId = user.credentials.communityId;
    
    NSDictionary *userInfo = @{ kSFNotificationUserInfoAccountKey : user };
    [[NSNotificationCenter defaultCenter]  postNotificationName:kSFNotificationUserWillLogout
                                                         object:self
                                                       userInfo:userInfo];

    [self deleteAccountForUser:user error:nil];
    id<SFSDKOAuthProtocol> authClient = self.authClient();
    [authClient revokeRefreshToken:user.credentials];
    SFSDK_USE_DEPRECATED_BEGIN // TODO: Remove in Mobile SDK 9.0
    [SFSecurityLockout clearPasscodeState:user];
    SFSDK_USE_DEPRECATED_END
    BOOL isCurrentUser = [user isEqual:self.currentUser];
    if (isCurrentUser) {
        [self setCurrentUserInternal:nil];
    }

    [SFSDKWebViewStateManager removeSession];
    
    //restore these id's inorder to enable post logout cleanup of components
    // TODO: Revisit the userInfo data structure of kSFNotificationUserDidLogout in 7.0.
    // Technically, an SFUserAccount should not continue to exist after logout.  The
    // identifying data here would be better organized into a standalone data structure.
    user.credentials.userId = userId;
    user.credentials.organizationId = orgId;
    user.credentials.communityId = communityId;
    
    NSNotification *logoutNotification = [NSNotification notificationWithName:kSFNotificationUserDidLogout object:self userInfo:userInfo];
    [[NSNotificationCenter defaultCenter] postNotification:logoutNotification];

    //post a notification if all users of the given org have logged out.
    if (![self orgHasLoggedInUsers:orgId]) {
        SFNotificationUserInfo *sfUserInfo = [[SFNotificationUserInfo alloc] initWithUser:user];
        
        NSDictionary *notificationUserInfo = @{ kSFNotificationUserInfoKey : sfUserInfo };
        NSNotification *orgLogoutNotification = [NSNotification notificationWithName:kSFNotificationOrgDidLogout object:self userInfo:notificationUserInfo];
        [[NSNotificationCenter defaultCenter] postNotification:orgLogoutNotification];
    }
    
    // NB: There's no real action that can be taken if this login state transition fails.  At any rate,
    // it's an unlikely scenario.
    [user transitionToLoginState:SFUserAccountLoginStateNotLoggedIn];
    [self dismissAuthViewControllerIfPresent];
}

- (void)logoutAllUsers {
    // Log out all other users, then the current user.
    NSArray *userAccounts = [self allUserAccounts];
    for (SFUserAccount *account in userAccounts) {
        if (account != self.currentUser) {
            [self logoutUser:account];
        }
    }
    [self logoutUser:[SFUserAccountManager sharedInstance].currentUser];
}

- (void)dismissAuthViewControllerIfPresent
{
    [self dismissAuthViewControllerIfPresent:nil];
}

- (void)dismissAuthViewControllerIfPresent:(void (^)(void))completionBlock {
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self dismissAuthViewControllerIfPresent:completionBlock];
        });
        return;
    }
    
    if (![SFSDKWindowManager sharedManager].authWindow.isEnabled) {
        if (completionBlock) completionBlock();
        return;
    }
    
    UIViewController *presentedViewController = [SFSDKWindowManager sharedManager].authWindow.viewController.presentedViewController;
    
    if (presentedViewController && presentedViewController.isBeingPresented) {
        [presentedViewController dismissViewControllerAnimated:NO completion:^{
            [[SFSDKWindowManager sharedManager].authWindow dismissWindowAnimated:NO withCompletion:^{
                if (completionBlock) {
                    completionBlock();
                }
            }];
        }];
    } else {
        [[SFSDKWindowManager sharedManager].authWindow dismissWindowAnimated:NO withCompletion:^{
            if (completionBlock) {
                completionBlock();
            }
        }];
    }
}

+ (BOOL)errorIsInvalidAuthCredentials:(NSError *)error {
    return [SFSDKAuthErrorManager errorIsInvalidAuthCredentials:error];
}

#pragma mark - SFOAuthCoordinatorDelegate
- (void)oauthCoordinatorWillBeginAuthentication:(SFOAuthCoordinator *)coordinator authInfo:(SFOAuthInfo *)info {
    coordinator.authSession.authInfo  = info;
    NSDictionary *userInfo = @{ kSFNotificationUserInfoCredentialsKey: coordinator.credentials,
                                kSFNotificationUserInfoAuthTypeKey: coordinator.authInfo };
    [[NSNotificationCenter defaultCenter] postNotificationName:kSFNotificationUserWillLogIn
                                                        object:self
                                                      userInfo:userInfo];
}

- (void)oauthCoordinatorDidAuthenticate:(SFOAuthCoordinator *)coordinator authInfo:(SFOAuthInfo *)info {
     coordinator.authSession.authInfo  = info;
     [self loggedIn:NO coordinator:coordinator notifyDelegatesOfFailure:YES];
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didFailWithError:(NSError *)error authInfo:(nullable SFOAuthInfo *)info {
    coordinator.authSession.authError = error;
    coordinator.authSession.authInfo  = info;
    __block BOOL errorWasHandledByDelegate = NO;
    
    //check if the request was initiated by spapp (idp scenario only)
    if (coordinator.authSession.oauthRequest.authenticateRequestFromSPApp) {
       [SFSDKIDPAuthHelper invokeSPAppWithError:coordinator.spAppCredentials error:error reason:@"User cancelled authentication"];
        return;
    }
    
    [self enumerateDelegates:^(id <SFUserAccountManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(userAccountManager:error:info:)]) {
            BOOL returnVal = [delegate userAccountManager:self error:error info:coordinator.authInfo];
            errorWasHandledByDelegate |= returnVal;
        }
    }];

    if (!errorWasHandledByDelegate) {
       BOOL errorWasHandledBySDK =  [self.errorManager processAuthError:error authContext:coordinator.authSession options:nil];
        if (!errorWasHandledBySDK) {
            [SFSDKCoreLogger e:[self class] format:@"Unhandled Error during authentication. Handle the error using   [SFUserAccountManagerDelegate userAccountManager:error:info:] and return true. %@", error.localizedDescription];
        }
    }
    self.authSession.notifiesDelegatesOfFailure = YES;
    [self handleFailure:error session:coordinator.authSession];
}

- (BOOL)oauthCoordinatorIsNetworkAvailable:(SFOAuthCoordinator*)coordinator {
     __block BOOL result = YES;
    [self enumerateDelegates:^(id <SFUserAccountManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(userAccountManagerIsNetworkAvailable:)]) {
            result &= [delegate userAccountManagerIsNetworkAvailable:self];
        }
    }];
    return result;
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator willBeginBrowserAuthentication:(SFOAuthBrowserFlowCallbackBlock)callbackBlock {
    coordinator.authSession.authCoordinatorBrowserBlock = callbackBlock;
    callbackBlock(YES);
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator displayAlertMessage:(NSString*)message completion:(dispatch_block_t)completion {
  
    SFSDKAlertMessage *messageObject = [SFSDKAlertMessage messageWithBlock:^(SFSDKAlertMessageBuilder *builder) {
       builder.actionOneTitle = [SFSDKResourceUtils localizedString:@"authAlertOkButton"];
       builder.alertTitle = @"Authentication";
       builder.actionOneCompletion = completion;
   }];
    dispatch_async(dispatch_get_main_queue(), ^{
        SFSDK_USE_DEPRECATED_BEGIN // TODO: Remove in Mobile SDK 9.0
        self.alertDisplayBlock(messageObject, [SFSDKWindowManager sharedManager].authWindow);
        SFSDK_USE_DEPRECATED_END
   });
    
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator displayConfirmationMessage:(NSString*)message completion:(void (^)(BOOL result))completion {
   SFSDKAlertMessage *messageObject = [SFSDKAlertMessage messageWithBlock:^(SFSDKAlertMessageBuilder *builder) {
        builder.actionOneTitle = [SFSDKResourceUtils localizedString:@"authAlertOkButton"];
        builder.actionTwoTitle = [SFSDKResourceUtils localizedString:@"authAlertCancelButton"];
        builder.alertTitle = @"";
        builder.alertMessage = message;
        builder.actionOneCompletion = ^{
            if (completion) completion(YES);
        };
        builder.actionTwoCompletion = ^{
            if (completion) completion(NO);
        };
    }];
    dispatch_async(dispatch_get_main_queue(), ^{
        SFSDK_USE_DEPRECATED_BEGIN // TODO: Remove in Mobile SDK 9.0
        self.alertDisplayBlock(messageObject, [SFSDKWindowManager sharedManager].authWindow);
        SFSDK_USE_DEPRECATED_END
    });
}
// IDP related code fetched as an identity provider app
- (void)oauthCoordinatorDidFetchAuthCode:(SFOAuthCoordinator *)coordinator authInfo:(SFOAuthInfo *)authInfo {
    coordinator.authSession.authInfo = authInfo;
    
    // Fetched auth code as an idp app
    [SFSDKIDPAuthHelper invokeSPApp:self.authSession completion:^(BOOL result) {
        [self dismissAuthViewControllerIfPresent];
    }];
    
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didBeginAuthenticationWithView:(WKWebView *)view {

    SFLoginViewController *loginViewController = [self createLoginViewControllerInstance:coordinator];
    loginViewController.oauthView = view;
    SFSDKAuthViewHolder *viewHolder = [SFSDKAuthViewHolder new];
    viewHolder.loginController = loginViewController;
    // Ensure this runs on the main thread.  Has to be sync, because the coordinator expects the auth view
    // to be added to a superview by the end of this method.
    if (![NSThread isMainThread]) {
       dispatch_sync(dispatch_get_main_queue(), ^{
           self.authViewHandler.authViewDisplayBlock(viewHolder);
       });
    } else {
       self.authViewHandler.authViewDisplayBlock(viewHolder);
    }
}

- (void)oauthCoordinator:(SFOAuthCoordinator *)coordinator didBeginAuthenticationWithSession:(ASWebAuthenticationSession *)session {
    SFSDKAuthViewHolder *viewHolder = [SFSDKAuthViewHolder new];
    viewHolder.isAdvancedAuthFlow = YES;
    viewHolder.session = session;
    NSDictionary *userInfo = @{ kSFNotificationUserInfoCredentialsKey: coordinator.credentials,
                                kSFNotificationUserInfoAuthTypeKey: coordinator.authInfo };
    [[NSNotificationCenter defaultCenter] postNotificationName:kSFNotificationUserWillShowAuthView object:self  userInfo:userInfo];
    self.authViewHandler.authViewDisplayBlock(viewHolder);
}

- (void)oauthCoordinatorDidCancelBrowserAuthentication:(SFOAuthCoordinator *)coordinator {
    
    SFOAuthInfo *authInfo = [[SFOAuthInfo alloc] initWithAuthType:SFOAuthTypeAdvancedBrowser];
    NSDictionary *userInfo = @{ kSFNotificationUserInfoCredentialsKey: coordinator.credentials,
                               kSFNotificationUserInfoAuthTypeKey: authInfo };
    [[NSNotificationCenter defaultCenter] postNotificationName:kSFNotificationUserCancelledAuth
                                                       object:self userInfo:userInfo];
    SFSDK_USE_DEPRECATED_BEGIN // TODO: Remove in Mobile SDK 9.0
    if (!self.authCancelledByUserHandlerBlock) {
           SFSDKLoginHostListViewController *hostListViewController = [[SFSDKLoginHostListViewController alloc] initWithStyle:UITableViewStylePlain];
           hostListViewController.delegate = self;
           SFSDKNavigationController *controller = [[SFSDKNavigationController alloc] initWithRootViewController:hostListViewController];
           hostListViewController.hidesCancelButton = YES;
           controller.modalPresentationStyle = UIModalPresentationFullScreen;
           [[SFSDKWindowManager sharedManager].authWindow presentWindowAnimated:NO withCompletion:^{
               [[SFSDKWindowManager sharedManager].authWindow.viewController presentViewController:controller animated:NO completion:nil];
           }];
    } else {
        self.authCancelledByUserHandlerBlock();
    }
    SFSDK_USE_DEPRECATED_END
}

#pragma mark - SFIdentityCoordinatorDelegate

- (void)identityCoordinatorRetrievedData:(SFIdentityCoordinator *)coordinator {
    [self retrievedIdentityData:coordinator.authSession];
}

- (void)identityCoordinator:(SFIdentityCoordinator *)coordinator didFailWithError:(NSError *)error {
   if (error.code == kSFIdentityErrorMissingParameters) {
        // No retry, as missing parameters are fatal
        [SFSDKCoreLogger e:[self class] format:@"Missing parameters attempting to retrieve identity data.  Error domain: %@, code: %ld, description: %@", [error domain], [error code], [error localizedDescription]];
        id<SFSDKOAuthProtocol> authClient = self.authClient();
        [authClient revokeRefreshToken:coordinator.credentials];
       [self handleFailure:error session:self.authSession];
    } else {
        [SFSDKCoreLogger e:[self class] format:@"Error retrieving idData:%@", error];
        SFSDKAlertMessage *message = [SFSDKAlertMessage messageWithBlock:^(SFSDKAlertMessageBuilder *builder) {
            builder.actionOneTitle = [SFSDKResourceUtils localizedString:@"authAlertRetryButton"];
            builder.actionTwoTitle = [SFSDKResourceUtils localizedString:@"authAlertDismissButton"];
            builder.alertTitle = [SFSDKResourceUtils localizedString:@"authAlertErrorTitle"];
            builder.alertMessage = [NSString stringWithFormat:[SFSDKResourceUtils localizedString:@"authAlertConnectionErrorFormatString"], [error localizedDescription]];
            builder.actionOneCompletion = ^{
                 [coordinator initiateIdentityDataRetrieval];
            };
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            SFSDK_USE_DEPRECATED_BEGIN // TODO: Remove in Mobile SDK 9.0
            self.alertDisplayBlock(message, [SFSDKWindowManager sharedManager].authWindow);
            SFSDK_USE_DEPRECATED_END
        });
    }
}
#pragma mark - SFLoginViewControllerDelegate

- (void)loginViewController:(SFLoginViewController *)loginViewController didChangeLoginHost:(SFSDKLoginHost *)newLoginHost {
    NSDictionary *userInfo = @{kSFNotificationPreviousLoginHost: self.loginHost, kSFNotificationCurrentLoginHost: newLoginHost.host};
    self.loginHost = newLoginHost.host;
    NSNotification *loginHostChangedNotification = [NSNotification notificationWithName:kSFNotificationDidChangeLoginHost object:self userInfo:userInfo];
    [[NSNotificationCenter defaultCenter] postNotification:loginHostChangedNotification];
    self.authSession.oauthRequest.loginHost = newLoginHost.host;
    [self restartAuthentication];
}

#pragma mark - SFSDKLoginHostDelegate
- (void)hostListViewControllerDidSelectLoginHost:(SFSDKLoginHostListViewController *)hostListViewController {
    [self loginHostSelected:hostListViewController];
}

- (void)hostListViewController:(SFSDKLoginHostListViewController *)hostListViewController didChangeLoginHost:(SFSDKLoginHost *)newLoginHost {
    [_accountsLock lock];
    NSDictionary *userInfo = @{kSFNotificationPreviousLoginHost: self.loginHost, kSFNotificationCurrentLoginHost: newLoginHost.host};
    self.loginHost = newLoginHost.host;
    NSNotification *loginHostChangedNotification = [NSNotification notificationWithName:kSFNotificationDidChangeLoginHost object:self userInfo:userInfo];
    [[NSNotificationCenter defaultCenter] postNotification:loginHostChangedNotification];
    self.authSession.oauthRequest.loginHost = newLoginHost.host;
    [_accountsLock unlock];
}

- (void)hostListViewControllerDidAddLoginHost:(SFSDKLoginHostListViewController *)hostListViewController {
    [self loginHostSelected:hostListViewController];
}

- (void)loginHostSelected:(SFSDKLoginHostListViewController *)hostListViewController {
    [hostListViewController dismissViewControllerAnimated:YES completion:nil];
    [self restartAuthentication];
}

#pragma mark - SFSDKLoginFlowSelectionViewDelegate (SP App flow Related Actions)

-(void)loginFlowSelectionIDPSelected:(UIViewController *)controller options:(NSDictionary *)appOptions {
    //User picked IDP flow from login Selection screen. start the idp flow.
    NSString *loginHost = appOptions[kSFLoginHostParam];
    if (loginHost) {
        self.authSession.oauthCoordinator.credentials.domain = loginHost;
    }
    self.authSession.oauthRequest.appDisplayName = self.appDisplayName;
    [SFSDKIDPAuthHelper invokeIDPApp:self.authSession completion:^(BOOL result) {
       [SFSDKCoreLogger d:[self class] format:@"Launced IDP App"];
    }];
}

-(void)loginFlowSelectionLocalLoginSelected:(UIViewController *)controller options:(NSDictionary *)appOptions  {
    __weak typeof (self) weakSelf = self;
    [self dismissAuthViewControllerIfPresent:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf authenticateWithRequest:strongSelf.authSession.oauthRequest completion:strongSelf.authSession.authSuccessCallback  failure:strongSelf.authSession.authFailureCallback];
    }];
}

#pragma mark - SFSDKUserSelectionViewDelegate (IDP App flow Related Actions)
- (void)createNewUser:(NSDictionary *)spAppOptions {
    //Create new user selected in IDP flow in the idp app mode.
    SFSDKAuthRequest *request = [self defaultAuthRequest];
    request.authenticateRequestFromSPApp = YES;
    __weak typeof(self) weakSelf = self;
    SFOAuthCredentials *spAppCredentials = [self spAppCredentials:spAppOptions];
    [self stopCurrentAuthentication:^(BOOL result) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf authenticateWithRequestOnBehalfOfSpApp:request spAppCredentials:spAppCredentials  completion:^(SFOAuthInfo *authInfo, SFUserAccount *user) {
            [strongSelf authenticateOnBehalfOfSPApp:user spAppCredentials:spAppCredentials];
        } failure:^(SFOAuthInfo *authInfo, NSError *error) {
            [SFSDKIDPAuthHelper invokeSPAppWithError:spAppCredentials error:error reason:@"Failed refreshing credentials"];
        }];
    }];
    
}

- (void)selectedUser:(SFUserAccount *)user spAppContext:(NSDictionary *)spAppOptions {
     //User has been selected in the idp app mode.
     //make sure access token is not expired
    __weak typeof (self) weakSelf = self;
    SFOAuthCredentials *spAppCredentials = [self spAppCredentials:spAppOptions];
    SFRestRequest *request = [[SFRestAPI sharedInstanceWithUser:user] requestForUserInfo];
    [[SFRestAPI sharedInstanceWithUser:user] sendRequest:request failureBlock:^(id response, NSError *error, NSURLResponse *rawResponse) {
        [SFSDKIDPAuthHelper invokeSPAppWithError:spAppCredentials error:error reason:@"Failed refreshing credentials"];
    } successBlock:^(id response, NSURLResponse *rawResponse) {
        __strong typeof (self) strongSelf = weakSelf;
        [strongSelf authenticateOnBehalfOfSPApp:user spAppCredentials:spAppCredentials];
    }];
}

- (void)cancel:(NSDictionary *)spAppOptions {
   // Uset Cancelled auth in the idp app mode
    SFOAuthCredentials *spAppCredentials = [self spAppCredentials:spAppOptions];
    [SFSDKIDPAuthHelper invokeSPAppWithError:spAppCredentials error:nil reason:@"User cancelled Authentication"];
}

- (SFOAuthCredentials *)spAppCredentials:(NSDictionary *)callingAppOptions {
    
    NSString *clientId = callingAppOptions[kSFOAuthClientIdParam];
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:clientId clientId:clientId encrypted:NO];
    creds.redirectUri = callingAppOptions[kSFOAuthRedirectUrlParam];
    creds.challengeString = callingAppOptions[kSFChallengeParamName];
    creds.accessToken = nil;
    
    NSString *loginHost = callingAppOptions[kSFLoginHostParam];
    
    if (loginHost == nil || [loginHost isEmptyOrWhitespaceAndNewlines]){
        loginHost = self.loginHost;
    }
    creds.domain = loginHost;
    return creds;
}

#pragma mark - SFUserAccountDelegate management

- (void)addDelegate:(id<SFUserAccountManagerDelegate>)delegate {
    @synchronized(self) {
        if (delegate) {
            [self.delegates addObject:delegate];
        }
    }
}

- (void)removeDelegate:(id<SFUserAccountManagerDelegate>)delegate {
    @synchronized(self) {
        if (delegate) {
            [self.delegates removeObject:delegate];
        }
    }
}

- (void)enumerateDelegates:(void (^)(id<SFUserAccountManagerDelegate>))block {
    @synchronized(self) {
        for (id<SFUserAccountManagerDelegate> delegate in self.delegates) {
            if (block) block(delegate);
        }
    }
}

#pragma mark - Anonymous User
- (BOOL)isCurrentUserAnonymous {
    return self.currentUser == nil;
}

-(NSMutableDictionary *)userAccountMap {
    if(!_userAccountMap) {
        [self reload];
    }
    return _userAccountMap;
}

SFSDK_USE_DEPRECATED_BEGIN // TODO: Remove in Mobile SDK 9.0
- (void)setAccountPersister:(id<SFUserAccountPersister>) persister {
SFSDK_USE_DEPRECATED_END
    if(persister != _accountPersister) {
        [_accountsLock lock];
        _accountPersister = persister;
        [self reload];
        [_accountsLock unlock];
    }
}

- (BOOL)handleAdvancedAuthURL:(NSURL *)advancedAuthURL {
    BOOL result = NO;
    if (self.authSession) {
        result = [self.authSession.oauthCoordinator handleAdvancedAuthenticationResponse:advancedAuthURL];
    }
    return result;
}

#pragma mark Account management
- (NSArray *)allUserAccounts {
    return [self.userAccountMap allValues];
}

- (NSArray *)allUserIdentities {
    // Sort the identities
    NSArray *keys = nil;
    [_accountsLock lock];
     keys = [[self.userAccountMap allKeys] sortedArrayUsingSelector:@selector(compare:)];
    [_accountsLock unlock];
    return keys;
}

- (SFUserAccount *)accountForCredentials:(SFOAuthCredentials *) credentials {
    // Sort the identities
    SFUserAccount *account = nil;
    [_accountsLock lock];
    NSArray *keys = [self.userAccountMap allKeys];
    for (SFUserAccountIdentity *identity in keys) {
        if ([identity matchesCredentials:credentials]) {
            account = (self.userAccountMap)[identity];
            break;
        }
    }
    [_accountsLock unlock];
    return account;
}

/** Returns all existing account names in the keychain
 */
- (NSSet*)allExistingAccountNames {
    NSMutableDictionary *tokenQuery = [[NSMutableDictionary alloc] init];
    tokenQuery[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
    tokenQuery[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitAll;
    tokenQuery[(__bridge id)kSecReturnAttributes] = (id)kCFBooleanTrue;

    CFArrayRef outArr = nil;
    OSStatus result = SecItemCopyMatching((__bridge CFDictionaryRef)[NSDictionary dictionaryWithDictionary:tokenQuery], (CFTypeRef *)&outArr);
    if (noErr == result) {
        NSMutableSet *accounts = [NSMutableSet set];
        for (NSDictionary *info in (__bridge_transfer NSArray *)outArr) {
            NSString *accountName = info[(__bridge NSString*)kSecAttrAccount];
            if (accountName) {
                [accounts addObject:accountName];
            }
        }

        return accounts;
    } else {
        [SFSDKCoreLogger d:[self class] format:@"Error querying for all existing accounts in the keychain: %ld", result];
        return nil;
    }
}

/** Returns a unique user account identifier
 */
- (NSString*)uniqueUserAccountIdentifier:(NSString *)clientId {
    NSSet *existingAccountNames = [self allExistingAccountNames];

    // Make sure to build a unique identifier
    NSString *identifier = nil;
    while (nil == identifier || [existingAccountNames containsObject:identifier]) {
        u_int32_t randomNumber = arc4random();
        identifier = [NSString stringWithFormat:@"%@-%u", clientId, randomNumber];
    }

    return identifier;
}

- (SFUserAccount*)createUserAccount:(SFOAuthCredentials *)credentials {
    SFUserAccount *newAcct = [[SFUserAccount alloc] initWithCredentials:credentials];
    [self saveAccountForUser:newAcct error:nil];
    return newAcct;
}

- (void)migrateUserDefaults {
    //Migrate the defaults to the correct location
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:[SFSDKDatasharingHelper sharedInstance].appGroupName];
    NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];

    BOOL isGroupAccessEnabled = [SFSDKDatasharingHelper sharedInstance].appGroupEnabled;
    BOOL userIdentityShared = [sharedDefaults boolForKey:@"userIdentityShared"];
    BOOL communityIdShared = [sharedDefaults boolForKey:@"communityIdShared"];

    if (isGroupAccessEnabled && !userIdentityShared) {
        //Migrate user identity to shared location
        NSData *userData = [standardDefaults objectForKey:kUserDefaultsLastUserIdentityKey];
        if (userData) {
            [sharedDefaults setObject:userData forKey:kUserDefaultsLastUserIdentityKey];
        }
        [sharedDefaults setBool:YES forKey:@"userIdentityShared"];
    }
    if (!isGroupAccessEnabled && userIdentityShared) {
        //Migrate base app identifier key to non-shared location
        NSData *userData = [sharedDefaults objectForKey:kUserDefaultsLastUserIdentityKey];
        if (userData) {
            [standardDefaults setObject:userData forKey:kUserDefaultsLastUserIdentityKey];
        }

        [sharedDefaults setBool:NO forKey:@"userIdentityShared"];
    } else if (isGroupAccessEnabled && !communityIdShared) {
        //Migrate communityId to shared location
        NSString *activeCommunityId = [standardDefaults stringForKey:kUserDefaultsLastUserCommunityIdKey];
        if (activeCommunityId) {
            [sharedDefaults setObject:activeCommunityId forKey:kUserDefaultsLastUserCommunityIdKey];
        }
        [sharedDefaults setBool:YES forKey:@"communityIdShared"];
    } else if (!isGroupAccessEnabled && communityIdShared) {
        //Migrate base app identifier key to non-shared location
        NSString *activeCommunityId = [sharedDefaults stringForKey:kUserDefaultsLastUserCommunityIdKey];
        if (activeCommunityId) {
            [standardDefaults setObject:activeCommunityId forKey:kUserDefaultsLastUserCommunityIdKey];
        }
        [sharedDefaults setBool:NO forKey:@"communityIdShared"];
    }

    [standardDefaults synchronize];
    [sharedDefaults synchronize];

}

- (BOOL)loadAccounts:(NSError **) error {
    BOOL success = YES;
    [_accountsLock lock];

    NSError *internalError = nil;
    SFSDK_USE_DEPRECATED_BEGIN // TODO: Remove in Mobile SDK 9.0
    NSDictionary<SFUserAccountIdentity *,SFUserAccount *> *accounts = [self.accountPersister fetchAllAccounts:&internalError];
    SFSDK_USE_DEPRECATED_END
    
    if (_userAccountMap)
        [_userAccountMap removeAllObjects];
    
    _userAccountMap = [NSMutableDictionary dictionaryWithDictionary:accounts];

    if (internalError)
        success = NO;

    if (error && internalError)
        *error = internalError;

    [_accountsLock unlock];
    return success;
}

- (SFUserAccount *)userAccountForUserIdentity:(SFUserAccountIdentity *)userIdentity {

    SFUserAccount *result = nil;
    [_accountsLock lock];
    result = (self.userAccountMap)[userIdentity];
    [_accountsLock unlock];
    return result;
}

- (NSArray *)userAccountsForDomain:(NSString *)domain {
    NSMutableArray *responseArray = [NSMutableArray array];
    [_accountsLock lock];
    for (SFUserAccountIdentity *key in self.userAccountMap) {
        SFUserAccount *account = (self.userAccountMap)[key];
        NSString *accountDomain = account.credentials.domain;
        if ([[accountDomain lowercaseString] isEqualToString:[domain lowercaseString]]) {
            [responseArray addObject:account];
        }
    }
    [_accountsLock unlock];
    return responseArray;
}

- (BOOL)orgHasLoggedInUsers:(NSString *)orgId {
    NSArray *accounts = [self accountsForOrgId:orgId];
    return accounts && (accounts.count > 0);
}

- (NSArray *)accountsForOrgId:(NSString *)orgId {
     NSMutableArray *responseArray = [NSMutableArray array];
    [_accountsLock lock];
    for (SFUserAccountIdentity *key in self.userAccountMap) {
        SFUserAccount *account = (self.userAccountMap)[key];
        NSString *accountOrg = account.credentials.organizationId;
        if ([accountOrg isEqualToEntityId:orgId]) {
            [responseArray addObject:account];
        }
    }
    [_accountsLock unlock];
    return responseArray;
}

- (NSArray *)accountsForInstanceURL:(NSURL *)instanceURL {

    NSMutableArray *responseArray = [NSMutableArray array];
    [_accountsLock lock];
    for (SFUserAccountIdentity *key in self.userAccountMap) {
        SFUserAccount *account = (self.userAccountMap)[key];
        if ([account.credentials.instanceUrl.host isEqualToString:instanceURL.host]) {
            [responseArray addObject:account];
        }
    }
    [_accountsLock unlock];
    return responseArray;
}

- (void)clearAllAccountState {
    [_accountsLock lock];
    _currentUser = nil;
    [_userAccountMap removeAllObjects];
    _userAccountMap = nil;
    [_accountsLock unlock];
}

- (NSString *)encodeUserIdentity:(SFUserAccountIdentity *)userIdentity {
    NSString *encodedString = [NSString stringWithFormat:@"%@:%@",userIdentity.userId,userIdentity.orgId];
    return encodedString;
}

- (SFUserAccountIdentity *)decodeUserIdentity:(NSString *)userIdentity {
    NSArray *listItems = [userIdentity componentsSeparatedByString:@":"];
    SFUserAccountIdentity *identity = [[SFUserAccountIdentity alloc] initWithUserId:listItems[0] orgId:listItems[1]];
    return identity;
}
- (BOOL)saveAccountForUser:(SFUserAccount*)userAccount error:(NSError **) error{
    BOOL success = NO;
    [_accountsLock lock];
    NSUInteger oldCount = self.userAccountMap.count;

    //remove from cache
    if ([self.userAccountMap objectForKey:userAccount.accountIdentity]!=nil)
        [self.userAccountMap removeObjectForKey:userAccount.accountIdentity];

    SFSDK_USE_DEPRECATED_BEGIN // TODO: Remove in Mobile SDK 9.0
    success = [self.accountPersister saveAccountForUser:userAccount error:error];
    SFSDK_USE_DEPRECATED_END
    if (success) {
        [self.userAccountMap setObject:userAccount forKey:userAccount.accountIdentity];
        if (self.userAccountMap.count>1 && oldCount<self.userAccountMap.count ) {
            [SFSDKAppFeatureMarkers registerAppFeature:kSFAppFeatureMultiUser];
        }

    }
    [_accountsLock unlock];
    return success;
}

- (BOOL)deleteAccountForUser:(SFUserAccount *)user error:(NSError **)error {
    BOOL success = NO;
    [_accountsLock lock];
    SFSDK_USE_DEPRECATED_BEGIN // TODO: Remove in Mobile SDK 9.0
    success = [self.accountPersister deleteAccountForUser:user error:error];
    SFSDK_USE_DEPRECATED_END

    if (success) {
        user.userDeleted = YES;
        [self.userAccountMap removeObjectForKey:user.accountIdentity];
        if ([self.userAccountMap count] < 2) {
            [SFSDKAppFeatureMarkers unregisterAppFeature:kSFAppFeatureMultiUser];
        }
        if ([user.accountIdentity isEqual:self->_currentUser.accountIdentity]) {
            _currentUser = nil;
            [self setCurrentUserIdentity:nil];
        }
    }

    [_accountsLock unlock];
    return success;
}

- (SFUserAccount *)applyCredentials:(SFOAuthCredentials*)credentials {
    return [self applyCredentials:credentials withIdData:nil];
}

- (SFUserAccount *)applyCredentials:(SFOAuthCredentials*)credentials withIdData:(SFIdentityData *) identityData {
    return [self applyCredentials:credentials withIdData:identityData andNotification:YES];
}

- (SFUserAccount *)applyCredentials:(SFOAuthCredentials*)credentials withIdData:(SFIdentityData *) identityData andNotification:(BOOL) shouldSendNotification{
    
    SFUserAccount *currentAccount = [self accountForCredentials:credentials];
    SFUserAccountDataChange accountDataChange = SFUserAccountDataChangeUnknown;
    SFUserAccountChange userAccountChange = SFUserAccountChangeUnknown;

    if (currentAccount) {

        if (identityData)
            accountDataChange |= SFUserAccountDataChangeIdData;

        if ([credentials hasPropertyValueChangedForKey:@"accessToken"])
            accountDataChange |= SFUserAccountDataChangeAccessToken;

        if ([credentials hasPropertyValueChangedForKey:@"instanceUrl"])
            accountDataChange |= SFUserAccountDataChangeInstanceURL;

        if ([credentials hasPropertyValueChangedForKey:@"communityId"])
            accountDataChange |= SFUserAccountDataChangeCommunityId;

        if (accountDataChange!=SFUserAccountDataChangeUnknown)
            accountDataChange &= ~SFUserAccountDataChangeUnknown;

        currentAccount.credentials = credentials;
    }else {
        currentAccount = [[SFUserAccount alloc] initWithCredentials:credentials];

        //add the account to our list of possible accounts, but
        //don't set this as the current user account until somebody
        //asks us to login with this account.
        userAccountChange = SFUserAccountChangeNewUser;
    }
    [credentials resetCredentialsChangeSet];
    if (identityData) {
        currentAccount.idData = identityData;
    }
    [self saveAccountForUser:currentAccount error:nil];

    if(shouldSendNotification) {
        if (accountDataChange != SFUserAccountChangeUnknown) {
            [self notifyUserDataChange:SFUserAccountManagerDidChangeUserDataNotification withUser:currentAccount andChange:accountDataChange];
        } else if (userAccountChange!=SFUserAccountDataChangeUnknown) {
            [self notifyUserChange:SFUserAccountManagerDidChangeUserNotification withUser:currentAccount andChange:userAccountChange];
        }
    }
    return currentAccount;
}

- (SFUserAccount*) currentUser {
    if (!_currentUser) {
        [_accountsLock lock];
        NSData *resultData = nil;
        NSUserDefaults *userDefaults = [NSUserDefaults msdkUserDefaults];
        resultData = [userDefaults objectForKey:kUserDefaultsLastUserIdentityKey];
        if (resultData) {
            SFUserAccountIdentity *result = nil;
            NSError* error = nil;
            NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:resultData error:&error];
            unarchiver.requiresSecureCoding = NO;
            if (error) {
                [SFSDKCoreLogger e:[self class] format:@"Failed to init unarchiver for current user identity from user defaults: %@.", error];
            } else {
                result = [unarchiver decodeObjectForKey:kUserDefaultsLastUserIdentityKey];
                [unarchiver finishDecoding];
                if (result) {
                    _currentUser = [self userAccountForUserIdentity:result];
                } else {
                    [SFSDKCoreLogger e:[self class] format:@"Located current user Identity in NSUserDefaults but was not found in list of accounts managed by SFUserAccountManager."];
                }
            }
        }
        [_accountsLock unlock];
    }
    return _currentUser;
}

- (void)setCurrentUserInternal:(SFUserAccount*)user {
    BOOL userChanged = NO;
    if (user != _currentUser) {
        [_accountsLock lock];
        if (!user) {
            //clear current user if  nil
            [self willChangeValueForKey:@"currentUser"];
            _currentUser = nil;
            [self setCurrentUserIdentity:nil];
            [self didChangeValueForKey:@"currentUser"];
            userChanged = YES;
        } else {
            //check if this is valid managed user
            SFUserAccount *userAccount = [self userAccountForUserIdentity:user.accountIdentity];
            if (userAccount) {
                [self willChangeValueForKey:@"currentUser"];
                _currentUser = user;
                [self setCurrentUserIdentity:user.accountIdentity];
                if (user.credentials.domain)
                    self.loginHost = user.credentials.domain;
                [self didChangeValueForKey:@"currentUser"];
                userChanged = YES;
            } else {
                [SFSDKCoreLogger e:[self class] message:@"Cannot set the currentUser. Add the account to the SFAccountManager before making this call."];
            }
        }
        [_accountsLock unlock];
    }
    if (userChanged)
        [self notifyUserChange:SFUserAccountManagerDidChangeUserNotification withUser:_currentUser andChange:SFUserAccountChangeCurrentUser];
}

- (SFUserAccountIdentity *)currentUserIdentity {
    SFUserAccountIdentity *accountIdentity = nil;
    [_accountsLock lock];
    if (!_currentUser) {
        NSUserDefaults *userDefaults = [NSUserDefaults msdkUserDefaults];
        accountIdentity = [userDefaults objectForKey:kUserDefaultsLastUserIdentityKey];
    } else {
        accountIdentity = _currentUser.accountIdentity;
    }
    [_accountsLock unlock];
    return accountIdentity;
}

- (void)setCurrentUserIdentity:(SFUserAccountIdentity*)userAccountIdentity {
    NSUserDefaults *standardDefaults = [NSUserDefaults msdkUserDefaults];
    [_accountsLock lock];
    if (userAccountIdentity) {
        NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:NO];
        [archiver encodeObject:userAccountIdentity forKey:kUserDefaultsLastUserIdentityKey];
        [archiver finishEncoding];
        [standardDefaults setObject:archiver.encodedData forKey:kUserDefaultsLastUserIdentityKey];
    } else {  //clear current user if userAccountIdentity is nil
        [standardDefaults removeObjectForKey:kUserDefaultsLastUserIdentityKey];
    }
    [_accountsLock unlock];
    [standardDefaults synchronize];
}

- (void)applyIdData:(SFIdentityData *)idData forUser:(SFUserAccount *)user {
    if (user) {
        [_accountsLock lock];
        user.idData = idData;
        [self saveAccountForUser:user error:nil];
        [_accountsLock unlock];
        [self notifyUserDataChange:SFUserAccountManagerDidChangeUserDataNotification withUser:user andChange:SFUserAccountDataChangeIdData];
    }
}

- (void)applyIdDataCustomAttributes:(NSDictionary *)customAttributes forUser:(SFUserAccount *)user {
    if (user) {
        [_accountsLock lock];
        user.idData.customAttributes = customAttributes;
        [self saveAccountForUser:user error:nil];
        [_accountsLock unlock];
        [self notifyUserDataChange:SFUserAccountManagerDidChangeUserDataNotification withUser:user andChange:SFUserAccountDataChangeIdData];
    }
}

- (void)applyIdDataCustomPermissions:(NSDictionary *)customPermissions forUser:(SFUserAccount *)user {
     if (user) {
        [_accountsLock lock];
        user.idData.customPermissions = customPermissions;
        [self saveAccountForUser:user error:nil];
        [_accountsLock unlock];
        [self notifyUserDataChange:SFUserAccountManagerDidChangeUserDataNotification withUser:user andChange:SFUserAccountDataChangeIdData];
     }
}

- (void)setObjectForUserCustomData:(NSObject <NSCoding> *)object forKey:(NSString *)key andUser:(SFUserAccount *)user {
    if (user) {
        [_accountsLock lock];
        [user setCustomDataObject:object forKey:key];
        [self saveAccountForUser:user error:nil];
        [_accountsLock unlock];
    }
}

- (NSString *)currentCommunityId {
    NSUserDefaults *userDefaults = [NSUserDefaults msdkUserDefaults];
    return [userDefaults stringForKey:kUserDefaultsLastUserCommunityIdKey];
}

- (void)presentBiometricEnrollment:(nullable SFSDKAppLockViewConfig *)config {
    [SFSecurityLockout presentBiometricEnrollment:config];
}

- (BOOL)deviceHasBiometric {
    return [SFSecurityLockout deviceHasBiometric];
}

- (SFBiometricUnlockState)biometricUnlockState {
    return [SFSecurityLockout biometricState];
}

#pragma mark - private methods
//called by SP app to kick off idp authentication
- (BOOL)authenticateUsingIDP:(SFSDKAuthRequest *)request completion:(SFUserAccountManagerSuccessCallbackBlock)completionBlock failure:(SFUserAccountManagerFailureCallbackBlock)failureBlock {
    
    SFSDKAuthSession *authSession = [[SFSDKAuthSession alloc] initWith:request credentials:nil];
    authSession.isAuthenticating = YES;
    authSession.authFailureCallback = failureBlock;
    authSession.authSuccessCallback = completionBlock;
    authSession.oauthCoordinator.delegate = self;
    self.authSession = authSession;
    if (request.idpInitiatedAuth && request.userHint) {
        //no need to show login selection view
        self.authSession.oauthRequest.appDisplayName = self.appDisplayName;
        [SFSDKIDPAuthHelper invokeIDPApp:self.authSession completion:^(BOOL result) {
           [SFSDKCoreLogger d:[self class] format:@"Launced IDP App"];
        }];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            
            UIViewController<SFSDKLoginFlowSelectionView> *controller  = request.spAppLoginFlowSelectionAction();
            controller.selectionFlowDelegate = self;
            NSMutableDictionary *options = [[NSMutableDictionary alloc] init];
            if (request.userHint) {
                options[kSFUserHintParam] = request.userHint;
            }
            controller.appOptions = options;
            controller.selectionFlowDelegate = [SFUserAccountManager sharedInstance];
            SFSDKWindowContainer *authWindow = [SFSDKWindowManager sharedManager].authWindow;
           
            SFSDKNavigationController *navcontroller = [[SFSDKNavigationController alloc] initWithRootViewController:controller];
            navcontroller.modalPresentationStyle = UIModalPresentationFullScreen;
            [authWindow presentWindowAnimated:NO withCompletion:^{
               authWindow.viewController.modalPresentationStyle = UIModalPresentationFullScreen;
               [authWindow.viewController presentViewController:navcontroller animated:YES completion:^{
               }];
            }];
        });
    }
    return self.authSession.isAuthenticating;
}

- (void)authenticateOnBehalfOfSPApp:(SFUserAccount *)user spAppCredentials:(SFOAuthCredentials *)spAppCredentials {
    
    SFSDKAuthRequest *request = [self defaultAuthRequest];
    self.authSession = [[SFSDKAuthSession alloc] initWith:request credentials:user.credentials spAppCredentials:spAppCredentials];
    self.authSession.oauthCoordinator.delegate = self;
    self.authSession.identityCoordinator.delegate = self;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf dismissAuthViewControllerIfPresent:^{
             [strongSelf.authSession.oauthCoordinator beginIDPFlow];
        }];
    });
}

- (void)populateErrorHandlers {
    __weak typeof (self) weakSelf = self;
    
    self.errorManager.invalidAuthCredentialsErrorHandlerBlock  = ^(NSError *error, SFSDKAuthSession  *session,NSDictionary *options) {
        __strong typeof (weakSelf) strongSelf = weakSelf;
        [SFSDKCoreLogger w:[strongSelf class] format:@"OAuth refresh failed due to invalid grant.  Error code: %ld", (long)error.code];
        session.notifiesDelegatesOfFailure = NO;
        [strongSelf handleFailure:error session:session];
    };
    
    self.errorManager.networkErrorHandlerBlock = ^(NSError *error, SFSDKAuthSession *session,NSDictionary *options) {
        __strong typeof (weakSelf) strongSelf = weakSelf;
        session.notifiesDelegatesOfFailure = NO;
        [strongSelf loggedIn:YES coordinator:session.oauthCoordinator notifyDelegatesOfFailure:NO];
    };
    
    self.errorManager.hostConnectionErrorHandlerBlock = ^(NSError *error, SFSDKAuthSession *session, NSDictionary *options) {
        __strong typeof (weakSelf) strongSelf = weakSelf;
        NSString *alertMessage = [NSString stringWithFormat:[SFSDKResourceUtils localizedString:kAlertConnectionErrorFormatStringKey], [error localizedDescription]];
        NSString *okButton = [SFSDKResourceUtils localizedString:kAlertOkButtonKey];
        [strongSelf showErrorAlertWithMessage:alertMessage buttonTitle:okButton andCompletion:^() {
            [session.oauthCoordinator stopAuthentication];
            [strongSelf notifyUserCancelledOrDismissedAuth:session.oauthCoordinator.credentials andAuthInfo:session.authInfo];
            NSString *host = [[SFSDKLoginHostStorage sharedInstance] loginHostAtIndex:0].host;
            session.oauthRequest.loginHost = host;
            strongSelf.loginHost = host;
            [strongSelf restartAuthentication:session];
        }];
    };
    
    self.errorManager.genericErrorHandlerBlock = ^(NSError *error, SFSDKAuthSession *session,NSDictionary *options) {
        __strong typeof (weakSelf) strongSelf = weakSelf;

        NSString *message =[NSString stringWithFormat:[SFSDKResourceUtils localizedString:kAlertConnectionErrorFormatStringKey], [error localizedDescription]];
        NSString *retryButton = [SFSDKResourceUtils localizedString:kAlertOkButtonKey];
        [strongSelf showErrorAlertWithMessage:message buttonTitle:retryButton   andCompletion:^() {
            //TODO: RestartAuth
            [strongSelf restartAuthentication:session];
        }];
    };
    
    self.errorManager.connectedAppVersionMismatchErrorHandlerBlock = ^(NSError *  error, SFSDKAuthSession *session,NSDictionary *options) {
         __strong typeof (weakSelf) strongSelf = weakSelf;
        [SFSDKCoreLogger w:[strongSelf class] format:@"OAuth refresh failed due to Connected App version mismatch.  Error code: %ld", (long)error.code];
        [strongSelf showAlertForConnectedAppVersionMismatchError:error session:session];
    };
}

- (void)showErrorAlertWithMessage:(NSString *)alertMessage buttonTitle:(NSString *)buttonTitle andCompletion:(void(^)(void))completionBlock {
    __weak typeof (self) weakSelf = self;
    SFSDKAlertMessage *message = [SFSDKAlertMessage messageWithBlock:^(SFSDKAlertMessageBuilder *builder) {
        builder.alertTitle = [SFSDKResourceUtils localizedString:kAlertErrorTitleKey];
        builder.alertMessage = alertMessage;
        builder.actionOneTitle = buttonTitle;
        builder.actionOneCompletion = ^{
            completionBlock();
        };
    }];
    dispatch_async(dispatch_get_main_queue(), ^{
        SFSDK_USE_DEPRECATED_BEGIN // TODO: Remove in Mobile SDK 9.0
        weakSelf.alertDisplayBlock(message, SFSDKWindowManager.sharedManager.authWindow);
        SFSDK_USE_DEPRECATED_END
    });
}

- (void)showAlertForConnectedAppVersionMismatchError:(NSError *)error session:(SFSDKAuthSession *)session {
     __weak typeof (self) weakSelf = self;
    SFSDKAlertMessage *message = [SFSDKAlertMessage messageWithBlock:^(SFSDKAlertMessageBuilder *builder) {
        __strong typeof (weakSelf) strongSelf = weakSelf;
        builder.alertTitle = [SFSDKResourceUtils localizedString:kAlertErrorTitleKey];
        builder.alertMessage = [SFSDKResourceUtils localizedString:kAlertVersionMismatchErrorKey];
        builder.actionOneTitle = [SFSDKResourceUtils localizedString:kAlertErrorTitleKey];
        builder.actionTwoTitle = [SFSDKResourceUtils localizedString:kAlertDismissButtonKey];
        builder.actionOneCompletion = ^{
            session.notifiesDelegatesOfFailure = NO;
            [strongSelf handleFailure:error session:session];
        };
    }];
    dispatch_async(dispatch_get_main_queue(), ^{
        SFSDK_USE_DEPRECATED_BEGIN // TODO: Remove in Mobile SDK 9.0
        weakSelf.alertDisplayBlock(message, SFSDKWindowManager.sharedManager.authWindow);
        SFSDK_USE_DEPRECATED_END
    });
}

- (void)loggedIn:(BOOL)fromOffline coordinator:(SFOAuthCoordinator *)coordinator notifyDelegatesOfFailure:(BOOL)shouldNotify {
    if (!fromOffline) {
        SFIdentityCoordinator *identityCoordinator = [[SFIdentityCoordinator alloc] initWithAuthSession:coordinator.authSession];
        self.authSession.identityCoordinator = identityCoordinator;
        self.authSession.notifiesDelegatesOfFailure = shouldNotify;
        identityCoordinator.delegate = self;
        [identityCoordinator initiateIdentityDataRetrieval];
    } else {
        [self retrievedIdentityData:coordinator.authSession];
    }
}

- (void)retrievedIdentityData:(SFSDKAuthSession *)authSession {
    // NB: This method is assumed to run after identity data has been refreshed from the service, or otherwise
    // already exists.
    NSAssert(authSession.identityCoordinator.idData != nil, @"Identity data should not be nil/empty at this point.");
    SFIdentityCoordinator *identityCoordinator = authSession.identityCoordinator;
    NSNumber *biometricUnlockKey = [identityCoordinator.idData.customAttributes objectForKey:@"BIOMETRIC_UNLOCK"];
    BOOL biometricUnlockAvailable = (biometricUnlockKey == nil) ? YES : [biometricUnlockKey boolValue];
    __weak typeof(self) weakSelf = self;
    [self dismissAuthViewControllerIfPresent:^{
          __strong typeof(weakSelf) strongSelf = weakSelf;
        if (authSession.authInfo.authType != SFOAuthTypeRefresh) {
           [SFSecurityLockout setPasscodeViewConfig:authSession.oauthRequest.appLockViewControllerConfig];
           [SFSecurityLockout setLockScreenSuccessCallbackBlock:^(SFSecurityLockoutAction action) {
               [strongSelf finalizeAuthCompletion:authSession];
           }];
           [SFSecurityLockout setLockScreenFailureCallbackBlock:^{
               strongSelf.authSession.notifiesDelegatesOfFailure = YES;
               [strongSelf handleFailure:authSession.authError session:strongSelf.authSession];
           }];
           // Check to see if a passcode needs to be created or updated, based on passcode policy data from the
           // identity service.
           [SFSecurityLockout setInactivityConfiguration:identityCoordinator.idData.mobileAppPinLength
                                             lockoutTime:(identityCoordinator.idData.mobileAppScreenLockTimeout * 60)
                                        biometricAllowed:biometricUnlockAvailable];
       } else {
           [strongSelf finalizeAuthCompletion:authSession];
       }
    }];
    
   
}

- (void)handleFailure:(NSError *)error session:(SFSDKAuthSession *)authSession {
    
    if(authSession.authFailureCallback) {
        authSession.authFailureCallback(authSession.authInfo,error);
    }
  
    if (authSession.notifiesDelegatesOfFailure) {
         __weak typeof(self) weakSelf = self;
        [self enumerateDelegates:^(id <SFUserAccountManagerDelegate> delegate) {
            if ([delegate respondsToSelector:@selector(userAccountManager:error:info:)]) {
                [delegate userAccountManager:weakSelf error:error info:authSession.authInfo];
            }
        }];
    }
    [self resetAuthentication];
}

- (void)resetAuthentication {
    
    [_accountsLock lock];
    if (self.authSession.authInfo.authType == SFOAuthTypeUserAgent) {
        [self.authSession.oauthCoordinator.view removeFromSuperview];
    }
    [self.authSession.oauthCoordinator stopAuthentication];
    self.authSession.identityCoordinator.idData = nil;
    self.authSession.isAuthenticating = NO;
    self.authSession = nil;
    [_accountsLock unlock];
}

- (void)finalizeAuthCompletion:(SFSDKAuthSession *)authSession {
    SFSDK_USE_DEPRECATED_BEGIN // TODO: Remove in Mobile SDK 9.0
    // Apply the credentials that will ensure there is a user and that this
    // current user as the proper credentials.
    SFUserAccount *userAccount = [self applyCredentials:authSession.oauthCoordinator.credentials withIdData:authSession.identityCoordinator.idData];
    SFSDK_USE_DEPRECATED_END
    BOOL loginStateTransitionSucceeded = [userAccount transitionToLoginState:SFUserAccountLoginStateLoggedIn];
    if (!loginStateTransitionSucceeded) {

        // We're in an unlikely, but nevertheless bad state. Fail this authentication.
        [SFSDKCoreLogger e:[self class] format:@"%@: Unable to transition user to a logged in state.  Login failed.", NSStringFromSelector(_cmd)];
        NSString *reason = [NSString stringWithFormat:@"Unable to transition user to a logged in state.  Login failed "];
        [SFSDKCoreLogger w:[self class] format:reason];
        NSError *error = [NSError errorWithDomain:@"SFUserAccountManager"
                                             code:1005
                                         userInfo:@{ NSLocalizedDescriptionKey : reason } ];
        self.authSession.notifiesDelegatesOfFailure = YES;
        [self handleFailure:error session:authSession];
        return;
    }

    // Notify the session is ready.
    [self initAnalyticsManager];
    [self handleAnalyticsAddUserEvent:authSession account:userAccount];
    
    // Async call, ignore if theres a failure. If success save the user photo locally.
    [self retrieveUserPhotoIfNeeded:userAccount];
    BOOL shouldNotify = YES;
    
    if (self.currentUser == nil || !authSession.oauthRequest.authenticateRequestFromSPApp) {
        [self setCurrentUserInternal:userAccount];
    }

    shouldNotify = authSession.oauthRequest.authenticateRequestFromSPApp?(authSession.oauthRequest.authenticateRequestFromSPApp && self.currentUser == nil):YES;
    SFOAuthInfo *authInfo = authSession.authInfo;
    
    if (authSession.authSuccessCallback) {
        authSession.authSuccessCallback(authSession.authInfo,userAccount);
    }
    //notify for all login flows except during an SP apps login request.
    if (shouldNotify) {
        [self notifyLoginCompletion:userAccount authInfo:authInfo];
    }
    
    
    if (!authSession.oauthRequest.authenticateRequestFromSPApp) {
        [self resetAuthentication];
    }

}
- (void)notifyLoginCompletion:(SFUserAccount *)userAccount authInfo:(SFOAuthInfo *)authInfo {
     
     NSDictionary *userInfo = @{kSFNotificationUserInfoAccountKey: userAccount,
                                kSFNotificationUserInfoAuthTypeKey: authInfo};
     if (self.authSession.authInfo.authType != SFOAuthTypeRefresh) {
         [[NSNotificationCenter defaultCenter] postNotificationName:kSFNotificationUserDidLogIn
                                                             object:self
                                                           userInfo:userInfo];
     }  else if (self.authSession.authInfo.authType == SFOAuthTypeRefresh) {
         [[NSNotificationCenter defaultCenter] postNotificationName:kSFNotificationUserDidRefreshToken
                                                             object:self
                                                           userInfo:userInfo];
     }
    
}

- (void)retrieveUserPhotoIfNeeded:(SFUserAccount *)account {
    if (account.idData.thumbnailUrl) {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:account.idData.thumbnailUrl];
        [request setHTTPMethod:@"GET"];
        [request setValue:[NSString stringWithFormat:kHttpAuthHeaderFormatString, account.credentials.accessToken] forHTTPHeaderField:kHttpHeaderAuthorization];
        SFNetwork *network = [SFNetwork sharedEphemeralInstance];
        [network sendRequest:request  dataResponseBlock:^(NSData *data, NSURLResponse *response, NSError *error){
            if (error) {
                [SFSDKCoreLogger w:[self class] format:@"Error while trying to retrieve user photo: %ld %@", (long) error.code, error.localizedDescription];
                return;
            } else {
                UIImage *photo = [UIImage imageWithData:data];
                [account setPhoto:photo completion:nil];
            }
        }];
    }
}

- (void)handleAnalyticsAddUserEvent:(SFSDKAuthSession *)authSession account:(SFUserAccount *) userAccount {
    if (authSession.authInfo.authType == SFOAuthTypeRefresh) {
        [SFSDKEventBuilderHelper createAndStoreEvent:@"tokenRefresh" userAccount:userAccount className:NSStringFromClass([self class]) attributes:nil];
    } else {

        // Logging events for add user and number of servers.
        NSArray *accounts = self.allUserAccounts;
        NSMutableDictionary *userAttributes = [[NSMutableDictionary alloc] init];
        userAttributes[@"numUsers"] = [NSNumber numberWithInteger:(accounts ? accounts.count : 0)];
        [SFSDKEventBuilderHelper createAndStoreEvent:@"addUser" userAccount:userAccount  className:NSStringFromClass([self class]) attributes:userAttributes];
        NSInteger numHosts = [SFSDKLoginHostStorage sharedInstance].numberOfLoginHosts;
        NSMutableArray<NSString *> *hosts = [[NSMutableArray alloc] init];
        for (int i = 0; i < numHosts; i++) {
            SFSDKLoginHost *host = [[SFSDKLoginHostStorage sharedInstance] loginHostAtIndex:i];
            if (host.host) {
                [hosts addObject:host.host];
            }
        }
        NSMutableDictionary *serverAttributes = [[NSMutableDictionary alloc] init];
        serverAttributes[@"numLoginServers"] = [NSNumber numberWithInteger:numHosts];
        serverAttributes[@"loginServers"] = hosts;
        [SFSDKEventBuilderHelper createAndStoreEvent:@"addUser" userAccount:nil className:NSStringFromClass([self class]) attributes:serverAttributes];
    }
}

- (void)initAnalyticsManager {
    SFSDKSalesforceAnalyticsManager *analyticsManager = [SFSDKSalesforceAnalyticsManager sharedInstanceWithUser:self.currentUser];
    [analyticsManager updateLoggingPrefs];
}

#pragma mark Switching Users
- (void)switchToNewUserWithCompletion:(void (^)(NSError *error, SFUserAccount * currentAccount))completion {
    SFUserAccount *prevUser = self.currentUser;
    if (!self.currentUser) {
        NSError *error = [[NSError alloc] initWithDomain:kSFSDKUserAccountManagerErrorDomain
                                                    code:SFSDKUserAccountManagerError
                                                userInfo:@{
                                                           NSLocalizedDescriptionKey : @"Cannot switch to new user. No currentUser has been set."
                                                           }];
        completion(error,nil);
    } else {
        [self stopCurrentAuthentication:^(BOOL result) {
            [self loginWithCompletion:^(SFOAuthInfo *authInfo, SFUserAccount *userAccount) {
                [self fireNotificationForSwitchUserFrom:prevUser to:userAccount];
                if (completion) {
                    completion(nil, userAccount);
                }
            } failure:^(SFOAuthInfo * authInfo, NSError * error) {
                if (completion) {
                    completion(error,nil);
                }
            }];
        }];
    }
}

- (void)switchToUser:(SFUserAccount *)newCurrentUser {
    if ([self.currentUser.accountIdentity isEqual:newCurrentUser.accountIdentity]) {
        [SFSDKCoreLogger w:[self class] format:@"%@ new user identity is the same as the current user.  No action taken.", NSStringFromSelector(_cmd)];
    } else {
        [self fireNotificationForSwitchUserFrom:self.currentUser to:newCurrentUser];
    }
}

- (void)fireNotificationForSwitchUserFrom:(SFUserAccount *)fromUser to:(SFUserAccount *)toUser {
    
    [self enumerateDelegates:^(id<SFUserAccountManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(userAccountManager:willSwitchFromUser:toUser:)]) {
            [delegate userAccountManager:self willSwitchFromUser:fromUser toUser:toUser];
        }
    }];
    [[NSNotificationCenter defaultCenter] postNotificationName:kSFNotificationUserWillSwitch
                                                        object:self
                                                      userInfo:@{
                                                          kSFNotificationFromUserKey: fromUser ?: [NSNull null],
                                                                 kSFNotificationToUserKey: toUser?: [NSNull null]
                                                                 }];
    
    [self setCurrentUserInternal:toUser];
    [self enumerateDelegates:^(id<SFUserAccountManagerDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(userAccountManager:didSwitchFromUser:toUser:)]) {
            [delegate userAccountManager:self didSwitchFromUser:fromUser toUser:toUser];
        }
    }];
    [[NSNotificationCenter defaultCenter] postNotificationName:kSFNotificationUserDidSwitch
                                                        object:self
                                                      userInfo:@{
                                                                 kSFNotificationFromUserKey: fromUser ?: [NSNull null],
                                                                 kSFNotificationToUserKey: toUser?: [NSNull null]
                                                                 }];
}

#pragma mark - User Change Notifications
- (void)userChanged:(SFUserAccount *)user change:(SFUserAccountDataChange)change {
    [self notifyUserDataChange:SFUserAccountManagerDidChangeUserDataNotification withUser:user andChange:change];
}

- (void)notifyUserDataChange:(NSString *)notificationName withUser:(SFUserAccount *)user andChange:(SFUserAccountDataChange)change {
    if (user) {
        [[NSNotificationCenter defaultCenter] postNotificationName:notificationName
                                                            object:user
                                                          userInfo:@{
                                                                SFUserAccountManagerUserChangeKey: @(change)
                                                          }];
    }

}

- (void)notifyUserChange:(NSString *)notificationName withUser:(SFUserAccount *)user andChange:(SFUserAccountChange)change {
    if (user) {
        [[NSNotificationCenter defaultCenter] postNotificationName:notificationName
                                                            object:self
                                                          userInfo:@{
                                                                  SFUserAccountManagerUserChangeKey: @(change),                                                                  SFUserAccountManagerUserChangeUserKey: user
                                                          }];
    }else {
        [[NSNotificationCenter defaultCenter] postNotificationName:notificationName
                                                            object:self
                                                          userInfo:@{
                                                                  SFUserAccountManagerUserChangeKey: @(change)
                                                          }];

    }
}

- (void)notifyUserCancelledOrDismissedAuth:(SFOAuthCredentials *)credentials andAuthInfo:(SFOAuthInfo *)info {
    NSMutableDictionary *userInfo = [NSMutableDictionary new];
    userInfo[kSFNotificationUserInfoCredentialsKey] = credentials;
    if (info) {
        userInfo[kSFNotificationUserInfoAuthTypeKey] = info;
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:kSFNotificationUserCancelledAuth
                                                        object:self
                                                      userInfo:[userInfo copy]];
}

- (void)reload {
    [_accountsLock lock];
    if(!_accountPersister)
        _accountPersister = [SFDefaultUserAccountPersister new];
    [self loadAccounts:nil];
    [_accountsLock unlock];
}

- (void)presentLoginView:(SFSDKAuthViewHolder *)viewHandler {
   
    [[SFSDKWindowManager sharedManager].authWindow presentWindow];
    void (^presentViewBlock)(void) = ^void() {
        if (!viewHandler.isAdvancedAuthFlow) {
            UIViewController *controllerToPresent = [[SFSDKNavigationController  alloc]  initWithRootViewController:viewHandler.loginController];
            controllerToPresent.modalPresentationStyle = UIModalPresentationFullScreen;
            [[SFSDKWindowManager sharedManager].authWindow.viewController presentViewController:controllerToPresent animated:NO completion:^{
                NSAssert((nil != [viewHandler.loginController.oauthView superview]), @"No superview for oauth web view invoke [super viewDidLayoutSubviews] in the SFLoginViewController subclass");
            }];
        }
        else {
            if (@available(iOS 13.0, *)) {
                SFSDKAuthRootController* authRootController = [[SFSDKAuthRootController alloc] init];
                [SFSDKWindowManager sharedManager].authWindow.viewController = authRootController;
                authRootController.modalPresentationStyle = UIModalPresentationFullScreen;
                viewHandler.session.presentationContextProvider = (id<ASWebAuthenticationPresentationContextProviding>) [SFSDKWindowManager sharedManager].authWindow.viewController;
            }
           [viewHandler.session start];
        }
    };
  
    //dismiss if already presented and then present
    UIViewController* presentedViewController = [SFSDKWindowManager sharedManager].authWindow.viewController.presentedViewController;
    if ([self isAlreadyPresentingLoginController:presentedViewController]) {
        [presentedViewController dismissViewControllerAnimated:NO completion:^{
            presentViewBlock();
        }];
    } else {
        presentViewBlock();
    }
 }

- (BOOL)isAlreadyPresentingLoginController:(UIViewController*)presentedViewController {
    return (presentedViewController
            && !presentedViewController.beingDismissed
            && [presentedViewController isKindOfClass:[SFSDKNavigationController class]]
            && [((SFSDKNavigationController*) presentedViewController).topViewController isKindOfClass:[SFLoginViewController class]]);
}

- (SFLoginViewController *)createLoginViewControllerInstance:(SFOAuthCoordinator *)coordinator {
    SFLoginViewController *controller = nil;
    if (coordinator.authSession.oauthRequest.loginViewControllerConfig.loginViewControllerCreationBlock) {
        controller = coordinator.authSession.oauthRequest.loginViewControllerConfig.loginViewControllerCreationBlock();
    } else {
        controller = [[SFLoginViewController alloc] initWithNibName:nil bundle:nil];
    }
    [controller setConfig:coordinator.authSession.oauthRequest.loginViewControllerConfig];
    [controller setDelegate:self];
    return controller;
}


@end
