#import "ViewController.h"
@import AVFoundation;

@interface ViewController ()

@end

@implementation ViewController {
    AVCaptureSession * _captureSession;
    AVCaptureDevice * _videoDevice;
    AVCaptureDeviceInput * _videoInput;
    AVCaptureVideoPreviewLayer * _previewLayer;
    BOOL _running;
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
    
}

@end
