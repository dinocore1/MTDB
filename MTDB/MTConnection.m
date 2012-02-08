//
//  MTConnection.m
//  MTDB
//
//  Created by Paul Soucy on 2/4/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MTConnection.h"

@implementation MTConnection

@synthesize transactionCount;

- (id)initWithPath:(NSString*)aPath {
    self = [super init];
    
    if (self) {
        databasePath = [aPath copy];
        db = nil;
        transactionCount = 0;
    }
    
    return self;
}

- (void) dealloc {
    [self close];
    [databasePath release];
    [super dealloc];
}

- (BOOL)open {
    if (db) {
        return YES;
    }
    
    int err = sqlite3_open((databasePath ? [databasePath fileSystemRepresentation] : ":memory:"), &db );
    if(err != SQLITE_OK) {
        NSLog(@"error opening!: %d", err);
        return NO;
    }
    
    return YES;
}

#if SQLITE_VERSION_NUMBER >= 3005000
- (BOOL)openWithFlags:(int)flags {
    int err = sqlite3_open_v2((databasePath ? [databasePath fileSystemRepresentation] : ":memory:"), &db, flags, NULL /* Name of VFS module to use */);
    if(err != SQLITE_OK) {
        NSLog(@"error opening!: %d", err);
        return NO;
    }
    return YES;
}
#endif

- (BOOL)close {
    
    if (!db) {
        return YES;
    }
    
    int rc = sqlite3_close(db);
    if (SQLITE_OK != rc) {
        NSLog(@"error closing!: %d", rc);
        return NO;
    }
    
    db = nil;
    return YES;
}

- (NSString*)lastErrorMessage {
    return [NSString stringWithUTF8String:sqlite3_errmsg(db)];
}

- (int)lastErrorCode {
    return sqlite3_errcode(db);
}

- (BOOL)hadError {
    int lastErrCode = [self lastErrorCode];
    
    return (lastErrCode > SQLITE_OK && lastErrCode < SQLITE_ROW);
}


- (void)bindObject:(id)obj toColumn:(int)idx inStatement:(sqlite3_stmt*)pStmt {
    
    if ((!obj) || ((NSNull *)obj == [NSNull null])) {
        sqlite3_bind_null(pStmt, idx);
    }
    
    // FIXME - someday check the return codes on these binds.
    else if ([obj isKindOfClass:[NSData class]]) {
        sqlite3_bind_blob(pStmt, idx, [obj bytes], (int)[obj length], SQLITE_STATIC);
    }
    else if ([obj isKindOfClass:[NSDate class]]) {
        sqlite3_bind_double(pStmt, idx, [obj timeIntervalSince1970]);
    }
    else if ([obj isKindOfClass:[NSNumber class]]) {
        
        if (strcmp([obj objCType], @encode(BOOL)) == 0) {
            sqlite3_bind_int(pStmt, idx, ([obj boolValue] ? 1 : 0));
        }
        else if (strcmp([obj objCType], @encode(int)) == 0) {
            sqlite3_bind_int64(pStmt, idx, [obj longValue]);
        }
        else if (strcmp([obj objCType], @encode(long)) == 0) {
            sqlite3_bind_int64(pStmt, idx, [obj longValue]);
        }
        else if (strcmp([obj objCType], @encode(long long)) == 0) {
            sqlite3_bind_int64(pStmt, idx, [obj longLongValue]);
        }
        else if (strcmp([obj objCType], @encode(float)) == 0) {
            sqlite3_bind_double(pStmt, idx, [obj floatValue]);
        }
        else if (strcmp([obj objCType], @encode(double)) == 0) {
            sqlite3_bind_double(pStmt, idx, [obj doubleValue]);
        }
        else {
            sqlite3_bind_text(pStmt, idx, [[obj description] UTF8String], -1, SQLITE_STATIC);
        }
    }
    else {
        sqlite3_bind_text(pStmt, idx, [[obj description] UTF8String], -1, SQLITE_STATIC);
    }
}


