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
-(WFWorkflowRecord *)workflowRecord {
  WFWorkflowRecord *workflowRecord = %orig;
  [workflowRecord setMinimumClientVersion:@"1"];
  NSArray *origShortcutActions = (NSArray *)[workflowRecord actions];
  NSMutableArray *newMutableShortcutActions = [origShortcutActions mutableCopy];
  int shortcutActionIndex = 0;
  NSMutableDictionary *getDeviceDetailsActions = [[NSMutableDictionary alloc]init];
    
  for (NSDictionary *shortcutAction in origShortcutActions) {
    NSString *identifier = shortcutAction[@"WFWorkflowActionIdentifier"];
    NSDictionary *workflowParameters = shortcutAction[@"WFWorkflowActionParameters"];

    if ([identifier isEqualToString:@"is.workflow.actions.returntohomescreen"]) {
      //in iOS 15, there's a native return to homescreen action. pre-iOS 15 you could use open app for SpringBoard instead, so we're doing that
      NSMutableDictionary *mutableShortcutAction = [shortcutAction mutableCopy];
      mutableShortcutAction[@"WFWorkflowActionIdentifier"] = @"is.workflow.actions.openapp";
      //remember to add a grouping identifier to the action if needed
      //actually, i dont think this is needed since its not like return to homescreen is a conditional or has magic variables so yeah
      mutableShortcutAction[@"WFWorkflowActionParameters"] = @{ @"WFAppIdentifier": @"com.apple.springboard" };
      newMutableShortcutActions[shortcutActionIndex] = mutableShortcutAction;
    } else if ([identifier isEqualToString:@"is.workflow.actions.output"]) {
      NSMutableDictionary *mutableShortcutAction = [shortcutAction mutableCopy];
      mutableShortcutAction[@"WFWorkflowActionIdentifier"] = @"is.workflow.actions.exit";
      NSDictionary *outputValueDict = workflowParameters[@"WFOutput"]? workflowParameters[@"WFOutput"][@"Value"] : nil;
      NSDictionary *attachmentsByRangeDict = outputValueDict? outputValueDict[@"attachmentsByRange"] : nil;
      NSDictionary *outputDictionary = attachmentsByRangeDict? attachmentsByRangeDict[@"{0, 1}"] : nil;
      
      if (outputDictionary) {
	//in iOS 15, if an Exit action has output it's converted into the Output action, so we convert it back
	//at first i thought it may be good to keep WFWorkflowActionParameters original and only change WFResult, but now that i think about it, it may not be necessary for Output action
	NSMutableDictionary *mutableActionParameters = [@{ @"WFResult": @{ @"Value": outputDictionary, @"WFSerializationType": @"WFTextTokenAttachment" } } mutableCopy];
	mutableShortcutAction[@"WFWorkflowActionParameters"] = mutableActionParameters;
      }
      newMutableShortcutActions[shortcutActionIndex] = mutableShortcutAction;
    } else if ([identifier isEqualToString:@"is.workflow.actions.file.select"]) {
      //in iOS 15, Get File with WFShowFilePicker is turned into Select File, so we convert it back
      NSMutableDictionary *mutableShortcutAction = [shortcutAction mutableCopy];

      mutableShortcutAction[@"WFWorkflowActionIdentifier"] = @"is.workflow.actions.documentpicker.open";
      NSMutableDictionary *mutableActionParameters = [workflowParameters mutableCopy];
      mutableActionParameters[@"WFShowFilePicker"] = @YES;
      mutableShortcutAction[@"WFWorkflowActionParameters"] = mutableActionParameters;

      newMutableShortcutActions[shortcutActionIndex] = mutableShortcutAction;
     } else if ([identifier isEqualToString:@"is.workflow.actions.documentpicker.open"]) {
       NSMutableDictionary *mutableShortcutAction = [shortcutAction mutableCopy];
       //in iOS 15, a new Get File action doesn't initially use WFShowFilePicker, so if WFGetFilePath is there and WFShowFilePicker we set it to false
       if (workflowParameters[@"WFGetFilePath"] && ![workflowParameters[@"WFShowFilePicker"] boolValue]) {
         mutableShortcutAction[@"WFWorkflowActionParameters"][@"WFShowFilePicker"] = @NO;
       }
       newMutableShortcutActions[shortcutActionIndex] = mutableShortcutAction;
      } else if ([identifier isEqualToString:@"com.apple.shortcuts.CreateWorkflowAction"]) {
	//in iOS 16, there's a new Create Shortcut action, we replace it with a URL scheme
	NSMutableDictionary *mutableShortcutAction = [shortcutAction mutableCopy];
	mutableShortcutAction[@"WFWorkflowActionIdentifier"] = @"is.workflow.actions.openurl";
	mutableShortcutAction[@"WFWorkflowActionParameters"] = @{ @"WFInput": @"shortcuts://create-shortcut" };
	newMutableShortcutActions[shortcutActionIndex] = mutableShortcutAction;
      } else if (@available(iOS 14, *)) {
        //iOS 13 conversions
        if ([identifier isEqualToString:@"is.workflow.actions.openworkflow"]) {
	  //in iOS 14, there's a open shortcut action, so on iOS 13 we replace this with a url scheme to do same thing
          NSMutableDictionary *mutableShortcutAction = [shortcutAction mutableCopy];
	  NSString *workflowName = workflowParameters[@"workflowName"];
	  if (workflowName) {
	    NSString *escapedWorkflowName = [workflowName stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet alphanumericCharacterSet]];
	    mutableShortcutAction[@"WFWorkflowActionIdentifier"] = @"is.workflow.actions.openurl";
	    mutableShortcutAction[@"WFWorkflowActionParameters"] = @{ @"WFInput": [NSString stringWithFormat:@"shortcuts://open-shortcut?name=%@", escapedWorkflowName] };
	  } else {
	    mutableShortcutAction[@"WFWorkflowActionIdentifier"] = @"is.workflow.actions.openurl";
	    mutableShortcutAction[@"WFWorkflowActionParameters"] = @{ @"WFInput": @"shortcuts://open-shortcut?name=PASTCUTS_ERROR" };
	  }
	  newMutableShortcutActions[shortcutActionIndex] = mutableShortcutAction;
        }
      }
      //in iOS 15, there's a new device details global variable, so we cycle through all parameters of the action, and if we find it, replace it with magic var to device details action
      //hopefully there's a better method for handling global variables than needing to loop through every action parameter, but can't think of one atm
      for (NSString* wfDictKey in workflowParameters) {
        NSDictionary *wfDictValue = workflowParameters[wfDictKey][@"Value"];
	NSDictionary *attachmentsByRange = wfDictValue[@"attachmentsByRange"];
        for (NSString *wfParamKey in attachmentsByRange) {
          if ([[attachmentsByRange[wfParamKey]objectForKey:@"Type"]isEqualToString:@"DeviceDetails"]) {
            //if we already created a device details action link to it, if not new one
            NSString *actionUUID;
            if ([getDeviceDetailsActions objectForKey:[[[attachmentsByRange[wfParamKey]objectForKey:@"Aggrandizements"]firstObject]objectForKey:@"PropertyName"]]) {
              actionUUID = [[[attachmentsByRange[wfParamKey]objectForKey:@"Aggrandizements"]firstObject]objectForKey:@"PropertyName"];
            } else {
              actionUUID = [[NSUUID UUID] UUIDString];
              [getDeviceDetailsActions setObject:actionUUID forKey:[[[attachmentsByRange[wfParamKey]objectForKey:@"Aggrandizements"]firstObject]objectForKey:@"PropertyName"]];
              //insert new device details variable
              [newMutableShortcutActions insertObject:[[NSDictionary alloc]initWithObjectsAndKeys:[[NSDictionary alloc]initWithObjectsAndKeys:[[[attachmentsByRange[wfParamKey]objectForKey:@"Aggrandizements"]firstObject]objectForKey:@"PropertyName"],@"WFDeviceDetail",actionUUID,@"UUID",nil],@"WFWorkflowActionParameters",@"is.workflow.actions.getdevicedetails",@"WFWorkflowActionIdentifier",nil] atIndex:0];
              //since we added an action to top, we add to shortcutActionIndex
              shortcutActionIndex++;
            }
	    //TODO: yes, i know this fucking sucks
            NSMutableDictionary *mutableShortcutAction = [shortcutAction mutableCopy];
            NSMutableDictionary *mutableActionParameters = [workflowParameters mutableCopy];
            NSMutableDictionary *mutableActionParameter1 = [[workflowParameters objectForKey:wfDictKey] mutableCopy];
            NSMutableDictionary *mutableActionParameter2 = [wfDictValue mutableCopy];
            NSMutableDictionary *mutableActionParameter3 = [attachmentsByRange mutableCopy];
            [mutableActionParameter3 setObject:[[NSDictionary alloc]initWithObjectsAndKeys:@"ActionOutput",@"Type",actionUUID,@"OutputUUID",[[[attachmentsByRange[wfParamKey]objectForKey:@"Aggrandizements"]firstObject]objectForKey:@"PropertyName"],@"OutputName",nil] forKey:wfParamKey];
            [mutableActionParameter2 setObject:[[NSDictionary alloc]initWithDictionary:mutableActionParameter3] forKey:@"attachmentsByRange"];
            [mutableActionParameter1 setObject:[[NSDictionary alloc]initWithDictionary:mutableActionParameter2] forKey:@"Value"];
            [mutableActionParameters setObject:[[NSDictionary alloc]initWithDictionary:mutableActionParameter1] forKey:wfDictKey];
            [mutableShortcutAction setObject:[[NSDictionary alloc]initWithDictionary:mutableActionParameters] forKey:@"WFWorkflowActionParameters"];
            newMutableShortcutActions[shortcutActionIndex] = [[NSDictionary alloc]initWithDictionary:mutableShortcutAction];
	  }
	}
      }
      shortcutActionIndex++;
    }
    
    shortcutActionIndex = 0;

    //NSLog(@"Pastcuts Our new actions mutable array is %@",newMutableShortcutActions);
    [workflowRecord setActions:newMutableShortcutActions];
    //NSLog(@"Pastcuts Finished analyzation of workflowRecord!");
    return workflowRecord;
}
%end

