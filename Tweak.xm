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

%group iOS13AndAbove
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

//Remember to add a not recommended alert due to force opening hooking every shortcut loaded, bad for performance and potentially may cause unintended side effects
%group pastcutsForceOpen
%hook WFWorkflowRecord
-(void)setMinimumClientVersion:(NSString *)arg1 {
    %orig(@"1");
}
%end
%end

%end

%group iOS12
%hook WFSharedShortcut
-(id)workflow {
    id rettype = %orig;
    [rettype setMinimumClientVersion:@"1"];
    return rettype;
}
%end
//Remember to add a not recommended alert due to force opening hooking every shortcut loaded, bad for performance and potentially may cause unintended side effects
%group pastcutsForceOpen
%hook WFWorkflow
-(void)setMinimumClientVersion:(NSString *)arg1 {
    %orig(@"1");
}
%end
%end
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

// https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes

//eng [[NSDictionary alloc]initWithObjectsAndKeys:@"Get What’s On Screen",@"Get What's On Screen",@"Get What’s On Screen",@"Get On-Screen Content",@"Open Reminders List",@"Show Reminders List",@"Open Directions",@"Show Directions",@"Open in Maps",@"Show in Maps",@"Open in BlindSquare",@"Show in BlindSquare",@"Open in Calendar",@"Show in Calendar",@"Add to Playing Next",@"Add to Up Next",@"Clear Playing Next",@"Clear Up Next",@"Find Giphy GIFs",@"Search Giphy",@"Follow Podcast",@"Subscribe to Podcast",@"Scan QR or Barcode",@"Scan QR or Bar Code",@"Scan QR or Barcode",@"Scan QR/Bar Code",@"Find App Store Apps",@"Search App Store",@"Find iTunes Store Items",@"Search iTunes Store",@"Find Places",@"Search Local Businesses",@"Find Podcasts",@"Search Podcasts",@"Show Web View",@"Show Web Page",@"Detect Language",@"Detect Language with Microsoft",@"Stop This Shortcut",@"Stop Shortcut",@"Get Current Web Page from Safari",@"Get Current URL from Safari",@"Change Playback Destination",@"Set Playback Destination",@"Translate Text",@"Translate Text with Microsoft",@"Set Focus",@"Set Do Not Disturb",@"Get File from Folder",@"Get File",@"Stop This Shortcut",@"Exit Shortcut",@"Append to Text File",@"Append to File",@"Rotate Image/Video",@"Rotate Image",@"Open File",@"Open In...",@"Share with Apps",@"Share with Extensions",nil];
//es (wip) [[NSDictionary alloc]initWithObjectsAndKeys:@"Get What’s On Screen",@"Obtener contenido en pantalla",@"Get What’s On Screen",@"Obtener contenido en pantalla",@"Open Reminders Crear lista",@"Show Reminders Crear lista",@"Open Directions",@"Mostrar ruta",@"Open in Maps",@"Mostrar en Mapas",@"Open in BlindSquare",@"Mostrar en BlindSquare",@"Open in Calendar",@"Mostrar en el calendario",@"Add to Playing Next",@"Añadir a “A continuación”",@"Clear Playing Next",@"Borrar “A continuación”",@"Find Giphy GIFs",@"Buscar en Giphy",@"Follow Podcast",@"Suscribirse a podcast",@"Scan QR or Barcode",@"Escanear código de barras o QR",@"Scan QR or Barcode",@"Escanear código de barras/QR",@"Find App Store Apps",@"Buscar en App Store",@"Find iTunes Store Items",@"Buscar en iTunes Store",@"Find Places",@"Buscar negocios locales",@"Find Podcasts",@"Buscar podcasts",@"Show Web View",@"Mostrar página web",@"Detectar idioma",@"Detectar idioma con Microsoft",@"Detener este atajo",@"Detener atajo",@"Obtener la página web actual de Safari",@"Obtener URL de Safari",@"Cambiar destino de la reproducción",@"Definir destino de reproducción",@"Translate Texto",@"Traducir texto con Microsoft",@"Definir modo de concentración",@"Set Do Not Disturb",@"Get File from Carpeta",@"Get Archivo",@"Detener este atajo",@"Exit Shortcut",@"Append to Text Archivo",@"Append to Archivo",@"Girar imagen/vídeo",@"Rotate Image",@"Abrir archivo",@"Open In...",@"Compartir con apps",@"Share with Extensions",nil];
//fr (wip) [[NSDictionary alloc]initWithObjectsAndKeys:@"Get What’s On Screen",@"Obtenir le contenu affiché",@"Get What’s On Screen",@"Obtenir le contenu à l’écran",@"Open Reminders Lister",@"Show Reminders Lister",@"Open Directions",@"Afficher l’itinéraire",@"Open in Maps",@"Afficher dans Plans",@"Open in BlindSquare",@"Afficher dans BlindSquare",@"Open in Calendar",@"Afficher dans le calendrier",@"Add to Playing Next",@"Ajouter à la file d’attente",@"Clear Playing Next",@"Effacer la file d’attente",@"Find Giphy GIFs",@"Rechercher dans Giphy",@"Follow Podcast",@"S’abonner au podcast",@"Scan QR or Barcode",@"Scanner un code-barres ou QR",@"Scan QR or Barcode",@"Numériser le code-barres ou QR",@"Find App Store Apps",@"Rechercher dans l’App Store",@"Find iTunes Store Items",@"Rechercher dans l’iTunes Store",@"Find Places",@"Rechercher des commerces locaux",@"Find Podcasts",@"Rechercher des podcasts",@"Show Web View",@"Afficher la page web",@"Détecter la langue",@"Détecter la langue avec Microsoft",@"Arrêter ce raccourci",@"Arrêter le raccourci",@"Obtenir la page web actuelle de Safari",@"Obtenir l’URL actuelle de Safari",@"Changer de destination de lecture",@"Définir la destination pour la lecture",@"Translate Texte",@"Traduire le texte avec Microsoft",@"Définir le mode de concentration",@"Set Do Not Disturb",@"Get File from Dossier",@"Get Fichier",@"Arrêter ce raccourci",@"Exit Shortcut",@"Append to Text Fichier",@"Append to Fichier",@"Faire pivoter l’image ou la vidéo",@"Rotate Image",@"Ouvrir le fichier",@"Open In...",@"Partager avec des apps",@"Share with Extensions",nil];
//fr_CA (wip) [[NSDictionary alloc]initWithObjectsAndKeys:@"Get What’s On Screen",@"Obtenir ce qui est affiché à l’écran",@"Get What’s On Screen",@"Obtenir le contenu à l’écran",@"Open Reminders Liste",@"Show Reminders Liste",@"Open Directions",@"Afficher l’itinéraire",@"Open in Maps",@"Afficher dans Plans",@"Open in BlindSquare",@"Afficher dans BlindSquare",@"Open in Calendar",@"Afficher dans Calendrier",@"Add to Playing Next",@"Ajouter aux suivants",@"Clear Playing Next",@"Effacer la liste Suivants",@"Find Giphy GIFs",@"Rechercher dans Giphy",@"Follow Podcast",@"S’abonner au balado",@"Scan QR or Barcode",@"Numériser le code QR ou à barres",@"Scan QR or Barcode",@"Numériser le code QR ou à barres",@"Find App Store Apps",@"Rechercher dans l’App Store",@"Find iTunes Store Items",@"Rechercher dans l’iTunes Store",@"Find Places",@"Rechercher les entreprises locales",@"Find Podcasts",@"Rechercher des balados",@"Show Web View",@"Afficher la page Web",@"Détecter la langue",@"Détecter la langue avec Microsoft",@"Arrêter ce raccourci",@"Arrêter le raccourci",@"Obtenir la page Web actuelle de Safari",@"Obtenir l’URL actuelle de Safari",@"Modifier la destination de lecture",@"Définir la destination de lecture",@"Translate Texte",@"Traduire du texte avec Microsoft",@"Régler le mode de concentration",@"Set Do Not Disturb",@"Get File from Dossier",@"Get Fichier",@"Arrêter ce raccourci",@"Exit Shortcut",@"Append to Text Fichier",@"Append to Fichier",@"Faire pivoter l’image ou la vidéo",@"Rotate Image",@"Ouvrir le fichier",@"Open In...",@"Partager avec les apps",@"Share with Extensions",nil];
//es_419 (wip) [[NSDictionary alloc]initWithObjectsAndKeys:@"Get What’s On Screen",@"Recibir lo que se muestra en pantalla",@"Get What’s On Screen",@"Obtener contenido en pantalla",@"Open Reminders Crear lista",@"Show Reminders Crear lista",@"Open Directions",@"Mostrar ruta",@"Open in Maps",@"Mostrar en Mapas",@"Open in BlindSquare",@"Mostrar en BlindSquare",@"Open in Calendar",@"Mostrar en el calendario",@"Add to Playing Next",@"Agregar a “A continuación”",@"Clear Playing Next",@"Borrar “A continuación”",@"Find Giphy GIFs",@"Buscar en Giphy",@"Follow Podcast",@"Suscribirse a un podcast",@"Scan QR or Barcode",@"Escanear código QR o de barras",@"Scan QR or Barcode",@"Escanear código QR/barras",@"Find App Store Apps",@"Buscar en App Store",@"Find iTunes Store Items",@"Buscar en iTunes Store",@"Find Places",@"Buscar negocios locales",@"Find Podcasts",@"Buscar podcasts",@"Show Web View",@"Mostrar página web",@"Detectar idioma",@"Detectar idioma con Microsoft",@"Detener este atajo",@"Detener atajo",@"Obtener página actual de Safari",@"Obtener URL actual de Safari",@"Cambiar destino de reproducción",@"Configurar destino de la reproducción",@"Translate Texto",@"Traducir texto con Microsoft",@"Establecer enfoque",@"Set Do Not Disturb",@"Get File from Carpeta",@"Get Archivo",@"Detener este atajo",@"Exit Shortcut",@"Append to Text Archivo",@"Append to Archivo",@"Girar imagen/video",@"Rotate Image",@"Abrir archivo",@"Open In...",@"Compartir con apps",@"Share with Extensions",nil];
//ja (wip) [[NSDictionary alloc]initWithObjectsAndKeys:@"Get What’s On Screen",@"画面上のものを取得",@"Get What’s On Screen",@"画面上のコンテンツを取得",@"Open Reminders リスト",@"Show Reminders リスト",@"Open Directions",@"経路を表示",@"Open in Maps",@"“マップ”で表示",@"Open in BlindSquare",@"BlindSquareで表示",@"Open in Calendar",@"カレンダーに表示",@"Add to Playing Next",@"“次はこちら”に追加",@"Clear Playing Next",@"“次はこちら”を消去",@"Find Giphy GIFs",@"Giphyを検索",@"Follow Podcast",@"Podcastのサブスクリプションに登録",@"Scan QR or Barcode",@"QRまたはバーコードをスキャン",@"Scan QR or Barcode",@"QR/バーコードをスキャン",@"Find App Store Apps",@"App Storeで検索",@"Find iTunes Store Items",@"iTunes Storeを検索",@"Find Places",@"近くの店舗や企業を検索",@"Find Podcasts",@"Podcastを検索",@"Show Web View",@"Webページを表示",@"言語を検出",@"Microsoftで言語を検出",@"このショートカットを停止",@"ショートカットを停止",@"Safariから現在のWebページを取得",@"Safariから現在のURLを取得",@"再生出力先を変更",@"再生出力先を設定",@"Translate テキスト",@"Microsoftでテキストを翻訳",@"集中モードを設定",@"Set Do Not Disturb",@"Get File from フォルダ",@"Get ファイル",@"このショートカットを停止",@"Exit Shortcut",@"Append to Text ファイル",@"Append to ファイル",@"イメージ/ビデオを回転",@"Rotate Image",@"ファイルを開く",@"Open In...",@"Appで共有",@"Share with Extensions",nil];
//zh_CN (wip) [[NSDictionary alloc]initWithObjectsAndKeys:@"Get What’s On Screen",@"获取屏幕内容",@"Get What’s On Screen",@"获取屏幕上的内容",@"Open Reminders 列表",@"Show Reminders 列表",@"Open Directions",@"显示路线",@"Open in Maps",@"在地图中显示",@"Open in BlindSquare",@"在BlindSquare中显示",@"Open in Calendar",@"在日历中显示",@"Add to Playing Next",@"添加到待播清单",@"Clear Playing Next",@"清除待播清单",@"Find Giphy GIFs",@"在Giphy中搜索",@"Follow Podcast",@"订阅播客",@"Scan QR or Barcode",@"扫描二维码或条形码",@"Scan QR or Barcode",@"扫描二维码/条形码",@"Find App Store Apps",@"搜索App Store",@"Find iTunes Store Items",@"搜索iTunes Store",@"Find Places",@"搜索本地商户",@"Find Podcasts",@"搜索播客",@"Show Web View",@"显示网页",@"检测语言",@"使用Microsoft检测语言",@"停止执行此快捷指令",@"停止快捷指令",@"从Safari浏览器获取当前网页",@"从Safari浏览器中获取当前URL",@"更改播放位置",@"设定播放位置",@"Translate 文本",@"使用Microsoft翻译文本",@"设定专注模式",@"Set Do Not Disturb",@"Get File from 文件夹",@"Get 文件",@"停止执行此快捷指令",@"Exit Shortcut",@"Append to Text 文件",@"Append to 文件",@"旋转图像/视频",@"Rotate Image",@"打开文件",@"Open In...",@"与App共享",@"Share with Extensions",nil];
//zh_HK (wip) [[NSDictionary alloc]initWithObjectsAndKeys:@"Get What’s On Screen",@"取得螢幕內容",@"Get What’s On Screen",@"取得螢幕內容",@"Open Reminders 列表",@"Show Reminders 列表",@"Open Directions",@"顯示路線",@"Open in Maps",@"在「地圖」顯示",@"Open in BlindSquare",@"在BlindSquare顯示",@"Open in Calendar",@"在「日曆」顯示",@"Add to Playing Next",@"加至「待播清單」",@"Clear Playing Next",@"清除「待播清單」",@"Find Giphy GIFs",@"搜尋Giphy",@"Follow Podcast",@"訂閲Podcast",@"Scan QR or Barcode",@"掃描二維碼或條碼",@"Scan QR or Barcode",@"掃描二維碼/條碼",@"Find App Store Apps",@"搜尋App Store",@"Find iTunes Store Items",@"搜尋iTunes Store",@"Find Places",@"搜尋本地商店",@"Find Podcasts",@"搜尋Podcast",@"Show Web View",@"顯示網頁",@"偵測語言",@"使用Microsoft偵測語言",@"停止此捷徑",@"停止捷徑",@"從Safari取得目前網頁",@"取得Safari現時的URL",@"更改播放位置",@"設定播放位置",@"Translate 文字",@"使用Microsoft翻譯文字",@"設定專注模式",@"Set Do Not Disturb",@"Get File from 資料夾",@"Get 檔案",@"停止此捷徑",@"Exit Shortcut",@"Append to Text 檔案",@"Append to 檔案",@"旋轉影像/影片",@"Rotate Image",@"開啟檔案",@"Open In...",@"使用App分享",@"Share with Extensions",nil];
//zh_TW (wip) [[NSDictionary alloc]initWithObjectsAndKeys:@"Get What’s On Screen",@"取得螢幕上的內容",@"Get What’s On Screen",@"取得螢幕上的內容",@"Open Reminders 列表",@"Show Reminders 列表",@"Open Directions",@"顯示路線",@"Open in Maps",@"顯示於地圖",@"Open in BlindSquare",@"顯示於BlindSquare",@"Open in Calendar",@"顯示於行事曆",@"Add to Playing Next",@"加入待播清單",@"Clear Playing Next",@"清除待播清單",@"Find Giphy GIFs",@"搜尋Giphy",@"Follow Podcast",@"訂閱Podcast",@"Scan QR or Barcode",@"掃描行動條碼或條碼",@"Scan QR or Barcode",@"掃描行動條碼/條碼",@"Find App Store Apps",@"搜尋App Store",@"Find iTunes Store Items",@"搜尋iTunes Store",@"Find Places",@"搜尋本地商家",@"Find Podcasts",@"搜尋Podcast",@"Show Web View",@"顯示網頁",@"偵測語言",@"刪除Microsoft語言",@"停止此捷徑",@"停止捷徑",@"取得Safari目前的網頁",@"從Safari取得目前的URL",@"更改播放位置",@"設定播放位置",@"Translate 文字",@"使用Microsoft轉譯文字",@"設定專注模式",@"Set Do Not Disturb",@"Get File from 檔案夾",@"Get 檔案",@"停止此捷徑",@"Exit Shortcut",@"Append to Text 檔案",@"Append to 檔案",@"旋轉影像/影片",@"Rotate Image",@"打開檔案",@"Open In...",@"與App分享",@"Share with Extensions",nil];
//de (wip) [[NSDictionary alloc]initWithObjectsAndKeys:@"Get What’s On Screen",@"Bildschirminhalt erhalten",@"Get What’s On Screen",@"Bildschirminhalt abrufen",@"Open Reminders Liste",@"Show Reminders Liste",@"Open Directions",@"Route einblenden",@"Open in Maps",@"In einer Karten-App anzeigen",@"Open in BlindSquare",@"In BlindSquare anzeigen",@"Open in Calendar",@"Im Kalender anzeigen",@"Add to Playing Next",@"Zu „Als Nächstes“ hinzufügen",@"Clear Playing Next",@"„Als Nächstes“ löschen",@"Find Giphy GIFs",@"In Giphy suchen",@"Follow Podcast",@"Podcast abonnieren",@"Scan QR or Barcode",@"QR- oder Strichcode scannen",@"Scan QR or Barcode",@"QR-/Balkencode scannen",@"Find App Store Apps",@"Im App Store suchen",@"Find iTunes Store Items",@"Im iTunes Store suchen",@"Find Places",@"Lokale Betriebe suchen",@"Find Podcasts",@"Podcasts suchen",@"Show Web View",@"Webseite anzeigen",@"Sprache erkennen",@"Spracherkennung mit Microsoft",@"Kurzbefehl stoppen",@"Kurzbefehl stoppen",@"Aktuelle Webseite von Safari aufrufen",@"Aktuelle URL von Safari abrufen",@"Wiedergabeziel ändern",@"Wiedergabeziel festlegen",@"Translate Text",@"Textübersetzung mit Microsoft",@"Fokus festlegen",@"Set Do Not Disturb",@"Get File from Ordner",@"Get Datei",@"Kurzbefehl stoppen",@"Exit Shortcut",@"Append to Text Datei",@"Append to Datei",@"Bild/Video drehen",@"Rotate Image",@"Datei öffnen",@"Open In...",@"Mit Apps teilen",@"Share with Extensions",nil];
//nl (wip) [[NSDictionary alloc]initWithObjectsAndKeys:@"Get What’s On Screen",@"Haal op wat er op het scherm te zien is",@"Get What’s On Screen",@"Haal scherm­inhoud op",@"Open Reminders Lijst",@"Show Reminders Lijst",@"Open Directions",@"Toon route",@"Open in Maps",@"Toon op kaart",@"Open in BlindSquare",@"Toon in BlindSquare",@"Open in Calendar",@"Toon in agenda",@"Add to Playing Next",@"Zet in 'Volgende'",@"Clear Playing Next",@"Wis 'Volgende'",@"Find Giphy GIFs",@"Zoek in Giphy",@"Follow Podcast",@"Abonneren op podcast",@"Scan QR or Barcode",@"Scan QR- of streepjescode",@"Scan QR or Barcode",@"Scan QR-/streepjescode",@"Find App Store Apps",@"Zoek in App Store",@"Find iTunes Store Items",@"Zoek in iTunes Store",@"Find Places",@"Zoek lokale bedrijven",@"Find Podcasts",@"Zoek podcasts",@"Show Web View",@"Toon webpagina",@"Detecteer taal",@"Detecteer taal met Microsoft",@"Stop deze opdracht",@"Stop opdracht",@"Haal huidige webpagina op uit Safari",@"Haal huidige URL uit Safari op",@"Wijzig afspeelbestemming",@"Stel afspeelbestemming in",@"Translate Tekst",@"Vertaal tekst met Microsoft",@"Stel focus in",@"Set Do Not Disturb",@"Get File from Map",@"Get Bestand",@"Stop deze opdracht",@"Exit Shortcut",@"Append to Text Bestand",@"Append to Bestand",@"Roteer afbeelding/video",@"Rotate Image",@"Open bestand",@"Open In...",@"Deel met apps",@"Share with Extensions",nil];
//da (wip) [[NSDictionary alloc]initWithObjectsAndKeys:@"Get What’s On Screen",@"Få det, der vises på skærmen",@"Get What’s On Screen",@"Hent indholdet på skærmen",@"Open Reminders Liste",@"Show Reminders Liste",@"Open Directions",@"Vis vej",@"Open in Maps",@"Vis i Kort",@"Open in BlindSquare",@"Vis i BlindSquare",@"Open in Calendar",@"Vis i Kalender",@"Add to Playing Next",@"Føj til Kø",@"Clear Playing Next",@"Ryd Kø",@"Find Giphy GIFs",@"Søg i Giphy",@"Follow Podcast",@"Abonner på podcast",@"Scan QR or Barcode",@"Scan QR- eller stregkode",@"Scan QR or Barcode",@"Scan QR-/stregkode",@"Find App Store Apps",@"Søg i App Store",@"Find iTunes Store Items",@"Søg i iTunes Store",@"Find Places",@"Søg efter lokale virksomheder",@"Find Podcasts",@"Søg efter podcasts",@"Show Web View",@"Vis webside",@"Registrer sprog",@"Find sprog med Microsoft",@"Stop denne genvej",@"Stop genvej",@"Hent aktuel webside fra Safari",@"Hent aktuel URL-adresse fra Safari",@"Skift afspilningsenhed",@"Vælg afspilningsenhed",@"Translate Tekst",@"Oversæt tekst med Microsoft",@"Indstil fokusfunktion",@"Set Do Not Disturb",@"Get File from Mappe",@"Get Arkiv",@"Stop denne genvej",@"Exit Shortcut",@"Append to Text Arkiv",@"Append to Arkiv",@"Roter billede/video",@"Rotate Image",@"Åbn arkiv",@"Open In...",@"Del med apps",@"Share with Extensions",nil];
//ar (wip) [[NSDictionary alloc]initWithObjectsAndKeys:@"Get What’s On Screen",@"إحضار ما على الشاشة",@"Get What’s On Screen",@"إحضار المحتوى الذي يظهر على الشاشة",@"Open Reminders قائمة",@"Show Reminders قائمة",@"Open Directions",@"إظهار الاتجاهات",@"Open in Maps",@"إظهار في الخرائط",@"Open in BlindSquare",@"إظهار في BlindSquare",@"Open in Calendar",@"إظهار في التقويم",@"Add to Playing Next",@"إضافة إلى "التالي"",@"Clear Playing Next",@"مسح التالي",@"Find Giphy GIFs",@"بحث في Giphy",@"Follow Podcast",@"اشتراك في البودكاست",@"Scan QR or Barcode",@"مسح ضوئي لرمز QR أو رمز شريطي",@"Scan QR or Barcode",@"مسح ضوئي لرمز QR/رمز شريطي",@"Find App Store Apps",@"بحث في App Store",@"Find iTunes Store Items",@"بحث في iTunes Store",@"Find Places",@"بحث عن الأعمال التجارية المحلية",@"Find Podcasts",@"بحث في البودكاست",@"Show Web View",@"إظهار صفحة الويب",@"اكتشاف اللغة",@"اكتشاف اللغة باستخدام Microsoft",@"إيقاف هذا الاختصار",@"إيقاف الاختصار",@"إحضار صفحة الويب الحالية من Safari",@"إحضار الرابط الحالي من Safari",@"تغيير وجهة التشغيل",@"تعيين وجهة التشغيل",@"Translate نص",@"ترجمة النص باستخدام Microsoft",@"تعيين التركيز",@"Set Do Not Disturb",@"Get File from مجلد",@"Get ملف",@"إيقاف هذا الاختصار",@"Exit Shortcut",@"Append to Text ملف",@"Append to ملف",@"تدوير الصورة/الفيديو",@"Rotate Image",@"فتح ملف",@"Open In...",@"مشاركة مع التطبيقات",@"Share with Extensions",nil];
//hi (wip) [[NSDictionary alloc]initWithObjectsAndKeys:@"Get What’s On Screen",@"स्क्रीन पर मौजूद आइटम प्राप्त करें",@"Get What’s On Screen",@"ऑन-स्क्रीन कॉन्टेंट प्राप्त करें",@"Open Reminders सूची",@"Show Reminders सूची",@"Open Directions",@"दिशानिर्देश दिखाएँ",@"Open in Maps",@"नक़्शा में दिखाएँ",@"Open in BlindSquare",@"BlindSquare में दिखाएँ",@"Open in Calendar",@"कैलेंडर में दिखाएँ",@"Add to Playing Next",@"आगामी में जोड़ें",@"Clear Playing Next",@"“आगामी” को साफ़ करें",@"Find Giphy GIFs",@"Giphy खोजें",@"Follow Podcast",@"पॉडकास्ट के लिए सब्सक्राइब करें",@"Scan QR or Barcode",@"QR या बार कोड स्कैन करें",@"Scan QR or Barcode",@"QR/बार कोड स्कैन करें",@"Find App Store Apps",@"App Store में खोजें",@"Find iTunes Store Items",@"iTunes Store में खोजें",@"Find Places",@"स्थानीय व्यवसाय खोजें",@"Find Podcasts",@"पॉडकास्ट खोजें",@"Show Web View",@"वेब पृष्ठ दिखाएँ",@"भाषा का पता लगाएँ",@"Microsoft के साथ भाषा का पता लगाएँ",@"यह शॉर्टकट रोकें",@"शॉर्टकट रोकें",@"Safari से वर्तमान वेब पृष्ठ प्राप्त करें",@"Safari से वर्तमान URL प्राप्त करें",@"प्लेबैक गंतव्य बदलें",@"प्लेबैक गंतव्य सेट करें",@"Translate टेक्स्ट",@"Microsoft के साथ टेक्स्ट का अनुवाद करें",@"फ़ोकस सेट करें",@"Set Do Not Disturb",@"Get File from फ़ोल्डर",@"Get फ़ाइल",@"यह शॉर्टकट रोकें",@"Exit Shortcut",@"Append to Text फ़ाइल",@"Append to फ़ाइल",@"इमेज/वीडियो को घुमाता है",@"Rotate Image",@"फ़ाइल खोलें",@"Open In...",@"ऐप्स के साथ शेयर करें",@"Share with Extensions",nil];
//pt (wip) [[NSDictionary alloc]initWithObjectsAndKeys:@"Get What’s On Screen",@"Receba o que Está na Tela",@"Get What’s On Screen",@"Obter Conteúdo na Tela",@"Open Reminders Lista",@"Show Reminders Lista",@"Open Directions",@"Mostrar Itinerários",@"Open in Maps",@"Mostrar no Mapa",@"Open in BlindSquare",@"Mostrar no BlindSquare",@"Open in Calendar",@"Mostrar no Calendário",@"Add to Playing Next",@"Adicionar a Seguintes",@"Clear Playing Next",@"Limpar Seguintes",@"Find Giphy GIFs",@"Buscar no Giphy",@"Follow Podcast",@"Assinar Podcast",@"Scan QR or Barcode",@"Escanear Código de Barras ou QR",@"Scan QR or Barcode",@"Escanear Código de Barras/QR",@"Find App Store Apps",@"Buscar na App Store",@"Find iTunes Store Items",@"Buscar na iTunes Store",@"Find Places",@"Buscar Empresas Locais",@"Find Podcasts",@"Buscar Podcasts",@"Show Web View",@"Mostrar Página Web",@"Detectar Idioma",@"Detectar Idioma com a Microsoft",@"Parar Este Atalho",@"Parar Atalho",@"Obter Página Web Atual do Safari",@"Obter URL Atual do Safari",@"Alterar Destino de Reprodução",@"Definir Destino de Reprodução",@"Translate Texto",@"Traduzir Texto com a Microsoft",@"Definir Foco",@"Set Do Not Disturb",@"Get File from Pasta",@"Get Arquivo",@"Parar Este Atalho",@"Exit Shortcut",@"Append to Text Arquivo",@"Append to Arquivo",@"Girar Imagem/Vídeo",@"Rotate Image",@"Abrir Arquivo",@"Open In...",@"Compartilhar com Apps",@"Share with Extensions",nil];
//ru (wip) [[NSDictionary alloc]initWithObjectsAndKeys:@"Get What’s On Screen",@"Получить контент на экране",@"Get What’s On Screen",@"Получить отображаемый на экране контент",@"Open Reminders Список",@"Show Reminders Список",@"Open Directions",@"Показать маршруты",@"Open in Maps",@"Показать на карте",@"Open in BlindSquare",@"Показать в BlindSquare",@"Open in Calendar",@"Показать в Календаре",@"Add to Playing Next",@"Добавить в список «На очереди»",@"Clear Playing Next",@"Очистить список «На очереди»",@"Find Giphy GIFs",@"Искать в Giphy",@"Follow Podcast",@"Подписка на подкаст",@"Scan QR or Barcode",@"Сканировать QR‑код или штрихкод",@"Scan QR or Barcode",@"Сканировать QR‑код/штрихкод",@"Find App Store Apps",@"Искать в App Store",@"Find iTunes Store Items",@"Искать в iTunes Store",@"Find Places",@"Искать компании поблизости",@"Find Podcasts",@"Поиск подкастов",@"Show Web View",@"Показать веб-страницу",@"Распознать язык",@"Распознать язык (Microsoft)",@"Остановить эту быструю команду",@"Остановить быструю команду",@"Получить ссылку на текущую веб‑страницу от Safari",@"Получить текущий URL‑адрес из Safari",@"Изменить место воспроизведения",@"Задать место воспроизведения",@"Translate Отправить сообщение",@"Перевести текст (Microsoft)",@"Вкл./выкл. фокусирование",@"Set Do Not Disturb",@"Get File from Папка",@"Get Файл",@"Остановить эту быструю команду",@"Exit Shortcut",@"Append to Text Файл",@"Append to Файл",@"Повернуть изображение или видео",@"Rotate Image",@"Открыть файл",@"Open In...",@"Поделиться через приложения",@"Share with Extensions",nil];
//uk (wip) [[NSDictionary alloc]initWithObjectsAndKeys:@"Get What’s On Screen",@"Отримати інформацію про елементи на екрані",@"Get What’s On Screen",@"Отримати вміст на екрані",@"Open Reminders Подати списком",@"Show Reminders Подати списком",@"Open Directions",@"Показати маршрут",@"Open in Maps",@"Показати на карті",@"Open in BlindSquare",@"Показати в BlindSquare",@"Open in Calendar",@"Показати в календарі",@"Add to Playing Next",@"Додати до списку «На черзі»",@"Clear Playing Next",@"Очистити чергу",@"Find Giphy GIFs",@"Шукати Giphy",@"Follow Podcast",@"Підписатися на подкаст",@"Scan QR or Barcode",@"Відсканувати QR-код або штрихкод",@"Scan QR or Barcode",@"Сканувати QR/штрихкод",@"Find App Store Apps",@"Шукати в App Store",@"Find iTunes Store Items",@"Шукати в iTunes Store",@"Find Places",@"Шукати місцеві компанії",@"Find Podcasts",@"Шукати у подкастах",@"Show Web View",@"Показати вебсторінку",@"Визначити мову",@"Виявити мову через Microsoft",@"Зупинити цю швидку команду",@"Зупинити швидку команду",@"Отримати поточну вебсторінку із Safari",@"Отримати поточну URL‑адресу із Safari",@"Змінити пристрій відтворення",@"Задати пристрій відтворення",@"Translate Текст",@"Перекласти текст через Microsoft",@"Задати режим зосередження",@"Set Do Not Disturb",@"Get File from Папка",@"Get Файл",@"Зупинити цю швидку команду",@"Exit Shortcut",@"Append to Text Файл",@"Append to Файл",@"Повернути зображення чи відео",@"Rotate Image",@"Відкрити файл",@"Open In...",@"Поширити для програм",@"Share with Extensions",nil];
//ko (wip) [[NSDictionary alloc]initWithObjectsAndKeys:@"Get What’s On Screen",@"화면상에 표시되는 항목 가져오기",@"Get What’s On Screen",@"화면상의 콘텐츠 가져오기",@"Open Reminders 목록",@"Show Reminders 목록",@"Open Directions",@"경로 보기",@"Open in Maps",@"지도에서 보기",@"Open in BlindSquare",@"BlindSquare에서 보기",@"Open in Calendar",@"캘린더에서 보기",@"Add to Playing Next",@"재생 대기 목록에 추가",@"Clear Playing Next",@"재생 대기 목록 지우기",@"Find Giphy GIFs",@"Giphy 검색",@"Follow Podcast",@"팟캐스트 구독",@"Scan QR or Barcode",@"QR 코드 또는 바코드 스캔",@"Scan QR or Barcode",@"QR 코드/바코드 스캔",@"Find App Store Apps",@"App Store 검색",@"Find iTunes Store Items",@"iTunes Store 검색",@"Find Places",@"근처 업체 검색",@"Find Podcasts",@"팟캐스트 검색",@"Show Web View",@"웹 페이지 보기",@"언어 감지",@"Microsoft로 언어 감지",@"이 단축어 중단",@"단축어 중단",@"Safari에서 현재 웹 페이지 가져오기",@"Safari에서 현재의 URL 가져오기",@"재생 대상 변경",@"재생 대상 설정",@"Translate 텍스트",@"Microsoft로 텍스트 번역",@"집중 모드 설정",@"Set Do Not Disturb",@"Get File from 폴더",@"Get 파일",@"이 단축어 중단",@"Exit Shortcut",@"Append to Text 파일",@"Append to 파일",@"이미지/비디오 회전",@"Rotate Image",@"파일 열기",@"Open In...",@"앱과 공유",@"Share with Extensions",nil];
//pl (wip) [[NSDictionary alloc]initWithObjectsAndKeys:@"Get What’s On Screen",@"Pobierz zawartość ekranu",@"Get What’s On Screen",@"Pobierz zawartość ekranu",@"Open Reminders Lista",@"Show Reminders Lista",@"Open Directions",@"Pokaż trasę",@"Open in Maps",@"Pokaż na mapie",@"Open in BlindSquare",@"Pokaż w aplikacji BlindSquare",@"Open in Calendar",@"Pokaż w kalendarzu",@"Add to Playing Next",@"Dodaj do następnych",@"Clear Playing Next",@"Wymaż następne",@"Find Giphy GIFs",@"Szukaj w Giphy",@"Follow Podcast",@"Subskrypcja podcastu",@"Scan QR or Barcode",@"Skanuj kod QR lub kod paskowy",@"Scan QR or Barcode",@"Skanuj kod QR/kod paskowy",@"Find App Store Apps",@"Szukaj w App Store",@"Find iTunes Store Items",@"Przeszukaj iTunes Store",@"Find Places",@"Szukaj lokalnych firm",@"Find Podcasts",@"Szukaj",@"Show Web View",@"Pokaż stronę www",@"Wykryj język",@"Wykryj język (Microsoft)",@"Zatrzymaj ten skrót",@"Zatrzymaj skrót",@"Pobierz bieżącą stronę www z Safari",@"Pobierz bieżący URL z Safari",@"Zmień wyjście odtwarzania",@"Ustaw wyjście odtwarzania",@"Translate Tekst",@"Przetłumacz tekst (Microsoft)",@"Ustaw tryb skupienia",@"Set Do Not Disturb",@"Get File from Folder",@"Get Plik",@"Zatrzymaj ten skrót",@"Exit Shortcut",@"Append to Text Plik",@"Append to Plik",@"Obróć obrazek/wideo",@"Rotate Image",@"Otwórz plik",@"Open In...",@"Udostępnij aplikacjom",@"Share with Extensions",nil];
//id (wip) [[NSDictionary alloc]initWithObjectsAndKeys:@"Get What’s On Screen",@"Dapatkan Apa yang Ada Pada Layar",@"Get What’s On Screen",@"Dapatkan Konten Pada Layar",@"Open Reminders Daftar",@"Show Reminders Daftar",@"Open Directions",@"Tampilkan Petunjuk Arah",@"Open in Maps",@"Tampilkan di Peta",@"Open in BlindSquare",@"Tampilkan di BlindSquare",@"Open in Calendar",@"Tampilkan di Kalender",@"Add to Playing Next",@"Tambahkan ke Berikutnya",@"Clear Playing Next",@"Bersihkan Berikutnya",@"Find Giphy GIFs",@"Cari di Giphy",@"Follow Podcast",@"Berlangganan ke Podcast",@"Scan QR or Barcode",@"Pindai Kode QR atau Bar",@"Scan QR or Barcode",@"Pindai Kode QR/Bar",@"Find App Store Apps",@"Cari di App Store",@"Find iTunes Store Items",@"Cari di iTunes Store",@"Find Places",@"Cari Bisnis Lokal",@"Find Podcasts",@"Cari Podcast",@"Show Web View",@"Tampilkan Halaman Web",@"Deteksi Bahasa",@"Deteksi Bahasa dengan Microsoft",@"Hentikan Pintasan Ini",@"Hentikan Pintasan",@"Dapatkan Halaman Web Saat Ini dari Safari",@"Dapatkan URL Saat Ini dari Safari",@"Ubah Tujuan Pemutaran",@"Atur Tujuan Pemutaran",@"Translate Teks",@"Terjemahkan Teks dengan Microsoft",@"Atur Fokus",@"Set Do Not Disturb",@"Get File from Folder",@"Get File",@"Hentikan Pintasan Ini",@"Exit Shortcut",@"Append to Text File",@"Append to File",@"Putar Gambar/Video",@"Rotate Image",@"Buka File",@"Open In...",@"Bagikan dengan App",@"Share with Extensions",nil];
//it (wip) [[NSDictionary alloc]initWithObjectsAndKeys:@"Get What’s On Screen",@"Ottieni contenuti sullo schermo",@"Get What’s On Screen",@"Ottieni contenuto sullo schermo",@"Open Reminders Elenco",@"Show Reminders Elenco",@"Open Directions",@"Mostra indicazioni",@"Open in Maps",@"Mostra in Mappe",@"Open in BlindSquare",@"Mostra su BlindSquare",@"Open in Calendar",@"Mostra in Calendario",@"Add to Playing Next",@"Aggiungi in coda",@"Clear Playing Next",@"Cancella coda",@"Find Giphy GIFs",@"Cerca su Giphy",@"Follow Podcast",@"Iscriviti al podcast",@"Scan QR or Barcode",@"Scansiona codice a barre o QR",@"Scan QR or Barcode",@"Scansiona il codice a barre/QR",@"Find App Store Apps",@"Cerca su App Store",@"Find iTunes Store Items",@"Cerca su iTunes Store",@"Find Places",@"Cerca attività commerciali locali",@"Find Podcasts",@"Cerca podcast",@"Show Web View",@"Mostra pagina web",@"Rileva lingua",@"Rileva lingua con Microsoft",@"Interrompi comando rapido",@"Interrompi comando rapido",@"Ottieni la pagina web attuale da Safari",@"Ottieni URL attuale da Safari",@"Cambia destinazione di riproduzione",@"Imposta la destinazione di riproduzione",@"Translate Testo",@"Traduci il testo con Microsoft",@"Imposta full immersion",@"Set Do Not Disturb",@"Get File from Cartella",@"Get File",@"Interrompi comando rapido",@"Exit Shortcut",@"Append to Text File",@"Append to File",@"Ruota immagine/video",@"Rotate Image",@"Apri file",@"Open In...",@"Condividi con app",@"Share with Extensions",nil];
//ms (wip) [[NSDictionary alloc]initWithObjectsAndKeys:@"Get What’s On Screen",@"Dapatkan Kandungan Skrin",@"Get What’s On Screen",@"Dapatkan Kandungan Pada Skrin",@"Open Reminders Senarai",@"Show Reminders Senarai",@"Open Directions",@"Tunjukkan Arah",@"Open in Maps",@"Tunjukkan dalam Peta",@"Open in BlindSquare",@"Tunjukkan dalam BlindSquare",@"Open in Calendar",@"Tunjukkan dalam Kalendar",@"Add to Playing Next",@"Tambah ke Seterusnya",@"Clear Playing Next",@"Kosongkan Seterusnya",@"Find Giphy GIFs",@"Cari dalam Giphy",@"Follow Podcast",@"Langgan Podcast",@"Scan QR or Barcode",@"Imbas Kod QR atau Bar",@"Scan QR or Barcode",@"Imbas Kod QR/Bar",@"Find App Store Apps",@"Cari dalam App Store",@"Find iTunes Store Items",@"Cari dalam iTunes Store",@"Find Places",@"Cari Perniagaan Tempatan",@"Find Podcasts",@"Cari Podcast",@"Show Web View",@"Tunjukkan Halaman Web",@"Kesan Bahasa",@"Kesan Bahasa dengan Microsoft",@"Hentikan Pintasan Ini",@"Hentikan Pintasan",@"Dapatkan Halaman Web Semasa daripada Safari",@"Dapatkan URL Semasa daripada Safari",@"Tukar Destinasi Main Balik",@"Setkan Destinasi Main Balik",@"Translate Teks",@"Terjemahkan Teks dengan Microsoft",@"Setkan Fokus",@"Set Do Not Disturb",@"Get File from Folder",@"Get Fail",@"Hentikan Pintasan Ini",@"Exit Shortcut",@"Append to Text Fail",@"Append to Fail",@"Putar Imej/Video",@"Rotate Image",@"Buka Fail",@"Open In...",@"Kongsi dengan App",@"Share with Extensions",nil];
//vi (wip) [[NSDictionary alloc]initWithObjectsAndKeys:@"Get What’s On Screen",@"Nhận nội dung trên màn hình",@"Get What’s On Screen",@"Lấy nội dung trên màn hình",@"Open Reminders Danh sách",@"Show Reminders Danh sách",@"Open Directions",@"Hiển thị chỉ đường",@"Open in Maps",@"Hiển thị trong Bản đồ",@"Open in BlindSquare",@"Hiển thị trong BlindSquare",@"Open in Calendar",@"Hiển thị trong Lịch",@"Add to Playing Next",@"Thêm vào Tiếp theo",@"Clear Playing Next",@"Xóa Tiếp theo",@"Find Giphy GIFs",@"Tìm kiếm trong Giphy",@"Follow Podcast",@"Đăng ký vào Podcast",@"Scan QR or Barcode",@"Quét mã QR hoặc mã vạch",@"Scan QR or Barcode",@"Quét mã QR/vạch",@"Find App Store Apps",@"Tìm kiếm trong App Store",@"Find iTunes Store Items",@"Tìm kiếm trong iTunes Store",@"Find Places",@"Tìm kiếm doanh nghiệp địa phương",@"Find Podcasts",@"Tìm Podcast",@"Show Web View",@"Hiển thị Trang web",@"Phát hiện ngôn ngữ",@"Phát hiện ngôn ngữ với Microsoft",@"Dừng phím tắt này",@"Dừng phím tắt",@"Lấy trang web hiện tại từ Safari",@"Lấy URL hiện tại từ Safari",@"Thay đổi đích phát lại",@"Đặt đích phát lại",@"Translate Văn bản",@"Dịch văn bản bằng Microsoft",@"Đặt chế độ Tập trung",@"Set Do Not Disturb",@"Get File from Thư mục",@"Get Tệp",@"Dừng phím tắt này",@"Exit Shortcut",@"Append to Text Tệp",@"Append to Tệp",@"Xoay hình ảnh/video",@"Rotate Image",@"Mở Tệp",@"Open In...",@"Chia sẻ với ứng dụng",@"Share with Extensions",nil];
//no (wip) [[NSDictionary alloc]initWithObjectsAndKeys:@"Get What’s On Screen",@"Hent innholdet på skjermen",@"Get What’s On Screen",@"Hent innholdet på skjermen",@"Open Reminders Liste",@"Show Reminders Liste",@"Open Directions",@"Vis veibeskrivelse",@"Open in Maps",@"Vis i Kart",@"Open in BlindSquare",@"Vis i BlindSquare",@"Open in Calendar",@"Vis i Kalender",@"Add to Playing Next",@"Legg til i Neste",@"Clear Playing Next",@"Tøm Neste",@"Find Giphy GIFs",@"Søk i Giphy",@"Follow Podcast",@"Abonner på podkast",@"Scan QR or Barcode",@"Skann QR- eller strekkode",@"Scan QR or Barcode",@"Skann QR-/strekkode",@"Find App Store Apps",@"Søk i App Store",@"Find iTunes Store Items",@"Søk i iTunes Store",@"Find Places",@"Søk etter lokale bedrifter",@"Find Podcasts",@"Søk etter podkaster",@"Show Web View",@"Vis nettside",@"Fastslå språk",@"Fastslå språk med Microsoft",@"Stopp denne snarveien",@"Stopp snarvei",@"Hent gjeldende nettside fra Safari",@"Hent nåværende URL fra Safari",@"Endre avspillingsmål",@"Angi avspillingsenhet",@"Translate Tekst",@"Oversett tekst med Microsoft",@"Angi fokus",@"Set Do Not Disturb",@"Get File from Mappe",@"Get Fil",@"Stopp denne snarveien",@"Exit Shortcut",@"Append to Text Fil",@"Append to Fil",@"Roter bilde/video",@"Rotate Image",@"Åpne fil",@"Open In...",@"Del med apper",@"Share with Extensions",nil];
//sv (wip) [[NSDictionary alloc]initWithObjectsAndKeys:@"Get What’s On Screen",@"Hämta det som visas på skärmen",@"Get What’s On Screen",@"Hämta innehåll på skärmen",@"Open Reminders Lista",@"Show Reminders Lista",@"Open Directions",@"Visa färdbeskrivning",@"Open in Maps",@"Visa i Kartor",@"Open in BlindSquare",@"Visa i BlindSquare",@"Open in Calendar",@"Visa i Kalender",@"Add to Playing Next",@"Lägg till i Nästa",@"Clear Playing Next",@"Rensa Nästa",@"Find Giphy GIFs",@"Sök i Giphy",@"Follow Podcast",@"Prenumerera på podcast",@"Scan QR or Barcode",@"Skanna QR- eller streckkod",@"Scan QR or Barcode",@"Skanna QR-/streckkod",@"Find App Store Apps",@"Sök i App Store",@"Find iTunes Store Items",@"Sök i iTunes Store",@"Find Places",@"Sök i lokala företag",@"Find Podcasts",@"Sök efter podcaster",@"Show Web View",@"Visa webbsida",@"Upptäck språk",@"Upptäck språk med Microsoft",@"Stoppa den här genvägen",@"Stoppa genväg",@"Hämta aktuell webbsida från Safari",@"Hämta aktuell URL från Safari",@"Ändra uppspelningsmålplats",@"Ställ in uppspelningsmålplats",@"Translate Text",@"Översätt text med Microsoft",@"Ställ in fokus",@"Set Do Not Disturb",@"Get File from Mapp",@"Get Fil",@"Stoppa den här genvägen",@"Exit Shortcut",@"Append to Text Fil",@"Append to Fil",@"Rotera bild/video",@"Rotate Image",@"Öppna fil",@"Open In...",@"Dela med appar",@"Share with Extensions",nil];
//fi (wip) [[NSDictionary alloc]initWithObjectsAndKeys:@"Get What’s On Screen",@"Hae näytön sisältö",@"Get What’s On Screen",@"Hae näytön sisältö",@"Open Reminders Luettelo",@"Show Reminders Luettelo",@"Open Directions",@"Näytä reittiohjeet",@"Open in Maps",@"Näytä kartta-apissa",@"Open in BlindSquare",@"Näytä BlindSquaressa",@"Open in Calendar",@"Näytä kalenterissa",@"Add to Playing Next",@"Lisää Seuraavaksi-listalle",@"Clear Playing Next",@"Tyhjennä Seuraavaksi-lista",@"Find Giphy GIFs",@"Etsi Giphystä",@"Follow Podcast",@"Tilaa podcast",@"Scan QR or Barcode",@"Skannaa QR- tai viivakoodi",@"Scan QR or Barcode",@"Skannaa QR- tai viivakoodi",@"Find App Store Apps",@"Etsi App Storesta",@"Find iTunes Store Items",@"Etsi iTunes Storesta",@"Find Places",@"Etsi paikallisia yrityksiä",@"Find Podcasts",@"Etsi podcasteista",@"Show Web View",@"Näytä verkkosivu",@"Tunnista kieli",@"Tunnista kieli Microsoftin avulla",@"Lopeta tämä pikakomento",@"Lopeta pikakomento",@"Hae nykyinen verkkosivu Safarista",@"Hae nykyinen URL Safarista",@"Vaihda toistolaite",@"Aseta toistolaite",@"Translate Teksti",@"Käännä tekstiä Microsoftin avulla",@"Aseta Keskity-tila",@"Set Do Not Disturb",@"Get File from Kansio",@"Get Tiedosto",@"Lopeta tämä pikakomento",@"Exit Shortcut",@"Append to Text Tiedosto",@"Append to Tiedosto",@"Pyöritä kuvaa/videota",@"Rotate Image",@"Avaa tiedosto",@"Open In...",@"Jaa appien kanssa",@"Share with Extensions",nil];
//tr (wip) [[NSDictionary alloc]initWithObjectsAndKeys:@"Get What’s On Screen",@"Ekrandakileri Al",@"Get What’s On Screen",@"Ekran İçeriğini Al",@"Open Reminders Liste",@"Show Reminders Liste",@"Open Directions",@"Yol Tarifini Göster",@"Open in Maps",@"Haritada Göster",@"Open in BlindSquare",@"BlindSquare’de Göster",@"Open in Calendar",@"Takvim’de Göster",@"Add to Playing Next",@"Sıradaki’ne Ekle",@"Clear Playing Next",@"Sıradaki Listesini Temizle",@"Find Giphy GIFs",@"Giphy Ara",@"Follow Podcast",@"Podcast’e Abone Ol",@"Scan QR or Barcode",@"QR Kodunu veya Barkodu Tara",@"Scan QR or Barcode",@"QR Kodunu/Barkodu Tara",@"Find App Store Apps",@"App Store’da Ara",@"Find iTunes Store Items",@"iTunes Store’da Ara",@"Find Places",@"Yerel İşletmeleri Ara",@"Find Podcasts",@"Podcast’lerde Ara",@"Show Web View",@"Web Sayfasını Göster",@"Dili Algıla",@"Microsoft ile Dili Algıla",@"Bu Kestirmeyi Durdur",@"Kestirmeyi Durdur",@"Safari’den Şu Anki Web Sayfasını Al",@"Safari’de Şu An Görüntülenen URL’yi Al",@"Çalma Hedefini Değiştir",@"Çalma Hedefini Ayarla",@"Translate Metin",@"Metni Microsoft ile Çevir",@"Odağı Ayarla",@"Set Do Not Disturb",@"Get File from Klasör",@"Get Dosya",@"Bu Kestirmeyi Durdur",@"Exit Shortcut",@"Append to Text Dosya",@"Append to Dosya",@"Görüntüyü/Videoyu Döndür",@"Rotate Image",@"Dosyayı Aç",@"Open In...",@"Uygulamalar ile Paylaş",@"Share with Extensions",nil];
//th (wip) [[NSDictionary alloc]initWithObjectsAndKeys:@"Get What’s On Screen",@"รับสิ่งที่อยู่บนหน้าจอ",@"Get What’s On Screen",@"รับเนื้อหาบนหน้าจอ",@"Open Reminders ลิสต์",@"Show Reminders ลิสต์",@"Open Directions",@"แสดงเส้นทาง",@"Open in Maps",@"แสดงในแผนที่",@"Open in BlindSquare",@"แสดงใน BlindSquare",@"Open in Calendar",@"แสดงในปฏิทิน",@"Add to Playing Next",@"เพิ่มไปยังรายการถัดไป",@"Clear Playing Next",@"ลบรายการถัดไปทั้งหมด",@"Find Giphy GIFs",@"ค้นหาใน Giphy",@"Follow Podcast",@"สมัครรับพ็อดคาสท์",@"Scan QR or Barcode",@"สแกนคิวอาร์โค้ดหรือบาร์โค้ด",@"Scan QR or Barcode",@"สแกน QR/บาร์โค้ด",@"Find App Store Apps",@"ค้นหาใน App Store",@"Find iTunes Store Items",@"ค้นหาใน iTunes Store",@"Find Places",@"ค้นหาธุรกิจในท้องถิ่น",@"Find Podcasts",@"ค้นหาพ็อดคาสท์",@"Show Web View",@"แสดงหน้าเว็บ",@"ตรวจหาภาษา",@"ตรวจหาภาษาด้วย Microsoft",@"หยุดคำสั่งลัดนี้",@"หยุดคำสั่งลัด",@"รับหน้าเว็บปัจจุบันจาก Safari",@"รับ URL ปัจจุบันจาก Safari",@"เปลี่ยนปลายทางการเล่น",@"ตั้งค่าปลายทางการเล่น",@"Translate ข้อความ",@"แปลข้อความด้วย Microsoft",@"ตั้งค่าโหมดโฟกัส",@"Set Do Not Disturb",@"Get File from โฟลเดอร์",@"Get ไฟล์",@"หยุดคำสั่งลัดนี้",@"Exit Shortcut",@"Append to Text ไฟล์",@"Append to ไฟล์",@"หมุนภาพ/วิดีโอ",@"Rotate Image",@"เปิดไฟล์",@"Open In...",@"แชร์กับแอป",@"Share with Extensions",nil];

%ctor {
  preferences = [[HBPreferences alloc] initWithIdentifier:@"com.zachary7829.pastcutsprefs"];
  if ([preferences boolForKey:@"isEnableVersionSpoofing"]) %init(pastcutsVersionSpoofing);
  if ([preferences boolForKey:@"isEnableModernActionNames"]) %init(pastcutsModernActionNames);
  if ([preferences boolForKey:@"isEnableForceOpen"]) %init(pastcutsForceOpen);
  %init(_ungrouped);
}
