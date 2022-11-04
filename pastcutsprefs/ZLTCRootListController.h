#import <Preferences/PSListController.h>

@class PSSpecifier;

typedef NS_ENUM(NSInteger, XXDynamicSpecifierOperatorType) {
  XXEqualToOperatorType,
  XXNotEqualToOperatorType,
  XXGreaterThanOperatorType,
  XXLessThanOperatorType,
};

@interface ZLTCRootListController : PSListController
@property (nonatomic, assign) BOOL hasDynamicSpecifiers;
@property (nonatomic, retain) NSMutableDictionary *dynamicSpecifiers;
@end