%hook WFGalleryShortcut
-(WFWorkflowRecord *)workflowRecord {
  WFWorkflowRecord *workflowRecord = %orig;
  [workflowRecord setMinimumClientVersion:@"1"];
  NSArray *origShortcutActions = (NSArray *)[workflowRecord actions];
  NSMutableArray *newMutableShortcutActions = [origShortcutActions mutableCopy];
  int shortcutActionIndex = 0;
  NSMutableDictionary *getDeviceDetailsActions = [[NSMutableDictionary alloc]init];
    
  for (NSDictionary *shortcutAction in origShortcutActions) {
    NSString *identifier = shortcutAction[@"WFWorkflowActionIdentifier"];
    NSDictionary *workflowParameters = shortcutAction[@"WFWorkflowActionParameters"];

    if ([identifier isEqualToString:@"is.workflow.actions.returntohomescreen"]) {
      //in iOS 15, there's a native return to homescreen action. pre-iOS 15 you could use open app for SpringBoard instead, so we're doing that
      NSMutableDictionary *mutableShortcutAction = [shortcutAction mutableCopy];
      mutableShortcutAction[@"WFWorkflowActionIdentifier"] = @"is.workflow.actions.openapp";
      //remember to add a grouping identifier to the action if needed
      //actually, i dont think this is needed since its not like return to homescreen is a conditional or has magic variables so yeah
      mutableShortcutAction[@"WFWorkflowActionParameters"] = @{ @"WFAppIdentifier": @"com.apple.springboard" };
      newMutableShortcutActions[shortcutActionIndex] = mutableShortcutAction;
    } else if ([identifier isEqualToString:@"is.workflow.actions.output"]) {
      NSMutableDictionary *mutableShortcutAction = [shortcutAction mutableCopy];
      mutableShortcutAction[@"WFWorkflowActionIdentifier"] = @"is.workflow.actions.exit";
      NSDictionary *outputDictionary = mutableShortcutAction[@"WFWorkflowActionParameters"][@"WFOutput"][@"Value"][@"attachmentsByRange"][@"{0, 1}"];
      
      if (outputDictionary) {
	//in iOS 15, if an Exit action has output it's converted into the Output action, so we convert it back
	//at first i thought it may be good to keep WFWorkflowActionParameters original and only change WFResult, but now that i think about it, it may not be necessary for Output action
	NSMutableDictionary *mutableActionParameters = [@{ @"WFResult": @{ @"Value": outputDictionary, @"WFSerializationType": @"WFTextTokenAttachment" } } mutableCopy];
	mutableShortcutAction[@"WFWorkflowActionParameters"] = mutableActionParameters;
      }
      newMutableShortcutActions[shortcutActionIndex] = mutableShortcutAction;
    } else if ([identifier isEqualToString:@"is.workflow.actions.file.select"]) {
      //in iOS 15, Get File with WFShowFilePicker is turned into Select File, so we convert it back
      NSMutableDictionary *mutableShortcutAction = [shortcutAction mutableCopy];

      mutableShortcutAction[@"WFWorkflowActionIdentifier"] = @"is.workflow.actions.documentpicker.open";
      NSMutableDictionary *mutableActionParameters = [workflowParameters mutableCopy];
      mutableActionParameters[@"WFShowFilePicker"] = @YES;
      mutableShortcutAction[@"WFWorkflowActionParameters"] = mutableActionParameters;

      newMutableShortcutActions[shortcutActionIndex] = mutableShortcutAction;
     } else if ([identifier isEqualToString:@"is.workflow.actions.documentpicker.open"]) {
       NSMutableDictionary *mutableShortcutAction = [shortcutAction mutableCopy];
       //in iOS 15, a new Get File action doesn't initially use WFShowFilePicker, so if WFGetFilePath is there and WFShowFilePicker we set it to false
       if (mutableShortcutAction[@"WFWorkflowActionParameters"][@"WFGetFilePath"] && ![mutableShortcutAction[@"WFWorkflowActionParameters"][@"WFShowFilePicker"] boolValue]) {
         mutableShortcutAction[@"WFWorkflowActionParameters"][@"WFShowFilePicker"] = @NO;
       }
       newMutableShortcutActions[shortcutActionIndex] = mutableShortcutAction;
      } else if ([identifier isEqualToString:@"com.apple.shortcuts.CreateWorkflowAction"]) {
	//in iOS 16, there's a new Create Shortcut action, we replace it with a URL scheme
	NSMutableDictionary *mutableShortcutAction = [shortcutAction mutableCopy];
	mutableShortcutAction[@"WFWorkflowActionIdentifier"] = @"is.workflow.actions.openurl";
	mutableShortcutAction[@"WFWorkflowActionParameters"] = @{ @"WFInput": @"shortcuts://create-shortcut" };
	newMutableShortcutActions[shortcutActionIndex] = mutableShortcutAction;
      } else if (@available(iOS 14, *)) {
        //iOS 13 conversions
        if ([identifier isEqualToString:@"is.workflow.actions.openworkflow"]) {
	  //in iOS 14, there's a open shortcut action, so on iOS 13 we replace this with a url scheme to do same thing
          NSMutableDictionary *mutableShortcutAction = [shortcutAction mutableCopy];
	  NSString *workflowName = mutableShortcutAction[@"WFWorkflowActionParameters"][@"workflowName"];
	  NSString *escapedWorkflowName = [workflowName stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet alphanumericCharacterSet]];
	  mutableShortcutAction[@"WFWorkflowActionIdentifier"] = @"is.workflow.actions.openurl";
	  mutableShortcutAction[@"WFWorkflowActionParameters"] = @{ @"WFInput": [NSString stringWithFormat:@"shortcuts://open-shortcut?name=%@", escapedWorkflowName] };
	  newMutableShortcutActions[shortcutActionIndex] = mutableShortcutAction;
        }
      }
      //in iOS 15, there's a new device details global variable, so we cycle through all parameters of the action, and if we find it, replace it with magic var to device details action
      //hopefully there's a better method for handling global variables than needing to loop through every action parameter, but can't think of one atm
      for (NSString* wfDictKey in workflowParameters) {
        NSDictionary *wfDict = workflowParameters[wfDictKey];
        NSDictionary *wfDictValue = [wfDict isKindOfClass:[NSDictionary class]]? wfDict[@"Value"] : nil;
	NSDictionary *attachmentsByRange = (wfDictValue && [wfDictValue isKindOfClass:[NSDictionary class]])? wfDictValue[@"attachmentsByRange"] : nil;
        for (NSString *wfParamKey in attachmentsByRange) {
          if ([attachmentsByRange[wfParamKey][@"Type"]isEqualToString:@"DeviceDetails"]) {
            //if we already created a device details action link to it, if not new one
            NSString *actionUUID;
            if ([getDeviceDetailsActions objectForKey:[[[attachmentsByRange[wfParamKey]objectForKey:@"Aggrandizements"]firstObject]objectForKey:@"PropertyName"]]) {
              actionUUID = [[[attachmentsByRange[wfParamKey]objectForKey:@"Aggrandizements"]firstObject]objectForKey:@"PropertyName"];
            } else {
              actionUUID = [[NSUUID UUID] UUIDString];
              [getDeviceDetailsActions setObject:actionUUID forKey:[[[attachmentsByRange[wfParamKey]objectForKey:@"Aggrandizements"]firstObject]objectForKey:@"PropertyName"]];
              //insert new device details variable
              [newMutableShortcutActions insertObject:[[NSDictionary alloc]initWithObjectsAndKeys:[[NSDictionary alloc]initWithObjectsAndKeys:[[[attachmentsByRange[wfParamKey]objectForKey:@"Aggrandizements"]firstObject]objectForKey:@"PropertyName"],@"WFDeviceDetail",actionUUID,@"UUID",nil],@"WFWorkflowActionParameters",@"is.workflow.actions.getdevicedetails",@"WFWorkflowActionIdentifier",nil] atIndex:0];
              //since we added an action to top, we add to shortcutActionIndex
              shortcutActionIndex++;
            }
	    //TODO: yes, i know this fucking sucks
            NSMutableDictionary *mutableShortcutAction = [shortcutAction mutableCopy];
            NSMutableDictionary *mutableActionParameters = [workflowParameters mutableCopy];
            NSMutableDictionary *mutableActionParameter1 = [[workflowParameters objectForKey:wfDictKey] mutableCopy];
            NSMutableDictionary *mutableActionParameter2 = [wfDictValue mutableCopy];
            NSMutableDictionary *mutableActionParameter3 = [attachmentsByRange mutableCopy];
            [mutableActionParameter3 setObject:[[NSDictionary alloc]initWithObjectsAndKeys:@"ActionOutput",@"Type",actionUUID,@"OutputUUID",[[[attachmentsByRange[wfParamKey]objectForKey:@"Aggrandizements"]firstObject]objectForKey:@"PropertyName"],@"OutputName",nil] forKey:wfParamKey];
            [mutableActionParameter2 setObject:[[NSDictionary alloc]initWithDictionary:mutableActionParameter3] forKey:@"attachmentsByRange"];
            [mutableActionParameter1 setObject:[[NSDictionary alloc]initWithDictionary:mutableActionParameter2] forKey:@"Value"];
            [mutableActionParameters setObject:[[NSDictionary alloc]initWithDictionary:mutableActionParameter1] forKey:wfDictKey];
            [mutableShortcutAction setObject:[[NSDictionary alloc]initWithDictionary:mutableActionParameters] forKey:@"WFWorkflowActionParameters"];
            newMutableShortcutActions[shortcutActionIndex] = [[NSDictionary alloc]initWithDictionary:mutableShortcutAction];
	  }
	}
      }
      shortcutActionIndex++;
    }
    
    shortcutActionIndex = 0;

    //NSLog(@"Pastcuts Our new actions mutable array is %@",newMutableShortcutActions);
    [workflowRecord setActions:newMutableShortcutActions];
    //NSLog(@"Pastcuts Finished analyzation of workflowRecord!");
    return workflowRecord;
}
%end

