//
//  MessageComposeTableViewController.m
//  
//
//  Created by Dylan Bourgeois on 02/11/14.
//
//

#import "Environment.h"
#import "Contact.h"
#import "MessageComposeTableViewController.h"
#import "MessagesViewController.h"
#import "SignalsViewController.h"

#import "ContactTableViewCell.h"

@interface MessageComposeTableViewController () <UISearchBarDelegate, UISearchResultsUpdating>
{
    NSArray* contacts;
    NSArray* searchResults;
}

@property (nonatomic, strong) UISearchController *searchController;

@end

@implementation MessageComposeTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self initializeSearch];
    
    contacts = [[Environment getCurrent] contactsManager].textSecureContacts;
    searchResults = contacts;

    self.tableView.tableFooterView = [[UIView alloc]initWithFrame:CGRectZero];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - Initializers

-(void)initializeSearch
{
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    
    self.searchController.searchResultsUpdater = self;
    
    self.searchController.searchBar.frame = CGRectMake(self.searchController.searchBar.frame.origin.x, self.searchController.searchBar.frame.origin.y, self.searchController.searchBar.frame.size.width, 44.0);
    
    self.tableView.tableHeaderView = self.searchController.searchBar;
    
    self.searchController.dimsBackgroundDuringPresentation = NO;
    self.searchController.hidesNavigationBarDuringPresentation = NO;
    
    self.definesPresentationContext = YES;
    
    self.searchController.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchController.searchBar.placeholder = @"Search by name or number";
    
}

#pragma mark - UISearchResultsUpdating

-(void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    
    NSString *searchString = [self.searchController.searchBar text];
    
    [self filterContentForSearchText:searchString scope:nil];
    
    [self.tableView reloadData];
}


#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)selectedScope {
    [self updateSearchResultsForSearchController:self.searchController];
}


#pragma mark - Filter

- (void)filterContentForSearchText:(NSString*)searchText scope:(NSString*)scope
{
    // (123) 456-7890 would be sanitized into 1234567890
    NSCharacterSet *illegalCharacters = [NSCharacterSet characterSetWithCharactersInString:@" ()-+[]"];
    NSString *sanitizedNumber = [[searchText componentsSeparatedByCharactersInSet:illegalCharacters] componentsJoinedByString:@""];
    
    NSPredicate *resultPredicate = [NSPredicate predicateWithFormat:@"(fullName contains[c] %@) OR (allPhoneNumbers contains[c] %@)", searchText, sanitizedNumber];
    searchResults = [contacts filteredArrayUsingPredicate:resultPredicate];
    if (!searchResults.count && _searchController.searchBar.text.length == 0) searchResults = contacts;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    if (self.searchController.active) {
        return (NSInteger)[searchResults count];
    } else {
        return (NSInteger)[contacts count];
    }
}


- (ContactTableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ContactTableViewCell *cell = (ContactTableViewCell*)[tableView dequeueReusableCellWithIdentifier:@"ContactTableViewCell"];
    
    if (cell == nil) {
        cell = [[ContactTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ContactTableViewCell"];
    }

    cell.shouldShowContactButtons = NO;

    [cell configureWithContact:[self contactForIndexPath:indexPath]];
    
    tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];

    return cell;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 44.0f;
}

#pragma mark - Table View delegate

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *identifier = [[[self contactForIndexPath:indexPath] textSecureIdentifiers] firstObject];
    
    [self dismissViewControllerAnimated:YES completion:^(){
        [Environment messageIdentifier:identifier];
    }];
}
    

-(void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
    ContactTableViewCell * cell = (ContactTableViewCell*)[tableView cellForRowAtIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryNone;
}

-(Contact*)contactForIndexPath:(NSIndexPath*)indexPath
{
    Contact *contact = nil;
    
    if (self.searchController.active) {
        contact = [searchResults objectAtIndex:(NSUInteger)indexPath.row];
    } else {
        contact = [contacts objectAtIndex:(NSUInteger)indexPath.row];
    }

    return contact;
}


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
  
}

-(IBAction)closeAction:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}



@end
