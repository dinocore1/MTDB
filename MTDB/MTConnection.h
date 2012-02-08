//
//  MTConnection.h
//  MTDB
//
//  Created by Paul Soucy on 2/4/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MTResultSet.h"

@interface MTConnection : NSObject {
    sqlite3* db;
    NSString* databasePath;
    int transactionCount;
}

- (id)initWithPath:(NSString*)inPath;

- (BOOL)open;
#if SQLITE_VERSION_NUMBER >= 3005000
- (BOOL)openWithFlags:(int)flags;
#endif
- (BOOL)close;

- (NSString*)lastErrorMessage;

- (MTResultSet *)executeQuery:(NSString *)sql withArgumentsInArray:(NSArray*)arrayArgs orVAList:(va_list)args;
- (BOOL)executeUpdate:(NSString*)sql error:(NSError**)outErr withArgumentsInArray:(NSArray*)arrayArgs orVAList:(va_list)args;

- (sqlite3_int64) lastInsertedRowId; 

@property int transactionCount;

@end
