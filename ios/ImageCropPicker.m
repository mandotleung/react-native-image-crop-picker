//
//  ImageManager.m
//
//  Created by Ivan Pusic on 5/4/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ImageCropPicker.h"

#define ERROR_PICKER_CANNOT_RUN_CAMERA_ON_SIMULATOR_KEY @"E_PICKER_CANNOT_RUN_CAMERA_ON_SIMULATOR"
#define ERROR_PICKER_CANNOT_RUN_CAMERA_ON_SIMULATOR_MSG @"Cannot run camera on simulator"

#define ERROR_PICKER_NO_CAMERA_PERMISSION_KEY @"E_PICKER_NO_CAMERA_PERMISSION"
#define ERROR_PICKER_NO_CAMERA_PERMISSION_MSG @"User did not grant camera permission."

#define ERROR_PICKER_UNAUTHORIZED_KEY @"E_PERMISSION_MISSING"
#define ERROR_PICKER_UNAUTHORIZED_MSG @"Cannot access images. Please allow access if you want to be able to select images."

#define ERROR_PICKER_CANCEL_KEY @"E_PICKER_CANCELLED"
#define ERROR_PICKER_CANCEL_MSG @"User cancelled image selection"

#define ERROR_PICKER_NO_DATA_KEY @"E_NO_IMAGE_DATA_FOUND"
#define ERROR_PICKER_NO_DATA_MSG @"Cannot find image data"

#define ERROR_CROPPER_IMAGE_NOT_FOUND_KEY @"E_CROPPER_IMAGE_NOT_FOUND"
#define ERROR_CROPPER_IMAGE_NOT_FOUND_MSG @"Can't find the image at the specified path"

#define ERROR_CLEANUP_ERROR_KEY @"E_ERROR_WHILE_CLEANING_FILES"
#define ERROR_CLEANUP_ERROR_MSG @"Error while cleaning up tmp files"

#define ERROR_CANNOT_SAVE_IMAGE_KEY @"E_CANNOT_SAVE_IMAGE"
#define ERROR_CANNOT_SAVE_IMAGE_MSG @"Cannot save image. Unable to write to tmp location."

#define ERROR_CANNOT_PROCESS_VIDEO_KEY @"E_CANNOT_PROCESS_VIDEO"
#define ERROR_CANNOT_PROCESS_VIDEO_MSG @"Cannot process video data"

@implementation ImageResult
@end

@implementation ImageCropPicker

RCT_EXPORT_MODULE();

@synthesize bridge = _bridge;

- (instancetype)init
{
    if (self = [super init]) {
        self.defaultOptions = @{
                                @"multiple": @NO,
                                @"cropping": @NO,
                                @"cropperCircleOverlay": @NO,
                                @"includeBase64": @NO,
                                @"compressVideo": @YES,
                                @"minFiles": @1,
                                @"maxFiles": @5,
                                @"width": @200,
                                @"waitAnimationEnd": @YES,
                                @"height": @200,
                                @"useFrontCamera": @NO,
                                @"compressImageQuality": @1,
                                @"compressVideoPreset": @"MediumQuality",
                                @"loadingLabelText": @"Processing assets...",
                                @"mediaType": @"any",
                                @"showsSelectedCount": @YES
                                @"copyMetaData":@NO,
                                @"checkProjectionType": @NO,
                                @"compressImage": @YES,
                                };
        self.compression = [[Compression alloc] init];
    }

    return self;
}

- (void (^ __nullable)(void))waitAnimationEnd:(void (^ __nullable)(void))completion {
    if ([[self.options objectForKey:@"waitAnimationEnd"] boolValue]) {
        return completion;
    }

    if (completion != nil) {
        completion();
    }

    return nil;
}

- (void)checkCameraPermissions:(void(^)(BOOL granted))callback
{
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (status == AVAuthorizationStatusAuthorized) {
        callback(YES);
        return;
    } else if (status == AVAuthorizationStatusNotDetermined){
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            callback(granted);
            return;
        }];
    } else {
        callback(NO);
    }
}

- (void) setConfiguration:(NSDictionary *)options
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject {

    self.resolve = resolve;
    self.reject = reject;
    self.options = [NSMutableDictionary dictionaryWithDictionary:self.defaultOptions];
    for (NSString *key in options.keyEnumerator) {
        [self.options setValue:options[key] forKey:key];
    }
}

- (UIViewController*) getRootVC {
    UIViewController *root = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
    while (root.presentedViewController != nil) {
        root = root.presentedViewController;
    }

    return root;
}

