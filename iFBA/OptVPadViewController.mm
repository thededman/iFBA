//
//  OptVPadViewController.m
//  iFBA
//
//  Created by Yohann Magnien on 28/02/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#define MAX_PAD_OFS_X 64
#define MAX_PAD_OFS_Y 64

#define MAX_BUTTON_OFS_X 64
#define MAX_BUTTON_OFS_Y 64

#import "OptVPadViewController.h"
#import "MNEValueTrackingSlider.h"

#import "fbaconf.h"

//iCade & wiimote
#import "iCadeReaderView.h"
#include "wiimote.h"
#import <QuartzCore/CADisplayLink.h>
#import <QuartzCore/QuartzCore.h>
static int ui_currentIndex_s,ui_currentIndex_r;
static int wiimoteBtnState;
static iCadeReaderView *iCaderv;
static CADisplayLink* m_displayLink;

extern int optionScope;
#define OPTION(a) (optionScope?ifba_game_conf.a:ifba_conf.a)


extern volatile int emuThread_running;
extern int launchGame;
extern char gameName[64];

@implementation OptVPadViewController
@synthesize tabView,btn_backToEmu;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        self.title=NSLocalizedString(@"Virtual pad",@"");
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    //
    // Change the properties of the imageView and tableView (these could be set
    // in interface builder instead).
    //
    //self.tabView.style=UITableViewStyleGrouped;
    tabView.backgroundView=nil;
    tabView.backgroundView=[[[UIView alloc] init] autorelease];
    //ICADE & Wiimote
    ui_currentIndex_s=-1;
    iCaderv = [[iCadeReaderView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:iCaderv];
    [iCaderv changeLang:ifba_conf.icade_lang];
    iCaderv.active = YES;
    iCaderv.delegate = self;
    [iCaderv release];
    wiimoteBtnState=0;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    /* Wiimote check => rely on cadisplaylink*/
    m_displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(checkWiimote)];
    m_displayLink.frameInterval = 3; //20fps
	[m_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];    

    if (emuThread_running) {
        btn_backToEmu.title=[NSString stringWithFormat:@"%s",gameName];
        self.navigationItem.rightBarButtonItem = btn_backToEmu;
    }    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    iCaderv.active = YES;
    iCaderv.delegate = self;
    [iCaderv becomeFirstResponder];
    
}
-(void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (m_displayLink) [m_displayLink invalidate];
    m_displayLink=nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

#pragma mark - UITableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
	return 4;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    switch (section) {
        case 0:return 2;
        case 1:return 2;
        case 2:return 5;
        case 3:return 1;
    }
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *title=nil;
    switch (section) {
        case 0:title=NSLocalizedString(@"Display",@"");
            break;
        case 1:title=NSLocalizedString(@"Size",@"");
            break;
        case 2:title=NSLocalizedString(@"Position",@"");
            break;
        case 3:title=@"";
            break;
    }
    return title;
}

- (void)segActionOpacity:(id)sender {
    int refresh=0;
    if (OPTION(vpad_alpha)!=[sender selectedSegmentIndex]) refresh=1;
    OPTION(vpad_alpha)=[sender selectedSegmentIndex];
    if (refresh) [tabView reloadData];
}

- (void)switchDisplaySpecial:(id)sender {
    OPTION(vpad_showSpecial) =((UISwitch*)sender).on;
    [tabView reloadData];
}

