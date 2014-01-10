//
//  MasterViewController.m
//  Test Cora Data
//
//  Created by Vojtěch Šťavík on 03/01/14.
//  Copyright (c) 2014 VojtechStavik.cz. All rights reserved.
//

#import "MasterViewController.h"

#import "DetailViewController.h"
#import "AppDelegate.h"
#import "Topic+Doplnky.h"
#import "AddTopicVC.h"
#import "GeoLocator.h"

#import <CoreLocation/CoreLocation.h>

#import "TopicRefreshController.h"

#import "TwitterFetcher.h"
#import "ProgressView.h"


@interface MasterViewController () <TopicRefreshControllerDelegate>

@property (nonatomic, strong) NSMutableDictionary* topicControllers;


@property (nonatomic, copy) void (^completionHandler)(UIBackgroundFetchResult);
@property (nonatomic) BOOL backgroundFetch;
@property (nonatomic) int pocetTweetuPredBackgroundFetch;


- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;

@end



@implementation MasterViewController


- (NSMutableDictionary *) topicControllers {
    
    // topicController je třída, která se stará o aktualizaci a práci s tématy
    
    
    if (!_topicControllers) {
        
        _topicControllers = [[NSMutableDictionary alloc] init];
        
        NSArray* topics = [self.fetchedResultsController fetchedObjects];

        
        for (Topic* topic in topics) {
            
            TopicRefreshController* trc = [[TopicRefreshController alloc] init];
            
            trc.topic = topic;
            
            trc.delegate = self;
            
            [_topicControllers setObject:trc forKey:topic.name];
            
        }
        
        
    }
    
    return _topicControllers;
    
}


- (void)awakeFromNib
{
    [super awakeFromNib];
}


- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    self.navigationItem.leftBarButtonItem = self.editButtonItem;
  
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];

    [refreshControl addTarget:self action:@selector(refreshData) forControlEvents:UIControlEventValueChanged];
    
    self.refreshControl = refreshControl;
    
}




#pragma mark - Delegates


    // TODO lepsi aktualizace nez reload data !


- (void) didStartTweetsFetching:(TopicRefreshController *)sender {
    
    [self.tableView reloadData];
    
}

- (void) didFinishTweetsFetching:(TopicRefreshController *)sender {
    
    [self.tableView reloadData];
    
}

- (void) didStartGeolocation:(TopicRefreshController *)sender {
    
    [self.tableView reloadData];
    
}

- (void) didFinishGeolocation:(TopicRefreshController *)sender {
    
    [self.tableView reloadData];

    
    if (self.backgroundFetch)
        
    {
     
        BOOL dokoncenUpdate = YES;
        
        NSArray* trcs = [self.topicControllers allValues];
        
        for (TopicRefreshController* trc in trcs) {
            
            {
                NSLog(@"Kontorlu topic:%@", trc.topic.name);
            
                if ( trc.isFetchingTweets || trc.isGeolocating )
                
                    dokoncenUpdate = NO;
            }
        }
        
    
        if (dokoncenUpdate) {
            
            int pocetNovychTweetu = [self pocetVsechTweetu] - self.pocetTweetuPredBackgroundFetch;

            NSLog(@"------- background fetch ----------  Novych tweetu: %i", pocetNovychTweetu);

            
            
            [UIApplication sharedApplication].applicationIconBadgeNumber += pocetNovychTweetu;
            
            
            self.completionHandler(UIBackgroundFetchResultNewData);
            
            self.completionHandler = nil;
            
            self.backgroundFetch = NO;
            
        }

    
    }
    
}

- (void) progressChanged:(TopicRefreshController *)sender progress:(float)progres {
    
    [self.tableView reloadData];

}




#pragma mark - Table View



#define MAX_POCET_TWEETU_PRI_AKTUALIZACI 500 // není relevatní, při aktualiaci stahujeme vždy maximální počet tweetů, stačí když bude větší než 0

-(void) refreshData {
    
        [self.refreshControl endRefreshing]; // budeme zobrazovat refresh indicator u kazde bunky zvlast, ne u tabulky
        
        
        NSArray* trcs = [self.topicControllers allValues];
    
        for (TopicRefreshController* trc in trcs) {
    
            [trc downloadNewTweets:MAX_POCET_TWEETU_PRI_AKTUALIZACI refresh:YES];
        
        }

}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
 
    return [sectionInfo numberOfObjects];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
        
        Topic* t = [self.fetchedResultsController objectAtIndexPath:indexPath];
        
        [self.topicControllers removeObjectForKey:t.name];
        
        
        [context deleteObject:[self.fetchedResultsController objectAtIndexPath:indexPath]];
        
        NSError *error = nil;
        if (![context save:&error]) {
             // Replace this implementation with code to handle the error appropriately.
             // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }   
}


- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // The table view should not be re-orderable.
    return NO;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showDetail"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        NSManagedObject *object = [[self fetchedResultsController] objectAtIndexPath:indexPath];
        Topic* t = (Topic *)object;

        [[segue destinationViewController] setTitle:t.name];
        [[segue destinationViewController] setTopic:t];
        
    }
    
    if ([[segue identifier] isEqualToString:@"newTopic"]) {
        
        AddTopicVC* vc = [segue destinationViewController];
        vc.delegate = self;
    }
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath*)indexPath {
    
    return 100.0; // vymyslena hodnota, aby to "hezky vypadalo"
    
}