RCT_EXPORT_METHOD(openCamera:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {

    [self setConfiguration:options resolver:resolve rejecter:reject];
    self.cropOnly = NO;

#if TARGET_IPHONE_SIMULATOR
    self.reject(ERROR_PICKER_CANNOT_RUN_CAMERA_ON_SIMULATOR_KEY, ERROR_PICKER_CANNOT_RUN_CAMERA_ON_SIMULATOR_MSG, nil);
    return;
#else
    [self checkCameraPermissions:^(BOOL granted) {
        if (!granted) {
            self.reject(ERROR_PICKER_NO_CAMERA_PERMISSION_KEY, ERROR_PICKER_NO_CAMERA_PERMISSION_MSG, nil);
            return;
        }

        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.delegate = self;
        picker.allowsEditing = NO;
        picker.sourceType = UIImagePickerControllerSourceTypeCamera;
        if ([[self.options objectForKey:@"useFrontCamera"] boolValue]) {
            picker.cameraDevice = UIImagePickerControllerCameraDeviceFront;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [[self getRootVC] presentViewController:picker animated:YES completion:nil];
        });
    }];
#endif
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *chosenImage = [info objectForKey:UIImagePickerControllerOriginalImage];
    UIImage *chosenImageT = [chosenImage fixOrientation];
    
    [self processSingleImagePick:chosenImageT withViewController:picker withSourceURL:self.croppingFile[@"sourceURL"] withLocalIdentifier:self.croppingFile[@"localIdentifier"] withFilename:self.croppingFile[@"filename"]];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:[self waitAnimationEnd:^{
        self.reject(ERROR_PICKER_CANCEL_KEY, ERROR_PICKER_CANCEL_MSG, nil);
    }]];
}

- (NSString*) getTmpDirectory {
    NSString *TMP_DIRECTORY = @"react-native-image-crop-picker/";
    NSString *tmpFullPath = [NSTemporaryDirectory() stringByAppendingString:TMP_DIRECTORY];

    BOOL isDir;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:tmpFullPath isDirectory:&isDir];
    if (!exists) {
        [[NSFileManager defaultManager] createDirectoryAtPath: tmpFullPath
                                  withIntermediateDirectories:YES attributes:nil error:nil];
    }

    return tmpFullPath;
}

- (BOOL)cleanTmpDirectory {
    NSString* tmpDirectoryPath = [self getTmpDirectory];
    NSArray* tmpDirectory = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tmpDirectoryPath error:NULL];

    for (NSString *file in tmpDirectory) {
        BOOL deleted = [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@%@", tmpDirectoryPath, file] error:NULL];

        if (!deleted) {
            return NO;
        }
    }

    return YES;
}

RCT_EXPORT_METHOD(cleanSingle:(NSString *) path
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {

    BOOL deleted = [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];

    if (!deleted) {
        reject(ERROR_CLEANUP_ERROR_KEY, ERROR_CLEANUP_ERROR_MSG, nil);
    } else {
        resolve(nil);
    }
}

RCT_REMAP_METHOD(clean, resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject) {
    if (![self cleanTmpDirectory]) {
        reject(ERROR_CLEANUP_ERROR_KEY, ERROR_CLEANUP_ERROR_MSG, nil);
    } else {
        resolve(nil);
    }
}

RCT_EXPORT_METHOD(openPicker:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {

    [self setConfiguration:options resolver:resolve rejecter:reject];
    self.cropOnly = NO;

    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        if (status != PHAuthorizationStatusAuthorized) {
            self.reject(ERROR_PICKER_UNAUTHORIZED_KEY, ERROR_PICKER_UNAUTHORIZED_MSG, nil);
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            // init picker
            QBImagePickerController *imagePickerController =
            [QBImagePickerController new];
            imagePickerController.delegate = self;
            imagePickerController.allowsMultipleSelection = [[self.options objectForKey:@"multiple"] boolValue];
            imagePickerController.minimumNumberOfSelection = abs([[self.options objectForKey:@"minFiles"] intValue]);
            imagePickerController.maximumNumberOfSelection = abs([[self.options objectForKey:@"maxFiles"] intValue]);
            imagePickerController.showsNumberOfSelectedAssets = [[self.options objectForKey:@"showsSelectedCount"] boolValue];

            if ([self.options objectForKey:@"smartAlbums"] != nil) {
                NSDictionary *smartAlbums = @{
                                          @"UserLibrary" : @(PHAssetCollectionSubtypeSmartAlbumUserLibrary),
                                          @"PhotoStream" : @(PHAssetCollectionSubtypeAlbumMyPhotoStream),
                                          @"Panoramas" : @(PHAssetCollectionSubtypeSmartAlbumPanoramas),
                                          @"Videos" : @(PHAssetCollectionSubtypeSmartAlbumVideos),
                                          @"Bursts" : @(PHAssetCollectionSubtypeSmartAlbumBursts),
                                          };
                NSMutableArray *albumsToShow = [NSMutableArray arrayWithCapacity:5];
                for (NSString* album in [self.options objectForKey:@"smartAlbums"]) {
                    if ([smartAlbums objectForKey:album] != nil) {
                        [albumsToShow addObject:[smartAlbums objectForKey:album]];
                    }
                }
                imagePickerController.assetCollectionSubtypes = albumsToShow;
            }

            if ([[self.options objectForKey:@"cropping"] boolValue]) {
                imagePickerController.mediaType = QBImagePickerMediaTypeImage;
            } else {
                NSString *mediaType = [self.options objectForKey:@"mediaType"];

                if ([mediaType isEqualToString:@"any"]) {
                    imagePickerController.mediaType = QBImagePickerMediaTypeAny;
                } else if ([mediaType isEqualToString:@"photo"]) {
                    imagePickerController.mediaType = QBImagePickerMediaTypeImage;
                } else {
                    imagePickerController.mediaType = QBImagePickerMediaTypeVideo;
                }

            }

            [[self getRootVC] presentViewController:imagePickerController animated:YES completion:nil];
        });
    }];
}

