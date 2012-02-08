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

- (BOOL) executeUpdate:(NSString *)sql lastId:(sqlite3_int64*)rowId, ... {
    va_list args;
    va_start(args, rowId);
    
    MTConnection* connection = [self getConnection];
    BOOL retval = [connection executeUpdate:sql error:nil withArgumentsInArray:nil orVAList:args];
    if(rowId != nil) {
        *rowId = [connection lastInsertedRowId];
    }
    
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

- (void) executeQuery:(NSString *)sql, ...{
    int count = [[sql componentsSeparatedByString:@"?"] count] - 1;
    
    NSMutableArray* valistArray = [NSMutableArray arrayWithCapacity:count];
    va_list arguments;
    va_start(arguments, sql);
    
    for(int i=0;i<count;i++) {
        id obj = va_arg(arguments, id);
        if(obj == nil){
            obj = [NSNull null];
        }
        [valistArray addObject: obj];
    }
    
    void (^block)(MTResultSet* rs)  = va_arg(arguments, void(^)(MTResultSet*));
    
    [self executeQuery:sql withArgArray:valistArray block:block];
    
    va_end(arguments);
}

- (BOOL)performTransaction:(BOOL (^)())block {
    MTConnection* connection = [self getConnection];
    
    if(connection.transactionCount++ <= 0){
        [connection executeUpdate:@"BEGIN EXCLUSIVE TRANSACTION;" error:nil withArgumentsInArray:nil orVAList:nil];
    }
    
    BOOL success = block();
    
    if(--connection.transactionCount <=0 ){
        if (!success) {
            [connection executeUpdate:@"ROLLBACK TRANSACTION;" error:nil withArgumentsInArray:nil orVAList:nil];
        } else {
            [connection executeUpdate:@"COMMIT TRANSACTION;" error:nil withArgumentsInArray:nil orVAList:nil];
        }
    }
    return success;
}


@end
