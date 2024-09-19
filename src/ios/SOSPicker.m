//
//  SOSPicker.m
//  SyncOnSet
//
//  Created by Christopher Sullivan on 10/25/13.
//
//

#import "SOSPicker.h"


#import "GMImagePickerController.h"
#import "GMFetchItem.h"
#import <PhotosUI/PhotosUI.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#define CDV_PHOTO_PREFIX @"cdv_photo_"

typedef enum : NSUInteger {
    FILE_URI = 0,
    BASE64_STRING = 1
} SOSPickerOutputType;

@interface SOSPicker () <GMImagePickerControllerDelegate>
@end

@implementation SOSPicker

@synthesize callbackId;

- (void) hasReadPermission:(CDVInvokedUrlCommand *)command {
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:[PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusAuthorized];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) requestReadPermission:(CDVInvokedUrlCommand *)command {
    // [PHPhotoLibrary requestAuthorization:]
    // this method works only when it is a first time, see
    // https://developer.apple.com/library/ios/documentation/Photos/Reference/PHPhotoLibrary_Class/

    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    if (status == PHAuthorizationStatusAuthorized) {
        NSLog(@"Access has been granted.");

        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    } else if (status == PHAuthorizationStatusDenied) {
        NSString* message = @"Access has been denied. Change your setting > this app > Photo enable";
        NSLog(@"%@", message);

        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:message];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    } else if (status == PHAuthorizationStatusNotDetermined) {
        // Access has not been determined. requestAuthorization: is available
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {}];

        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    } else if (status == PHAuthorizationStatusRestricted) {
        NSString* message = @"Access has been restricted. Change your setting > Privacy > Photo enable";
        NSLog(@"%@", message);

        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:message];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

- (void) getPictures:(CDVInvokedUrlCommand *)command {

    NSDictionary *options = [command.arguments objectAtIndex: 0];

    self.outputType = [[options objectForKey:@"outputType"] integerValue];
    BOOL allow_video = [[options objectForKey:@"allow_video" ] boolValue ];
    NSInteger maximumImagesCount = [[options objectForKey:@"maximumImagesCount"] integerValue];
    NSString * title = [options objectForKey:@"title"];
    NSString * message = [options objectForKey:@"message"];
    BOOL disable_popover = [[options objectForKey:@"disable_popover" ] boolValue];
    if (message == (id)[NSNull null]) {
      message = nil;
    }
    self.width = [[options objectForKey:@"width"] integerValue];
    self.height = [[options objectForKey:@"height"] integerValue];
    self.quality = [[options objectForKey:@"quality"] integerValue];

    self.callbackId = command.callbackId;
    [self launchGMImagePicker:allow_video title:title message:message disable_popover:disable_popover maximumImagesCount:maximumImagesCount];
}

- (void)launchGMImagePicker:(bool)allow_video title:(NSString *)title message:(NSString *)message disable_popover:(BOOL)disable_popover maximumImagesCount:(NSInteger)maximumImagesCount
{
    // GMImagePickerController *picker = [[GMImagePickerController alloc] init:allow_video];
    // picker.delegate = self;
    // picker.maximumImagesCount = maximumImagesCount;
    // picker.title = title;
    // picker.customNavigationBarPrompt = message;
    // picker.colsInPortrait = 4;
    // picker.colsInLandscape = 6;
    // picker.minimumInteritemSpacing = 2.0;

    // if(!disable_popover) {
    //     picker.modalPresentationStyle = UIModalPresentationPopover;

    //     UIPopoverPresentationController *popPC = picker.popoverPresentationController;
    //     popPC.permittedArrowDirections = UIPopoverArrowDirectionAny;
    //     popPC.sourceView = picker.view;
    //     //popPC.sourceRect = nil;
    // }

    // [self.viewController showViewController:picker sender:nil];

    // Configuração do PHPicker
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
    config.selectionLimit = maximumImagesCount; // Pode alterar para permitir múltiplas seleções
    config.filter = [PHPickerFilter imagesFilter]; // Para selecionar apenas imagens

    // Inicializando o PHPickerViewController
    PHPickerViewController *pickerViewController = [[PHPickerViewController alloc] initWithConfiguration:config];
    pickerViewController.delegate = self;

    // Apresentando o Picker
    [self.viewController presentViewController:pickerViewController animated:YES completion:nil];
}

