//
//  Barcode.h
//  ColloQR
//
//  Created by Oleksandr Isaiev on 01.09.14.
//  Copyright (c) 2014 None. All rights reserved.
//

#import <Foundation/Foundation.h>
@import AVFoundation;

@interface Barcode : NSObject

@property (nonatomic, strong) AVMetadataMachineReadableCodeObject * metadataObject;
@property (nonatomic, strong) UIBezierPath * cornersPath;
@property (nonatomic, strong) UIBezierPath * boundingBoxPath;

@end
