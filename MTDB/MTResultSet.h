//
//  MTResultSet.h
//  MTDB
//
//  Created by Paul Soucy on 2/1/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//


@class MTDatabase;
@class MTStatement;

@interface MTResultSet : NSObject {
    MTDatabase *parentDB;
    MTStatement *statement;
    
    NSString *query;
    NSMutableDictionary *columnNameToIndexMap;
    BOOL columnNamesSetup;
}

@property (retain) NSString *query;
@property (retain) NSMutableDictionary *columnNameToIndexMap;
@property (retain) MTStatement *statement;

+ (id)resultSetWithStatement:(MTStatement *)statement usingParentDatabase:(MTDatabase*)aDB;

- (void)close;

- (void)setParentDB:(MTDatabase *)newDb;

- (BOOL)next;
- (BOOL)hasAnotherRow;

- (int)columnCount;

- (int)columnIndexForName:(NSString*)columnName;
- (NSString*)columnNameForIndex:(int)columnIdx;

- (int)intForColumn:(NSString*)columnName;
- (int)intForColumnIndex:(int)columnIdx;

- (long)longForColumn:(NSString*)columnName;
- (long)longForColumnIndex:(int)columnIdx;

- (long long int)longLongIntForColumn:(NSString*)columnName;
- (long long int)longLongIntForColumnIndex:(int)columnIdx;

- (BOOL)boolForColumn:(NSString*)columnName;
- (BOOL)boolForColumnIndex:(int)columnIdx;

- (double)doubleForColumn:(NSString*)columnName;
- (double)doubleForColumnIndex:(int)columnIdx;

- (NSString*)stringForColumn:(NSString*)columnName;
- (NSString*)stringForColumnIndex:(int)columnIdx;

- (NSDate*)dateForColumn:(NSString*)columnName;
- (NSDate*)dateForColumnIndex:(int)columnIdx;

- (NSData*)dataForColumn:(NSString*)columnName;
- (NSData*)dataForColumnIndex:(int)columnIdx;

- (const unsigned char *)UTF8StringForColumnIndex:(int)columnIdx;
- (const unsigned char *)UTF8StringForColumnName:(NSString*)columnName;

// returns one of NSNumber, NSString, NSData, or NSNull
- (id)objectForColumnName:(NSString*)columnName;
- (id)objectForColumnIndex:(int)columnIdx;

/*
 If you are going to use this data after you iterate over the next row, or after you close the
 result set, make sure to make a copy of the data first (or just use dataForColumn:/dataForColumnIndex:)
 If you don't, you're going to be in a world of hurt when you try and use the data.
 */
- (NSData*)dataNoCopyForColumn:(NSString*)columnName NS_RETURNS_NOT_RETAINED;
- (NSData*)dataNoCopyForColumnIndex:(int)columnIdx NS_RETURNS_NOT_RETAINED;

- (BOOL)columnIndexIsNull:(int)columnIdx;
- (BOOL)columnIsNull:(NSString*)columnName;

- (void)kvcMagic:(id)object;
- (NSDictionary *)resultDict;

@end

