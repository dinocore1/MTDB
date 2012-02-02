//
//  MTStatement.h
//  MTDB
//
//  Created by Paul Soucy on 2/1/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//



@interface MTStatement : NSObject {
    sqlite3_stmt *statement;
    NSString *query;
    long useCount;
}

@property (assign) long useCount;
@property (retain) NSString *query;
@property (assign) sqlite3_stmt *statement;

- (void)close;
- (void)reset;

@end
