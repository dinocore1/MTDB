//
//  MTDatabase.m
//  MTDB
//
//  Created by Paul Soucy on 2/1/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MTDatabase.h"

@implementation MTDatabase 

@synthesize databasePath;



+ (id)databaseWithPath:(NSString*) path {
    return [[[self alloc] initWithPath:path] autorelease];
}

- (id)initWithPath:(NSString *)path {
    self = [super init];
    if(self) {
        self.databasePath = path;
    }
    return self;
}

@end
