//
//  MTDatabase.m
//  MTDB
//
//  Created by Paul Soucy on 2/1/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MTDatabase.h"
#import "MTConnection.h"

@implementation MTDatabase 

@synthesize databasePath;



+ (id)databaseWithPath:(NSString*) path {
    return [[[self alloc] initWithPath:path] autorelease];
}

- (id)initWithPath:(NSString *)path {
    self = [super init];
    if(self) {
        databasePath = path;
    }
    return self;
}

- (MTConnection*) getConnection {
    NSString* key = [NSString stringWithFormat:@"sqlite%@", databasePath];
    MTConnection* retval = [[[NSThread currentThread] threadDictionary] objectForKey:key];
    if(retval == nil){
        retval = [[[MTConnection alloc] initWithPath:databasePath] autorelease];
        [[[NSThread currentThread] threadDictionary] setObject:retval forKey:key];
    }
    return retval;
}

- (BOOL) executeUpdate:(NSString*)sql, ... {
    
    va_list args;
    va_start(args, sql);
    
    MTConnection* connection = [self getConnection];
    BOOL retval = [connection executeUpdate:sql error:nil withArgumentsInArray:nil orVAList:args];
    
    va_end(args);
    return retval;
}

- (void) executeQuery:(NSString*)sql withArgArray:(NSArray*)arrayArgs block:(void (^)(MTResultSet* rs))block {
    MTConnection* connection = [self getConnection];
    MTResultSet* rs = [connection executeQuery:sql withArgumentsInArray:arrayArgs orVAList:nil];
    @try {
        block(rs);
    } @finally {
        [rs close];
    }
}


@end