#pragma mark - New topic

-(void) addNewTopicWithName: (NSString* ) name initialTweetCount:(int) count {
    
    Topic* newTopic = [Topic topicWithString:name inManagedObjectContext:self.managedObjectContext];
    
    TopicRefreshController* trc = [[TopicRefreshController alloc] init];
    
    trc.topic = newTopic;
    
    trc.delegate = self;
    
    [self.topicControllers setObject:trc forKey:newTopic.name];
    
    [trc downloadNewTweets:count refresh:NO];
    
    
    // TODO vyresit to nejak efektivneji
    
    [self.tableView reloadData];
    
}





#pragma mark - Fetched results controller

- (NSFetchedResultsController *)fetchedResultsController
{
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Topic" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    
    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:20];
    
    // Edit the sort key as appropriate.
  
    
    // TODO - řazení témat podle ID nejnovejsiho tweetu
    
    
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:NO];
    NSArray *sortDescriptors = @[sortDescriptor];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    
     
    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:nil];
    aFetchedResultsController.delegate = self;
    self.fetchedResultsController = aFetchedResultsController;
    
	NSError *error = nil;
	if (![self.fetchedResultsController performFetch:&error]) {
	     // Replace this implementation with code to handle the error appropriately.
	     // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
	    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
	    abort();
	}
    
    return _fetchedResultsController;
}    

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    UITableView *tableView = self.tableView;
    
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView endUpdates];
    
}



- (ProgressView* ) getProgressViewForCell: (UITableViewCell* ) cell {
    
    ProgressView* progress = nil;

    
    for (id subView in cell.contentView.subviews) {
        
        if ([subView isKindOfClass:[ProgressView class]]) {
            
            progress = (ProgressView* )subView;

            
        }
            
        
    }
    
    
    if (! progress)  {
        
        progress = [[ProgressView alloc] initWithFrame:CGRectMake( - cell.frame.size.width, 0, cell.frame.size.width, cell.frame.size.height)];
        progress.alpha = 0;
        
        [cell.contentView addSubview:progress];
        [cell.contentView sendSubviewToBack:progress];

        
    }
    
    return progress;

    
}




- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    NSManagedObject *object = [self.fetchedResultsController objectAtIndexPath:indexPath];
    
    Topic* topic = (Topic *)object;
    
    TopicRefreshController* trc = [self.topicControllers objectForKey:topic.name];
    

    cell.textLabel.text = topic.name;
    cell.detailTextLabel.numberOfLines = 3;
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0];
    
    
    if (trc.isFetchingTweets || trc.isGeolocating) {
        
        cell.detailTextLabel.text = trc.isFetchingTweets ? [NSString stringWithFormat:@"Stahuji tweety ...\n"] : [NSString stringWithFormat:@"Zjištuji GPS souřadnice ...\n"];
        
        cell.userInteractionEnabled = NO;
        
        
        // animace progressu
        
        [UIView animateWithDuration:0.1 animations:^{
            
            ProgressView* pw = [self getProgressViewForCell:cell];
            
            pw.frame = CGRectMake( - (1 - trc.progress) * cell.frame.size.width, 0, cell.frame.size.width, cell.frame.size.height);
            pw.alpha = 0.2;
        }];
        
        
    }
    
    else {

        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"dd.MM.yyyy"];
        
        NSString* oldestTweetDate = [formatter stringFromDate:[topic getOldestTweet].date];
        NSString* newestTweetDate = [formatter stringFromDate:[topic getNewestTweet].date];
        
        if (!oldestTweetDate) oldestTweetDate = @"Žádné tweety";
        if (!newestTweetDate) newestTweetDate = @"Žádné tweety";
        
        cell.detailTextLabel.text = [NSString stringWithFormat:@"Tweetů s GPS: %i\n od: %@\n do: %@",[topic.tweets count], oldestTweetDate, newestTweetDate];
        
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
        [UIView animateWithDuration:1 animations:^{
        
            ProgressView* pw = [self getProgressViewForCell:cell];
            pw.frame = CGRectMake(- cell.frame.size.width, 0, cell.frame.size.width, cell.frame.size.height);
            pw.alpha = 0;
            
        }];
        
        
        // pokud nejsou platné tweety, nelze je zobrazit na mapě
        if ([topic.tweets count] == 0) {
            
            cell.userInteractionEnabled = NO;
            cell.textLabel.enabled = NO;
            cell.detailTextLabel.enabled = NO;
            
        } else {
            
            cell.userInteractionEnabled = YES;
            cell.textLabel.enabled = YES;
            cell.detailTextLabel.enabled = YES;
            
        }
        
        
        
        
    }
    
}

#pragma mark - BackgroundFetch

- (void) backgroundRefreshDataWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    
    self.completionHandler = completionHandler;
    
    self.backgroundFetch = YES;
    
    self.pocetTweetuPredBackgroundFetch = [self pocetVsechTweetu];
    
    [self refreshData];
    
    
}

- (int) pocetVsechTweetu {
    
    int pocet = 0;
    
    NSArray* trcs = [self.topicControllers allValues];
    
    for (TopicRefreshController* trc in trcs) {
    
        pocet += [trc.topic.tweets count];
    
    
    }
    
    return pocet;
}


@end
