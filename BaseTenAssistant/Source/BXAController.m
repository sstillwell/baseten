//
// BXAController.m
// BaseTen Assistant
//
// Copyright (C) 2006-2008 Marko Karppinen & Co. LLC.
//
// Before using this software, please review the available licensing options
// by visiting http://basetenframework.org/licensing/ or by contacting
// us at sales@karppinen.fi. Without an additional license, this software
// may be distributed only in compliance with the GNU General Public License.
//
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License, version 2.0,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
//
// $Id$
//


#import "BXAController.h"
#import "BXAImportController.h"
#import "Additions.h"

#import "MKCBackgroundView.h"
#import "MKCPolishedHeaderView.h"
#import "MKCPolishedCornerView.h"
#import "MKCForcedSizeToFitButtonCell.h"
#import "MKCAlternativeDataCellColumn.h"

#import <BaseTen/BXEntityDescriptionPrivate.h>
#import <BaseTen/BXPGInterface.h>
#import <BaseTen/BXDatabaseContextPrivate.h>
#import <BaseTen/BXAttributeDescriptionPrivate.h>


static NSString* kBXAControllerCtx = @"kBXAControllerCtx";


//FIXME: come up with a way for the entities etc. to get an NSDocument or something if we want to be document based some day.
__strong static BXAController* gController = nil;


@implementation BXEntityDescription (BXAControllerAdditions)
- (BOOL) isEnabledForAssistant
{
	NSLog (@"%@ is enabled: %d", [self name], [self isEnabled]);
	return [self isEnabled];
}

- (void) setEnabledForAssistant: (BOOL) aBool
{
	NSLog (@"setEnabled: %d", aBool);
	[gController process: aBool entity: self];
}

+ (NSSet *) keyPathsForValuesAffectingAllowsSettingPrimaryKey
{
	return [NSSet setWithObjects: @"isView", @"isEnabled", nil];
}

- (BOOL) allowsSettingPrimaryKey
{
	BOOL retval = NO;
	if ([self isView] && ! [self isEnabled])
		retval = YES;
	return retval;
}

+ (NSSet *) keyPathsForValuesAffectingAllowsEnabling
{
	return [NSSet setWithObjects: @"isView", @"primaryKeyFields", nil];
}

- (BOOL) allowsEnabling
{
	BOOL retval = YES;
	if ([self isView])
		retval = (0 < [[self primaryKeyFields] count]);
	return retval;
}
@end


@implementation BXAttributeDescription (BXAControllerAdditions)
- (BOOL) isPrimaryKeyForAssistant
{
	return [self isPrimaryKey];
}

- (void) setPrimaryKeyForAssistant: (BOOL) aBool
{
	NSLog (@"setPrimaryKey: %d", aBool);
	[gController process: aBool attribute: self];
}
@end


@implementation BXAController
- (NSPredicate *) attributeFilterPredicate
{
	return [NSPredicate predicateWithFormat: @"value.isExcluded == false"];
}

- (void) setupTableViews
{
	//Table headers
	{
		NSRect headerRect = NSMakeRect (0.0, 0.0, 0.0, 23.0);
		headerRect.size.width = [mDBTableView bounds].size.width;
		MKCPolishedHeaderView* headerView = [[[MKCPolishedHeaderView alloc] initWithFrame: headerRect] autorelease];
		[headerView setColours: [MKCPolishedHeaderView darkColours]];
		[headerView setDrawingMask: kMKCPolishDrawBottomLine | 
		 kMKCPolishDrawLeftAccent | kMKCPolishDrawTopAccent | kMKCPolishDrawSeparatorLines];
		[mDBTableView setHeaderView: headerView];
		
		headerView = [[[MKCPolishedHeaderView alloc] initWithFrame: headerRect] autorelease];
		headerRect.size.width = [mDBSchemaView bounds].size.width;
		[headerView setDrawingMask: kMKCPolishDrawBottomLine | kMKCPolishDrawTopAccent];
		[mDBSchemaView setHeaderView: headerView];
	}
	
	//Table corners
	{
		NSRect cornerRect = NSMakeRect (0.0, 0.0, 15.0, 23.0);
		MKCPolishedCornerView* otherCornerView = [[[MKCPolishedCornerView alloc] initWithFrame: cornerRect] autorelease];
		[otherCornerView setDrawingMask: kMKCPolishDrawBottomLine | kMKCPolishDrawTopAccent];
		[mDBTableView setCornerView: otherCornerView];
		
		mCornerView = [[MKCPolishedCornerView alloc] initWithFrame: cornerRect];
		[mCornerView setDrawingMask: kMKCPolishDrawBottomLine | kMKCPolishDrawTopAccent];
		[mCornerView setDrawsHandle: YES];
		[mDBSchemaView setCornerView: mCornerView];
	}
		
	{
#if 0
		NSButtonCell* enabledButtonCell = [mTableEnabledColumn dataCell];
		[enabledButtonCell setAction: @selector (processForBaseTen:)];
		[enabledButtonCell setTarget: self];
#endif
		
		mInspectorButtonCell = [[MKCForcedSizeToFitButtonCell alloc] initTextCell: @"Setup..."];
		[mInspectorButtonCell setButtonType: NSMomentaryPushInButton];
		[mInspectorButtonCell setBezelStyle: NSRoundedBezelStyle];
		[mInspectorButtonCell setControlSize: NSMiniControlSize];
		[mInspectorButtonCell setFont: [NSFont systemFontOfSize: 
										[NSFont systemFontSizeForControlSize: NSMiniControlSize]]];
		[mInspectorButtonCell setTarget: mInspectorWindow];
		[mInspectorButtonCell setAction: @selector (makeKeyAndOrderFront:)];
	}
}

