#import "ViewController.h"
@import AVFoundation;
#import "Barcode.h"


@interface ViewController () <AVCaptureMetadataOutputObjectsDelegate>

@end

@implementation ViewController {
    AVCaptureSession * _captureSession;
    AVCaptureDevice * _videoDevice;
    AVCaptureDeviceInput * _videoInput;
    AVCaptureVideoPreviewLayer * _previewLayer;
    BOOL _running;
    AVCaptureMetadataOutput * _metadataOutput;
    NSMutableDictionary * _barcodes;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self setupCaptureSession];
    
    _previewView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
    [self.view addSubview:_previewView];
    
    _previewLayer.frame = _previewView.bounds;
    [_previewView.layer addSublayer:_previewLayer];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    
   [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    
    _barcodes = [NSMutableDictionary new];
}


- (void) viewDidAppear: (BOOL) animated {
    [super viewDidAppear:animated];
    [self startRunning];
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopRunning];
}


- (void) applicationWillEnterForeground: (NSNotification *) note {
    [self startRunning];
}

- (void) applicationDidEnterBackground: (NSNotification *) note {
    [self stopRunning];
}

- (void) startRunning {
    if (_running) {
        return;
    }
    [_captureSession startRunning];
    _running = YES;
    _metadataOutput.metadataObjectTypes = _metadataOutput.availableMetadataObjectTypes;
}

- (void) stopRunning {
    if (!_running) {
        return;
    }
    [_captureSession stopRunning];
    _running = NO;
}
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) setupCaptureSession {
    if (_captureSession) {
        return;
    }
    
    _videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (!_videoDevice) {
        NSLog(@"No video camera on this device!");
        return;
    }
    
    _captureSession = [[AVCaptureSession alloc] init];
    _videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:_videoDevice error:nil];
    
    if ([_captureSession canAddInput:_videoInput]) {
        [_captureSession addInput:_videoInput];
    }
    
    _previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
    _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
 
    // way to capture and process that metadata
    _metadataOutput = [[AVCaptureMetadataOutput alloc] init];
    dispatch_queue_t metadataQueue = dispatch_queue_create("com.razeware.ColloQR.metadata", 0);
    [_metadataOutput setMetadataObjectsDelegate:self queue:metadataQueue];
    if ([_captureSession canAddOutput:_metadataOutput]) {
        [_captureSession addOutput:_metadataOutput];
    }
}

- (void) captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
        
        NSMutableSet * foundBarcodes = [NSMutableSet new];
        
        [metadataObjects enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
             NSLog(@"Metadata: %@", obj);
        
        if ([obj isKindOfClass:[AVMetadataMachineReadableCodeObject class]]) {
            AVMetadataMachineReadableCodeObject * code = (AVMetadataMachineReadableCodeObject *)(AVMetadataMachineReadableCodeObject *)[_previewLayer transformedMetadataObjectForMetadataObject:obj];
            Barcode * barcode = [self processMetadataObject:code];
            [foundBarcodes addObject:barcode];
        }

        }];
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            // remove all old layers
            
            NSArray * allSublayers = [_previewView.layer.sublayers copy];
            [allSublayers enumerateObjectsUsingBlock:^(CALayer * layer, NSUInteger idx, BOOL *stop) {
                if (layer != _previewLayer) {
                    [layer removeFromSuperlayer];
                }
            }];
            // add new layers
            [foundBarcodes enumerateObjectsUsingBlock:^(Barcode * barcode, BOOL *stop) {
                CAShapeLayer * boundingBoxLayer = [CAShapeLayer new];
                boundingBoxLayer.path = barcode.boundingBoxPath.CGPath;
                boundingBoxLayer.lineWidth = 2.0f;
                boundingBoxLayer.strokeColor = [UIColor greenColor].CGColor;
                boundingBoxLayer.fillColor = [UIColor colorWithRed:0.0f green:1.0f blue:0.0f alpha:0.5f].CGColor;
                [_previewView.layer addSublayer:boundingBoxLayer];
                
                CAShapeLayer * cornerPathLayer = [CAShapeLayer new];
                cornerPathLayer.path = barcode.cornersPath.CGPath;
                cornerPathLayer.lineWidth = 2.0f;
                cornerPathLayer.strokeColor = [UIColor blueColor].CGColor;
                cornerPathLayer.fillColor = [UIColor colorWithRed:0.0f green:0.0f blue:1.0f alpha:0.5f].CGColor;
                [_previewView.layer addSublayer:cornerPathLayer];
            }];
        });
}

- (Barcode *) processMetadataObject: (AVMetadataMachineReadableCodeObject *) code {
    Barcode * barcode = _barcodes[code.stringValue];
    
    if (!barcode) {
        barcode = [Barcode new];
        _barcodes[code.stringValue] = barcode;
    }
    
    barcode.metadataObject = code;
    
    // create the path joining code's corners
    
    CGMutablePathRef cornersPath = CGPathCreateMutable();
    CGPoint point;
    CGPointMakeWithDictionaryRepresentation((CFDictionaryRef)code.corners[0], &point);
    CGPathMoveToPoint(cornersPath, nil, point.x, point.y);
    for (int i = 1; i < code.corners.count; ++i) {
        CGPointMakeWithDictionaryRepresentation((CFDictionaryRef)code.corners[i], &point);
        CGPathAddLineToPoint(cornersPath, nil, point.x, point.y);
    }
    CGPathCloseSubpath(cornersPath);
    barcode.cornersPath = [UIBezierPath bezierPathWithCGPath:cornersPath];
    CGPathRelease(cornersPath);
    
    // create the path for the code's bounding box
    barcode.boundingBoxPath = [UIBezierPath bezierPathWithRect:code.bounds];
    
    return barcode;
}
@end
