//
//  MTResultSet.m
//  MTDB
//
//  Created by Paul Soucy on 2/1/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MTResultSet.h"
#import "MTConnection.h"

@implementation MTResultSet

@synthesize query;
@synthesize columnNameToIndexMap;

@interface MTResultSet (Private)
- (NSMutableDictionary *)columnNameToIndexMap;
- (void)setColumnNameToIndexMap:(NSMutableDictionary *)value;
@end


+ (id)resultSetWithStatement:(sqlite3_stmt *)statement usingParentConnection:(MTConnection*)aConnection {
    
    MTResultSet *rs = [[MTResultSet alloc] init];
    
    rs->statement = statement;
    rs->connection = aConnection;
    
    return [rs autorelease];
}

- (void)dealloc {
    [self close];
    
    [query release];
    query = nil;
    
    [columnNameToIndexMap release];
    columnNameToIndexMap = nil;
    
    [super dealloc];
}

- (void)close {
    if(statement != nil){
        sqlite3_finalize(statement);
        statement = nil;
    }
    
    
}

- (int)columnCount {
	return sqlite3_column_count(statement);
}

- (void)setupColumnNames {
    
    if (!columnNameToIndexMap) {
        [self setColumnNameToIndexMap:[NSMutableDictionary dictionary]];
    }    
    
    int columnCount = sqlite3_column_count(statement);
    
    int columnIdx = 0;
    for (columnIdx = 0; columnIdx < columnCount; columnIdx++) {
        [columnNameToIndexMap setObject:[NSNumber numberWithInt:columnIdx]
                                 forKey:[[NSString stringWithUTF8String:sqlite3_column_name(statement, columnIdx)] lowercaseString]];
    }
    columnNamesSetup = YES;
}

- (void)kvcMagic:(id)object {
    
    int columnCount = sqlite3_column_count(statement);
    
    int columnIdx = 0;
    for (columnIdx = 0; columnIdx < columnCount; columnIdx++) {
        
        const char *c = (const char *)sqlite3_column_text(statement, columnIdx);
        
        // check for a null row
        if (c) {
            NSString *s = [NSString stringWithUTF8String:c];
            
            [object setValue:s forKey:[NSString stringWithUTF8String:sqlite3_column_name(statement, columnIdx)]];
        }
    }
}

- (NSDictionary *)resultDict {
    
    int num_cols = sqlite3_data_count(statement);
    
    if (num_cols > 0) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:num_cols];
        
        if (!columnNamesSetup) {
            [self setupColumnNames];
        }
        
        NSEnumerator *columnNames = [columnNameToIndexMap keyEnumerator];
        NSString *columnName = nil;
        while ((columnName = [columnNames nextObject])) {
            id objectValue = [self objectForColumnName:columnName];
            [dict setObject:objectValue forKey:columnName];
        }
        
        return [[dict copy] autorelease];
    }
    else {
        NSLog(@"Warning: There seem to be no columns in this set.");
    }
    
    return nil;
}

- (BOOL)next {
    
    int rc;
    BOOL retry;
    do {
        retry = NO;
        
        rc = sqlite3_step(statement);
        
        if (SQLITE_BUSY == rc || SQLITE_LOCKED == rc) {
            // this will happen if the db is locked, like if we are doing an update or insert.
            // in that case, retry the step... and maybe wait just 10 milliseconds.
            retry = YES;
            if (SQLITE_LOCKED == rc) {
                rc = sqlite3_reset(statement);
                if (rc != SQLITE_LOCKED) {
                    NSLog(@"Unexpected result from sqlite3_reset (%d) rs", rc);
                }
            }
            usleep(20);
        }
        else if (SQLITE_DONE == rc || SQLITE_ROW == rc) {
            // all is well, let's return.
        }
        else if (SQLITE_ERROR == rc) {
            NSLog(@"Error calling sqlite3_step (%d: %@) rs", rc, [connection lastErrorMessage]);
            break;
        } 
        else if (SQLITE_MISUSE == rc) {
            // uh oh.
            NSLog(@"Error calling sqlite3_step (%d: %@) rs", rc, [connection lastErrorMessage]);
            break;
        }
        else {
            // wtf?
            NSLog(@"Unknown error calling sqlite3_step (%d: %@) rs", rc, [connection lastErrorMessage]);
            break;
        }
        
    } while (retry);
    
    
    if (rc != SQLITE_ROW) {
        [self close];
    }
    
    return (rc == SQLITE_ROW);
}



- (int)columnIndexForName:(NSString*)columnName {
    
    if (!columnNamesSetup) {
        [self setupColumnNames];
    }
    
    columnName = [columnName lowercaseString];
    
    NSNumber *n = [columnNameToIndexMap objectForKey:columnName];
    
    if (n) {
        return [n intValue];
    }
    
    NSLog(@"Warning: I could not find the column named '%@'.", columnName);
    
    return -1;
}



- (int)intForColumn:(NSString*)columnName {
    return [self intForColumnIndex:[self columnIndexForName:columnName]];
}

- (int)intForColumnIndex:(int)columnIdx {
    return sqlite3_column_int(statement, columnIdx);
}

- (long)longForColumn:(NSString*)columnName {
    return [self longForColumnIndex:[self columnIndexForName:columnName]];
}