RCT_EXPORT_METHOD(openCropper:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {

    [self setConfiguration:options resolver:resolve rejecter:reject];
    self.cropOnly = YES;

    NSString *path = [options objectForKey:@"path"];

    [self.bridge.imageLoader loadImageWithURLRequest:[RCTConvert NSURLRequest:path] callback:^(NSError *error, UIImage *image) {
        if (error) {
            self.reject(ERROR_CROPPER_IMAGE_NOT_FOUND_KEY, ERROR_CROPPER_IMAGE_NOT_FOUND_MSG, nil);
        } else {
            [self startCropping:image];
        }
    }];
}

- (void)startCropping:(UIImage *)image {
    RSKImageCropViewController *imageCropVC = [[RSKImageCropViewController alloc] initWithImage:image];
    if ([[[self options] objectForKey:@"cropperCircleOverlay"] boolValue]) {
        imageCropVC.cropMode = RSKImageCropModeCircle;
    } else {
        imageCropVC.cropMode = RSKImageCropModeCustom;
    }
    imageCropVC.avoidEmptySpaceAroundImage = YES;
    imageCropVC.dataSource = self;
    imageCropVC.delegate = self;
    [imageCropVC setModalPresentationStyle:UIModalPresentationCustom];
    [imageCropVC setModalTransitionStyle:UIModalTransitionStyleCrossDissolve];

    dispatch_async(dispatch_get_main_queue(), ^{
        [[self getRootVC] presentViewController:imageCropVC animated:YES completion:nil];
    });
}

- (void)showActivityIndicator:(void (^)(UIActivityIndicatorView*, UIView*))handler {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *mainView = [[self getRootVC] view];

        // create overlay
        UIView *loadingView = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
        loadingView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.5];
        loadingView.clipsToBounds = YES;

        // create loading spinner
        UIActivityIndicatorView *activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        activityView.frame = CGRectMake(65, 40, activityView.bounds.size.width, activityView.bounds.size.height);
        activityView.center = loadingView.center;
        [loadingView addSubview:activityView];

        // create message
        UILabel *loadingLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 115, 130, 22)];
        loadingLabel.backgroundColor = [UIColor clearColor];
        loadingLabel.textColor = [UIColor whiteColor];
        loadingLabel.adjustsFontSizeToFitWidth = YES;
        CGPoint loadingLabelLocation = loadingView.center;
        loadingLabelLocation.y += [activityView bounds].size.height;
        loadingLabel.center = loadingLabelLocation;
        loadingLabel.textAlignment = UITextAlignmentCenter;
        loadingLabel.text = [self.options objectForKey:@"loadingLabelText"];
        [loadingLabel setFont:[UIFont boldSystemFontOfSize:18]];
        [loadingView addSubview:loadingLabel];

        // show all
        [mainView addSubview:loadingView];
        [activityView startAnimating];

        handler(activityView, loadingView);
    });
}


- (void) getVideoAsset:(PHAsset*)forAsset completion:(void (^)(NSDictionary* image))completion {
    PHImageManager *manager = [PHImageManager defaultManager];
    PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
    options.version = PHVideoRequestOptionsVersionOriginal;

    [manager
     requestAVAssetForVideo:forAsset
     options:options
     resultHandler:^(AVAsset * asset, AVAudioMix * audioMix,
                     NSDictionary *info) {
         NSURL *sourceURL = [(AVURLAsset *)asset URL];

         // create temp file
         NSString *tmpDirFullPath = [self getTmpDirectory];
         NSString *filePath = [tmpDirFullPath stringByAppendingString:[[NSUUID UUID] UUIDString]];
         filePath = [filePath stringByAppendingString:@".mp4"];
         NSURL *outputURL = [NSURL fileURLWithPath:filePath];

         [self.compression compressVideo:sourceURL outputURL:outputURL withOptions:self.options handler:^(AVAssetExportSession *exportSession) {
             if (exportSession.status == AVAssetExportSessionStatusCompleted) {
                 AVAsset *compressedAsset = [AVAsset assetWithURL:outputURL];
                 AVAssetTrack *track = [[compressedAsset tracksWithMediaType:AVMediaTypeVideo] firstObject];

                 NSNumber *fileSizeValue = nil;
                 [outputURL getResourceValue:&fileSizeValue
                                      forKey:NSURLFileSizeKey
                                       error:nil];

                 completion([self createAttachmentResponse:[outputURL absoluteString]
                                             withSourceURL:[sourceURL absoluteString]
                                                 withLocalIdentifier: forAsset.localIdentifier
                                             withFilename:[forAsset valueForKey:@"filename"]
                                                 withWidth:[NSNumber numberWithFloat:track.naturalSize.width]
                                                withHeight:[NSNumber numberWithFloat:track.naturalSize.height]
                                                  withMime:@"video/mp4"
                                                  withSize:fileSizeValue
                                                  withData:[NSNull null]]);
             } else {
                 completion(nil);
             }
         }];
     }];
}

