#import <UIKit/UIKit.h>
#import <Cephei/HBPreferences.h>

HBPreferences *preferences;

@protocol WFCloudKitItem
@end

@protocol WFLoggableObject
@end

@protocol WFNaming
@end

@interface WFRecord : NSObject <NSCopying>
@end

@interface WFWorkflowRecord : WFRecord <WFNaming>
@property (copy, nonatomic) NSArray *actions; // ivar: _actions
@property (copy, nonatomic) NSString *minimumClientVersion; // ivar: _minimumClientVersion
@end

@interface WFSharedShortcut : NSObject <WFCloudKitItem, WFLoggableObject>
@property (retain, nonatomic) WFWorkflowRecord *workflowRecord; // ivar: _workflowRecord
-(id)workflowRecord;
@end

%hook WFSharedShortcut
-(id)workflowRecord {
    //NSLog(@"Pastcuts HOOKING WFSharedShortcut!");
    id rettype = %orig;
    [rettype setMinimumClientVersion:@"1"];
    //NSLog(@"Pastcuts Actions by WFSharedShortcutshare: %@", [rettype actions]);
    NSArray *origShortcutActions = [rettype actions];
    NSMutableArray *newMutableShortcutActions = [origShortcutActions mutableCopy];
    int shortcutActionsObjectIndex = 0;
    
    for (id shortcutActionsObject in origShortcutActions) {
        //NSLog(@"Pastcuts Array Item in %i: %@",shortcutActionsObjectIndex,shortcutActionsObject);
        if ([shortcutActionsObject isKindOfClass:[NSDictionary class]]){
            //NSLog(@"Pastcuts item is NSDictionary!");
            if ([[shortcutActionsObject objectForKey:@"WFWorkflowActionIdentifier"] isEqualToString:@"is.workflow.actions.returntohomescreen"]) {
	//in iOS 15, there's a native return to homescreen action. pre-iOS 15 you could use open app for SpringBoard instead, so we're doing that
            NSMutableDictionary *mutableShortcutActionsObject = [shortcutActionsObject mutableCopy];
    
            [mutableShortcutActionsObject setValue:@"is.workflow.actions.openapp" forKey:@"WFWorkflowActionIdentifier"];
	    //remember to add a grouping identifier to the action if needed
            NSDictionary *actionparameters = [[NSDictionary alloc] initWithObjectsAndKeys:@"com.apple.springboard", @"WFAppIdentifier", nil];
            [mutableShortcutActionsObject setValue:actionparameters forKey:@"WFWorkflowActionParameters"];
    
            newMutableShortcutActions[shortcutActionsObjectIndex] = [[NSDictionary alloc] initWithDictionary:mutableShortcutActionsObject];
            } else if ([[shortcutActionsObject objectForKey:@"WFWorkflowActionIdentifier"] isEqualToString:@"is.workflow.actions.output"]) {
            NSMutableDictionary *mutableShortcutActionsObject = [shortcutActionsObject mutableCopy];

            [mutableShortcutActionsObject setValue:@"is.workflow.actions.exit" forKey:@"WFWorkflowActionIdentifier"];
            if ([[[[[mutableShortcutActionsObject objectForKey:@"WFWorkflowActionParameters"] objectForKey:@"WFOutput"] objectForKey:@"Value"] objectForKey:@"attachmentsByRange"] objectForKey:@"{0, 1}"]) {
	//in iOS 15, if an Exit action has output it's converted into the Output action, so we convert it back

            NSDictionary *actionParametersWFResult = [[NSDictionary alloc] initWithObjectsAndKeys:@"placeholder", @"Value", @"WFTextTokenAttachment", @"WFSerializationType", nil];
            NSMutableDictionary *mutableActionParametersWFResult = [actionParametersWFResult mutableCopy];
            [mutableActionParametersWFResult setValue:[[[[[mutableShortcutActionsObject objectForKey:@"WFWorkflowActionParameters"] objectForKey:@"WFOutput"] objectForKey:@"Value"] objectForKey:@"attachmentsByRange"] objectForKey:@"{0, 1}"] forKey:@"Value"];
            NSDictionary *actionParameters = [[NSDictionary alloc] initWithObjectsAndKeys:@"placeholder", @"WFResult", nil];
            NSMutableDictionary *mutableActionParameters = [actionParameters mutableCopy];
            [mutableActionParameters setValue:mutableActionParametersWFResult forKey:@"WFResult"];
            [mutableShortcutActionsObject setValue:mutableActionParameters forKey:@"WFWorkflowActionParameters"];
            }
            newMutableShortcutActions[shortcutActionsObjectIndex] = [[NSDictionary alloc] initWithDictionary:mutableShortcutActionsObject];
            } else if ([[shortcutActionsObject objectForKey:@"WFWorkflowActionIdentifier"] isEqualToString:@"is.workflow.actions.file.select"]) {
	//in iOS 15, Get File with WFShowFilePicker is turned into Select File, so we convert it back
            NSMutableDictionary *mutableShortcutActionsObject = [shortcutActionsObject mutableCopy];

            [mutableShortcutActionsObject setValue:@"is.workflow.actions.documentpicker.open" forKey:@"WFWorkflowActionIdentifier"];
            NSMutableDictionary *mutableActionParameters = [[mutableShortcutActionsObject objectForKey:@"WFWorkflowActionParameters"] mutableCopy];
            BOOL yesvalue = YES;
            [mutableActionParameters setValue:[NSNumber numberWithBool:yesvalue] forKey:@"WFShowFilePicker"];
            [mutableShortcutActionsObject setValue:mutableActionParameters forKey:@"WFWorkflowActionParameters"];

            newMutableShortcutActions[shortcutActionsObjectIndex] = [[NSDictionary alloc] initWithDictionary:mutableShortcutActionsObject];
            } else if ([[shortcutActionsObject objectForKey:@"WFWorkflowActionIdentifier"] isEqualToString:@"is.workflow.actions.documentpicker.open"] && [[shortcutActionsObject objectForKey:@"WFWorkflowActionParameters"] objectForKey:@"WFGetFilePath"] && (!([[shortcutActionsObject objectForKey:@"WFWorkflowActionParameters"] objectForKey:@"WFShowFilePicker"]))) {
	//in iOS 15, a new Get File action doesn't initially use WFShowFilePicker, so if WFGetFilePath is there and WFShowFilePicker we set it to false
                //NSLog(@"Pastcuts Setting WFShowFilePicker to false...");
            NSMutableDictionary *mutableShortcutActionsObject = [shortcutActionsObject mutableCopy];

            NSMutableDictionary *mutableActionParameters = [[mutableShortcutActionsObject objectForKey:@"WFWorkflowActionParameters"] mutableCopy];
            BOOL novalue = NO;
            //NSLog(@"Pastcuts Setting no value to parameters...");
            [mutableActionParameters setObject:[NSNumber numberWithBool:novalue] forKey:@"WFShowFilePicker"];
            //NSLog(@"Pastcuts Updating new parameters to new action object...");
            //NSLog(@"Pastcuts Our new parameters are: %@",mutableActionParameters);
            [mutableShortcutActionsObject setObject:mutableActionParameters forKey:@"WFWorkflowActionParameters"];
            //NSLog(@"Pastcuts Updated New action object with modified parameters!");
            //NSLog(@"Pastcuts Our new action with fixed params is: %@",mutableShortcutActionsObject);

            newMutableShortcutActions[shortcutActionsObjectIndex] = [[NSDictionary alloc] initWithDictionary:mutableShortcutActionsObject];
            } else if ([[shortcutActionsObject objectForKey:@"WFWorkflowActionIdentifier"] isEqualToString:@"com.apple.shortcuts.CreateWorkflowAction"]) {
	//in iOS 16, there's a new Create Shortcut action, we replace it with a URL scheme
	    NSMutableDictionary *mutableShortcutActionsObject = [shortcutActionsObject mutableCopy];
	    [mutableShortcutActionsObject setValue:@"is.workflow.actions.openurl" forKey:@"WFWorkflowActionIdentifier"];
	    [mutableShortcutActionsObject setValue:[[NSMutableDictionary alloc]initWithObjectsAndKeys:@"shortcuts://create-shortcut",@"WFInput",nil] forKey:@"WFWorkflowActionParameters"];
	    newMutableShortcutActions[shortcutActionsObjectIndex] = [[NSDictionary alloc]initWithDictionary:mutableShortcutActionsObject];
            } else if ([[[UIDevice currentDevice] systemVersion] compare:@"13.7" options:NSNumericSearch] != NSOrderedDescending) {
	    //iOS 13 conversions
            if ([[shortcutActionsObject objectForKey:@"WFWorkflowActionIdentifier"] isEqualToString:@"is.workflow.actions.openworkflow"]) {
	//in iOS 14, there's a open shortcut action, so on iOS 13 we replace this with a url scheme to do same thing
            NSMutableDictionary *mutableShortcutActionsObject = [shortcutActionsObject mutableCopy];
	    [mutableShortcutActionsObject setValue:@"is.workflow.actions.openurl" forKey:@"WFWorkflowActionIdentifier"];
	    [mutableShortcutActionsObject setValue:[[NSMutableDictionary alloc]initWithObjectsAndKeys:[NSString stringWithFormat:@"shortcuts://open-shortcut?name=%@",[[shortcutActionsObject objectForKey:@"WFWorkflowActionParameters"]objectForKey:@"workflowName"]],@"WFInput",nil] forKey:@"WFWorkflowActionParameters"];
	    newMutableShortcutActions[shortcutActionsObjectIndex] = [[NSDictionary alloc]initWithDictionary:mutableShortcutActionsObject];
            }
            }
	    //hopefully there's a better method for handling global variables than needing to loop through every action parameter, but can't think of one atm
	    if ([shortcutActionsObject objectForKey:@"WFWorkflowActionParameters"]) {
	    for (NSString* wfDictKey in [shortcutActionsObject objectForKey:@"WFWorkflowActionParameters"]) {
	    if ([[[[shortcutActionsObject objectForKey:@"WFWorkflowActionParameters"]objectForKey:wfDictKey]objectForKey:@"Value"] objectForKey:@"attachmentsByRange"]) {
	    for (NSString* wfParamKey in [shortcutActionsObject objectForKey:@"WFWorkflowActionParameters"]) {
	    if ([[[[[[[shortcutActionsObject objectForKey:@"WFWorkflowActionParameters"]objectForKey:wfDictKey]objectForKey:@"Value"] objectForKey:@"attachmentsByRange"]objectForKey:wfParamKey]objectForKey:@"Type"]isEqualToString:@"DeviceDetails"]) {
	    //if we already created a device details action link to it, if not new one
	    }
	    }
	    }
	    }
            }
        }
        //NSLog(@"Type: %@",[shortcutActionsObject class]);
        shortcutActionsObjectIndex++;
    }
    
    shortcutActionsObjectIndex = 0;

    //NSLog(@"Pastcuts Our new actions mutable array is %@",newMutableShortcutActions);
    [rettype setActions:newMutableShortcutActions];
    //NSLog(@"Pastcuts Finished analyzation of workflowRecord!");
    return rettype;
}
%end

