//
//  MessageComposeTableViewController.h
//  
//
//  Created by Dylan Bourgeois on 02/11/14.
//
//

#import <UIKit/UIKit.h>

#import "Contact.h"

#import "JSQMessagesToolbarContentView.h"
#import "JSQMessagesInputToolbar.h"
#import "JSQMessagesComposerTextView.h"

#import "JSQMessagesKeyboardController.h"

@interface MessageComposeTableViewController : UITableViewController

- (NSString *)sanitizePhoneNumberString:(NSString *)phoneNumber;

@end