%group pastcutsVersionSpoofing
%hook WFDevice
-(id)systemVersion {
    if (!([preferences objectForKey:@"versionToSpoof"])){
        return @"16.4";
    } else {
        return [preferences objectForKey:@"versionToSpoof"];
    }
}
%end
%end

%group pastcutsModernActionNames
%hook WFAction
-(NSString*)name {
    NSString *origName = %orig;
    NSDictionary *modernNames = [[NSDictionary alloc]initWithObjectsAndKeys:@"Get What’s On Screen",@"Get What's On Screen",@"Get What’s On Screen",@"Get On-Screen Content",@"Open Reminders List",@"Show Reminders List",@"Open Directions",@"Show Directions",@"Open in Maps",@"Show in Maps",@"Open in BlindSquare",@"Show in BlindSquare",@"Open in Calendar",@"Show in Calendar",@"Add to Playing Next",@"Add to Up Next",@"Clear Playing Next",@"Clear Up Next",@"Find Giphy GIFs",@"Search Giphy",@"Follow Podcast",@"Subscribe to Podcast",@"Scan QR or Barcode",@"Scan QR or Bar Code",@"Scan QR or Barcode",@"Scan QR/Bar Code",@"Find App Store Apps",@"Search App Store",@"Find iTunes Store Items",@"Search iTunes Store",@"Find Places",@"Search Local Businesses",@"Find Podcasts",@"Search Podcasts",@"Show Web View",@"Show Web Page",@"Detect Language",@"Detect Language with Microsoft",@"Stop This Shortcut",@"Stop Shortcut",@"Get Current Web Page from Safari",@"Get Current URL from Safari",@"Change Playback Destination",@"Set Playback Destination",@"Translate Text",@"Translate Text with Microsoft",@"Set Focus",@"Set Do Not Disturb",@"Get File from Folder",@"Get File",@"Stop This Shortcut",@"Exit Shortcut",@"Append to Text File",@"Append to File",@"Rotate Image/Video",@"Rotate Image",@"Open File",@"Open In...",@"Share with Apps",@"Share with Extensions",nil];
    if ([modernNames objectForKey:origName]) {
        return [modernNames objectForKey:origName];
    }
    return origName;
}
%end
%end

//Remember to add a not recommended alert due to force opening hooking every shortcut loaded, bad for performance and potentially may cause unintended side effects
%group pastcutsForceOpen
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
  if ([preferences boolForKey:@"isEnableForceOpen"]) %init(pastcutsForceOpen);
  %init(_ungrouped);
}