- (NSDictionary*) createAttachmentResponse:(NSString*)filePath withSourceURL:(NSString*)sourceURL withLocalIdentifier:(NSString*)localIdentifier withFilename:(NSString*)filename withWidth:(NSNumber*)width withHeight:(NSNumber*)height withMime:(NSString*)mime withSize:(NSNumber*)size withData:(NSString*)data {
    return @{
             @"path": filePath,
             @"sourceURL": (sourceURL) ? sourceURL : @"",
             @"localIdentifier": (localIdentifier) ? localIdentifier : @"",
             @"filename": (filename) ? filename : @"",
             @"width": width,
             @"height": height,
             @"mime": mime,
             @"size": size,
             @"data": data,
             };
}

- (void)qb_imagePickerController:
(QBImagePickerController *)imagePickerController
          didFinishPickingAssets:(NSArray *)assets {
    
    PHImageManager *manager = [PHImageManager defaultManager];
    PHImageRequestOptions* options = [[PHImageRequestOptions alloc] init];
    options.synchronous = NO;
    options.networkAccessAllowed = YES;
    
    if ([[[self options] objectForKey:@"multiple"] boolValue]) {
        NSMutableArray *selections = [[NSMutableArray alloc] init];
        
        [self showActivityIndicator:^(UIActivityIndicatorView *indicatorView, UIView *overlayView) {
            NSLock *lock = [[NSLock alloc] init];
            __block int processed = 0;
            
            for (PHAsset *phAsset in assets) {
                
                if (phAsset.mediaType == PHAssetMediaTypeVideo) {
                    [self getVideoAsset:phAsset completion:^(NSDictionary* video) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [lock lock];
                            
                            if (video == nil) {
                                [indicatorView stopAnimating];
                                [overlayView removeFromSuperview];
                                [imagePickerController dismissViewControllerAnimated:YES completion:[self waitAnimationEnd:^{
                                    self.reject(ERROR_CANNOT_PROCESS_VIDEO_KEY, ERROR_CANNOT_PROCESS_VIDEO_MSG, nil);
                                }]];
                                return;
                            }
                            
                            [selections addObject:video];
                            processed++;
                            [lock unlock];
                            
                            if (processed == [assets count]) {
                                [indicatorView stopAnimating];
                                [overlayView removeFromSuperview];
                                [imagePickerController dismissViewControllerAnimated:YES completion:[self waitAnimationEnd:^{
                                    self.resolve(selections);
                                }]];
                                return;
                            }
                        });
                    }];
                } else {
                    [manager
                     requestImageDataForAsset:phAsset
                     options:options
                     resultHandler:^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
                         
                         NSURL *sourceURL = [info objectForKey:@"PHImageFileURLKey"];
                         
                         dispatch_async(dispatch_get_main_queue(), ^{
                             [lock lock];
                             @autoreleasepool {
                                 UIImage *imgT = [UIImage imageWithData:imageData];
                                 UIImage *imageT = [imgT fixOrientation];
                                 
                                 ImageResult *imageResult = [[ImageResult alloc] init];
                                 if(![self.options objectForKey:@"compressImage"])
                                 {
                                     imageResult.width = [NSNumber numberWithFloat:imageT.size.width];
                                     imageResult.height = [NSNumber numberWithFloat:imageT.size.height];
                                     imageResult.image = imageT;
                                     imageResult.data = imageData;
                                     imageResult.mime = [NSString stringWithFormat:@"%@%@", @"image/", (sourceURL.pathExtension != nil && sourceURL.pathExtension.length > 0 ? [sourceURL.pathExtension lowercaseString]:dataUTI)];
                                 }
                                 else {
                                     imageResult = [self.compression compressImage:imageT withOptions:self.options];
                                 }
                                 NSString *filePath = [self persistFile:imageResult.data];
                                 
                                 BOOL success = true;
                                 //if not compressImage, no need to copyMetaData
                                 if([self.options objectForKey:@"compressImage"] && [self.options objectForKey:@"copyMetaData"])
                                 {
                                     success = [self addMetaDataToFilePath:filePath fromSrc:imageData AndJpg:imageResult.data];
                                 }
                                 if(!success || filePath == nil)
                                 {
                                     [indicatorView stopAnimating];
                                     [overlayView removeFromSuperview];
                                     [imagePickerController dismissViewControllerAnimated:YES completion:[self waitAnimationEnd:^{
                                         self.reject(ERROR_CANNOT_SAVE_IMAGE_KEY, ERROR_CANNOT_SAVE_IMAGE_MSG, nil);
                                     }]];
                                     return;
                                 }
                                 
                                 NSMutableDictionary* responseForResolve = [NSMutableDictionary dictionaryWithDictionary: [self createAttachmentResponse:filePath withSourceURL:sourceURL.absoluteString                                                                                                                              withLocalIdentifier: phAsset.localIdentifier                                                                                                                                            withFilename: sourceURL.lastPathComponent                                                                                                                                               withWidth:imageResult.width                                                                                                                                              withHeight:imageResult.height                                                                                                                                                withMime:imageResult.mime                                                                                                                                                withSize:[NSNumber numberWithUnsignedInteger:imageResult.data.length]                                                                                                                                                withData:[[self.options objectForKey:@"includeBase64"] boolValue] ? [imageResult.data base64EncodedStringWithOptions:0] : [NSNull null]]];
                                 
                                 if([self.options objectForKey:@"checkProjectionType"])
                                     [responseForResolve
                                      setValue: ([self is360Photo:imageData size:CGSizeMake( [imageResult.width floatValue], [imageResult.height floatValue])]?@"Y":@"N")
                                      forKey:@"is360Photo"];
                                 
                                 [selections addObject:responseForResolve];
                             }
                             processed++;
                             [lock unlock];
                             
                             if (processed == [assets count]) {
                                 
                                 [indicatorView stopAnimating];
                                 [overlayView removeFromSuperview];
                                 [imagePickerController dismissViewControllerAnimated:YES completion:[self waitAnimationEnd:^{
                                     self.resolve(selections);
                                 }]];
                                 return;
                             }
                         });
                     }];
                }
            }
        }];
    } else {
        PHAsset *phAsset = [assets objectAtIndex:0];
        
        [self showActivityIndicator:^(UIActivityIndicatorView *indicatorView, UIView *overlayView) {
            if (phAsset.mediaType == PHAssetMediaTypeVideo) {
                [self getVideoAsset:phAsset completion:^(NSDictionary* video) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [indicatorView stopAnimating];
                        [overlayView removeFromSuperview];
                        [imagePickerController dismissViewControllerAnimated:YES completion:[self waitAnimationEnd:^{
                            if (video != nil) {
                                self.resolve(video);
                            } else {
                                self.reject(ERROR_CANNOT_PROCESS_VIDEO_KEY, ERROR_CANNOT_PROCESS_VIDEO_MSG, nil);
                            }
                        }]];
                    });
                }];
            } else {
                [manager
                 requestImageDataForAsset:phAsset
                 options:options
                 resultHandler:^(NSData *imageData, NSString *dataUTI,
                                 UIImageOrientation orientation,
                                 NSDictionary *info) {
                     NSURL *sourceURL = [info objectForKey:@"PHImageFileURLKey"];
                     dispatch_async(dispatch_get_main_queue(), ^{
                         [indicatorView stopAnimating];
                         [overlayView removeFromSuperview];
                         
                         if ([[[self options] objectForKey:@"cropping"] boolValue])
                             [self processSingleImagePick:[UIImage imageWithData:imageData] withViewController:imagePickerController withSourceURL:[sourceURL absoluteString] withLocalIdentifier:phAsset.localIdentifier withFilename:[phAsset valueForKey:@"filename"]];
                         else
                         {
                             UIImage* image = [UIImage imageWithData:imageData];
                             
                             ImageResult *imageResult = [[ImageResult alloc] init];
                             if(![self.options objectForKey:@"compressImage"])
                             {
                                 imageResult.width = [NSNumber numberWithFloat:image.size.width];
                                 imageResult.height = [NSNumber numberWithFloat:image.size.height];
                                 imageResult.image = image;
                                 imageResult.data = imageData;
                                 imageResult.mime = [NSString stringWithFormat:@"%@%@", @"image/", (sourceURL.pathExtension != nil && sourceURL.pathExtension.length > 0 ? [sourceURL.pathExtension lowercaseString]:dataUTI)];
                             }
                             else
                                 imageResult = [self.compression compressImage:image withOptions:self.options];
                             
                             NSString *filePath = [self persistFile:imageResult.data];
                             
                             BOOL success = true;
                             //if not compressImage, no need to copyMetaData
                             if([self.options objectForKey:@"compressImage"] && [self.options objectForKey:@"copyMetaData"])
                             {
                                 success = [self addMetaDataToFilePath:filePath fromSrc:imageData AndJpg:imageResult.data];
                             }
                             
                             if(!success || filePath == nil)
                             {
                                 [indicatorView stopAnimating];
                                 [overlayView removeFromSuperview];
                                 [imagePickerController dismissViewControllerAnimated:YES completion:[self waitAnimationEnd:^{
                                     self.reject(ERROR_CANNOT_SAVE_IMAGE_KEY, ERROR_CANNOT_SAVE_IMAGE_MSG, nil);
                                 }]];
                                 return;
                             }
                             
                             // Wait for viewController to dismiss before resolving, or we lose the ability to display
                             // Alert.alert in the .then() handler.
                             [imagePickerController dismissViewControllerAnimated:YES completion:[self waitAnimationEnd:^{
                                 
                                 NSMutableDictionary* responseForResolve = [NSMutableDictionary dictionaryWithDictionary: [self createAttachmentResponse:filePath withSourceURL:sourceURL.absoluteString                                                                                                                              withLocalIdentifier: phAsset.localIdentifier                                                                                                                                            withFilename: sourceURL.lastPathComponent                                                                                                                                               withWidth:imageResult.width                                                                                                                                              withHeight:imageResult.height                                                                                                                                                withMime:imageResult.mime                                                                                                                                                withSize:[NSNumber numberWithUnsignedInteger:imageResult.data.length]                                                                                                                                                withData:[[self.options objectForKey:@"includeBase64"] boolValue] ? [imageResult.data base64EncodedStringWithOptions:0] : [NSNull null]
                                                                                                                           ]];
                                 
                                 if([self.options objectForKey:@"checkProjectionType"])
                                     [responseForResolve
                                      setValue: ([self is360Photo:imageData size:CGSizeMake( [imageResult.width floatValue], [imageResult.height floatValue])]?@"Y":@"N")
                                      forKey:@"is360Photo"];
                                 
                                 self.resolve(responseForResolve);
                             }]];
                         }
                     });
                 }];
            }
        }];
    }
}