%hook WFGalleryShortcut
-(id)workflowRecord {
    id rettype = %orig;
    [rettype setMinimumClientVersion:@"1"];
    NSArray *origShortcutActions = [rettype actions];
    NSMutableArray *newMutableShortcutActions = [origShortcutActions mutableCopy];
    int shortcutActionsObjectIndex = 0;
    
    for (id shortcutActionsObject in origShortcutActions) {
        if ([shortcutActionsObject isKindOfClass:[NSDictionary class]]){
            if ([[shortcutActionsObject objectForKey:@"WFWorkflowActionIdentifier"] isEqualToString:@"is.workflow.actions.returntohomescreen"]) {
	//in iOS 15, there's a native return to homescreen action. pre-iOS 15 you could use open app for SpringBoard instead, so we're doing that
            NSMutableDictionary *mutableShortcutActionsObject = [shortcutActionsObject mutableCopy];
    
            [mutableShortcutActionsObject setValue:@"is.workflow.actions.openapp" forKey:@"WFWorkflowActionIdentifier"];
	    //remember to add a grouping identifier to the action if needed
            NSDictionary *actionparameters = [[NSDictionary alloc] initWithObjectsAndKeys:@"com.apple.springboard", @"WFAppIdentifier", nil];
            [mutableShortcutActionsObject setValue:actionparameters forKey:@"WFWorkflowActionParameters"];
    
            NSDictionary *newShortDict = [[NSDictionary alloc] initWithDictionary:mutableShortcutActionsObject];
            newMutableShortcutActions[shortcutActionsObjectIndex] = newShortDict;
            } else if ([[shortcutActionsObject objectForKey:@"WFWorkflowActionIdentifier"] isEqualToString:@"is.workflow.actions.output"]) {
            NSMutableDictionary *mutableShortcutActionsObject = [shortcutActionsObject mutableCopy];

            [mutableShortcutActionsObject setValue:@"is.workflow.actions.exit" forKey:@"WFWorkflowActionIdentifier"];
            if ([[[[[mutableShortcutActionsObject objectForKey:@"WFWorkflowActionParameters"] objectForKey:@"WFOutput"] objectForKey:@"Value"] objectForKey:@"attachmentsByRange"] objectForKey:@"{0, 1}"]) {
	//in iOS 15, if an Exit action has output it's converted into the Output action, so we convert it back

            NSDictionary *actionParametersWFResult = [[NSDictionary alloc] initWithObjectsAndKeys:@"placeholder", @"Value", @"WFTextTokenAttachment", @"WFSerializationType", nil];
            NSMutableDictionary *mutableActionParametersWFResult = [actionParametersWFResult mutableCopy];
            [mutableActionParametersWFResult setValue:[[[[[mutableShortcutActionsObject objectForKey:@"WFWorkflowActionParameters"] objectForKey:@"WFOutput"] objectForKey:@"Value"] objectForKey:@"attachmentsByRange"] objectForKey:@"{0, 1}"] forKey:@"Value"];
            NSDictionary *actionParameters = [[NSDictionary alloc] initWithObjectsAndKeys:@"placeholder", @"WFResult", nil];
            NSMutableDictionary *mutableActionParameters = [actionParameters mutableCopy];
            [mutableActionParameters setValue:mutableActionParametersWFResult forKey:@"WFResult"];
            [mutableShortcutActionsObject setValue:mutableActionParameters forKey:@"WFWorkflowActionParameters"];
            }
            NSDictionary *newShortDict = [[NSDictionary alloc] initWithDictionary:mutableShortcutActionsObject];
            newMutableShortcutActions[shortcutActionsObjectIndex] = newShortDict;
            } else if ([[shortcutActionsObject objectForKey:@"WFWorkflowActionIdentifier"] isEqualToString:@"is.workflow.actions.file.select"]) {
	//in iOS 15, Get File with WFShowFilePicker is turned into Select File, so we convert it back
            NSMutableDictionary *mutableShortcutActionsObject = [shortcutActionsObject mutableCopy];

            [mutableShortcutActionsObject setValue:@"is.workflow.actions.documentpicker.open" forKey:@"WFWorkflowActionIdentifier"];
            NSMutableDictionary *mutableActionParameters = [[mutableShortcutActionsObject objectForKey:@"WFWorkflowActionParameters"] mutableCopy];
            BOOL yesvalue = YES;
            [mutableActionParameters setValue:[NSNumber numberWithBool:yesvalue] forKey:@"WFShowFilePicker"];
            [mutableShortcutActionsObject setValue:mutableActionParameters forKey:@"WFWorkflowActionParameters"];

            NSDictionary *newShortDict = [[NSDictionary alloc] initWithDictionary:mutableShortcutActionsObject];
            newMutableShortcutActions[shortcutActionsObjectIndex] = newShortDict;
            } else if ([[shortcutActionsObject objectForKey:@"WFWorkflowActionIdentifier"] isEqualToString:@"is.workflow.actions.documentpicker.open"] && [[shortcutActionsObject objectForKey:@"WFWorkflowActionParameters"] objectForKey:@"WFGetFilePath"] && (!([[shortcutActionsObject objectForKey:@"WFWorkflowActionParameters"] objectForKey:@"WFShowFilePicker"]))) {
	//in iOS 15, a new Get File action doesn't initially use WFShowFilePicker, so if WFGetFilePath is there and WFShowFilePicker we set it to false
            NSMutableDictionary *mutableShortcutActionsObject = [shortcutActionsObject mutableCopy];

            NSMutableDictionary *mutableActionParameters = [[mutableShortcutActionsObject objectForKey:@"WFWorkflowActionParameters"] mutableCopy];
            BOOL novalue = NO;
            [mutableActionParameters setObject:[NSNumber numberWithBool:novalue] forKey:@"WFShowFilePicker"];
            [mutableShortcutActionsObject setObject:mutableActionParameters forKey:@"WFWorkflowActionParameters"];

            NSDictionary *newShortDict = [[NSDictionary alloc] initWithDictionary:mutableShortcutActionsObject];
            newMutableShortcutActions[shortcutActionsObjectIndex] = newShortDict;
            } else if ([[shortcutActionsObject objectForKey:@"WFWorkflowActionIdentifier"] isEqualToString:@"com.apple.shortcuts.CreateWorkflowAction"]) {
	//in iOS 16, there's a new Create Shortcut action, we replace it with a URL scheme
	    NSMutableDictionary *mutableShortcutActionsObject = [shortcutActionsObject mutableCopy];
	    [mutableShortcutActionsObject setValue:@"is.workflow.actions.openurl" forKey:@"WFWorkflowActionIdentifier"];
	    [mutableShortcutActionsObject setValue:[[NSMutableDictionary alloc]initWithObjectsAndKeys:@"shortcuts://create-shortcut",@"WFInput",nil] forKey:@"WFWorkflowActionParameters"];
	    newMutableShortcutActions[shortcutActionsObjectIndex] = [[NSDictionary alloc]initWithDictionary:mutableShortcutActionsObject];
            } else if ([[[UIDevice currentDevice] systemVersion] compare:@"13.7" options:NSNumericSearch] != NSOrderedDescending) {
	    //iOS 13 conversions
            if ([[shortcutActionsObject objectForKey:@"WFWorkflowActionIdentifier"] isEqualToString:@"is.workflow.actions.openworkflow"]) {
	//in iOS 14, there's a open shortcut action, so on iOS 13 we replace this with a url scheme to do same thing
            NSMutableDictionary *mutableShortcutActionsObject = [shortcutActionsObject mutableCopy];
	    [mutableShortcutActionsObject setValue:@"is.workflow.actions.openurl" forKey:@"WFWorkflowActionIdentifier"];
	    [mutableShortcutActionsObject setValue:[[NSMutableDictionary alloc]initWithObjectsAndKeys:[NSString stringWithFormat:@"shortcuts://open-shortcut?name=%@",[[shortcutActionsObject objectForKey:@"WFWorkflowActionParameters"]objectForKey:@"workflowName"]],@"WFInput",nil] forKey:@"WFWorkflowActionParameters"];
	    newMutableShortcutActions[shortcutActionsObjectIndex] = [[NSDictionary alloc]initWithDictionary:mutableShortcutActionsObject];
            }
            }
        }
        shortcutActionsObjectIndex++;
    }
    
    shortcutActionsObjectIndex = 0;

    [rettype setActions:newMutableShortcutActions];
    return rettype;
}
%end

%group pastcutsVersionSpoofing
%hook WFDevice
-(id)systemVersion {
    if (!([preferences objectForKey:@"versionToSpoof"])){
        return @"16.1";
    } else {
        return [preferences objectForKey:@"versionToSpoof"];
    }
}
%end
%end

%group pastcutsModernActionNames
//finish latr
%end

//Remember to add a not recommended alert due to force importing hooking every shortcut loaded, bad for performance and potentially may cause unintended effects
%group pastcutsForceImport
%hook WFWorkflowRecord
-(void)setMinimumClientVersion:(NSString *)arg1 {
    %orig(@"1");
}
%end
%end

%ctor {
  preferences = [[HBPreferences alloc] initWithIdentifier:@"cum.0xilis.pastcutsprefs"];
  if ([preferences boolForKey:@"isEnableVersionSpoofing"]) %init(pastcutsVersionSpoofing);
  if ([preferences boolForKey:@"isEnableModernActionNames"]) %init(pastcutsModernActionNames);
  if ([preferences boolForKey:@"isEnableForceImport"]) %init(pastcutsForceImport);
}