// - (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
//     [self.viewController dismissViewControllerAnimated:YES completion:nil];

//     NSLog(@"PHPicker: User finished picking assets. Number of selected items is: %lu", (unsigned long)results.count);
//     if (results.count == 0) {
//         // Nenhuma imagem selecionada
//         return;
//     }

//     NSMutableArray *result_all = [[NSMutableArray alloc] init];
//     CGSize targetSize = CGSizeMake(self.width, self.height);
//     NSFileManager* fileMgr = [[NSFileManager alloc] init];
//     NSString* docsPath = [NSTemporaryDirectory() stringByStandardizingPath];

//     __block int i = 1;
//     __block NSString* filePath;
//     __block CDVPluginResult* result = nil;

//     // Criando o dispatch_group
//     dispatch_group_t group = dispatch_group_create();

//     NSError *err = nil;

//     for (PHPickerResult *item in results) {
//         if ([item.itemProvider canLoadObjectOfClass:[UIImage class]]) {
//             // Entra no grupo antes de iniciar o processamento de cada imagem
//             dispatch_group_enter(group);

//             [item.itemProvider loadObjectOfClass:[UIImage class] completionHandler:^(UIImage *image, NSError * _Nullable error) {
//                 if (image != nil) {
//                     dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//                         NSLog(@"Imagem selecionada: %@", image);

//                         do {
//                             filePath = [NSString stringWithFormat:@"%@/%@%03d.%@", docsPath, CDV_PHOTO_PREFIX, i++, @"jpg"];
//                         } while ([fileMgr fileExistsAtPath:filePath]);

//                         NSData* data = nil;
//                         NSError __autoreleasing *blockError = err;

//                         // Adicionando os condicionais de redimensionamento e qualidade
//                         if (self.width == 0 && self.height == 0) {
//                             // No scaling required
//                             if (self.outputType == BASE64_STRING) {
//                                 [result_all addObject:[UIImageJPEGRepresentation(image, self.quality / 100.0f) base64EncodedStringWithOptions:0]];
//                             } else {
//                                 if (self.quality == 100) {
//                                     // No scaling, no downsampling, fastest option
//                                     [result_all addObject:filePath];
//                                 } else {
//                                     // Resample first
//                                     data = UIImageJPEGRepresentation(image, self.quality / 100.0f);
//                                     if (![data writeToFile:filePath options:NSAtomicWrite error:&blockError]) {
//                                         result = [CDVPluginResult resultWithStatus:CDVCommandStatus_IO_EXCEPTION messageAsString:[blockError localizedDescription]];
//                                     } else {
//                                         [result_all addObject:[[NSURL fileURLWithPath:filePath] absoluteString]];
//                                     }
//                                 }
//                             }
//                         } else {
//                             // Scale the image
//                             UIImage* scaledImage = [self imageByScalingNotCroppingForSize:image toSize:targetSize];
//                             data = UIImageJPEGRepresentation(scaledImage, self.quality / 100.0f);

//                             if (![data writeToFile:filePath options:NSAtomicWrite error:&blockError]) {
//                                 result = [CDVPluginResult resultWithStatus:CDVCommandStatus_IO_EXCEPTION messageAsString:[blockError localizedDescription]];
//                             } else {
//                                 if (self.outputType == BASE64_STRING) {
//                                     [result_all addObject:[data base64EncodedStringWithOptions:0]];
//                                 } else {
//                                     [result_all addObject:[[NSURL fileURLWithPath:filePath] absoluteString]];
//                                 }
//                             }
//                         }

//                         // Sair do grupo após o processamento da imagem
//                         dispatch_group_leave(group);
//                     });
//                 } else {
//                     // Se houve erro ao carregar a imagem, sair do grupo
//                     dispatch_group_leave(group);
//                 }
//             }];
//         }
//     }