- (void)qb_imagePickerControllerDidCancel:(QBImagePickerController *)imagePickerController {
    [imagePickerController dismissViewControllerAnimated:YES completion:[self waitAnimationEnd:^{
        self.reject(ERROR_PICKER_CANCEL_KEY, ERROR_PICKER_CANCEL_MSG, nil);
    }]];
}

// when user selected single image, with camera or from photo gallery,
// this method will take care of attaching image metadata, and sending image to cropping controller
// or to user directly
- (void) processSingleImagePick:(UIImage*)image withViewController:(UIViewController*)viewController withSourceURL:(NSString*)sourceURL withLocalIdentifier:(NSString*)localIdentifier withFilename:(NSString*)filename {

    if (image == nil) {
        [viewController dismissViewControllerAnimated:YES completion:[self waitAnimationEnd:^{
            self.reject(ERROR_PICKER_NO_DATA_KEY, ERROR_PICKER_NO_DATA_MSG, nil);
        }]];
        return;
    }
    
    NSLog(@"id: %@ filename: %@", localIdentifier, filename);
    
    if ([[[self options] objectForKey:@"cropping"] boolValue]) {
        self.croppingFile = [[NSMutableDictionary alloc] init];
        self.croppingFile[@"sourceURL"] = sourceURL;
        self.croppingFile[@"localIdentifier"] = localIdentifier;
        self.croppingFile[@"filename"] = filename;
        NSLog(@"CroppingFile %@", self.croppingFile);
        
        [self startCropping:image];
    } else {
        ImageResult *imageResult = [self.compression compressImage:image withOptions:self.options];
        NSString *filePath = [self persistFile:imageResult.data];
        if (filePath == nil) {
            [viewController dismissViewControllerAnimated:YES completion:[self waitAnimationEnd:^{
                self.reject(ERROR_CANNOT_SAVE_IMAGE_KEY, ERROR_CANNOT_SAVE_IMAGE_MSG, nil);
            }]];
            return;
        }

        // Wait for viewController to dismiss before resolving, or we lose the ability to display
        // Alert.alert in the .then() handler.
        [viewController dismissViewControllerAnimated:YES completion:[self waitAnimationEnd:^{
            self.resolve([self createAttachmentResponse:filePath
                                          withSourceURL:sourceURL
                                    withLocalIdentifier:localIdentifier
                                           withFilename:filename
                                              withWidth:imageResult.width
                                             withHeight:imageResult.height
                                               withMime:imageResult.mime
                                               withSize:[NSNumber numberWithUnsignedInteger:imageResult.data.length]
                                               withData:[[self.options objectForKey:@"includeBase64"] boolValue] ? [imageResult.data base64EncodedStringWithOptions:0] : [NSNull null]]);
        }]];
    }
}

