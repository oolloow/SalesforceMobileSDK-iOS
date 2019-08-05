/* 
 * Copyright (c) 2013-present, salesforce.com, inc.
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided 
 * that the following conditions are met:
 * 
 *    Redistributions of source code must retain the above copyright notice, this list of conditions and the 
 *    following disclaimer.
 *  
 *    Redistributions in binary form must reproduce the above copyright notice, this list of conditions and 
 *    the following disclaimer in the documentation and/or other materials provided with the distribution. 
 *    
 *    Neither the name of salesforce.com, inc. nor the names of its contributors may be used to endorse or 
 *    promote products derived from this software without specific prior written permission.
 *  
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED 
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A 
 * PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR 
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED 
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING 
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
 * POSSIBILITY OF SUCH DAMAGE.
 */

#import <SalesforceSDKCommon/SFJsonUtils.h>
#import "SFRestAPI+Files.h"
#import "SFRestRequest+Internal.h"
#import "SFOAuthCredentials.h"
#define ME @"me"
#define PAGE @"page"
#define VERSION @"versionNumber"
#define CONTENT_DOCUMENT_ID @"ContentDocumentId"
#define LINKED_ENTITY_ID @"LinkedEntityId"
#define SHARE_TYPE @"ShareType"
#define RENDITION_TYPE @"type"
#define FILE_DATA @"fileData"
#define FILE_UPLOAD @"fileUpload"

@implementation SFRestAPI (Files)

- (SFRestRequest *)requestForOwnedFilesList:(NSString *)userId page:(NSUInteger)page {
    return [self requestForOwnedFilesList:userId page:page apiVersion:self.apiVersion];
}

- (SFRestRequest *)requestForOwnedFilesList:(NSString *)userId page:(NSUInteger)page apiVersion:(NSString *)apiVersion {
    NSString *path = [NSString stringWithFormat:@"/%@/connect%@/files/users/%@", [self computeAPIVersion:apiVersion], [self communitiesUrlPathIfRequired],  (userId == nil ? ME : userId)];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if (page) params[PAGE] = @(page);
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:params];
}

- (SFRestRequest *)requestForFilesInUsersGroups:(NSString *)userId page:(NSUInteger)page {
    return [self requestForFilesInUsersGroups:userId page:page apiVersion:self.apiVersion];
}

- (SFRestRequest *)requestForFilesInUsersGroups:(NSString *)userId page:(NSUInteger)page apiVersion:(NSString *)apiVersion {
    NSString *path = [NSString stringWithFormat:@"/%@/connect%@/files/users/%@/filter/groups", [self computeAPIVersion:apiVersion], [self communitiesUrlPathIfRequired], (userId == nil ? ME : userId)];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if (page) params[PAGE] = @(page);
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:params];
}

- (SFRestRequest *)requestForFilesSharedWithUser:(NSString *)userId page:(NSUInteger)page {
    return [self requestForFilesSharedWithUser:userId page:page apiVersion:self.apiVersion];
}

- (SFRestRequest *)requestForFilesSharedWithUser:(NSString *)userId page:(NSUInteger)page apiVersion:(NSString *)apiVersion {
    NSString *path = [NSString stringWithFormat:@"/%@/connect%@/files/users/%@/filter/sharedwithme", [self computeAPIVersion:apiVersion], [self communitiesUrlPathIfRequired],(userId == nil ? ME : userId)];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if (page) params[PAGE] = @(page);
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:params];
}

- (SFRestRequest *)requestForFileDetails:(NSString *)sfdcId forVersion:(NSString *)version {
    return [self requestForFileDetails:sfdcId forVersion:version apiVersion:self.apiVersion];
}

- (SFRestRequest *)requestForFileDetails:(NSString *)sfdcId forVersion:(NSString *)version apiVersion:(NSString *)apiVersion {
    NSString *path = [NSString stringWithFormat:@"/%@/connect%@/files/%@", [self computeAPIVersion:apiVersion], [self communitiesUrlPathIfRequired], sfdcId];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if (version) params[VERSION] = version;
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:params];
}

- (SFRestRequest *)requestForBatchFileDetails:(NSArray *)sfdcIds {
    return [self requestForBatchFileDetails:sfdcIds apiVersion:self.apiVersion];
}

- (SFRestRequest *)requestForBatchFileDetails:(NSArray *)sfdcIds apiVersion:(NSString *)apiVersion {
    NSString *ids = [sfdcIds componentsJoinedByString:@","];
    NSString *path = [NSString stringWithFormat:@"/%@/connect%@/files/batch/%@", [self computeAPIVersion:apiVersion], [self communitiesUrlPathIfRequired], ids];
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:nil];
}

- (SFRestRequest *)requestForFileRendition:(NSString *)sfdcId version:(NSString *)version renditionType:(NSString *)renditionType page:(NSUInteger)page {
    return [self requestForFileRendition:sfdcId version:version renditionType:renditionType page:page apiVersion:self.apiVersion];
}

- (SFRestRequest *)requestForFileRendition:(NSString *)sfdcId version:(NSString *)version renditionType:(NSString *)renditionType page:(NSUInteger)page apiVersion:(NSString *)apiVersion {
    NSString *path = [NSString stringWithFormat:@"/%@/connect%@/files/%@/rendition", [self computeAPIVersion:apiVersion], [self communitiesUrlPathIfRequired], sfdcId];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[RENDITION_TYPE] = renditionType;
    if (page) params[PAGE] = @(page);
    if (version) params[VERSION] = version;
    SFRestRequest *request = [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:params];
    return request;
}

