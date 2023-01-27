# Pastcuts Writeup

It has been a year since Pastcuts released. While I did technically release tweaks prior to it (ex NoYTAds), most were very simple and had already been done before, I mean one of them is literally called AnotherLazyHideDockTweak. I still did not know much about Logos or Objective-C at the time, and most of my tweaks was me just hooking random things in Flex 3, seeing what happened and convert it to theos using FTT and compile.

Pastcuts is in my opinion my first *good* tweak - back when I was in the Shortcuts community I remember always wanting to make it, but never knew how. Even though I didn't know any RE or much Objective-C or Logos at the time, I did learn how the unsigned shortcut file format works which will help in this case.

With that being said, that's not saying everything I did making Pastcuts, especially in the beginning, was a good idea. Hell as I just said I was a dumb kid just fucking around with Flex 3 not knowing what I was doing, I always wanted to learn tweak development (for some reason... I don't know why either) but was too afraid to ask many questions since I would seem like a dumbass (since I kinda was). I've since warmed up to asking for help though and I definitely improved. Just a recommendation: don't be afarid to ask for help.

So in this writeup, I'll explain how Pastcuts was made, the problems I made, how I first identified those problems and how I fixed them. I'm going to attempt to word this writeup so even someone with no Objective-C or Logos knowledge should *hopefully* get something out of this, but still might also help a little for those who are already experienced, though aren't aware of WorkflowKit much. 

### Creating Pastcuts 1.0
So we need to figure out what we need to hook beforehand. Back when shortcuts were shared as unsigned .shortcut files, I remember you could pull a shortcut file (which is just a plist) and modify it to have a lower WFWorkflowMinimumClientVersion, and boom import. Even if importing has been disabled on iOS 13/14 (excluding iOS 14 beta 1 where it was (possibly mistakenly?) re-enabled, and disabled the next beta), those unsigned shortcut files are still in use behind the scenes when importing shortcuts from iCloud in iOS 13/14 (you can even call the icloud API to receive the unsigned file if you want, ex links like these https://www.icloud.com/shortcuts/8d4e206d568d4aadb624b2a6191a3771 have this API https://www.icloud.com/shortcuts/api/records/8d4e206d568d4aadb624b2a6191a3771 in which contain a link to the signed shortcut for iOS 15+ and unsigned for iOS 14-), so that file must be in use somewhere.


So, what did I just say?


Well, there are two different types of plist formats shortcuts used for .shortcut files. Those are bplists and xml plists - I'm not touching bplists since everything should carry over to xml plists (at least for what we're doing). Rename an unsigned .shortcut file to .plist, and open in a plist editor. Here's an example of a xml plist .shortcut file, with just a comment action that says chocolate (excluding some keys that are not important and we aren't touching):


```xml
<key>WFWorkflowClientVersion</key>
<string>700</string>
<key>WFWorkflowClientRelease</key>
<string>2.0</string>
<key>WFWorkflowMinimumClientVersion</key>
<integer>411</integer>
<dict>
 <key>WFWorkflowActionIdentifier</key>
 <string>is.workflow.actions.comment</string>
 <key>WFWorkflowActionParameters</key>
 <dict>
  <key>WFCommentActionText</key>
  <string>Chocolate</string>
 </dict>
</dict>
```