//     // Aguardar até que todas as imagens tenham sido processadas
//     dispatch_group_notify(group, dispatch_get_main_queue(), ^{
//         if (result == nil) {
//             result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:result_all];
//         }

//         NSLog(@"Imagens selecionadas - End: %@", result);
//         [self.commandDelegate sendPluginResult:result callbackId:self.callbackId];
//     });
// }

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [self.viewController dismissViewControllerAnimated:YES completion:nil];

    NSLog(@"PHPicker: User finished picking assets. Number of selected items is: %lu", (unsigned long)results.count);

    // Verifica se nenhuma imagem foi selecionada e retorna um array vazio
    if (results.count == 0) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:@[]];
        [self.commandDelegate sendPluginResult:result callbackId:self.callbackId];
        return;
    }

    // Variáveis para armazenar o caminho e o resultado
    NSMutableArray *result_all = [[NSMutableArray alloc] init];
    CGSize targetSize = CGSizeMake(self.width, self.height);
    NSFileManager* fileMgr = [[NSFileManager alloc] init];
    NSString* docsPath = [NSTemporaryDirectory() stringByStandardizingPath];

    __block int i = 1;
    __block NSString* filePath;
    __block CDVPluginResult* result = nil;

    // Criando o dispatch_group
    dispatch_group_t group = dispatch_group_create();

    // Processar cada item selecionado
    for (PHPickerResult *item in results) {
        if ([item.itemProvider hasItemConformingToTypeIdentifier:(NSString *)UTTypeImage.identifier]) {
            // Entra no grupo antes de iniciar o processamento de cada imagem
            dispatch_group_enter(group);

            [item.itemProvider loadDataRepresentationForTypeIdentifier:(NSString *)UTTypeImage.identifier completionHandler:^(NSData *imageData, NSError *error) {
                if (imageData != nil) {
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        @autoreleasepool {
                            do {
                                filePath = [NSString stringWithFormat:@"%@/%@%03d.%@", docsPath, CDV_PHOTO_PREFIX, i++, @"jpg"];
                            } while ([fileMgr fileExistsAtPath:filePath]);

                            NSError __autoreleasing *blockError = nil;
                            NSData *processedData = nil;

                            // Verifica as condições para escalonamento e qualidade
                            if (self.width == 0 && self.height == 0) {
                                // Não há necessidade de escalonar a imagem
                                if (self.outputType == BASE64_STRING) {
                                    [result_all addObject:[imageData base64EncodedStringWithOptions:0]];
                                } else {
                                    // Sem redimensionamento, apenas salvar a imagem
                                    processedData = imageData;
                                    if (![processedData writeToFile:filePath options:NSAtomicWrite error:&blockError]) {
                                        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_IO_EXCEPTION messageAsString:[blockError localizedDescription]];
                                    } else {
                                        [result_all addObject:[[NSURL fileURLWithPath:filePath] absoluteString]];
                                    }
                                }
                            } else {
                                // Redimensionar a imagem para o targetSize
                                processedData = [self imageDataByScalingNotCroppingForSize:imageData toSize:targetSize];

                                if (![processedData writeToFile:filePath options:NSAtomicWrite error:&blockError]) {
                                    result = [CDVPluginResult resultWithStatus:CDVCommandStatus_IO_EXCEPTION messageAsString:[blockError localizedDescription]];
                                } else {
                                    if (self.outputType == BASE64_STRING) {
                                        [result_all addObject:[processedData base64EncodedStringWithOptions:0]];
                                    } else {
                                        [result_all addObject:[[NSURL fileURLWithPath:filePath] absoluteString]];
                                    }
                                }
                            }

                            // Sair do grupo após o processamento da imagem
                            dispatch_group_leave(group);
                        }
                    });
                } else {
                    // Se houve erro ao carregar os dados da imagem, sair do grupo
                    dispatch_group_leave(group);
                }
            }];
        } else {
            // Sair do grupo se o item não for uma imagem válida
            dispatch_group_leave(group);
        }
    }

    // Aguardar até que todas as imagens tenham sido processadas
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (result == nil) {
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:result_all];
        }

        NSLog(@"Imagens selecionadas - End: %@", result);
        [self.commandDelegate sendPluginResult:result callbackId:self.callbackId];
    });
}

