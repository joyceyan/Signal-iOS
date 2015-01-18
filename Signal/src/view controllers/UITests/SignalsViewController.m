//
//  SignalsViewController.m
//  Signal
//
//  Created by Dylan Bourgeois on 27/10/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//

#import "UIUtil.h"
#import "InboxTableViewCell.h"

#import "Environment.h"
#import "MessagesViewController.h"
#import "SignalsViewController.h"
#import "InCallViewController.h"
#import "TSStorageManager.h"
#import "TSAccountManager.h"
#import "TSDatabaseView.h"
#import "TSSocketManager.h"
#import "TSContactThread.h"
#import "TSMessagesManager+sendMessages.h"

#import "NSDate+millisecondTimeStamp.h"

#import <YapDatabase/YapDatabaseViewChange.h>
#import "YapDatabaseViewTransaction.h"
#import "YapDatabaseViewMappings.h"
#import "YapDatabaseViewConnection.h"
#import "YapDatabaseFullTextSearch.h"
#import "YapDatabase.h"

#define CELL_HEIGHT 72.0f
#define HEADER_HEIGHT 44.0f


static NSString *const inboxTableViewCell      = @"inBoxTableViewCell";
static NSString *const kSegueIndentifier = @"showSegue";
static NSString* const kCallSegue = @"2.0_6.0_Call_Segue";
static NSString* const kShowSignupFlowSegue = @"showSignupFlow";

@interface SignalsViewController ()

@property (strong, nonatomic) UILabel * emptyViewLabel;
@property (nonatomic, strong) YapDatabaseConnection *editingDbConnection;
@property (nonatomic, strong) YapDatabaseConnection *uiDatabaseConnection;
@property (nonatomic, strong) YapDatabaseViewMappings *threadMappings;

@end

@implementation SignalsViewController

- (void)awakeFromNib{
    [[Environment getCurrent] setSignalsViewController:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self tableViewSetUp];
    
    self.editingDbConnection = TSStorageManager.sharedManager.newDatabaseConnection;
    
    [self.uiDatabaseConnection beginLongLivedReadTransaction];
    
    self.threadMappings = [[YapDatabaseViewMappings alloc] initWithGroups:@[TSInboxGroup]
                                                                     view:TSThreadDatabaseViewExtensionName];
    
    [self.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction){
        [self.threadMappings updateWithTransaction:transaction];
    }];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(yapDatabaseModified:)
                                                 name:TSUIDatabaseConnectionDidUpdateNotification
                                               object:nil];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self  updateTableViewHeader];
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
    if (![TSAccountManager isRegistered]){
        [self performSegueWithIdentifier:kShowSignupFlowSegue sender:self];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}


-(void)tableViewSetUp
{
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (NSInteger)[self.threadMappings numberOfSections];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)[self.threadMappings numberOfItemsInSection:(NSUInteger)section];
}

- (InboxTableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath {
    
    InboxTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:inboxTableViewCell];
    TSThread *thread         = [self threadForIndexPath:indexPath];
    
    if (!cell) {
        cell = [[InboxTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                         reuseIdentifier:inboxTableViewCell];
        cell.delegate = self;
    }
    
    [cell configureWithThread:thread];
    [cell configureForState:_inboxArchiveSwitch.selectedSegmentIndex == 0 ? kInboxState : kArchiveState];
    
    return cell;
}

- (TSThread*)threadForIndexPath:(NSIndexPath*)indexPath {
    
    __block TSThread *thread = nil;
    [self.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        thread = [[transaction extension:TSThreadDatabaseViewExtensionName] objectAtIndexPath:indexPath withMappings:self.threadMappings];
    }];
    
    return thread;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return CELL_HEIGHT;
}

#pragma mark - HomeFeedTableViewCellDelegate

- (void)tableViewCellTappedDelete:(InboxTableViewCell*)cell {
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    TSThread    *thread    = [self threadForIndexPath:indexPath];
    if([thread isKindOfClass:[TSGroupThread class]]) {
        DDLogDebug(@"leaving the group");
        TSOutgoingMessage *message = [[TSOutgoingMessage alloc] initWithTimestamp:[NSDate ows_millisecondTimeStamp] inThread:thread messageBody:@"" attachments:[[NSMutableArray alloc] init]];
        message.groupMetaMessage = TSGroupMessageQuit;
        [[TSMessagesManager sharedManager] sendMessage:message inThread:thread];
    }
    [self.editingDbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        [thread removeWithTransaction:transaction];
    }];
}

- (void)tableViewCellTappedArchive:(InboxTableViewCell*)cell {
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    TSThread    *thread    = [self threadForIndexPath:indexPath];
    thread.archivalDate    = _inboxArchiveSwitch.selectedSegmentIndex == 0 ? [NSDate date] : nil ;
    
    [self.editingDbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        [thread saveWithTransaction:transaction];
    }];
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath{
    [self performSegueWithIdentifier:kSegueIndentifier sender:self];
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    if ([segue.identifier isEqualToString:kSegueIndentifier]){
        MessagesViewController * vc    = [segue destinationViewController];
        NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
        TSThread *thread               = [self threadForIndexPath:selectedIndexPath];
        
        if (self.contactIdentifierFromCompose){
            [vc setupWithTSIdentifier:self.contactIdentifierFromCompose];
            self.contactIdentifierFromCompose = nil;
        }
        else if (self.groupFromCompose) {
            [vc setupWithTSGroup:self.groupFromCompose];
            self.groupFromCompose = nil;
        }
        else if (thread) {
            [vc setupWithThread:thread];
        }
    }
    else if ([segue.identifier isEqualToString:kCallSegue]) {
        InCallViewController* vc = [segue destinationViewController];
        [vc configureWithLatestCall:_latestCall];
        _latestCall = nil;
    }
}

