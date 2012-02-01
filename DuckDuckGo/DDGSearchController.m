//
//  DDGSearchController.m
//  DuckDuckGo2
//
//  Created by Chris Heimark on 12/9/11.
//  Copyright (c) 2011 DuckDuckGo, Inc. All rights reserved.
//

#import "DDGSearchController.h"
#import "SBJson.h"
#import "DDGSearchSuggestionCache.h"

static NSString *const sBaseSuggestionServerURL = @"http://swass.duckduckgo.com:6767/face/suggest/?q=";
static NSUInteger kSuggestionServerResponseBufferCapacity = 6 * 1024;

@implementation DDGSearchController

@synthesize loadedCell;
@synthesize search;
@synthesize searchHandler;
@synthesize searchButton;
@synthesize state;

@synthesize serverRequest;
@synthesize serverCache;

- (id)initWithNibName:(NSString *)nibNameOrNil view:(UIView*)parent
{
	self = [super initWithNibName:nibNameOrNil bundle:nil];
	if (self)
	{
		[parent addSubview:self.view];
		kbRect = CGRectZero;
		
		self.serverRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://duckduckgo.com"]
													 cachePolicy:NSURLRequestUseProtocolCachePolicy
												 timeoutInterval:10.0];
		
		NSLog(@"HEADERS: %@", [serverRequest allHTTPHeaderFields]);
		[serverRequest setValue:@"Keep-Alive" forHTTPHeaderField:@"Connection"];
		[serverRequest setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
		[serverRequest setValue:@"text/plain; charset=UTF-8" forHTTPHeaderField:@"Accept"];
		
		NSLog(@"HEADERS: %@", [serverRequest allHTTPHeaderFields]);

		dataHelper = [[DataHelper alloc] initWithDelegate:self];
		
		search.placeholder = NSLocalizedString (@"SearchPlaceholder", nil);
	}
	return self;
}

- (void)dealloc
{
	self.serverRequest = nil;
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self.view removeFromSuperview];
}
- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
	search.rightViewMode = UITextFieldViewModeAlways;
	search.leftViewMode = UITextFieldViewModeAlways;
	search.leftView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"spacer8x16.png"]];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(kbShowing:) name:UIKeyboardDidShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(kbHiding:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
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
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)kbShowing:(NSNotification*)notification
{
	kbRect = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
	kbRect = [self.view convertRect:kbRect toView:nil];
}

- (void)kbHiding:(NSNotification*)notification
{
	kbRect = CGRectZero;
}


#pragma  mark - Handle user actions

- (void)autoCompleteReveal:(BOOL)reveal
{
	CGSize screenSize = self.view.superview.frame.size;
	CGRect rect = self.view.frame;
	if (reveal)
	{
		rect.size.height = screenSize.height - kbRect.size.height;
	}
	else
	{
		// clip to search entry height
		rect.size.height = 44.0;
	}
	[UIView animateWithDuration:0.25 animations:^
	{
		self.view.frame = rect;
	}];
}

- (IBAction)searchButtonAction:(UIButton*)sender
{
	[search resignFirstResponder];
	
	[searchHandler loadHome];
}

- (void)switchModeTo:(enum eSearchState)searchState
{
	state = searchState;
}