- (void)segActionBtnSize:(id)sender {
    int refresh=0;
    if (OPTION(vpad_btnsize)!=[sender selectedSegmentIndex]) refresh=1;
    OPTION(vpad_btnsize)=[sender selectedSegmentIndex];
    if (refresh) [tabView reloadData];
}
- (void)segActionPadSize:(id)sender {
    int refresh=0;
    if (OPTION(vpad_padsize)!=[sender selectedSegmentIndex]) refresh=1;
    OPTION(vpad_padsize)=[sender selectedSegmentIndex];
    if (refresh) [tabView reloadData];
}
- (void)segActionSkin:(id)sender {
    int refresh=0;
    if (OPTION(vpad_style)!=[sender selectedSegmentIndex]) refresh=1;
    OPTION(vpad_style)=[sender selectedSegmentIndex];
    if (refresh) [tabView reloadData];
}
- (void)sldActionPadX:(id)sender {
    OPTION(vpad_pad_x)=((UISlider *)sender).value;
}
- (void)sldActionPadY:(id)sender {
    OPTION(vpad_pad_y)=((UISlider *)sender).value;
}
- (void)sldActionButtonX:(id)sender {
    OPTION(vpad_button_x)=((UISlider *)sender).value;
}
- (void)sldActionButtonY:(id)sender {
    OPTION(vpad_button_y)=((UISlider *)sender).value;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    NSString *footer=nil;
    switch (section) {
        case 0://Display
            footer=NSLocalizedString(@"Display vpad",@"");
            break;
        case 1://Size
            footer=NSLocalizedString(@"Change size",@"");
            break;
        case 2://Position
            footer=NSLocalizedString(@"Change position",@"");
            break;
    }
    return footer;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UISwitch *switchview;
    UISegmentedControl *segconview;
    MNEValueTrackingSlider *sliderview;
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];                
    }
    cell.accessoryType=UITableViewCellAccessoryNone;
    switch (indexPath.section) {
        case 0://Display
            if (indexPath.row==0) {//Opacity
            cell.textLabel.text=NSLocalizedString(@"Opacity",@"");
                cell.textLabel.textAlignment=UITextAlignmentLeft;
            segconview = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@" 0 ", @" 1 ",@" 2 ",@" 3 ",nil]];
            segconview.segmentedControlStyle = UISegmentedControlStylePlain;
            [segconview addTarget:self action:@selector(segActionOpacity:) forControlEvents:UIControlEventValueChanged];            
            cell.accessoryView = segconview;
            [segconview release];
            segconview.selectedSegmentIndex=OPTION(vpad_alpha);
            } else if (indexPath.row==1) {//Display specials
                cell.textLabel.text=NSLocalizedString(@"Display specials",@"");
                cell.textLabel.textAlignment=UITextAlignmentLeft;
                switchview = [[UISwitch alloc] initWithFrame:CGRectZero];
                [switchview addTarget:self action:@selector(switchDisplaySpecial:) forControlEvents:UIControlEventValueChanged];
                cell.accessoryView = switchview;
                [switchview release];
                switchview.on=OPTION(vpad_showSpecial);

            }
            break;
        case 1://Size
            if (indexPath.row==0) {//Buttons
                cell.textLabel.text=NSLocalizedString(@"Buttons",@"");
                cell.textLabel.textAlignment=UITextAlignmentLeft;
                segconview = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@" 0 ", @" 1 ",@" 2 ",nil]];
                segconview.segmentedControlStyle = UISegmentedControlStylePlain;
                [segconview addTarget:self action:@selector(segActionBtnSize:) forControlEvents:UIControlEventValueChanged];            
                cell.accessoryView = segconview;
                [segconview release];
                segconview.selectedSegmentIndex=OPTION(vpad_btnsize);
            } else if (indexPath.row==1) {//Pad
                cell.textLabel.text=NSLocalizedString(@"Pad",@"");
                cell.textLabel.textAlignment=UITextAlignmentLeft;
                segconview = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@" 0 ", @" 1 ",@" 2 ",nil]];
                segconview.segmentedControlStyle = UISegmentedControlStylePlain;
                [segconview addTarget:self action:@selector(segActionPadSize:) forControlEvents:UIControlEventValueChanged];            
                cell.accessoryView = segconview;
                [segconview release];
                segconview.selectedSegmentIndex=OPTION(vpad_padsize);                
            }
            break;
        case 2://position
            switch (indexPath.row) {
                case 0://Pad X
                    cell.textLabel.text=NSLocalizedString(@"Pad X",@"");
                    cell.textLabel.textAlignment=UITextAlignmentLeft;
                    sliderview = [[MNEValueTrackingSlider alloc] initWithFrame:CGRectMake(0,0,140,30)];
                    sliderview.integerMode=1;
                    [sliderview setMaximumValue:MAX_PAD_OFS_X];
                    [sliderview setMinimumValue:-MAX_PAD_OFS_X];
                    [sliderview setContinuous:true];
                    sliderview.value=OPTION(vpad_pad_x);                    
                    [sliderview addTarget:self action:@selector(sldActionPadX:) forControlEvents:UIControlEventValueChanged];
                    cell.accessoryView = sliderview;
                    [sliderview release];
                    break;
                case 1://Pad Y
                    cell.textLabel.text=NSLocalizedString(@"Pad Y",@"");
                    cell.textLabel.textAlignment=UITextAlignmentLeft;
                    sliderview = [[MNEValueTrackingSlider alloc] initWithFrame:CGRectMake(0,0,140,30)];
                    sliderview.integerMode=1;
                    [sliderview setMaximumValue:MAX_PAD_OFS_Y];
                    [sliderview setMinimumValue:-MAX_PAD_OFS_Y];
                    [sliderview setContinuous:true];
                    sliderview.value=OPTION(vpad_pad_y);                    
                    [sliderview addTarget:self action:@selector(sldActionPadY:) forControlEvents:UIControlEventValueChanged];
                    cell.accessoryView = sliderview;
                    [sliderview release];
                    break;
                case 2://Button X
                    cell.textLabel.text=NSLocalizedString(@"Buttons X",@"");
                    cell.textLabel.textAlignment=UITextAlignmentLeft;
                    sliderview = [[MNEValueTrackingSlider alloc] initWithFrame:CGRectMake(0,0,140,30)];
                    sliderview.integerMode=1;
                    [sliderview setMaximumValue:MAX_BUTTON_OFS_X];
                    [sliderview setMinimumValue:-MAX_BUTTON_OFS_X];
                    [sliderview setContinuous:true];
                    sliderview.value=OPTION(vpad_button_x);                    
                    [sliderview addTarget:self action:@selector(sldActionButtonX:) forControlEvents:UIControlEventValueChanged];
                    cell.accessoryView = sliderview;
                    [sliderview release];
                    break;
                case 3://Button Y
                    cell.textLabel.text=NSLocalizedString(@"Buttons Y",@"");
                    cell.textLabel.textAlignment=UITextAlignmentLeft;
                    sliderview = [[MNEValueTrackingSlider alloc] initWithFrame:CGRectMake(0,0,140,30)];
                    sliderview.integerMode=1;
                    [sliderview setMaximumValue:MAX_BUTTON_OFS_Y];
                    [sliderview setMinimumValue:-MAX_BUTTON_OFS_Y];
                    [sliderview setContinuous:true];
                    sliderview.value=OPTION(vpad_button_y);                    
                    [sliderview addTarget:self action:@selector(sldActionButtonY:) forControlEvents:UIControlEventValueChanged];
                    cell.accessoryView = sliderview;
                    [sliderview release];
                    break;
                case 4://Default
                    cell.textLabel.text=NSLocalizedString(@"Reset to default",@"");
                    cell.textLabel.textAlignment=UITextAlignmentCenter;
                    cell.accessoryView=nil;
                    break;
            }            
            break;
        case 3://skin
                cell.textLabel.text=NSLocalizedString(@"Skin",@"");
            cell.textLabel.textAlignment=UITextAlignmentLeft;
                segconview = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@" 0 ", @" 1 ",@" 2 ",nil]];
                segconview.segmentedControlStyle = UISegmentedControlStylePlain;
                [segconview addTarget:self action:@selector(segActionSkin:) forControlEvents:UIControlEventValueChanged];            
                cell.accessoryView = segconview;
                [segconview release];
                segconview.selectedSegmentIndex=OPTION(vpad_style);
            break;
    }
    
	
    
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section==2) {//Position
        if (indexPath.row==4) {//Reset x,y ofs to default
            OPTION(vpad_button_x)=0;
            OPTION(vpad_button_y)=0;
            OPTION(vpad_pad_x)=0;
            OPTION(vpad_pad_y)=0;
            [tableView reloadData];
        }
    }
}