So in a plist editor, if you change the WFWorkflowMinimumClientVersion in the file to something like 1, you can import it on an iOS 12 device without issues! (Well, that won't say the shortcut won't have issues - iOS 13 has a lot of actions that iOS 12 doesn't so the shortcut might not work if it uses one of those, but it will still allow importing).

So, how do we change that value automatically upon importing?


Shortcuts on iOS 13+ differs greatly behind the scenes from iOS 12-, with a lot of it being in iOS itself rather than the app - more specifically, ContentKit.framework, ActionKit.framework, and (the most important) WorkflowKit.framework. First let's understand what we need to hook. Thankfully shortcuts has a built-in action that makes this easy for us: View Content Graph of (x). Make a shortcut to get all shortcuts, choose list action, then view content graph. Run and choose a shortcut, and View Content graph should appear. Tap on the shortcut's name, then Shortcut. We can see 5 items - WFWorkflowReference, Shortcut, WFImage, WFWorkflowRecord, and NSString. We're going to modify WFWorkflowRecord. Let's take a look at the header - https://headers.cynder.me/index.php?sdk=ios/13.7&fw=/PrivateFrameworks/WorkflowKit.framework&file=%2FHeaders%2FWFWorkflowRecord.h. Oooo, NSString *minimumClientVersion - that sounds useful! Just hook minimumClientVersion in WFWorkflowRecord, and make it return NSString of 1. Boom - You just created Pastcuts 1.0!


Well, this actually honestly wasn't how I created it. Remember how I said I was a dumb kid doing random Flex 3? Yeah, admittedly that's just what I did: edit random Flex 3 stuff until I saw it worked. This is why older Pastcuts versions not only hook WFWorkflowRecord minimumClientVersion (the one thing that makes Pastcuts 1.0 word), but also WFWorkflowReference minimumClientVersion, which is unneeded, as well as some other random stuff that had methods that sounded related to importing with as isSupportedOnThisDevice, which isn't related to importing at *all* and is completely unneeded.

Here's all that's needed to recreate Pastcuts 1.0:

```objc
%hook WFWorkflowRecord
-(id)minimumClientVersion {
  return @"1";
}
%end
```
### Pastcuts 1.1.2+
Okay, so, what's wrong here? Well, in 1.2 I wanted Pastcuts to convert shortcut actions when importing. I realized that my logic was bad. Why? Well, we're hooking minimumClientVersion in EVERY shortcut loaded. This might be bad for performance / battery, and while we're not doing anything that can go wrong that much, once we get to hooking actions, if we make one mistake, not just that shortcut gets affected but EVERY shortcut gets affected, so it's pretty dangerous as well.

I still wasn't that experienced with RE, but I had improved by Obj-C skills a bit by this point - instead of RE, I instead just plopped in a NSLog, looked at console, and saw how many times it was called and was like, "okay, this definitely is called too much". I still didn't know RE so I just messed with random classes Flex 3 showed, and found WFSharedShortcut. After trying an NSLog with a hook *this* time, I saw that it seems to not be called when loading shortcuts, only when importing. So I decided that WFSharedShortcut was a much better option for this than WFWorkflowRecord. Current Pastcuts, 1.3.0, still actually uses WFSharedShortcut, fun fact, and some other tweaks of mine such as Safecuts, which mitigates an iOS 15.0-15.3.1 hidden action vuln also use it (although I should really switch to using WFShortcutExporter for Safecuts - it's brand new to iOS 15, and if you're doing iOS 15, it's more better suited for this type of stuff). I would still recommend doing, uh, good RE and understanding exactly how WFSharedShortcut works, but at the time this was all I knew and I guess it's better than nothing.


So, let's just switch to hooking (also in WorkflowKit) WFSharedShortcut's workflowRecord instead. Let's do id rettype = %orig;. Then, [rettype setMinimumClientVersion:@"1"]; to make minimumClientVersion 1 in it. Then just return rettype, and boom, now we only hook when a shortcut is imported, making us MUCH more optimized! I was planning on waiting for Pastcuts 1.2, but I decided this optimization is enough to deserve a quick 1.1.2 release.

```objc
%hook WFSharedShortcut
-(id)workflowRecord {
  id rettype = %orig;
  [rettype setMinimumClientVersion:@"1"];
  return rettype;
}
%end
```
### Pastcuts 1.2/1.3 (starting to get good - we're actually converting actions)!
Okay, so we can import all Shortcuts imported now. I missed that gallery shortcuts won't be under WFSharedShortcut, so we should also do the same hook for WFGalleryShortcut's workflowRecord as well. Now, even though we can import any action, iOS 13/14 doesn't have every action iOS 15 does, does it? Let's fix that.

So first off I want to thank u/gluebyte for documenting some of the backwards (in)compatibility of iOS 15. See the post here https://www.reddit.com/r/shortcuts/comments/opak23/backward_incompatibility_of_ios_15_shortcuts/. Let's start by converting the stop action back to the exit action.

We need to get the actions, obv. NSArray *origShortcutActions = (NSArray *)[rettype actions];. I also create a mutable copy of the actions as newMutableShortcutActions. Then I proceed to have a for loop to loop through all the actions in origShortcutActions. Actions codewise are very similar to Shortcut's unsigned plist format, so if you're already aware of it this should be fairly easy to understand.

WFWorkflowActionIdentifier is a string representing the action'd id. To check if the action is a stop action, we just check if the action in the loop's WFWorkflowActionIdentifier is equal to string is.workflow.actions.output.

If so, I create a mutable copy of the action to modify it. Then I change the WFWorkflowActionIdentifier to equal is.workflow.actions.exit. I then proceed to attempt to get its output and correspond to is.workflow.actions.exit's way.

If you're unaware of how an action is structured, I really recommend creating a shortcut with the action, using the Get My Shortcuts action, Choose from List, and then get file of type com.apple.plist to view the shortcuts unsigned plist. It should give you a good look at how the action works without even needing to look at rev'ing WorkflowKit/ActionKit.

(Note: That being said, when needed to, I highly recommend learning some basic reverse engineering. I made Pastcuts before I knew anything and just tried a bunch of classes hoping to eventually get it right. Don't do this. That's a ton more effort and rev'ing gives you a much better chance of ensuring what you're hooking is good to hook. I have since and it's been very helpful.)

Here's an example of this:

```objc
%hook WFSharedShortcut
-(id)workflowRecord {
  id rettype = %orig;
  [rettype setMinimumClientVersion:@"1"];
  NSArray *origShortcutActions = (NSArray *)[rettype actions];
  NSMutableArray *newMutableShortcutActions = [origShortcutActions mutableCopy];
  int shortcutActionsObjectIndex = 0;
  for (id shortcutActionsObject in origShortcutActions) {
    //this safety check is only needed if you are unaware of in actions it potentially contains more than NSDictionaries.
    if ([shortcutActionsObject isKindOfClass:[NSDictionary class]]){
      if ([[shortcutActionsObject objectForKey:@"WFWorkflowActionIdentifier"] isEqualToString:@"is.workflow.actions.output"]) {
        NSMutableDictionary *mutableShortcutActionsObject = [shortcutActionsObject mutableCopy];

        [mutableShortcutActionsObject setObject:@"is.workflow.actions.exit" forKey:@"WFWorkflowActionIdentifier"];
        if ([[[[[mutableShortcutActionsObject objectForKey:@"WFWorkflowActionParameters"] objectForKey:@"WFOutput"] objectForKey:@"Value"] objectForKey:@"attachmentsByRange"] objectForKey:@"{0, 1}"]) {
    //in iOS 15, if an Exit action has output it's converted into the Output action, so we convert it back

          NSDictionary *actionParametersWFResult = [[NSDictionary alloc] initWithObjectsAndKeys:@"placeholder", @"Value", @"WFTextTokenAttachment", @"WFSerializationType", nil];
          NSMutableDictionary *mutableActionParametersWFResult = [actionParametersWFResult mutableCopy];
          [mutableActionParametersWFResult setObject:[[[[[mutableShortcutActionsObject objectForKey:@"WFWorkflowActionParameters"] objectForKey:@"WFOutput"] objectForKey:@"Value"] objectForKey:@"attachmentsByRange"] objectForKey:@"{0, 1}"] forKey:@"Value"];
          NSDictionary *actionParameters = [[NSDictionary alloc] initWithObjectsAndKeys:@"placeholder", @"WFResult", nil];
          NSMutableDictionary *mutableActionParameters = [actionParameters mutableCopy];
          [mutableActionParameters setObject:mutableActionParametersWFResult forKey:@"WFResult"];
          [mutableShortcutActionsObject setObject:mutableActionParameters forKey:@"WFWorkflowActionParameters"];
        }
        newMutableShortcutActions[shortcutActionsObjectIndex] = [[NSDictionary alloc] initWithDictionary:mutableShortcutActionsObject];
      }
    }
  }
  return rettype;
}
%end
```
### The (potential) future - iOS 12 support?
Remember how I claimed iOS 13 works greatly behind the scenes than iOS 12 Shortcuts? I've finally learned a bit of rev'ing and took a look back at Shortcuts 2.2.2 - and it looks like they may have a lot more in common than I originally thought.

While in iOS 12 there is no WorkflowKit system framework, Shortcuts 2.2.2 embeds frameworks that later become embedded. ActionKit.framework, ContentKit.framework, WorkflowUI.framework are all embedded. And, most interestingly, WorkflowAppKit is embedded. This isn't a 1:1 copy of WorkflowKit but it's fairly similar. A lot of code seems to e later re-used in WorkflowKit. My best guess is that they knew they couldn't rework the whole app to integrate into the OS, so rather as a stopgap they did some embedded frameworks they planned to integrate later when fully finished. iOS 12 Shortcuts is not fully made of these frameworks however, the binary does in fact have some actual code implemented, with it all being Swift. I'd honestly say iOS 12 Shortcuts has more Swift than iOS 13.

WorkflowAppKit, from what I can see does not handle gallery shortcuts, that's by Shortcuts itself which is all in swift, so adding gallery support isn't so easy. But, for what's going to matter the most, importing, is handled by WorkflowAppKit's WFSharedShortcut - hmm, where have we seen this before?

WFSharedShortcut is nearly identical to how it is in WorkflowKit in iOS 13. WFWorkflowRecord however, doesn't exist yet - instead WFWorkflow is used. So, we should just be able to hook that and (hopefully) be good.

That's not saying it'll be as neat as Pastcuts iOS 13/14 for iOS 15 shortcuts - iOS 12 to 13, unlike 14 to 15, does differ a lot in structure, with iOS 12 being more dependent on actions using input passed in from the last action, and iOS 13+ is more dependent on using the passed in magic variable of the action.

Perhaps, maybe, it could be usual to convert actions that rely on that magic variable structure in iOS 13 to cycle through all params, and place the magic variables in a Get Variable action on top of the action. iOS 13 also features a lot of acitons that you may be able to easily just substitute with a Get Variable action.

This is currently what I'm working on with Pastcuts 1.4.0. Sadly I wasn't able to finish for the 1 year anniversary, but I'm still trying and hoping to make Pastcuts 1.4.0 the best update it can be

### The (potential) future - potentially better hooking?

Hey - why are we using WFSharedShortcut, anyway? A potentially better method is to hook the Shortcut app's openFile or openURL in the app delegate, and auto change the file to do our action modification and minimum client version patching. This should work great for iOS 13/14. Hey, what about iOS 15? Our old WFSharedShortcut is still fine and seems like it doesn't fuck up shortcuts signing, but our new method probably will. Well, as I prev mentioned, a new method has been implemented in WorkflowKit - WFShortcutExporter - this workflowkit method is going to be *awesome* for this. Hook it, and everything after the %orig you shouldn't need to worry about shortcuts signing at all anymore.