- (void) setupToolbar
{
	[mToolbar setBackgroundColor: [NSColor colorWithCalibratedRed: 214.0 / 255.0 green: 221.0 / 255.0 blue: 229.0 / 255.0 alpha: 1.0]];
	NSMutableParagraphStyle* paragraphStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
	[paragraphStyle setAlignment: NSCenterTextAlignment];
	NSDictionary* attributes = [NSDictionary dictionaryWithObjectsAndKeys:
								paragraphStyle, NSParagraphStyleAttributeName,
								[NSFont systemFontOfSize: [NSFont smallSystemFontSize]], NSFontAttributeName,
								nil];
	
	const int count = 3; //Remember to set this when changing the arrays below.
	id targets [] = {self, mInspectorWindow, mLogWindow};
	SEL actions [] = {@selector (importDataModel:), @selector (MKCToggle:), @selector (MKCToggle:)};
	NSString* labels [] = {@"Import Data Model", @"Inspector", @"Log"};
	NSString* imageNames [] = {@"ImportModel32", @"Inspector32", @"Log32"};
	NSAttributedString* attributedTitles [count];
	CGFloat widths [count];
	
	//Calculate text dimensions
	CGFloat height = 0.0;
	for (int i = 0; i < count; i++)
	{
		attributedTitles [i] = [[[NSAttributedString alloc] initWithString: labels [i] attributes: attributes] autorelease];
		NSSize size = [attributedTitles [i] size];
		widths [i] = MAX (size.width, 32.0) + 5.0; //5.0 px padding to make text fit
		height = MAX (height, size.height);
	}
	height += 33.0; //Image maximum height
	CGFloat xPosition = 12.0; //Left margin
	
	for (int i = 0; i < count; i++)
	{
		NSButton* button = [[NSButton alloc] init];
		[mToolbar addSubview: button];
		[button release];
		
		[button setButtonType: NSMomentaryPushInButton];
		[button setBezelStyle: NSShadowlessSquareBezelStyle];
		[button setBordered: NO];
		[button setImagePosition: NSImageAbove];
		[[button cell] setHighlightsBy: NSPushInCellMask];
		[button setTarget: targets [i]];
		[button setAction: actions [i]];
		[button setAttributedTitle: attributedTitles [i]];
		[button setImage: [NSImage imageNamed: imageNames [i]]];				
		switch (i)
		{
			case 2:
				[button setFrame: NSMakeRect ([mToolbar bounds].size.width - (widths [i] + 10.0), 3.0, widths [i], height)];
				[button setAutoresizingMask: NSViewMinXMargin];
				break;
			default:
				[button setFrame: NSMakeRect (xPosition, 3.0, widths [i], height)];
				break;
		}
		xPosition += widths [i] + 13.0;
	}	
}


- (void) awakeFromNib
{
	gController = self;
	mLastSelectedEntityWasView = YES;
	
	//Make main window's bottom edge lighter
	[mMainWindow setContentBorderThickness: 24.0 forEdge: NSMinYEdge];

	[self setupToolbar];
	[self setupTableViews];
	
	[mProgressIndicator setUsesThreadedAnimation: YES];
	
	NSNotificationCenter* nc = [mContext notificationCenter];
	[nc addObserver: self selector: @selector (connected:) name: kBXConnectionSuccessfulNotification object: nil];
	[nc addObserver: self selector: @selector (failedToConnect:) name: kBXConnectionFailedNotification object: nil];
	
	[mEntities addObserver: self forKeyPath: @"selection" 
				   options: NSKeyValueObservingOptionInitial
				   context: kBXAControllerCtx];	
}