-(IBAction) backToEmu {
    launchGame=2;
    [self.navigationController popToRootViewControllerAnimated:NO];
}

#pragma Wiimote/iCP support
#define WII_BUTTON_UP(A) (wiimoteBtnState&A)&& !(pressedBtn&A)
-(void) checkWiimote {
    if (num_of_joys==0) return;
    int pressedBtn=iOS_wiimote_check(&(joys[0]));
    
    if (WII_BUTTON_UP(WII_JOY_DOWN)) {
        [self buttonUp:iCadeJoystickDown];
    } else if (WII_BUTTON_UP(WII_JOY_UP)) {
        [self buttonUp:iCadeJoystickUp];
    } else if (WII_BUTTON_UP(WII_JOY_LEFT)) {
        [self buttonUp:iCadeJoystickLeft];
    } else if (WII_BUTTON_UP(WII_JOY_RIGHT)) {
        [self buttonUp:iCadeJoystickRight];
    } else if (WII_BUTTON_UP(WII_JOY_A)) {
        [self buttonUp:iCadeButtonA];
    } else if (WII_BUTTON_UP(WII_JOY_B)) {
        [self buttonUp:iCadeButtonB];
    } else if (WII_BUTTON_UP(WII_JOY_C)) {
        [self buttonUp:iCadeButtonC];
    } else if (WII_BUTTON_UP(WII_JOY_D)) {
        [self buttonUp:iCadeButtonD];
    } else if (WII_BUTTON_UP(WII_JOY_E)) {
        [self buttonUp:iCadeButtonE];
    } else if (WII_BUTTON_UP(WII_JOY_F)) {
        [self buttonUp:iCadeButtonF];
    } else if (WII_BUTTON_UP(WII_JOY_G)) {
        [self buttonUp:iCadeButtonG];
    } else if (WII_BUTTON_UP(WII_JOY_H)) {
        [self buttonUp:iCadeButtonH];
    }
    
    
    wiimoteBtnState=pressedBtn;
}