- (MTResultSet *)executeQuery:(NSString *)sql withArgumentsInArray:(NSArray*)arrayArgs orVAList:(va_list)args {
    
    MTResultSet *rs = nil;
    
    int rc                  = 0x00;
    sqlite3_stmt *pStmt     = 0x00;
    
    BOOL retry          = NO;
    
    if (!pStmt) {
        do {
            retry   = NO;
            rc      = sqlite3_prepare_v2(db, [sql UTF8String], -1, &pStmt, 0);
            
            if (SQLITE_BUSY == rc || SQLITE_LOCKED == rc) {
                retry = YES;
                usleep(20);
                
                NSLog(@"Database busy %@", databasePath);
            } else if (SQLITE_OK != rc) {
                
                NSLog(@"DB Error: %d \"%@\"", [self lastErrorCode], [self lastErrorMessage]);
                NSLog(@"DB Query: %@", sql);
                
                sqlite3_finalize(pStmt);
                
                return nil;
            }
        }
        while (retry);
    }
    
    id obj;
    int idx = 0;
    int queryCount = sqlite3_bind_parameter_count(pStmt); // pointed out by Dominic Yu (thanks!)
    
    while (idx < queryCount) {
        
        if (arrayArgs) {
            obj = [arrayArgs objectAtIndex:idx];
        }
        else {
            obj = va_arg(args, id);
        }
        
        idx++;
        
        [self bindObject:obj toColumn:idx inStatement:pStmt];
    }
    
    if (idx != queryCount) {
        NSLog(@"Error: the bind count is not correct for the # of variables (executeQuery)");
        sqlite3_finalize(pStmt);
        return nil;
    }
    
    rs = [MTResultSet resultSetWithStatement:pStmt usingParentConnection:self];
    [rs setQuery:sql];
    
    return rs;
}

- (BOOL)executeUpdate:(NSString*)sql error:(NSError**)outErr withArgumentsInArray:(NSArray*)arrayArgs orVAList:(va_list)args {
    
    
    int rc                   = 0x00;
    sqlite3_stmt *pStmt      = 0x00;
    BOOL retry          = NO;
    
    if (!pStmt) {
        
        do {
            retry   = NO;
            rc      = sqlite3_prepare_v2(db, [sql UTF8String], -1, &pStmt, 0);
            if (SQLITE_BUSY == rc || SQLITE_LOCKED == rc) {
                retry = YES;
                usleep(20);
                NSLog(@"Database busy %@", databasePath);
            } else if (SQLITE_OK != rc) {
                
                
                NSLog(@"DB Error: %d \"%@\"", [self lastErrorCode], [self lastErrorMessage]);
                NSLog(@"DB Query: %@", sql);
                
                sqlite3_finalize(pStmt);
                
                if (outErr) {
                    *outErr = [NSError errorWithDomain:[NSString stringWithUTF8String:sqlite3_errmsg(db)] code:rc userInfo:nil];
                }
                
                return NO;
            }
        }
        while (retry);
    }
    
    
    id obj;
    int idx = 0;
    int queryCount = sqlite3_bind_parameter_count(pStmt);
    
    while (idx < queryCount) {
        
        if (arrayArgs) {
            obj = [arrayArgs objectAtIndex:idx];
        }
        else {
            obj = va_arg(args, id);
        }
        
        idx++;
        
        [self bindObject:obj toColumn:idx inStatement:pStmt];
    }
    
    if (idx != queryCount) {
        NSLog(@"Error: the bind count is not correct for the # of variables (%@) (executeUpdate)", sql);
        sqlite3_finalize(pStmt);
        return NO;
    }
    
    /* Call sqlite3_step() to run the virtual machine. Since the SQL being
     ** executed is not a SELECT statement, we assume no data will be returned.
     */
    do {
        rc      = sqlite3_step(pStmt);
        retry   = NO;
        
        if (SQLITE_BUSY == rc || SQLITE_LOCKED == rc) {
            // this will happen if the db is locked, like if we are doing an update or insert.
            // in that case, retry the step... and maybe wait just 10 milliseconds.
            retry = YES;
            if (SQLITE_LOCKED == rc) {
                rc = sqlite3_reset(pStmt);
                if (rc != SQLITE_LOCKED) {
                    NSLog(@"Unexpected result from sqlite3_reset (%d) eu", rc);
                }
            }
            usleep(20);
        }
        else if (SQLITE_DONE == rc || SQLITE_ROW == rc) {
            // all is well, let's return.
        }
        else if (SQLITE_ERROR == rc) {
            NSLog(@"Error calling sqlite3_step (%d: %s) SQLITE_ERROR", rc, sqlite3_errmsg(db));
            NSLog(@"DB Query: %@", sql);
        }
        else if (SQLITE_MISUSE == rc) {
            // uh oh.
            NSLog(@"Error calling sqlite3_step (%d: %s) SQLITE_MISUSE", rc, sqlite3_errmsg(db));
            NSLog(@"DB Query: %@", sql);
        }
        else {
            // wtf?
            NSLog(@"Unknown error calling sqlite3_step (%d: %s) eu", rc, sqlite3_errmsg(db));
            NSLog(@"DB Query: %@", sql);
        }
        
    } while (retry);
    
    assert( rc!=SQLITE_ROW );
    
    
    /* Finalize the virtual machine. This releases all memory and other
     ** resources allocated by the sqlite3_prepare() call above.
     */
    rc = sqlite3_finalize(pStmt);
    
    return (rc == SQLITE_OK);
}

- (sqlite3_int64) lastInsertedRowId {
    return sqlite3_last_insert_rowid(db);
}

@end
