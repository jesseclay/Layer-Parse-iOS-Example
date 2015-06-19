//
//  ConversationDetailViewController.m
//  Layer-Parse-iOS-Example
//
//  Copyright (c) 2015 Layer, Inc. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "ConversationDetailViewController.h"
#import <Atlas/Atlas.h>
#import "CenterTextTableViewCell.h"
#import "InputTableViewCell.h"
#import "SVProgressHUD.h"

typedef NS_ENUM(NSInteger, ATLMConversationDetailTableSection) {
    ATLMConversationDetailTableSectionMetadata,
    ATLMConversationDetailTableSectionLeave,
    ATLMConversationDetailTableSectionCount,
};

typedef NS_ENUM(NSInteger, ATLMActionSheetTag) {
    ATLMActionSheetLeaveConversation
};

@interface ConversationDetailViewController () <UITextFieldDelegate, UIActionSheetDelegate>

@property (nonatomic) LYRConversation *conversation;
@property (nonatomic) NSMutableArray *participantIdentifiers;
@property (nonatomic) NSIndexPath *indexPathToRemove;

@end

@implementation ConversationDetailViewController

NSString *const ATLMConversationDetailViewControllerTitle = @"Details";
NSString *const ATLMConversationDetailTableViewAccessibilityLabel = @"Conversation Detail Table View";
NSString *const ATLMConversationNamePlaceholderText = @"Enter Conversation Name";
NSString *const ATLMConversationMetadataNameKey = @"title";

NSString *const ATLMDeleteConversationText = @"Delete Conversation";
NSString *const ATLMLeaveConversationText = @"Leave Conversation";

static NSString *const ATLMDefaultCellIdentifier = @"ATLMDefaultCellIdentifier";
static NSString *const ATLMInputCellIdentifier = @"ATLMInputCell";
static NSString *const ATLMCenterContentCellIdentifier = @"ATLMCenterContentCellIdentifier";

+ (instancetype)conversationDetailViewControllerWithConversation:(LYRConversation *)conversation
{
    return [[self alloc] initWithConversation:conversation];
}

- (id)initWithConversation:(LYRConversation *)conversation
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        _conversation = conversation;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = ATLMConversationDetailViewControllerTitle;
    self.tableView.sectionHeaderHeight = 48.0f;
    self.tableView.sectionFooterHeight = 0.0f;
    self.tableView.rowHeight = 48.0f;
    self.tableView.accessibilityLabel = ATLMConversationDetailTableViewAccessibilityLabel;
    self.tableView.isAccessibilityElement = YES;
    [self.tableView registerClass:[CenterTextTableViewCell class] forCellReuseIdentifier:ATLMCenterContentCellIdentifier];
    [self.tableView registerClass:[InputTableViewCell class] forCellReuseIdentifier:ATLMInputCellIdentifier];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:ATLMDefaultCellIdentifier];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return ATLMConversationDetailTableSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case ATLMConversationDetailTableSectionMetadata:
            return 1;
            
        case ATLMConversationDetailTableSectionLeave:
            return 1;
            
        default:
            return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case ATLMConversationDetailTableSectionMetadata: {
            InputTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:ATLMInputCellIdentifier forIndexPath:indexPath];
            [self configureConversationNameCell:cell];
            return cell;
        }
            
        case ATLMConversationDetailTableSectionLeave: {
            CenterTextTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:ATLMCenterContentCellIdentifier];
            cell.centerTextLabel.textColor = ATLRedColor();
            cell.centerTextLabel.text = self.conversation.participants.count > 2 ? ATLMLeaveConversationText : ATLMDeleteConversationText;
            return cell;
        }
            
        default:
            return nil;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch ((ATLMConversationDetailTableSection)section) {
        case ATLMConversationDetailTableSectionMetadata:
            return @"Conversation Name";
            
        default:
            return nil;
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch ((ATLMConversationDetailTableSection)indexPath.section) {
        case ATLMConversationDetailTableSectionLeave:
            [self confirmLeaveConversation];
            break;
            
        default:
            break;
    }
}

#pragma mark - Cell Configuration

- (void)configureConversationNameCell:(InputTableViewCell *)cell
{
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textField.delegate = self;
    cell.textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    cell.guideText = @"Name:";
    cell.placeHolderText = @"Enter Conversation Name";
    NSString *conversationName = [self.conversation.metadata valueForKey:ATLMConversationMetadataNameKey];
    cell.textField.text = conversationName;
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (actionSheet.tag == ATLMActionSheetLeaveConversation) {
        if (buttonIndex == actionSheet.destructiveButtonIndex) {
            self.conversation.participants.count > 2 ? [self leaveConversation] : [self deleteConversation];
        }
    }
}

#pragma mark - Actions
- (void)confirmLeaveConversation
{
    NSString *destructiveButtonTitle = self.conversation.participants.count > 2 ? ATLMLeaveConversationText : ATLMDeleteConversationText;
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:destructiveButtonTitle otherButtonTitles:nil];
    actionSheet.tag = ATLMActionSheetLeaveConversation;
    [actionSheet showInView:self.view];
}

- (void)leaveConversation
{
    NSSet *participants = [NSSet setWithObject:self.layerClient.authenticatedUserID];
    NSError *error;
    [self.conversation removeParticipants:participants error:&error];
    if (error) {
        NSLog(@"There was an error leaving the conversation: %@",error);
        return;
    } else {
        ConversationListViewController *conversationListViewController = [ConversationListViewController  conversationListViewControllerWithLayerClient:self.layerClient];
        [self.navigationController pushViewController:conversationListViewController animated:YES];
    }
}

- (void)deleteConversation
{
    NSError *error;
    [self.conversation delete:LYRDeletionModeAllParticipants error:&error];
    if (error) {
            NSLog(@"There was an error deleting the conversation: %@",error);
        return;
    } else {
        ConversationListViewController *conversationListViewController = [ConversationListViewController  conversationListViewControllerWithLayerClient:self.layerClient];
        [self.navigationController pushViewController:conversationListViewController animated:YES];
    }
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    NSString *title = [self.conversation.metadata valueForKey:ATLMConversationMetadataNameKey];
    if (![textField.text isEqualToString:title]) {
        [self.conversation setValue:textField.text forMetadataAtKeyPath:ATLMConversationMetadataNameKey];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField.text.length > 0) {
        [self.conversation setValue:textField.text forMetadataAtKeyPath:ATLMConversationMetadataNameKey];
    } else {
        [self.conversation deleteValueForMetadataAtKeyPath:ATLMConversationMetadataNameKey];
    }
    [textField resignFirstResponder];
    return YES;
}

@end