#pragma mark - CustomCropModeDelegates

// Returns a custom rect for the mask.
- (CGRect)imageCropViewControllerCustomMaskRect:
(RSKImageCropViewController *)controller {
    CGSize maskSize = CGSizeMake(
                                 [[self.options objectForKey:@"width"] intValue],
                                 [[self.options objectForKey:@"height"] intValue]);

    CGFloat viewWidth = CGRectGetWidth(controller.view.frame);
    CGFloat viewHeight = CGRectGetHeight(controller.view.frame);

    CGRect maskRect = CGRectMake((viewWidth - maskSize.width) * 0.5f,
                                 (viewHeight - maskSize.height) * 0.5f,
                                 maskSize.width, maskSize.height);

    return maskRect;
}

// if provided width or height is bigger than screen w/h,
// then we should scale draw area
- (CGRect) scaleRect:(RSKImageCropViewController *)controller {
    CGRect rect = controller.maskRect;
    CGFloat viewWidth = CGRectGetWidth(controller.view.frame);
    CGFloat viewHeight = CGRectGetHeight(controller.view.frame);

    double scaleFactor = fmin(viewWidth / rect.size.width, viewHeight / rect.size.height);
    rect.size.width *= scaleFactor;
    rect.size.height *= scaleFactor;
    rect.origin.x = (viewWidth - rect.size.width) / 2;
    rect.origin.y = (viewHeight - rect.size.height) / 2;

    return rect;
}

