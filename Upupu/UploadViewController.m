//
//  UploadViewControllerDelegate.m
//  Upupu
//
//  Created by David Ott on 11/23/11.
//  Copyright 2011 Xcoo, Inc. All rights reserved.
//

#import "UploadViewController.h"
#import "UpupuAppDelegate.h"

#import "WebDAVUploader.h"
#import "DropboxUploader.h"

#import "Settings.h"
#import "IASKAppSettingsViewController.h"

#import "ImageUtil.h"
#import "HUDUtil.h"
#import "AlertUtil.h"

@interface UploadViewController () <MBProgressHUDDelegate, UITextFieldDelegate> {
    MBProgressHUD *_hud;
}

- (IBAction)retake:(id)sender;
- (IBAction)upload:(id)sender;
- (IBAction)setting:(id)sender;

@property (nonatomic, retain) IBOutlet UITextField *nameField;
@property (nonatomic, retain) IBOutlet UIImageView *imageView;
@property (nonatomic, retain) IBOutlet UIBarItem *retakeButton;
@property (nonatomic, retain) IBOutlet UIBarItem *uploadButton;
@property (nonatomic, retain) IBOutlet UIBarItem *settingButton;

@end

@implementation UploadViewController

@synthesize nameField = _nameField, imageView = _imageView;
@synthesize retakeButton = _retakeButton, uploadButton = _uploadButton, settingButton = _settingButton;
@synthesize image = _image;
@synthesize delegate = _delegate;

#pragma mark - Class Method -

+ (NSString *)makeFilename
{
    NSDate *dateCreated = [[[NSDate alloc] init] autorelease];
    NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
    [dateFormatter setDateFormat:@"yyyyMMdd_HHmmss"];
    return [dateFormatter stringFromDate:dateCreated];
}

#pragma mark - Actions -

-(IBAction) retake:(id)sender
{
    if( _delegate != nil && [_delegate respondsToSelector:@selector(uploadViewControllerDidReturn:)] ) {
        [_delegate uploadViewControllerDidReturn:self];
    }
}

- (IBAction) upload:(id)sender
{
    if (![Settings isWebDAVEnabled] && ![Settings isDropboxEnabled]) {
        [AlertUtil showWithTitle:@"Error" andMessage:@"Setup server configuration before uploading"];
        return;
    }
    
    if ([Settings isWebDAVEnabled] &&
        ([Settings webDAVURL] == nil || [[Settings webDAVURL] isEqualToString:@""])) {
        [AlertUtil showWithTitle:@"Error" andMessage:@"Invalid WebDAV server URL"];
        return;
    }
    
    _hud = [[HUDUtil showWithText:@"Uploading" forView:self.navigationController.view whileExecuting:@selector(lauchUpload) onTarget:self] retain];
}

- (IBAction) setting:(id)sender
{
    if( _delegate != nil && [_delegate respondsToSelector:@selector(uploadViewControllerDidSetup:)] ) {
        [_delegate uploadViewControllerDidSetup:self];
    }
}

#pragma mark - Take Picture -

- (void) showFailed
{
    _hud.customView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"failure_icon.png"]] autorelease];
    _hud.mode = MBProgressHUDModeCustomView;
    _hud.labelText = @"Failed";
    _hud.detailsLabelText = @"";
}

- (void) lauchUpload
{
    UIImage *image = nil;
    
    // resize image
    switch ([Settings photoResolution]) {
        case 0:
        default:
            image = _image;
            break;
        case 1:
            image = [ImageUtil scaleImage:_image withSize:CGSizeMake(1600, 1200)];
            break;
        case 2:
            image = [ImageUtil scaleImage:_image withSize:CGSizeMake(800, 600)];
            break;
    }
    
    // convert to JPG data
    CGFloat quality;
    switch ([Settings photoQuality]) {
        case 0:
        default:
            quality = 1.0f; // High
            break;
        case 1:
            quality = 0.6f; // Mideum
            break;
        case 2:
            quality = 0.2f; // Low
            break;
    }
    
    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
    
    NSData *imageData = UIImageJPEGRepresentation(image, quality);
    
    NSString *filename = [_nameField text];

    // WebDAV
    if ( [Settings isWebDAVEnabled] ) {
        _hud.detailsLabelText = @"WebDAV";
        WebDAVUploader *uploader = [[WebDAVUploader alloc] initWithName:filename imageData:imageData];
        [uploader upload];
        if ( !uploader.success ) {
            [self showFailed];
            sleep(1);
            return;
        }
        [uploader release];
    }
    
    // Dropbox
    if ( [Settings isDropboxEnabled] ) {
        _hud.detailsLabelText = @"Dropbox";
        DropboxUploader *uploader = [DropboxUploader sharedInstance];
        [uploader uploadWithName:filename imageData:imageData];
        if ( !uploader.success ) {
            [self showFailed];
            sleep(1);
            return;
        }
    }
    
    // all succeeded
    _hud.customView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"success_icon.png"]] autorelease];
    _hud.mode = MBProgressHUDModeCustomView;
    _hud.labelText = @"Succeded";
    _hud.detailsLabelText = @"";
    
    sleep(1);

    // finish
    if( _delegate != nil && [_delegate respondsToSelector:@selector(uploadViewControllerDidFinished:)] ) {
        [_delegate uploadViewControllerDidFinished:self];
    }
}

#pragma mark - View lifecycle -

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _imageView.image = _image;
    
    if (!_image) {
        _nameField.enabled = NO;
        _uploadButton.enabled = NO;
    } else {
        _nameField.text = [UploadViewController makeFilename];
        _nameField.enabled = YES;
        _uploadButton.enabled = YES;
    }
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void) viewDidUnload
{
    SAFE_RELEASE(_image)
    
    SAFE_RELEASE(_nameField)
    SAFE_RELEASE(_imageView)
    SAFE_RELEASE(_retakeButton)
    SAFE_RELEASE(_uploadButton)
    SAFE_RELEASE(_settingButton)

    SAFE_RELEASE(_hud)
    
    [super viewDidUnload];
    
    Logging(@"deallocated");
}

- (void)dealloc
{
    SAFE_RELEASE(_image)
    
    SAFE_RELEASE(_nameField)
    SAFE_RELEASE(_imageView)
    SAFE_RELEASE(_retakeButton)
    SAFE_RELEASE(_uploadButton)
    SAFE_RELEASE(_settingButton)
    
    SAFE_RELEASE(_hud)
    
    [super dealloc];
    
    Logging(@"deallocated");
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - TextFieldDelegate -

- (BOOL)textFieldShouldReturn:(UITextField *)textField 
{
    [textField resignFirstResponder]; 
    return YES;
}

@end
