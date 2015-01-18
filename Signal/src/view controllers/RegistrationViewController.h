//
//  RegistrationViewController.h
//  Signal
//
//  Created by Dylan Bourgeois on 13/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CountryCodeViewController.h"


@interface RegistrationViewController : UIViewController<UITextFieldDelegate>

// Country code
@property (nonatomic, strong) IBOutlet UIButton* countryNameButton;
@property (nonatomic, strong) IBOutlet UIButton* countryCodeButton;

//Phone number
@property(nonatomic, strong) IBOutlet UITextField* phoneNumberTextField;

//Button
@property(nonatomic, strong) IBOutlet UIButton* sendCodeButton;


- (IBAction)unwindToCountryCodeWasSelected:(UIStoryboardSegue *)segue;
- (IBAction)unwindToCountryCodeSelectionCancelled:(UIStoryboardSegue *)segue;

@end
