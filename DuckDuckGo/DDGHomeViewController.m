//
//  DDGViewController.m
//  DuckDuckGo2
//
//  Created by Chris Heimark on 12/9/11.
//  Copyright (c) 2011 DuckDuckGo, Inc. All rights reserved.
//

#import "DDGAppDelegate.h"
#import "DDGHomeViewController.h"
#import "DDGWebViewController.h"
#import "AFNetworking.h"
#import "DDGCache.h"
#import <QuartzCore/QuartzCore.h>
#import "NSArray+ConcurrentIteration.h"
#import "DDGNewsProvider.h"
#import "DDGSettingsViewController.h"
#import "DDGChooseSourcesViewController.h"
#import <AudioToolbox/AudioToolbox.h>
#import "NSArray+ConcurrentIteration.h"
#import "DDGStory.h"
#import "ECSlidingViewController.h"
#import "DDGUnderViewController.h"

@implementation DDGHomeViewController

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
	self.searchController = [[DDGSearchController alloc] initWithNibName:@"DDGSearchController" containerViewController:self];
	_searchController.searchHandler = self;
    _searchController.state = DDGSearchControllerStateHome;
    
    linen = [UIColor colorWithPatternImage:[UIImage imageNamed:@"linen_bg.png"]];
    _tableView.separatorColor = [UIColor clearColor];
    _tableView.backgroundColor = linen;
    
    topShadow = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"table_view_shadow_top.png"]];
    topShadow.frame = CGRectMake(0, 0, self.tableView.frame.size.width, 5.0);
    topShadow.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    // shadow gets added to table view in scrollViewDidScroll
    
    if (refreshHeaderView == nil) {
		refreshHeaderView = [[EGORefreshTableHeaderView alloc] initWithFrame:CGRectMake(0.0f, 0.0f - self.tableView.bounds.size.height, self.view.frame.size.width, self.tableView.bounds.size.height)];
		refreshHeaderView.delegate = self;
		[self.tableView addSubview:refreshHeaderView];
        [refreshHeaderView refreshLastUpdatedDate];
	}
	
    [refreshHeaderView refreshLastUpdatedDate];
    
    // force-decompress the first 10 images
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        
        NSArray *stories = [DDGNewsProvider sharedProvider].stories;
        for(int i=0;i<MIN(stories.count, 10);i++)
            [[stories objectAtIndex:i] prefetchAndDecompressImage];
    });
    
    DDGUnderViewController *underVC = [[DDGUnderViewController alloc] initWithHomeViewController:self];
    self.slidingViewController.underLeftViewController = underVC;
    [self.slidingViewController setAnchorRightRevealAmount:200.0];
    
    // this one time, we have to do add the gesture recognizer manually; underVC only does it for us when the view is loaded through the menu
    [underVC configureViewController:self];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [_searchController clearAddressBar];
        
    [self beginDownloadingStories];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    // if we animated out, animate back in
    if(_tableView.alpha == 0) {
        _tableView.transform = CGAffineTransformMakeScale(2, 2);
        [UIView animateWithDuration:0.3 animations:^{
            _tableView.alpha = 1;
            _tableView.transform = CGAffineTransformIdentity;
        }];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
	if (IPHONE)
	    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
	else
        return YES;
}

-(void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
        
    [_searchController willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

#pragma mark - Scroll view delegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if(scrollView.contentOffset.y <= 0) {
        [refreshHeaderView egoRefreshScrollViewDidScroll:scrollView];

        CGRect f = topShadow.frame;
        f.origin.y = scrollView.contentOffset.y;
        topShadow.frame = f;
        
        [_tableView insertSubview:topShadow atIndex:0];
    }
}

-(void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    [refreshHeaderView egoRefreshScrollViewDidEndDragging:scrollView];
}

#pragma mark - EGORefreshTableHeaderDelegate Methods

- (void)egoRefreshTableHeaderDidTriggerRefresh:(EGORefreshTableHeaderView*)view {
    [self beginDownloadingStories];
    
    if([[DDGCache objectForKey:@"quack" inCache:@"settings"] boolValue]) {
        SystemSoundID quack;
        NSString *path = [[NSBundle mainBundle] pathForResource:@"quack" ofType:@"wav"];
        NSURL *url = [NSURL URLWithString:path];
        AudioServicesCreateSystemSoundID((__bridge_retained CFURLRef)url, &quack);
        AudioServicesPlaySystemSound(quack);
    }
}