// Returns a custom path for the mask.
- (UIBezierPath *)imageCropViewControllerCustomMaskPath:
(RSKImageCropViewController *)controller {
    CGRect rect = [self scaleRect:controller];
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect
                                               byRoundingCorners:UIRectCornerAllCorners
                                                     cornerRadii:CGSizeMake(0, 0)];
    return path;
}

// Returns a custom rect in which the image can be moved.
- (CGRect)imageCropViewControllerCustomMovementRect:
(RSKImageCropViewController *)controller {
    return [self scaleRect:controller];
}

#pragma mark - CropFinishDelegate

// Crop image has been canceled.
- (void)imageCropViewControllerDidCancelCrop:
(RSKImageCropViewController *)controller {
    [self dismissCropper:controller dismissAll: NO completion:[self waitAnimationEnd:^{
        if (self.cropOnly) {
            self.reject(ERROR_PICKER_CANCEL_KEY, ERROR_PICKER_CANCEL_MSG, nil);
        }
    }]];
}

- (void) dismissCropper:(RSKImageCropViewController*) controller dismissAll: (BOOL) dissmissAll completion:(void (^)())completion {
    //We've presented the cropper on top of the image picker as to not have a double modal animation.
    //Thus, we need to dismiss the image picker view controller to dismiss the whole stack.
    if (!self.cropOnly) {
        if (dissmissAll) {
            UIViewController *topViewController = controller.presentingViewController.presentingViewController;
            [topViewController dismissViewControllerAnimated:YES completion:completion];
        } else {
            UIViewController *topViewController = controller.presentingViewController;
            [topViewController dismissViewControllerAnimated:YES completion:completion];
        }
    } else {
        [controller dismissViewControllerAnimated:YES completion:completion];
    }
}

// The original image has been cropped.
- (void)imageCropViewController:(RSKImageCropViewController *)controller
                   didCropImage:(UIImage *)croppedImage
                  usingCropRect:(CGRect)cropRect {

    // we have correct rect, but not correct dimensions
    // so resize image
    CGSize resizedImageSize = CGSizeMake([[[self options] objectForKey:@"width"] intValue], [[[self options] objectForKey:@"height"] intValue]);
    UIImage *resizedImage = [croppedImage resizedImageToFitInSize:resizedImageSize scaleIfSmaller:YES];
    ImageResult *imageResult = [self.compression compressImage:resizedImage withOptions:self.options];

    NSString *filePath = [self persistFile:imageResult.data];
    if (filePath == nil) {
        [self dismissCropper:controller dismissAll: YES completion:[self waitAnimationEnd:^{
            self.reject(ERROR_CANNOT_SAVE_IMAGE_KEY, ERROR_CANNOT_SAVE_IMAGE_MSG, nil);
        }]];
        return;
    }

    [self dismissCropper:controller dismissAll: YES completion:[self waitAnimationEnd:^{
        self.resolve([self createAttachmentResponse:filePath
                                      withSourceURL: self.croppingFile[@"sourceURL"]
                                          withLocalIdentifier: self.croppingFile[@"localIdentifier"]
                                          withFilename: self.croppingFile[@"filename"]
                                          withWidth:imageResult.width
                                         withHeight:imageResult.height
                                           withMime:imageResult.mime
                                           withSize:[NSNumber numberWithUnsignedInteger:imageResult.data.length]
                                           withData:[[self.options objectForKey:@"includeBase64"] boolValue] ? [imageResult.data base64EncodedStringWithOptions:0] : [NSNull null]]);
    }]];
}

// at the moment it is not possible to upload image by reading PHAsset
// we are saving image and saving it to the tmp location where we are allowed to access image later
- (NSString*) persistFile:(NSData*)data {
    // create temp file
    NSString *tmpDirFullPath = [self getTmpDirectory];
    NSString *filePath = [tmpDirFullPath stringByAppendingString:[[NSUUID UUID] UUIDString]];
    filePath = [filePath stringByAppendingString:@".jpg"];

    // save cropped file
    BOOL status = [data writeToFile:filePath atomically:YES];
    if (!status) {
        return nil;
    }

    return filePath;
}

// The original image has been cropped. Additionally provides a rotation angle
// used to produce image.
- (void)imageCropViewController:(RSKImageCropViewController *)controller
                   didCropImage:(UIImage *)croppedImage
                  usingCropRect:(CGRect)cropRect
                  rotationAngle:(CGFloat)rotationAngle {
    [self imageCropViewController:controller didCropImage:croppedImage usingCropRect:cropRect];
}


