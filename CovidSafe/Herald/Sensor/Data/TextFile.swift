//
//  TextFile.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: MIT
//

import Foundation

class TextFile {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "Data.TextFile")
    private var file: URL?
    private let queue: DispatchQueue
    
    init(filename: String) {
        file = try? FileManager.default
        .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        .appendingPathComponent(filename)
        queue = DispatchQueue(label: "Sensor.Data.TextFile(\(filename))")
    }
    
    func empty() -> Bool {
        guard let file = file else {
            return true
        }
        return !FileManager.default.fileExists(atPath: file.path)
    }
    
    /// Append line to new or existing file
    func write(_ line: String) {
        queue.sync {
            guard let file = file else {
                return
            }
            guard let data = (line+"\n").data(using: .utf8) else {
                return
            }
            if FileManager.default.fileExists(atPath: file.path) {
                if let fileHandle = try? FileHandle(forWritingTo: file) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: file, options: .atomicWrite)
            }
        }
    }
    
    /// Overwrite file content
    func overwrite(_ content: String) {
        queue.sync {
            guard let file = file else {
                return
            }
            guard let data = content.data(using: .utf8) else {
                return
            }
            try? data.write(to: file, options: .atomicWrite)
        }
    }
    
    /// Quote value for CSV output if required.
    static func csv(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("'") || value.contains("’") else {
            return value
        }
        return "\"" + value + "\""

    }
}