- (BOOL)egoRefreshTableHeaderDataSourceIsLoading:(EGORefreshTableHeaderView*)view {
    return isRefreshing;
}

- (NSDate*)egoRefreshTableHeaderDataSourceLastUpdated:(EGORefreshTableHeaderView*)view {
    return [DDGCache objectForKey:@"storiesUpdated" inCache:@"misc"];
}

#pragma mark - Search handler

-(void)searchControllerLeftButtonPressed {
    [self.slidingViewController anchorTopViewTo:ECRight];
}

-(void)loadQueryOrURL:(NSString *)queryOrURL {    
    [(DDGUnderViewController *)self.slidingViewController.underLeftViewController loadQueryOrURL:queryOrURL];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [DDGNewsProvider sharedProvider].stories.count;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	static NSString *TwoLineCellIdentifier = @"TwoLineTopicCell";
	static NSString *OneLineCellIdentifier = @"OneLineTopicCell";
    static UIColor *CellOverlayPatternColor;
    if(!CellOverlayPatternColor)
        CellOverlayPatternColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"topic_cell_background.png"]];

    DDGStory *story = [[DDGNewsProvider sharedProvider].stories objectAtIndex:indexPath.row];
    
    NSString *cellID = nil;
    if([story.title sizeWithFont:[UIFont systemFontOfSize:14.0] constrainedToSize:CGSizeMake(tv.bounds.size.width, 60) lineBreakMode:UILineBreakModeWordWrap].height < 19)
        cellID = OneLineCellIdentifier;
    else
        cellID = TwoLineCellIdentifier;

    
	UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:cellID];
    
    if (cell == nil) {
        [[NSBundle mainBundle] loadNibNamed:cellID owner:self options:nil];
        cell = _loadedCell;
        self.loadedCell = nil;
        
        [[cell.contentView viewWithTag:100] setBackgroundColor:linen];
        
        UIImageView *overlayImageView = (UIImageView *)[cell.contentView viewWithTag:400];
        overlayImageView.backgroundColor = CellOverlayPatternColor;
        overlayImageView.image = nil;
    }
    
    UILabel *label = (UILabel *)[cell.contentView viewWithTag:200];
	label.text = story.title;
    if([[DDGCache objectForKey:story.storyID inCache:@"readStories"] boolValue])
        label.textColor = [UIColor colorWithWhite:1.0 alpha:0.5];
    else
        label.textColor = [UIColor whiteColor];
    
    // load article image
    UIImageView *articleImageView = (UIImageView *)[cell.contentView viewWithTag:100];
    [articleImageView setContentMode:UIViewContentModeScaleAspectFill];
    [story loadImageIntoView:articleImageView];
    // load site favicon image
    UIImageView *faviconImageView = (UIImageView *)[cell.contentView viewWithTag:300];
    if(story.feed)
        faviconImageView.image = [DDGCache objectForKey:story.feed inCache:@"sourceImages"];
    else
        faviconImageView.image = nil;
        
	return cell;
}

#pragma  mark - Table view delegate

- (void)tableView:(UITableView *)theTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    DDGStory *story = [[DDGNewsProvider sharedProvider].stories objectAtIndex:indexPath.row];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // mark the story as read
        [DDGCache setObject:@(YES) forKey:story.storyID inCache:@"readStories"];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [_tableView performSelector:@selector(reloadData) withObject:nil afterDelay:0.5]; // wait for the animation to complete
        });
    });

    NSString *escapedStoryURL = [story.url stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [(DDGUnderViewController *)self.slidingViewController.underLeftViewController loadQueryOrURL:escapedStoryURL];
}

#pragma mark - Loading popular stories

// downloads stories asynchronously
-(void)beginDownloadingStories {
    isRefreshing = YES;

    [[DDGNewsProvider sharedProvider] downloadSourcesFinished:^{        
        [[DDGNewsProvider sharedProvider] downloadStoriesInTableView:self.tableView finished:^{
            isRefreshing = NO;
            [refreshHeaderView egoRefreshScrollViewDataSourceDidFinishedLoading:self.tableView];
        }];
        
    }];
}

@end