- (SFRestRequest *)requestForFileContents:(NSString *)sfdcId version:(NSString *)version {
    return [self requestForFileContents:sfdcId version:version apiVersion:self.apiVersion];
}

- (SFRestRequest *)requestForFileContents:(NSString *)sfdcId version:(NSString *)version apiVersion:(NSString *)apiVersion {
    NSString *path = [NSString stringWithFormat:@"/%@/connect%@/files/%@/content", [self computeAPIVersion:apiVersion], [self communitiesUrlPathIfRequired], sfdcId];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if (version) params[VERSION] = version;
    SFRestRequest *request = [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:params];
    return request;
}

- (SFRestRequest *)requestForFileShares:(NSString *)sfdcId page:(NSUInteger)page {
    return [self requestForFileShares:sfdcId page:page apiVersion:self.apiVersion];
}

- (SFRestRequest *)requestForFileShares:(NSString *)sfdcId page:(NSUInteger)page apiVersion:(NSString *)apiVersion {
    NSString *path = [NSString stringWithFormat:@"/%@/connect%@/files/%@/file-shares", [self computeAPIVersion:apiVersion], [self communitiesUrlPathIfRequired], sfdcId];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if (page) params[PAGE] = @(page);
    return [SFRestRequest requestWithMethod:SFRestMethodGET path:path queryParams:params];
}

- (SFRestRequest *)requestForAddFileShare:(NSString *)fileId entityId:(NSString *)entityId shareType:(NSString *)shareType {
    return [self requestForAddFileShare:fileId entityId:entityId shareType:shareType apiVersion:self.apiVersion];
}

- (SFRestRequest *)requestForAddFileShare:(NSString *)fileId entityId:(NSString *)entityId shareType:(NSString *)shareType apiVersion:(NSString *)apiVersion {
    NSString *path = [NSString stringWithFormat:@"/%@/sobjects/ContentDocumentLink", [self computeAPIVersion:apiVersion]];
    NSDictionary *params = @{CONTENT_DOCUMENT_ID: fileId, LINKED_ENTITY_ID: entityId, SHARE_TYPE: shareType};
    SFRestRequest *request = [SFRestRequest requestWithMethod:SFRestMethodPOST path:path queryParams:nil];
    if (params) {
        request.requestBodyAsDictionary = params;
        NSData *body = [SFJsonUtils JSONDataRepresentation:params options:0];
        if (body) {
            [request setCustomRequestBodyData:body contentType:@"application/json"];
        }
    }
    return request;
}

- (SFRestRequest *)requestForDeleteFileShare:(NSString *)shareId {
    return [self requestForDeleteFileShare:shareId apiVersion:self.apiVersion];
}

- (SFRestRequest *)requestForDeleteFileShare:(NSString *)shareId apiVersion:(NSString *)apiVersion {
    NSString *path = [NSString stringWithFormat:@"/%@/sobjects/ContentDocumentLink/%@", [self computeAPIVersion:apiVersion], shareId];
    return [SFRestRequest requestWithMethod:SFRestMethodDELETE path:path queryParams:nil];
}

- (SFRestRequest *)requestForUploadFile:(NSData *)data name:(NSString *)name description:(NSString *)description mimeType:(NSString *)mimeType {
    return [self requestForUploadFile:data name:name description:description mimeType:mimeType apiVersion:self.apiVersion];
}

- (SFRestRequest *)requestForUploadFile:(NSData *)data name:(NSString *)name description:(NSString *)description mimeType:(NSString *)mimeType apiVersion:(NSString *)apiVersion {
    NSString *path = [NSString stringWithFormat:@"/%@/connect%@/files/users/me", [self computeAPIVersion:apiVersion], [self communitiesUrlPathIfRequired]];
    SFRestRequest *request = [SFRestRequest requestWithMethod:SFRestMethodPOST path:path queryParams:nil];
    NSDictionary *params = @{@"title" : name, @"desc" : description};
    [request addPostFileData:data paramName:FILE_DATA fileName:name mimeType:mimeType params:params];
    return request;
}

- (SFRestRequest *)requestForProfilePhotoUpload:(NSData *)data fileName:(NSString *)fileName mimeType:(NSString *)mimeType userId:(NSString *)userId {
    return [self requestForProfilePhotoUpload:data fileName:fileName mimeType:mimeType userId:userId apiVersion:self.apiVersion];
}

- (SFRestRequest *)requestForProfilePhotoUpload:(NSData *)data fileName:(NSString *)fileName mimeType:(NSString *)mimeType userId:(NSString *)userId apiVersion:(NSString *)apiVersion {
    NSString *path = [NSString stringWithFormat:@"/%@/connect%@/user-profiles/%@/photo", [self computeAPIVersion:apiVersion], [self communitiesUrlPathIfRequired], userId];
    SFRestRequest *request = [SFRestRequest requestWithMethod:SFRestMethodPOST path:path queryParams:nil];
    [request addPostFileData:data paramName:FILE_UPLOAD fileName:fileName mimeType:mimeType params:nil];
    return request;
}

- (NSString *)communitiesUrlPathIfRequired {
    if (!self.user.communityId) {
        return @"";
    }
    return [NSString stringWithFormat:@"/communities/%@", self.user.communityId];
}

- (NSString *)computeAPIVersion:(NSString *)apiVersion {
    return (apiVersion != nil ? apiVersion : self.apiVersion);
}

@end