-(void)updateBarWithURL:(NSURL *)url {
    
    // parse URL query components
    NSArray *queryComponentsArray = [[url query] componentsSeparatedByString:@"&"];
    NSMutableDictionary *queryComponents = [[NSMutableDictionary alloc] init];
    for(NSString *queryComponent in queryComponentsArray) {
        NSArray *parameter = [queryComponent componentsSeparatedByString:@"="];
        [queryComponents setObject:[parameter objectAtIndex:1] forKey:[parameter objectAtIndex:0]];
    }

    // check whether we have a DDG search URL
    if([[url host] isEqualToString:@"duckduckgo.com"] && [[url path] isEqualToString:@"/"] && [queryComponents objectForKey:@"q"]) {
        // yep! extract the search query...
        NSString *query = [queryComponents objectForKey:@"q"];
        query = [query stringByReplacingOccurrencesOfString:@"+" withString:@"%20"];
        query = [query stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
        search.text = query;
    } else {
        // no, just a plain old URL.
        search.text = [url absoluteString];
    }
}

#pragma  mark - Handle the text field input

- (NSArray*)currentResultForItem:(NSUInteger)item
{
	return [[DDGSearchSuggestionCache sharedInstance].serverCache objectForKey:[NSNumber numberWithUnsignedInteger:item]];
}

- (void)cacheCurrentResult:(NSArray*)result forItem:(NSUInteger)item
{
	[[DDGSearchSuggestionCache sharedInstance].serverCache setObject:result forKey:[NSNumber numberWithUnsignedInteger:item]];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
	NSUInteger lengthLeft = [textField.text length] - range.length + [string length];
	
	if (!lengthLeft)
		// going to NO characters
		[self autoCompleteReveal:NO];
	else if (![textField.text length] && lengthLeft)
	{
		// going from NO characters to something
		[self autoCompleteReveal:YES];
	}
	
	if (lengthLeft && lengthLeft < [textField.text length])
	{
		// destroying characters
		// this means we use a cached result
		if (lengthLeft < [[DDGSearchSuggestionCache sharedInstance].serverCache count])
		{
			// keep the cache trimmed to a max of number of characters
			NSUInteger maxLen = [[DDGSearchSuggestionCache sharedInstance].serverCache count];
			for (NSUInteger l = lengthLeft + 1; l <= maxLen; ++l)
			{
				NSNumber *n = [NSNumber numberWithUnsignedInteger:l];
				if ([[DDGSearchSuggestionCache sharedInstance].serverCache objectForKey:n])
					[[DDGSearchSuggestionCache sharedInstance].serverCache removeObjectForKey:n];
			}
		}
		[tableView reloadData];
	}
	else if (lengthLeft)
	{
		// we have replaced or added characters
		// time to server up
		NSString *searchStringWillBecome;
		if (!range.length)
			searchStringWillBecome = textField.text;
		else
			searchStringWillBecome = [textField.text substringWithRange:range];
		
		if (![searchStringWillBecome length])
			searchStringWillBecome = @"";
		searchStringWillBecome = [searchStringWillBecome stringByAppendingString:string ? string : @""];
		NSString *surl = [sBaseSuggestionServerURL stringByAppendingString:searchStringWillBecome];
		serverRequest.URL = [NSURL URLWithString:[surl stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];

		[dataHelper retrieve:serverRequest 
                       cache:kCacheIDNoFileCache 
                        name:nil 
                  returnData:NO 
                  identifier:1000+[searchStringWillBecome length] 
                  bufferSize:kSuggestionServerResponseBufferCapacity];
		
		NSLog (@"URL: %@", surl);
	}
	else if (!lengthLeft)
	{
		// stay slim and trim in memory :)
		[[DDGSearchSuggestionCache sharedInstance].serverCache removeAllObjects];
		[tableView reloadData];
	}
	
	return YES;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField
{
	[self autoCompleteReveal:NO];
	[[DDGSearchSuggestionCache sharedInstance].serverCache removeAllObjects];
	return YES;
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
	return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
	if ([textField.text length])
	{
		// user wants to edit the search term for another query
		[self autoCompleteReveal:YES];

		NSString *surl = [sBaseSuggestionServerURL stringByAppendingString:textField.text];
		serverRequest.URL = [NSURL URLWithString:[surl stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
		
		[dataHelper retrieve:serverRequest 
                       cache:kCacheIDNoFileCache 
                        name:nil 
                  returnData:NO 
                  identifier:1000+[textField.text length] 
                  bufferSize:kSuggestionServerResponseBufferCapacity];
		
		NSLog (@"URL: %@", surl);
	}
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField
{
	return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	NSString *s = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	if (![s length])
	{
		textField.text = nil;
		return NO;
	}
	[textField resignFirstResponder];
	[self autoCompleteReveal:NO];
	
	[searchHandler loadQuery:([search.text length] ? search.text : nil)];
	
	return YES;
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [[self currentResultForItem:[[DDGSearchSuggestionCache sharedInstance].serverCache count]] count];
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:CellIdentifier];
	UIImageView *iv;
    if (cell == nil)
	{
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
		cell.textLabel.font = [UIFont boldSystemFontOfSize:15.0];
		cell.textLabel.textColor = [UIColor darkGrayColor];
		cell.selectionStyle = UITableViewCellSelectionStyleGray;
		cell.imageView.image = [UIImage imageNamed:@"spacer44x44.png"];
		
		iv = [[UIImageView alloc] initWithFrame:CGRectMake(0.0, 0.0, 44.0, 44.0)];
		iv.tag = 100;
		iv.contentMode = UIViewContentModeScaleAspectFit;
		iv.backgroundColor = [UIColor whiteColor];
		[cell.contentView addSubview:iv];
    }
    NSArray *items = [self currentResultForItem:[[DDGSearchSuggestionCache sharedInstance].serverCache count]];
	NSDictionary *item = [items objectAtIndex:indexPath.row];
	
    // Configure the cell...
	cell.textLabel.text = [item objectForKey:ksDDGSearchControllerServerKeyPhrase];
	cell.detailTextLabel.text = [item objectForKey:ksDDGSearchControllerServerKeySnippet];

	iv = (UIImageView *)[cell.contentView viewWithTag:100];
	
	iv.backgroundColor = [UIColor whiteColor];
	iv.image = [UIImage imageWithData:[dataHelper retrieve:[item objectForKey:ksDDGSearchControllerServerKeyImage] 
													 cache:kCacheIDImages 
													  name:[NSString stringWithFormat:@"%08x", [[item objectForKey:ksDDGSearchControllerServerKeyImage] hash]]
												returnData:YES
												identifier:0
												bufferSize:4096]];    
    return cell;
}

#pragma mark - Table view delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 44.0;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSArray *items = [self currentResultForItem:[[DDGSearchSuggestionCache sharedInstance].serverCache count]];
	NSDictionary *item = [items objectAtIndex:indexPath.row];
	
	[tv deselectRowAtIndexPath:indexPath animated:YES];
	
	[search resignFirstResponder];
	[self autoCompleteReveal:NO];
    
    [searchHandler loadQuery:[item objectForKey:ksDDGSearchControllerServerKeyPhrase]];
}

#pragma mark - DataHelper delegate

- (void)dataReceivedWith:(NSInteger)identifier andData:(NSData*)data andStatus:(NSInteger)status
{
	if (identifier > 1000 && data.length)
	{
		NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		NSArray *result = [json JSONValue];
		[self cacheCurrentResult:result forItem:identifier-1000];
		[tableView reloadData];
	}
}

- (void)dataReceived:(NSInteger)identifier withStatus:(NSInteger)status
{
	// no matter what is coming back, we need a refesh
	[tableView reloadData];
}

- (void)redirectReceived:(NSInteger)identifier withURL:(NSString*)url
{
}

- (void)errorReceived:(NSInteger)identifier withError:(NSError*)error
{
}

@end

NSString *const ksDDGSearchControllerServerKeySnippet = @"snippet"; 
NSString *const ksDDGSearchControllerServerKeyPhrase = @"phrase"; 
NSString *const ksDDGSearchControllerServerKeyImage = @"image"; 