- (void) observeValueForKeyPath: (NSString *) keyPath ofObject: (id) object 
						 change: (NSDictionary *) change context: (void *) context
{
    if (context == kBXAControllerCtx) 
	{
		//selection.[...].isView might give us an NSStateMarker, which we don't want.
		BOOL currentIsView = NO;
		NSArray* selectedEntities = [mEntities selectedObjects];
		if (0 < [selectedEntities count])
			currentIsView = [[[selectedEntities objectAtIndex: 0] value]isView];
		
		NSView* scrollView = [[mAttributeTable superview] superview];
		NSRect frame = [scrollView frame];			
		if (mLastSelectedEntityWasView && !currentIsView)
		{
			frame.size.height += 75.0;
			[scrollView setFrame: frame];
		}
		else if (!mLastSelectedEntityWasView && currentIsView)
		{
			frame.size.height -= 75.0;
			[scrollView setFrame: frame];
		}
		mLastSelectedEntityWasView = currentIsView;
	}
	else 
	{
		[super observeValueForKeyPath: keyPath ofObject: object change: change context: context];
	}
}


- (void) continueDisconnect
{
	[mContext disconnect];
	[mStatusTextField setStringValue: @"Not connected."];
	[mStatusTextField makeEtchedSmall: YES];
	[self hideProgressPanel];
	[NSApp beginSheet: mConnectPanel modalForWindow: mMainWindow modalDelegate: self 
	   didEndSelector: NULL contextInfo: NULL];	
}


- (BOOL) allowEnablingForRow: (NSInteger) rowIndex
{
	BOOL retval = NO;
	if (-1 != rowIndex)
	{
		retval = YES;
		BXEntityDescription* entity = [[[mEntities arrangedObjects] objectAtIndex: rowIndex] value];
		if ([entity isView])
		{
			if (! [[entity primaryKeyFields] count])
				retval = NO;
		}	
	}
	return retval;
}


- (BOOL) hasBaseTenSchema
{
	//FIXME: make me work.
	return YES;
}


- (void) process: (BOOL) newState entity: (BXEntityDescription *) entity
{	
	if (![entity isView] || [[entity primaryKeyFields] count])
	{
		NSError* localError = nil;
		NSArray* entityArray = [NSArray arrayWithObject: entity];
		[(BXPGInterface *) [mContext databaseInterface] process: newState entities: entityArray error: &localError];
		if (localError)
		{
			[entity setIsEnabled: !newState];
			[NSApp presentError: localError modalForWindow: mMainWindow delegate: nil didPresentSelector: NULL contextInfo: NULL];
		}
	}
}

- (void) process: (BOOL) newState attribute: (BXAttributeDescription *) attribute
{
	NSError* localError = nil;
	NSArray* attributeArray = [NSArray arrayWithObject: attribute];
	[(BXPGInterface *) [mContext databaseInterface] process: newState primaryKeyFields: attributeArray error: &localError];
	if (localError)
	{
		[attribute setPrimaryKey: !newState];
		[NSApp presentError: localError modalForWindow: mMainWindow delegate: nil didPresentSelector: NULL contextInfo: NULL];
	}
}
@end


@implementation BXAController (ProgressPanel)
- (void) displayProgressPanel: (NSString *) message
{
    [mProgressField setStringValue: message];
    if (NO == [mProgressPanel isVisible])
    {
        [mProgressIndicator startAnimation: nil];
        [NSApp beginSheet: mProgressPanel modalForWindow: mMainWindow modalDelegate: self didEndSelector: NULL contextInfo: NULL];
    }
}

- (void) hideProgressPanel
{
    [NSApp endSheet: mProgressPanel];
    [mProgressPanel orderOut: nil];
}

- (void) importModelAtURL: (NSURL *) URL
{
	if (! mImportController)
		mImportController = [[BXAImportController alloc] initWithWindowNibName: @"Import"];
	
	NSManagedObjectModel* model = [[NSManagedObjectModel alloc] initWithContentsOfURL: URL];
	[mImportController setObjectModel: model];
	[mImportController showPanelAttachedTo: mMainWindow];	
}

- (void) compileAndImportModelAtURL: (NSURL *) URL
{
	if (! mCompiler)
	{
		mCompiler = [[BXDataModelCompiler alloc] init];
		[mCompiler setDelegate: self];
	}
	[mCompiler setModelURL: URL];
	[mCompiler compileDataModel];
}
@end


@implementation BXAController (Delegation)
- (void) dataModelCompiler: (BXDataModelCompiler *) compiler finished: (int) exitStatus
{
	if (0 == exitStatus)
	{
		NSURL* modelURL = [mCompiler compiledModelURL];
		[self importModelAtURL: modelURL];
	}
	else
	{
		//FIXME: handle the error.
	}
}


- (NSRect) splitView: (NSSplitView *) splitView additionalEffectiveRectOfDividerAtIndex: (NSInteger) dividerIndex
{
	NSRect retval = NSZeroRect;
	if (0 == dividerIndex)
	{
		retval = [splitView convertRect: [mCornerView bounds] fromView: mCornerView];
	}
	return retval;
}


