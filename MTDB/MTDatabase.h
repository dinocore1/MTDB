//
//  MTDatabase.h
//  MTDB
//
//  Created by Paul Soucy on 2/1/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "sqlite3.h"

@class MTResultSet;

@interface MTDatabase : NSObject {
    NSString* databasePath;
}

+ (id)databaseWithPath:(NSString*) path;

- (id)initWithPath:(NSString*)path;

- (BOOL) executeUpdate:(NSString*)sql, ...;
- (BOOL) executeUpdate:(NSString *)sql lastId:(sqlite3_int64*)rowId, ...;
- (void) executeQuery:(NSString*)sql withArgArray:(NSArray*)arrayArgs block:(void (^)(MTResultSet* rs))block;
- (void) executeQuery:(NSString*)sql, ...;
- (BOOL) performTransaction: (BOOL (^)())block;

@property (readonly) NSString* databasePath;

@end
