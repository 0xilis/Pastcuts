#import <Foundation/Foundation.h>
#import "ZLTCRootListController.h"
#import "ZLTCSwitchWithInfo.h"
//#import "NSTask.h"

@implementation ZLTCRootListController

// thanks to https://github.com/LacertosusRepo/Preference-Cell-Examples/tree/main/Dynamic%20Specifiers

-(void)collectDynamicSpecifiersFromArray:(NSArray *)array {
		//Create new dictionary or remove all previous specifiers
	if(!self.dynamicSpecifiers) {
		self.dynamicSpecifiers = [NSMutableDictionary new];

	} else {
		[self.dynamicSpecifiers removeAllObjects];
	}

		//Add any specifiers with rule to dynamic specifiers dictionary
	for(PSSpecifier *specifier in array) {
		NSString *dynamicSpecifierRule = [specifier propertyForKey:@"dynamicRule"];

		if(dynamicSpecifierRule.length > 0) {
				//Get rule components
			NSArray *ruleComponents = [dynamicSpecifierRule componentsSeparatedByString:@", "];

				//Add specifier to dictionary with opposing specifier ID as key
			if(ruleComponents.count == 3) {
				NSString *opposingSpecifierID = [ruleComponents objectAtIndex:0];
				[self.dynamicSpecifiers setObject:specifier forKey:opposingSpecifierID];

				//Throw error if rule has incorrect components
			} else {
				[NSException raise:NSInternalInconsistencyException format:@"dynamicRule key requires three components (Specifier ID, Comparator, Value To Compare To). You have %ld of 3 (%@) for specifier '%@'.", ruleComponents.count, dynamicSpecifierRule, [specifier propertyForKey:PSTitleKey]];
			}
		}
	}

		//Check if we need to update specifier height at all
	self.hasDynamicSpecifiers = (self.dynamicSpecifiers.count > 0);
}

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
		[self collectDynamicSpecifiersFromArray:_specifiers];
	}

	return _specifiers;
}

-(void)reloadSpecifiers {
  [super reloadSpecifiers];

  [self collectDynamicSpecifiersFromArray:self.specifiers];
}

-(void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
	[super setPreferenceValue:value specifier:specifier];
		
	if(self.hasDynamicSpecifiers) {
			//Check if dynamic specifier exists for opposing specifier ID
		NSString *specifierID = [specifier propertyForKey:PSIDKey];
		PSSpecifier *dynamicSpecifier = [self.dynamicSpecifiers objectForKey:specifierID];

			//Update cells
		if(dynamicSpecifier) {
			[self.table beginUpdates];
			[self.table endUpdates];
		}
	}
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if(self.hasDynamicSpecifiers) {
		PSSpecifier *dynamicSpecifier = [self specifierAtIndexPath:indexPath];

			//Check if specifier exists in our dictionary values
		if([self.dynamicSpecifiers.allValues containsObject:dynamicSpecifier]) {
			BOOL shouldHide = [self shouldHideSpecifier:dynamicSpecifier];

				//Clips bounds if we're hiding the cell
			UITableViewCell *specifierCell = [dynamicSpecifier propertyForKey:PSTableCellKey];
			specifierCell.clipsToBounds = shouldHide;

			if(shouldHide) {
				return 0;
			} 
		}
	}

	return UITableViewAutomaticDimension;
}

-(BOOL)shouldHideSpecifier:(PSSpecifier *)specifier {
	if(specifier) {
			//Get dynamic rule components
		NSString *dynamicSpecifierRule = [specifier propertyForKey:@"dynamicRule"];
		NSArray *ruleComponents = [dynamicSpecifierRule componentsSeparatedByString:@", "];

			//Get values to compare to specifier's value
		PSSpecifier *opposingSpecifier = [self specifierForID:[ruleComponents objectAtIndex:0]];
		id opposingValue = [self readPreferenceValue:opposingSpecifier];
		id requiredValue = [ruleComponents objectAtIndex:2];

			//Numbers can use any operator
		if([opposingValue isKindOfClass:NSNumber.class]) {
			XXDynamicSpecifierOperatorType operatorType = [self operatorTypeForString:[ruleComponents objectAtIndex:1]];

			switch(operatorType) {
				case XXEqualToOperatorType:
					return ([opposingValue intValue] == [requiredValue intValue]);
				break;

				case XXNotEqualToOperatorType:
					return ([opposingValue intValue] != [requiredValue intValue]);
				break;

				case XXGreaterThanOperatorType:
					return ([opposingValue intValue] > [requiredValue intValue]);
				break;

				case XXLessThanOperatorType:
					return ([opposingValue intValue] < [requiredValue intValue]);
				break;
			}
		}

			//Strings can only check if equal
		if([opposingValue isKindOfClass:NSString.class]) {
			return [opposingValue isEqualToString:requiredValue];
		}

			//Arrays can check if value exists
		if([opposingValue isKindOfClass:NSArray.class]) {
			return [opposingValue containsObject:requiredValue];
		}
	}

	return NO;
}