#pragma mark - IBAction

-(IBAction)segmentDidChange:(id)sender
{
    switch (_inboxArchiveSwitch.selectedSegmentIndex) {
        case 0:
            self.threadMappings = [[YapDatabaseViewMappings alloc] initWithGroups:@[TSInboxGroup]
                                                                             view:TSThreadDatabaseViewExtensionName];
            break;
            
        case 1:
            self.threadMappings = [[YapDatabaseViewMappings alloc] initWithGroups:@[TSArchiveGroup]
                                                                             view:TSThreadDatabaseViewExtensionName];
            break;
    }
    
    [self.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction){
        [self.threadMappings updateWithTransaction:transaction];
    }];
    [self.tableView reloadData];
    [self updateTableViewHeader];
}

#pragma mark Database delegates

- (YapDatabaseConnection *)uiDatabaseConnection {
    NSAssert([NSThread isMainThread], @"Must access uiDatabaseConnection on main thread!");
    if (!_uiDatabaseConnection) {
        YapDatabase *database = TSStorageManager.sharedManager.database;
        _uiDatabaseConnection = [database newConnection];
        [_uiDatabaseConnection beginLongLivedReadTransaction];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(yapDatabaseModified:)
                                                     name:YapDatabaseModifiedNotification
                                                   object:database];
    }
    return _uiDatabaseConnection;
}

- (void)yapDatabaseModified:(NSNotification *)notification {
    NSArray *notifications  = [self.uiDatabaseConnection beginLongLivedReadTransaction];
    NSArray *sectionChanges = nil;
    NSArray *rowChanges     = nil;

    [[self.uiDatabaseConnection ext:TSThreadDatabaseViewExtensionName] getSectionChanges:&sectionChanges
                                                                              rowChanges:&rowChanges
                                                                        forNotifications:notifications
                                                                            withMappings:self.threadMappings];
    
    if ([sectionChanges count] == 0 && [rowChanges count] == 0){
        return;
    }
    
    [self.tableView beginUpdates];
    
    for (YapDatabaseViewSectionChange *sectionChange in sectionChanges)
    {
        switch (sectionChange.type)
        {
            case YapDatabaseViewChangeDelete :
            {
                [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionChange.index]
                              withRowAnimation:UITableViewRowAnimationAutomatic];
                break;
            }
            case YapDatabaseViewChangeInsert :
            {
                [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionChange.index]
                              withRowAnimation:UITableViewRowAnimationAutomatic];
                break;
            }
            case YapDatabaseViewChangeUpdate:
            case YapDatabaseViewChangeMove:
                break;
        }
    }
    
    for (YapDatabaseViewRowChange *rowChange in rowChanges)
    {
        switch (rowChange.type)
        {
            case YapDatabaseViewChangeDelete :
            {
                [self.tableView deleteRowsAtIndexPaths:@[ rowChange.indexPath ]
                                      withRowAnimation:UITableViewRowAnimationAutomatic];
                break;
            }
            case YapDatabaseViewChangeInsert :
            {
                [self.tableView insertRowsAtIndexPaths:@[ rowChange.newIndexPath ]
                                      withRowAnimation:UITableViewRowAnimationAutomatic];
                break;
            }
            case YapDatabaseViewChangeMove :
            {
                [self.tableView deleteRowsAtIndexPaths:@[ rowChange.indexPath ]
                                      withRowAnimation:UITableViewRowAnimationAutomatic];
                [self.tableView insertRowsAtIndexPaths:@[ rowChange.newIndexPath ]
                                      withRowAnimation:UITableViewRowAnimationAutomatic];
                break;
            }
            case YapDatabaseViewChangeUpdate :
            {
                [self.tableView reloadRowsAtIndexPaths:@[ rowChange.indexPath ]
                                      withRowAnimation:UITableViewRowAnimationNone];
                break;
            }
        }
    }
    
    [self.tableView endUpdates];
    [self updateTableViewHeader];
}

- (void)updateTableViewHeader{
    if ([self.threadMappings numberOfItemsInAllGroups]==0)
    {
        CGRect r = CGRectMake(0, 60, 300, 70);
        _emptyViewLabel = [[UILabel alloc]initWithFrame:r];
        _emptyViewLabel.textColor = [UIColor grayColor];
        _emptyViewLabel.font = [UIFont ows_thinFontWithSize:14.0f];
        _emptyViewLabel.textAlignment = NSTextAlignmentCenter;
        _emptyViewLabel.text = @"You have no messages yet.";
        self.tableView.tableHeaderView = _emptyViewLabel;
    } else {
        _emptyViewLabel = nil;
        self.tableView.tableHeaderView = nil;
    }
}

- (IBAction)unwindSettingsDone:(UIStoryboardSegue *)segue {
    
}

@end
