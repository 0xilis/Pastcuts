# Pastcuts
Import iOS 15+ shortcuts on 13/14, and convert some actions to iOS 13/14

# Supported actions:

(Thanks to https://www.reddit.com/r/shortcuts/comments/opak23/backward_incompatibility_of_ios_15_shortcuts/)

- is.workflow.actions.output -> is.workflow.actions.exit
- is.workflow.actions.returntohomescreen -> is.workflow.actions.openapp to SpringBoard
- is.workflow.actions.file.select -> is.workflow.actions.documentpicker.open with WFShowFilePicker on
- If WFGetFilePath in is.workflow.actions.documentpicker.open and WFShowFilePicker not true, set WFShowFilePicker to false

# Here but not yet in release version:

- hook WFGalleryShortcut to fix not working for gallery shortcuts
- add force importing (unrecommended, only enable if absolutely needed)
- optimized some code
- default spoofed version updated from 15.4 to 16.1
- On iOS 13, replace iOS 14's Open Shortcut action with opening the shortcut via a URL scheme (shortcuts://open-shortcut?name=)
- Replace iOS 16's Create Shortcut action with creating the shortcut via a URL scheme (shortcuts://create-shortcut)
- Make iOS 15's Get Device Details Global Variable convert into a magic variable, add a Get Device Details action and make the magic variable link to that action

# Things needed to be changed:

- Improve code
- For iOS 13, either convert the iOS 14 Calculate Expression to a group of actions or javascript that mimic the behavior (would work in stock but may be less reliable) - or add action using Calculate.framework (more reliable but wouldn't work in stock)
- For iOS 13-14.2, mimic the Set Wallpaper action in a jailbroken state. Make damn sure that the input can be a wallpaper - Set Wallpaper was in iOS 13 betas but very quickly scrapped due to bad inputs causing respring loops and wasn't added back until iOS 14.3. I have test devices on iOS 13, but none on iOS 14 so not sure if my bad hacky workaround for custom shortcut actions works on iOS 14, so maybe for iOS 14.2 just play it safe and have it be a Powercuts action.
- Perhaps an option to change action names to future names? No affect on the shortcut at all but hey some people may be a fan of that ig.
- Move away from using Cephei for preferences
- Mimic iOS 16.2's Get Wallpaper action


### Refs may be helpful in future:

- List by atnbueno: https://cdn.discordapp.com/attachments/491381450306748426/983409287768469534/ios_shortcut_actions.xlsx
- https://www.reddit.com/r/shortcuts/comments/pxrby9/new_actions_and_parameters_in_ios_15_and_macos/
- https://www.reddit.com/r/shortcuts/comments/tg9k6n/action_and_parameter_changes_in_ios_154_and_macos/
- https://www.reddit.com/r/shortcuts/comments/v6r57z/ios_16_beta_1_new_actions_and_parameters_in_ios/

(Thanks flower for Pastcuts 1.2.2+ icon)