-(XXDynamicSpecifierOperatorType)operatorTypeForString:(NSString *)string {
	NSDictionary *operatorValues = @{ @"==" : @(XXEqualToOperatorType), @"!=" : @(XXNotEqualToOperatorType), @">" : @(XXGreaterThanOperatorType), @"<" : @(XXLessThanOperatorType) };
	return [operatorValues[string] intValue];
}

/*-(void)enableSemiPersistence {
	// NSTask *enPersistence = [[NSTask alloc] init];
	// enPersistence.launchPath = @"/usr/bin/enableSemiPersistenceScript";
	// enPersistence.arguments = @[@"ok"];
	// [enPersistence launch];
	pid_t pid;
	char *argv[] = {"bash", "-c", "/usr/local/bin/enableSemiPersistenceScript", NULL};
	posix_spawn(&pid, "/bin/bash", NULL, NULL, argv, NULL);
	// setuid(0);
	// setgid(0);
	// NSMutableDictionary * wflowKitPlist = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/System/Library/PrivateFrameworks/WorkflowKit.framework/Info.plist"];
	// NSUserDefaults * wflowKitPlist = [[NSUserDefaults alloc] initWithSuiteName:@"/System/Library/PrivateFrameworks/WorkflowKit.framework/Info.plist"];
	// [wflowKitPlist setValue:@"1146.11" forKey:@"CFBundleVersion"];
	// [wflowKitPlist synchronize];
	// [wflowKitPlist writeToFile:@"/System/Library/PrivateFrameworks/WorkflowKit.framework/Info.plist" atomically:NO];
}

-(void)disableSemiPersistence {
	// NSTask *diPersistence = [[NSTask alloc] init];
	// diPersistence.launchPath = @"/usr/local/bin/disableSemiPersistenceScript";
	// diPersistence.arguments = @[@"ok"];
	// [diPersistence launch];
	pid_t pid;
	char *argv[] = {"bash", "-c", "/usr/local/bin/disableSemiPersistenceScript", NULL};
	posix_spawn(&pid, "/bin/bash", NULL, NULL, argv, NULL);
	// setuid(0);
	// setgid(0);
	// NSUserDefaults *wflowKitPlist = [[NSUserDefaults alloc] initWithSuiteName:@"/System/Library/PrivateFrameworks/WorkflowKit.framework/Info.plist"];
	// NSUserDefaults *placeholderPlist = [[NSUserDefaults alloc] initWithSuiteName:@"/System/Library/AppPlaceholders/Shortcuts.app/Info.plist"];
	// [wflowKitPlist setValue:[placeholderPlist objectForKey:@"CFBundleVersion"] forKey: @"CFBundleVersion"];
	// [wflowKitPlist synchronize];
}*/

/*-(void)reloadShortcuts {
	NSTask *scutreload = [[NSTask alloc] init];
	scutreload.launchPath = @"/usr/bin/killall";
	scutreload.arguments = @[@"siriactionsd"];
	[scutreload launch];
	NSTask *scutreloadnew = [[NSTask alloc] init];
	scutreloadnew.launchPath = @"/usr/bin/killall";
	scutreloadnew.arguments = @[@"Shortcuts"];
	[scutreloadnew launch];
}*/

/*-(void)openPatreon {
	[[UIApplication sharedApplication]
	openURL:[NSURL URLWithString:@"https://www.patreon.com/zachary7829"]
	options:@{}
	completionHandler:nil];
}*/

-(void)openDiscord {
	[[UIApplication sharedApplication]
	openURL:[NSURL URLWithString:@"https://discord.gg/suFChKy6GV"]
	options:@{}
	completionHandler:nil];
}

-(void)openGitHub {
	[[UIApplication sharedApplication]
	openURL:[NSURL URLWithString:@"https://github.com/0xilis"]
	options:@{}
	completionHandler:nil];
}

-(void)openTwitter {
	[[UIApplication sharedApplication]
	openURL:[NSURL URLWithString:@"https://twitter.com/QuickUpdate5"]
	options:@{}
	completionHandler:nil];
}

-(void)openReddit {
	[[UIApplication sharedApplication]
	openURL:[NSURL URLWithString:@"https://reddit.com/user/0xilis"]
	options:@{}
	completionHandler:nil];
}

-(void)buyBadger {
	[[UIApplication sharedApplication]
	openURL:[NSURL URLWithString:@"https://havoc.app/package/badger"]
	options:@{}
	completionHandler:nil];
}
@end