//Tested the metadata to identitfy 360 photo will be cleared after UIImageJPEGRepresentation, add this method to use Image I/O to copy the metadata from source NSData to jpg image
- (BOOL) addMetaDataToFilePath:(NSString*)filePath fromSrc:(NSData*)srcImageData AndJpg:(NSData*)jpgImageData{
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)srcImageData, NULL);
    
    CGImageSourceRef jpgSource = CGImageSourceCreateWithData((__bridge CFDataRef)jpgImageData, NULL);
    
    CGImageRef jpgImage = CGImageSourceCreateImageAtIndex(jpgSource, 0, NULL);
    
    CGImageMetadataRef metadata = CGImageSourceCopyMetadataAtIndex(source,0,NULL);
    
    //uncomment and try this logic for copy specify metadata
    //    NSArray *metadataArray = nil;
    //    if (metadata) {
    //        metadataArray = CFBridgingRelease(CGImageMetadataCopyTags(metadata));
    //        //                                     CFRelease(metadata);
    //    }
    //
    //    //                                 NSDictionary *metaDataDic = [NSDictionary dictionary];
    //
    //    for (id aRef in metadataArray)
    //    {
    //        CGImageMetadataTagRef currentRef = (__bridge CGImageMetadataTagRef)(aRef);
    //        CGImageMetadataType type = CGImageMetadataTagGetType(currentRef);
    //        CFStringRef nameSpace = CGImageMetadataTagCopyNamespace(currentRef);
    //        CFStringRef prefix = CGImageMetadataTagCopyPrefix(currentRef);
    //        CFStringRef name = CGImageMetadataTagCopyName(currentRef);
    //        CFTypeRef value = CGImageMetadataTagCopyValue(currentRef);
    //        CFStringRef valueTypeStr =  CFCopyTypeIDDescription(CFGetTypeID(value));
    //
    //        if([((__bridge NSString*)prefix) isEqual: @"GPano"] &&
    //           [((__bridge NSString*)name) isEqual: @"ProjectionType"] &&
    //           [((__bridge NSString*)value) isEqual: @"equirectangular"])
    //        {
    //            //                                         [metaDataDic setValue:(__bridge NSString*)nameSpace forKey:@"nameSpace"];
    //            //                                         [metaDataDic setValue:(__bridge NSString*)prefix forKey:@"prefix"];
    //            //                                         [metaDataDic setValue:(__bridge NSString*)name forKey:@"name"];
    //            //                                         [metaDataDic setValue:(__bridge NSString*)value forKey:@"value"];
    //            //                                         [metaDataDic setValue:(__bridge NSString*)valueTypeStr forKey:@"valueTypeStr"];
    //        }
    //    }
    
    CFStringRef UTI = CGImageSourceGetType(source); //this is the type of image (e.g., public.jpeg)
    
    //this will be the data CGImageDestinationRef will write into
    NSMutableData *dest_data = [NSMutableData data];
    
    CGImageDestinationRef destination = CGImageDestinationCreateWithData((CFMutableDataRef)dest_data,UTI,1,NULL);
    
    if(!destination) {
        NSLog(@"***Could not create image destination ***");
    }
    
    CGImageDestinationAddImageAndMetadata(destination, jpgImage, metadata, NULL);
    
    BOOL success = NO;
    success = CGImageDestinationFinalize(destination);
    
    if(!success) {
        NSLog(@"***Could not create data from image destination ***");
    }
    
    BOOL status = [dest_data writeToFile:filePath atomically:YES];
    
    CFRelease(jpgSource);
    CFRelease(jpgImage);
    CFRelease(destination);
    CFRelease(source);
    
    return status;
}

//check is 360, refer to facebook - https://www.facebook.com/notes/eric-cheng/editing-360-photos-injecting-metadata/10156930564975277
- (BOOL) is360Photo:(NSData*) imageData size:(CGSize)imageSize{
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, NULL);
    
    CGImageMetadataRef metadata = CGImageSourceCopyMetadataAtIndex(source,0,NULL);
    
    NSArray *metadataArray = nil;
    
    if (metadata) {
        metadataArray = CFBridgingRelease(CGImageMetadataCopyTags(metadata));
        CFRelease(metadata);
    }
    CFRelease(source);
    
    for (id aRef in metadataArray)
    {
        CGImageMetadataTagRef currentRef = (__bridge CGImageMetadataTagRef)(aRef);
        CGImageMetadataType type = CGImageMetadataTagGetType(currentRef);
        CFStringRef nameSpace = CGImageMetadataTagCopyNamespace(currentRef);
        CFStringRef prefix = CGImageMetadataTagCopyPrefix(currentRef);
        CFStringRef name = CGImageMetadataTagCopyName(currentRef);
        CFTypeRef value = CGImageMetadataTagCopyValue(currentRef);
        CFStringRef valueTypeStr =  CFCopyTypeIDDescription(CFGetTypeID(value));
        
        if([((__bridge NSString*)prefix) isEqual: @"GPano"] &&
           [((__bridge NSString*)name) isEqual: @"ProjectionType"] &&
           [((__bridge NSString*)value) isEqual: @"equirectangular"] &&
           imageSize.width >0 && imageSize.width <= 6000 &&
           imageSize.height >0 && imageSize.height <= 3000 &&
           imageSize.width == imageSize.height * 2)
        {
            return YES;
        }
    }
    return NO;
}

@end