- (CGFloat)scaleFactorForOriginalSize:(CGSize)originalSize toSize:(CGSize)targetSize {
    // Verifica se o tamanho original ou de destino tem largura ou altura zero
    NSLog(@"In scale Tamanho original: %@", NSStringFromCGSize(originalSize));
    NSLog(@"In scale Tamanho de destino: %@", NSStringFromCGSize(targetSize));

    if (originalSize.width == 0 || originalSize.height == 0 || (targetSize.width == 0 && targetSize.height == 0)) {
        NSLog(@"Erro: Tamanho original ou de destino inválido.");
        return 1.0; // Não redimensionar
    }

    if (CGSizeEqualToSize(originalSize, targetSize)) {
        return 1.0;
    }

    // Calcula os fatores de escala
    CGFloat widthFactor = targetSize.width / originalSize.width;
    CGFloat heightFactor = targetSize.height / originalSize.height;

    // Seleciona o menor fator de escala para manter as proporções
    CGFloat scaleFactor = 0.0;

    if (widthFactor == 0.0) {
        scaleFactor = heightFactor;
    } else if (heightFactor == 0.0) {
        scaleFactor = widthFactor;
    } else if (widthFactor > heightFactor) {
        scaleFactor = heightFactor; // scale to fit height
    } else {
        scaleFactor = widthFactor; // scale to fit width
    }

    return scaleFactor;
}