- (long)longForColumnIndex:(int)columnIdx {
    return (long)sqlite3_column_int64(statement, columnIdx);
}

- (long long int)longLongIntForColumn:(NSString*)columnName {
    return [self longLongIntForColumnIndex:[self columnIndexForName:columnName]];
}

- (long long int)longLongIntForColumnIndex:(int)columnIdx {
    return sqlite3_column_int64(statement, columnIdx);
}

- (BOOL)boolForColumn:(NSString*)columnName {
    return [self boolForColumnIndex:[self columnIndexForName:columnName]];
}

- (BOOL)boolForColumnIndex:(int)columnIdx {
    return ([self intForColumnIndex:columnIdx] != 0);
}

- (double)doubleForColumn:(NSString*)columnName {
    return [self doubleForColumnIndex:[self columnIndexForName:columnName]];
}

- (double)doubleForColumnIndex:(int)columnIdx {
    return sqlite3_column_double(statement, columnIdx);
}

- (NSString*)stringForColumnIndex:(int)columnIdx {
    
    if (sqlite3_column_type(statement, columnIdx) == SQLITE_NULL || (columnIdx < 0)) {
        return nil;
    }
    
    const char *c = (const char *)sqlite3_column_text(statement, columnIdx);
    
    if (!c) {
        // null row.
        return nil;
    }
    
    return [NSString stringWithUTF8String:c];
}

- (NSString*)stringForColumn:(NSString*)columnName {
    return [self stringForColumnIndex:[self columnIndexForName:columnName]];
}

- (NSDate*)dateForColumn:(NSString*)columnName {
    return [self dateForColumnIndex:[self columnIndexForName:columnName]];
}

- (NSDate*)dateForColumnIndex:(int)columnIdx {
    
    if (sqlite3_column_type(statement, columnIdx) == SQLITE_NULL || (columnIdx < 0)) {
        return nil;
    }
    
    return [NSDate dateWithTimeIntervalSince1970:[self doubleForColumnIndex:columnIdx]];
}


- (NSData*)dataForColumn:(NSString*)columnName {
    return [self dataForColumnIndex:[self columnIndexForName:columnName]];
}

- (NSData*)dataForColumnIndex:(int)columnIdx {
    
    if (sqlite3_column_type(statement, columnIdx) == SQLITE_NULL || (columnIdx < 0)) {
        return nil;
    }
    
    int dataSize = sqlite3_column_bytes(statement, columnIdx);
    
    NSMutableData *data = [NSMutableData dataWithLength:dataSize];
    
    memcpy([data mutableBytes], sqlite3_column_blob(statement, columnIdx), dataSize);
    
    return data;
}


- (NSData*)dataNoCopyForColumn:(NSString*)columnName {
    return [self dataNoCopyForColumnIndex:[self columnIndexForName:columnName]];
}

- (NSData*)dataNoCopyForColumnIndex:(int)columnIdx {
    
    if (sqlite3_column_type(statement, columnIdx) == SQLITE_NULL || (columnIdx < 0)) {
        return nil;
    }
    
    int dataSize = sqlite3_column_bytes(statement, columnIdx);
    
    NSData *data = [NSData dataWithBytesNoCopy:(void *)sqlite3_column_blob(statement, columnIdx) length:dataSize freeWhenDone:NO];
    
    return data;
}


- (BOOL)columnIndexIsNull:(int)columnIdx {
    return sqlite3_column_type(statement, columnIdx) == SQLITE_NULL;
}

- (BOOL)columnIsNull:(NSString*)columnName {
    return [self columnIndexIsNull:[self columnIndexForName:columnName]];
}

- (const unsigned char *)UTF8StringForColumnIndex:(int)columnIdx {
    
    if (sqlite3_column_type(statement, columnIdx) == SQLITE_NULL || (columnIdx < 0)) {
        return nil;
    }
    
    return sqlite3_column_text(statement, columnIdx);
}

- (const unsigned char *)UTF8StringForColumnName:(NSString*)columnName {
    return [self UTF8StringForColumnIndex:[self columnIndexForName:columnName]];
}

- (id)objectForColumnIndex:(int)columnIdx {
    int columnType = sqlite3_column_type(statement, columnIdx);
    
    id returnValue = nil;
    
    if (columnType == SQLITE_INTEGER) {
        returnValue = [NSNumber numberWithLongLong:[self longLongIntForColumnIndex:columnIdx]];
    }
    else if (columnType == SQLITE_FLOAT) {
        returnValue = [NSNumber numberWithDouble:[self doubleForColumnIndex:columnIdx]];
    }
    else if (columnType == SQLITE_BLOB) {
        returnValue = [self dataForColumnIndex:columnIdx];
    }
    else {
        //default to a string for everything else
        returnValue = [self stringForColumnIndex:columnIdx];
    }
    
    if (returnValue == nil) {
        returnValue = [NSNull null];
    }
    
    return returnValue;
}

- (id)objectForColumnName:(NSString*)columnName {
    return [self objectForColumnIndex:[self columnIndexForName:columnName]];
}

// returns autoreleased NSString containing the name of the column in the result set
- (NSString*)columnNameForIndex:(int)columnIdx {
    return [NSString stringWithUTF8String: sqlite3_column_name(statement, columnIdx)];
}


@end
