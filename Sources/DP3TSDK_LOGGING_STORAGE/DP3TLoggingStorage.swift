/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import Foundation
import os.log
import SQLite

public struct LogEntry: Identifiable {
    public let id: Int
    public let type: OSLogType
    public let timestamp: Date
    public let message: String
}

/// Storage used to persist Logs
public class DP3TLoggingStorage {
    /// Database connection
    private let database: Connection

    /// Name of the table
    let table = Table("logs")

    /// Column definitions
    let idColumn = Expression<Int>("id")
    let typeColumn = Expression<Int>("type")
    let timestampColumn = Expression<Int64>("timestamp")
    let messageColumn = Expression<String>("message")

    /// Initializer
    public init() throws {
        let filePath = DP3TLoggingStorage.getDatabasePath()
        database = try Connection(filePath.absoluteString, readonly: false)
        try createTable()
    }

    /// Create the table
    private func createTable() throws {
        try database.run(table.create(ifNotExists: true) { t in
            t.column(idColumn, primaryKey: .autoincrement)
            t.column(timestampColumn)
            t.column(typeColumn)
            t.column(messageColumn)
        })
    }

    public func log(_ string: String, type: OSLogType) {
        let timestamp = Date()
        let insert = table.insert(
            timestampColumn <- timestamp.millisecondsSince1970,
            messageColumn <- string,
            typeColumn <- Int(type.rawValue)
        )
        _ = try? database.run(insert)

        NotificationCenter.default.post(name: .init("org.dpppt.didAddLog"), object: nil)
    }

    /// Delete all entries
    public func emptyStorage() throws {
        try database.run(table.delete())
    }

    /// count of entries
    func count() throws -> Int {
        try database.scalar(table.count)
    }

    public func getLogs() throws -> [LogEntry] {
        let query = table.order(timestampColumn.desc)

        var logs: [LogEntry] = []
        for row in try database.prepare(query) {
            logs.append(LogEntry(id: row[idColumn],
                                 type: OSLogType(rawValue: UInt8(row[typeColumn])),
                                 timestamp: Date(milliseconds: row[timestampColumn]),
                                 message: row[messageColumn]))
        }

        return logs
    }

    /// get database path
    private static func getDatabasePath() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory.appendingPathComponent("DP3T_tracing_db").appendingPathExtension("sqlite")
    }
}

extension Date {
    var millisecondsSince1970: Int64 {
        return Int64((timeIntervalSince1970 * 1000.0).rounded())
    }

    init(milliseconds: Int64) {
        self = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    }
}