#pragma Icade support
/****************************************************/
/****************************************************/
/*        ICADE                                     */
/****************************************************/
/****************************************************/
- (void)buttonDown:(iCadeState)button {
}
- (void)buttonUp:(iCadeState)button {
    if (ui_currentIndex_s==-1) {
        ui_currentIndex_s=ui_currentIndex_r=0;
    }
    else {
        if (button&iCadeJoystickDown) {            
            if (ui_currentIndex_r<[tabView numberOfRowsInSection:ui_currentIndex_s]-1) ui_currentIndex_r++; //next row
            else { //next section
                if (ui_currentIndex_s<[tabView numberOfSections]-1) {
                    ui_currentIndex_s++;ui_currentIndex_r=0; //next section
                } else {
                    ui_currentIndex_s=ui_currentIndex_r=0; //loop to 1st section
                }
            }             
        } else if (button&iCadeJoystickUp) {
            if (ui_currentIndex_r>0) ui_currentIndex_r--; //prev row            
            else { //prev section
                if (ui_currentIndex_s>0) {
                    ui_currentIndex_s--;ui_currentIndex_r=[tabView numberOfRowsInSection:ui_currentIndex_s]-1; //next section
                } else {
                    ui_currentIndex_s=[tabView numberOfSections]-1;ui_currentIndex_r=[tabView numberOfRowsInSection:ui_currentIndex_s]-1; //loop to 1st section
                }
            }
        } else if (button&iCadeButtonA) { //validate            
            [self tableView:tabView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:ui_currentIndex_r inSection:ui_currentIndex_s]];
            
        } else if (button&iCadeButtonB) { //back
            [self.navigationController popViewControllerAnimated:YES];
        }
    }
    [tabView selectRowAtIndexPath:[NSIndexPath indexPathForRow:ui_currentIndex_r inSection:ui_currentIndex_s] animated:YES scrollPosition:UITableViewScrollPositionMiddle];
}


@end