- (NSData*)imageDataByScalingNotCroppingForSize:(NSData*)imageData toSize:(CGSize)frameSize {
    // Verifica se o imageData não está vazio
    if (imageData == nil || imageData.length == 0) {
        NSLog(@"Erro: Os dados da imagem estão vazios ou corrompidos");
        return nil;
    }

    // Cria uma fonte de imagem a partir dos dados
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, NULL);
    if (imageSource == NULL) {
        NSLog(@"Erro ao criar CGImageSource");
        return nil;
    }

    // Verifica o status da imagem para garantir que está completa
    CGImageSourceStatus status = CGImageSourceGetStatus(imageSource);
    NSLog(@"Status da imagem: %d", status);
    if (status != kCGImageStatusComplete) {
        NSLog(@"Erro: O status da imagem é inválido, status: %d", status);
        CFRelease(imageSource);
        return nil;
    }

    // Verifica o tipo da imagem
    CFStringRef imageType = CGImageSourceGetType(imageSource);
    NSLog(@"Tipo da imagem: %@", imageType);

    // Obtém as propriedades da imagem original (tamanho)
    NSDictionary *imageProperties = (__bridge NSDictionary *)CGImageSourceCopyPropertiesAtIndex(imageSource, 0, NULL);
    CGSize imageSize = CGSizeMake([imageProperties[(NSString *)kCGImagePropertyPixelWidth] floatValue],
                                  [imageProperties[(NSString *)kCGImagePropertyPixelHeight] floatValue]);

    NSLog(@"Tamanho do frame: %@", NSStringFromCGSize(frameSize));

    // CGFloat width = imageSize.width;
    // CGFloat height = imageSize.height;
    // CGFloat targetWidth = frameSize.width;
    // CGFloat targetHeight = frameSize.height;

    // NSLog(@"Largura da imagem: %f", width);
    // NSLog(@"Altura da imagem: %f", height);
    // NSLog(@"Largura do frame: %f", targetWidth);
    // NSLog(@"Altura do frame: %f", targetHeight);

    // Calcula o fator de escala mantendo as proporções
    CGFloat scaleFactor = [self scaleFactorForOriginalSize:imageSize toSize:frameSize];
    CGSize scaledSize = CGSizeMake(floor(imageSize.width * scaleFactor), floor(imageSize.height * scaleFactor));

    NSLog(@"Fator de escala: %f", scaleFactor);
    NSLog(@"Tamanho da imagem original: %@", NSStringFromCGSize(imageSize));
    NSLog(@"Tamanho da imagem escalada: %@", NSStringFromCGSize(scaledSize));

    // if (!CGSizeEqualToSize(imageSize, frameSize)) {
    //     CGFloat widthFactor = targetWidth / width;
    //     CGFloat heightFactor = targetHeight / height;

    //     if (widthFactor == 0.0) {
    //         scaleFactor = heightFactor;
    //     } else if (heightFactor == 0.0) {
    //         scaleFactor = widthFactor;
    //     } else if (widthFactor > heightFactor) {
    //         scaleFactor = heightFactor; // scale to fit height
    //     } else {
    //         scaleFactor = widthFactor; // scale to fit width
    //     }


    //     scaledSize = CGSizeMake(floor(width * scaleFactor), floor(height * scaleFactor));
    // }

    // Configura as opções para o redimensionamento
    NSDictionary *options = @{
        (NSString *)kCGImageSourceThumbnailMaxPixelSize : @(MAX(scaledSize.width, scaledSize.height)),
        (NSString *)kCGImageSourceCreateThumbnailFromImageAlways : @YES
    };

    NSLog(@"Opções de redimensionamento: %@", options);
    // Tenta criar a miniatura
    CGImageRef scaledImageRef = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, (__bridge CFDictionaryRef)options);

    if (scaledImageRef == NULL) {
        NSLog(@"Erro: Falha ao criar miniatura, tentando carregar imagem completa");

        // Tenta criar a imagem completa se a miniatura falhar
        scaledImageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
        if (scaledImageRef == NULL) {
            NSLog(@"Erro: Falha ao criar a imagem completa");
            CFRelease(imageSource);
            return nil;
        }
    }

    // Converte o CGImage escalado para UIImage
    UIImage *scaledImage = [UIImage imageWithCGImage:scaledImageRef];
    NSData *scaledImageData = UIImageJPEGRepresentation(scaledImage, self.quality / 100.0f);

    // Limpa os recursos alocados
    CGImageRelease(scaledImageRef);
    CFRelease(imageSource);

    return scaledImageData;
}



// - (UIImage*)imageByScalingNotCroppingForSize:(UIImage*)anImage toSize:(CGSize)frameSize
// {
//     UIImage* sourceImage = anImage;
//     UIImage* newImage = nil;
//     CGSize imageSize = sourceImage.size;
//     CGFloat width = imageSize.width;
//     CGFloat height = imageSize.height;
//     CGFloat targetWidth = frameSize.width;
//     CGFloat targetHeight = frameSize.height;
//     CGFloat scaleFactor = 0.0;
//     CGSize scaledSize = frameSize;

//     if (CGSizeEqualToSize(imageSize, frameSize) == NO) {
//         CGFloat widthFactor = targetWidth / width;
//         CGFloat heightFactor = targetHeight / height;

//         // opposite comparison to imageByScalingAndCroppingForSize in order to contain the image within the given bounds
//         if (widthFactor == 0.0) {
//             scaleFactor = heightFactor;
//         } else if (heightFactor == 0.0) {
//             scaleFactor = widthFactor;
//         } else if (widthFactor > heightFactor) {
//             scaleFactor = heightFactor; // scale to fit height
//         } else {
//             scaleFactor = widthFactor; // scale to fit width
//         }
//         scaledSize = CGSizeMake(floor(width * scaleFactor), floor(height * scaleFactor));
//     }

//     UIGraphicsBeginImageContext(scaledSize); // this will resize

//     [sourceImage drawInRect:CGRectMake(0, 0, scaledSize.width, scaledSize.height)];

//     newImage = UIGraphicsGetImageFromCurrentImageContext();
//     if (newImage == nil) {
//         NSLog(@"could not scale image");
//     }

//     // pop the context to get back to the default
//     UIGraphicsEndImageContext();
//     return newImage;
// }






#pragma mark - UIImagePickerControllerDelegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [picker.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    NSLog(@"UIImagePickerController: User finished picking assets");
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    CDVPluginResult* pluginResult = nil;
    NSArray* emptyArray = [NSArray array];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:emptyArray];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
    [self.viewController dismissViewControllerAnimated:YES completion:nil];
    NSLog(@"UIImagePickerController: User pressed cancel button");
}

#pragma mark - GMImagePickerControllerDelegate

- (void)assetsPickerController:(GMImagePickerController *)picker didFinishPickingAssets:(NSArray *)fetchArray
{
    [picker.presentingViewController dismissViewControllerAnimated:YES completion:nil];

    NSLog(@"GMImagePicker: User finished picking assets. Number of selected items is: %lu", (unsigned long)fetchArray.count);

    NSMutableArray * result_all = [[NSMutableArray alloc] init];
    CGSize targetSize = CGSizeMake(self.width, self.height);
    NSFileManager* fileMgr = [[NSFileManager alloc] init];
    NSString* docsPath = [NSTemporaryDirectory()stringByStandardizingPath];

    NSError* err = nil;
    int i = 1;
    NSString* filePath;
    CDVPluginResult* result = nil;

    for (GMFetchItem *item in fetchArray) {

        if ( !item.image_fullsize ) {
            continue;
        }

        do {
            filePath = [NSString stringWithFormat:@"%@/%@%03d.%@", docsPath, CDV_PHOTO_PREFIX, i++, @"jpg"];
        } while ([fileMgr fileExistsAtPath:filePath]);

        NSData* data = nil;
        if (self.width == 0 && self.height == 0) {
            // no scaling required
            if (self.outputType == BASE64_STRING){
                UIImage* image = [UIImage imageNamed:item.image_fullsize];
                [result_all addObject:[UIImageJPEGRepresentation(image, self.quality/100.0f) base64EncodedStringWithOptions:0]];
            } else {
                if (self.quality == 100) {
                    // no scaling, no downsampling, this is the fastest option
                    [result_all addObject:item.image_fullsize];
                } else {
                    // resample first
                    UIImage* image = [UIImage imageNamed:item.image_fullsize];
                    data = UIImageJPEGRepresentation(image, self.quality/100.0f);
                    if (![data writeToFile:filePath options:NSAtomicWrite error:&err]) {
                        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_IO_EXCEPTION messageAsString:[err localizedDescription]];
                        break;
                    } else {
                        [result_all addObject:[[NSURL fileURLWithPath:filePath] absoluteString]];
                    }
                }
            }
        } else {
            // scale
            UIImage* image = [UIImage imageNamed:item.image_fullsize];
            UIImage* scaledImage = [self imageByScalingNotCroppingForSize:image toSize:targetSize];
            data = UIImageJPEGRepresentation(scaledImage, self.quality/100.0f);

            if (![data writeToFile:filePath options:NSAtomicWrite error:&err]) {
                result = [CDVPluginResult resultWithStatus:CDVCommandStatus_IO_EXCEPTION messageAsString:[err localizedDescription]];
                break;
            } else {
                if(self.outputType == BASE64_STRING){
                    [result_all addObject:[data base64EncodedStringWithOptions:0]];
                } else {
                    [result_all addObject:[[NSURL fileURLWithPath:filePath] absoluteString]];
                }
            }
        }
    }

    if (result == nil) {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:result_all];
    }

    [self.viewController dismissViewControllerAnimated:YES completion:nil];
    [self.commandDelegate sendPluginResult:result callbackId:self.callbackId];

}

//Optional implementation:
-(void)assetsPickerControllerDidCancel:(GMImagePickerController *)picker
{
   CDVPluginResult* pluginResult = nil;
   NSArray* emptyArray = [NSArray array];
   pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:emptyArray];
   [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
   [picker.presentingViewController dismissViewControllerAnimated:YES completion:nil];
   NSLog(@"GMImagePicker: User pressed cancel button");
}


@end
