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
    AVSpeechSynthesizer * _speechSynthesizer;
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
    _speechSynthesizer = [[AVSpeechSynthesizer alloc] init];
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
    
    // speech
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback withOptions:0 error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
}

- (void) stopRunning {
    if (!_running) {
        return;
    }
    [_captureSession stopRunning];
    _running = NO;
    
    // speech
    [[AVAudioSession sharedInstance] setActive:NO error:nil];
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
    
    NSSet * originalBarcodes = [NSSet setWithArray:_barcodes.allValues];
    // 1
        NSMutableSet * foundBarcodes = [NSMutableSet new];
        
        [metadataObjects enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
             NSLog(@"Metadata: %@", obj);
        // 2
        if ([obj isKindOfClass:[AVMetadataMachineReadableCodeObject class]]) {
            // 3
            AVMetadataMachineReadableCodeObject * code = (AVMetadataMachineReadableCodeObject *)[_previewLayer transformedMetadataObjectForMetadataObject:obj];
            // 4
            Barcode * barcode = [self processMetadataObject:code];
            [foundBarcodes addObject:barcode];
        }

        }];

    NSMutableSet * newBarcodes = [foundBarcodes mutableCopy];
    [newBarcodes minusSet:originalBarcodes];
    
    NSMutableSet * goneBarcodes = [originalBarcodes mutableCopy];
    [goneBarcodes minusSet:foundBarcodes];
    
    [goneBarcodes enumerateObjectsUsingBlock:^(Barcode * barcode, BOOL *stop) {
        [_barcodes removeObjectForKey:barcode.metadataObject.stringValue];
    }];
    
        dispatch_sync(dispatch_get_main_queue(), ^{
            // remove all old layers
            // 5
            NSArray * allSublayers = [_previewView.layer.sublayers copy];
            [allSublayers enumerateObjectsUsingBlock:^(CALayer * layer, NSUInteger idx, BOOL *stop) {
                if (layer != _previewLayer) {
                    [layer removeFromSuperlayer];
                }
            }];
            // add new layers
            // 6
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
            
            // speech
            [newBarcodes enumerateObjectsUsingBlock:^(Barcode * barcode, BOOL *stop) {
                AVSpeechUtterance * utterance = [[AVSpeechUtterance alloc] initWithString:barcode.metadataObject.stringValue];
                utterance.rate = AVSpeechUtteranceDefaultSpeechRate + ((AVSpeechUtteranceMaximumSpeechRate - AVSpeechUtteranceMinimumSpeechRate) * 0.5f);
                utterance.volume = 1.0f;
                utterance.pitchMultiplier = 1.2f;
                
                [_speechSynthesizer speakUtterance:utterance];
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
