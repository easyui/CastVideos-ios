// Copyright 2015 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "QueueTableViewController.h"

#import "ChromecastDeviceController.h"
#import "SimpleImageFetcher.h"

#import <GoogleCast/GoogleCast.h>

@interface QueueTableViewController () <ChromecastDeviceControllerDelegate>

@property(strong, nonatomic) GCKMediaControlChannel *mediaControlChannel;

@property(assign, nonatomic) NSInteger currentItemRow;

@end

@implementation QueueTableViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  _mediaControlChannel = [ChromecastDeviceController sharedInstance].mediaControlChannel;
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];

  // The queue is always reorderable.
  self.tableView.editing = YES;

  // Assign ourselves as delegate ONLY in viewWillAppear of a view controller.
  ChromecastDeviceController *controller = [ChromecastDeviceController sharedInstance];
  controller.delegate = self;
  self.navigationItem.rightBarButtonItem = [controller queueItemForController:self];

  [self updateCurrentItem];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  [[ChromecastDeviceController sharedInstance] updateToolbarForViewController:self];
}

- (void)viewWillDisappear:(BOOL)animated {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super viewWillDisappear:animated];
}

// Identify currentItemRow such that it can be indicated visually,
// and grey out rows before this item.
- (void)updateCurrentItem {
  _currentItemRow = -1;
  GCKMediaStatus *mediaStatus = _mediaControlChannel.mediaStatus;
  NSInteger count = [mediaStatus queueItemCount];
  for (NSInteger i = 0; i < count; ++i) {
    GCKMediaQueueItem *item = [mediaStatus queueItemAtIndex:i];
    if (item.itemID == mediaStatus.currentItemID) {
      _currentItemRow = i;
      break;
    }
  }
}

#pragma mark - ChromecastDeviceControllerDelegate

- (void)didUpdateQueueForDevice:(GCKDevice *)device {
  [self.tableView reloadData];
  [self updateCurrentItem];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return [_mediaControlChannel.mediaStatus queueItemCount];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *cell =
      [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];

  GCKMediaStatus *mediaStatus = _mediaControlChannel.mediaStatus;
  GCKMediaQueueItem *item = [mediaStatus queueItemAtIndex:indexPath.row];
  GCKMediaInformation *info = item.mediaInformation;

  if (indexPath.row < _currentItemRow) {
    cell.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.1];
  } else {
    cell.backgroundColor = nil;
  }

  UILabel *mediaTitle = (UILabel *)[cell viewWithTag:1];
  UILabel *mediaOwner = (UILabel *)[cell viewWithTag:2];
  UIImageView *mediaPreview = (UIImageView *)[cell viewWithTag:3];

  mediaTitle.text = [info.metadata stringForKey:kGCKMetadataKeyTitle];
  mediaOwner.text = [info.metadata stringForKey:kGCKMetadataKeySubtitle];

  // Update the image, async.
  GCKImage *img = [info.metadata.images objectAtIndex:0];
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    UIImage *image = [UIImage imageWithData:[SimpleImageFetcher getDataFromImageURL:img.URL]];
    dispatch_async(dispatch_get_main_queue(), ^{
      mediaPreview.image = image;
    });
  });

  return cell;
}

#pragma mark - UITableViewDelegate

- (BOOL)tableView:(UITableView *)tableView
    shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
  return NO;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
           editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
  return UITableViewCellEditingStyleNone;
}

// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView
    moveRowAtIndexPath:(NSIndexPath *)fromIndexPath
      toIndexPath:(NSIndexPath *)toIndexPath {
  GCKMediaStatus *mediaStatus = _mediaControlChannel.mediaStatus;

  GCKMediaQueueItem *from =
      [mediaStatus queueItemAtIndex:fromIndexPath.row];
  NSInteger toRow = toIndexPath.row;

  if (toIndexPath.row > fromIndexPath.row) {
    // Moving farther away in the queue.
    toRow += 1;
  }

  NSUInteger beforeItemID;
  if (toRow < [mediaStatus queueItemCount]) {
    GCKMediaQueueItem *to = [mediaStatus queueItemAtIndex:toRow];
    beforeItemID = to.itemID;
  } else {
    // Moving to the end.
    beforeItemID = kGCKMediaQueueInvalidItemID;
  }

  [_mediaControlChannel queueMoveItemWithID:from.itemID
                           beforeItemWithID:beforeItemID];
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
  // All rows inside the queue may be reordered.
  return YES;
}

@end