- (void) connected: (NSNotification *) n
{
	[self hideProgressPanel];
	[mStatusTextField setObjectValue: [NSString stringWithFormat: @"Connected to %@.", [mContext databaseURI]]];
	NSDictionary* entities = [mContext entitiesBySchemaAndName: NULL];
	[mEntitiesBySchema setContent: entities];
}


- (void) failedToConnect: (NSNotification *) n
{
	[self hideProgressPanel];
}


- (id) MKCTableView: (NSTableView *) tableView 
  dataCellForColumn: (MKCAlternativeDataCellColumn *) aColumn
                row: (int) rowIndex
			current: (NSCell *) currentCell
{
    id retval = nil;
	if (NO == [self allowEnablingForRow: rowIndex])
		retval = mInspectorButtonCell;
	else
		[currentCell setEnabled: [self hasBaseTenSchema]];
		
    return retval;
}


- (BOOL) selectionShouldChangeInTableView: (NSTableView *) aTableView
{
	[self willChangeValueForKey: @"selectedEntityEnabled"];
	return YES;
}


- (void) tableViewSelectionDidChange: (NSNotification *) aNotification
{
	[self didChangeValueForKey: @"selectedEntityEnabled"];
}


- (BOOL) validateMenuItem: (NSMenuItem *) menuItem
{
    BOOL retval = YES;
    switch ([menuItem tag])
    {
        case 1:
            if (! [mContext isConnected] || YES == [mProgressPanel isVisible])
            {
                retval = NO;
                break;
            }
            //Fall through
            
        case 2:
            if (nil != [mMainWindow attachedSheet])
                retval = NO;
            break;
            
        default:
            break;
    }
    return retval;
}


- (void) applicationDidFinishLaunching: (NSNotification *) aNotification
{
	[mMainWindow makeKeyAndOrderFront: nil];
	[self disconnect: nil];
}


- (void) importOpenPanelDidEnd: (NSOpenPanel *) panel returnCode: (int) returnCode contextInfo: (void *) contextInfo
{
    if (NSOKButton == returnCode)
    {		
        NSURL* URL = [[panel URLs] objectAtIndex: 0];
		NSString* URLString = [URL path];
        if ([URLString hasSuffix: @".mom"] || [URLString hasSuffix: @".momd"])
		{
			//Delay a bit so the open panel gets removed.
			[[NSRunLoop currentRunLoop] performSelector: @selector (importModelAtURL:) target: self argument: URL 
												  order: 0 modes: [NSArray arrayWithObject: NSRunLoopCommonModes]];
		}
        else
		{
			[self compileAndImportModelAtURL: URL];
		}
    }
}
@end


@implementation BXAController (IBActions)
- (IBAction) disconnect: (id) sender
{
	[self continueDisconnect];
}


- (IBAction) terminate: (id) sender
{
    [mConnectPanel orderOut: nil];
    [self hideProgressPanel];	
    [NSApp terminate: nil];
}


- (IBAction) connect: (id) sender
{
	NSString* username = [mUserNameCell objectValue];
	NSString* password = [mPasswordField objectValue];
	NSString* credentials = (0 < [password length] ? [NSString stringWithFormat: @"%@:%@", username, password] : username);
	
	NSString* host = [mHostCell objectValue];
	id port = [mPortCell objectValue];
	NSString* target = (port ? [NSString stringWithFormat: @"%@:%@", host, port] : host);
	
	NSString* URIFormat = [NSString stringWithFormat: @"pgsql://%@@%@/%@", credentials, target, [mDBNameCell objectValue]];
	NSURL* connectionURI = [NSURL URLWithString: URIFormat];
	[mContext setDatabaseURI: connectionURI];
	
    [NSApp endSheet: mConnectPanel];
    [mConnectPanel orderOut: nil];
    
    [self displayProgressPanel: @"Connecting..."];
	
	[mContext connect];
}


- (IBAction) importDataModel: (id) sender
{
    NSOpenPanel* openPanel = [NSOpenPanel openPanel];
    [openPanel setAllowsMultipleSelection: NO];
    [openPanel setCanChooseDirectories: NO];
    [openPanel setCanChooseFiles: YES];
    [openPanel setResolvesAliases: YES];
	NSArray* types = [NSArray arrayWithObjects: @"xcdatamodel", @"xcdatamodeld", @"mom", @"momd", nil];
    [openPanel beginSheetForDirectory: nil file: nil types: types modalForWindow: mMainWindow modalDelegate: self 
                       didEndSelector: @selector (importOpenPanelDidEnd:returnCode:contextInfo:) contextInfo: NULL];
}
@end


@implementation NSArrayController (BaseTenSetupApplicationAdditions)
- (BOOL) MKCHasEmptySelection
{
    return NSNotFound == [self selectionIndex];
}
@end