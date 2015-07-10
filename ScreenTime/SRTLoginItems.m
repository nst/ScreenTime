//
//  SRTLoginItems.m
//  ScreenTime
//
//  Created by Nicolas Seriot on 27/06/15.
//  Copyright © 2015 Nicolas Seriot. All rights reserved.
//

#import "SRTLoginItems.h"

@implementation SRTLoginItems

+ (LSSharedFileListItemRef)copyLoginItemsReference:(LSSharedFileListRef)sharedFilesRef {
    
    uint32_t outSnapshotSeed;
    
    CFArrayRef loginItemList = LSSharedFileListCopySnapshot(sharedFilesRef, &outSnapshotSeed);
    
    LSSharedFileListItemRef itemRef = NULL;
    
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    
    for(id item in (__bridge NSArray *)loginItemList) {
        
        LSSharedFileListItemRef currentItemRef = (__bridge LSSharedFileListItemRef)item;
        
        CFErrorRef outError = NULL;
        NSURL *fileURL = (__bridge_transfer NSURL *)LSSharedFileListItemCopyResolvedURL(currentItemRef, 0, &outError);
        if(fileURL == NULL) continue;
        
        if ([[fileURL path] hasPrefix:bundlePath]) {
            itemRef = currentItemRef;
            break;
        }
    }
    
    if(itemRef) CFRetain(itemRef);
    
    CFRelease(loginItemList);
    
    return itemRef;
}

+ (void)enableLoginItem {
    
    NSLog(@"-- enableLoginItem");
    
    LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if(loginItems == NULL) return;
    
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:bundlePath];
    LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(loginItems, kLSSharedFileListItemLast, NULL, NULL, url, NULL, NULL);
    if (item) CFRelease(item);
    CFRelease(loginItems);
}

+ (void)disableLoginItem {
    
    NSLog(@"-- disableLoginItem");
    
    LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if(loginItems == NULL) return;
    
    LSSharedFileListItemRef itemRef = [self copyLoginItemsReference:loginItems];
    if(itemRef) {
        LSSharedFileListItemRemove(loginItems, itemRef);
        CFRelease(itemRef);
    }
    CFRelease(loginItems);
}

+ (BOOL)loginItemIsEnabled {
    LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if(loginItems == NULL) return NO;
    
    LSSharedFileListItemRef itemRef = [self copyLoginItemsReference:loginItems];
    BOOL exists = (itemRef != NULL);
    if(itemRef) CFRelease(itemRef);
    CFRelease(loginItems);
    return exists;
}

@end
