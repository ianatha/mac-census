//
//  File.swift
//  i3
//
//  Created by Ian Atha on 2/6/18.
//  Copyright © 2018 Ian Atha. All rights reserved.
//

import Foundation
import Cocoa

extension URL {
    func extendedAttribute(forName name: String) -> Data? {
        do {
            return try self.withUnsafeFileSystemRepresentation { fileSystemPath -> Data? in
                // Determine attribute size:
                let length = getxattr(fileSystemPath, name, nil, 0, 0, 0)
                guard length >= 0 else { throw URL.posixError(errno) }

                // Create buffer with required size:
                var data = Data(count: length)

                // Retrieve attribute:
                let data_count = data.count
                let result = data.withUnsafeMutableBytes {
                    getxattr(fileSystemPath, name, $0, data_count, 0, 0)
                }

                guard result >= 0 else { return nil }
                return data
            }
        } catch {
            return nil
        }
    }

    private static func posixError(_ err: Int32) -> NSError {
        return NSError(domain: NSPOSIXErrorDomain, code: Int(err),
                       userInfo: [NSLocalizedDescriptionKey: String(cString: strerror(err))])
    }
}

class I3Configuration {
    var fleetImage: NSImage?
    var fleetFriendlyName: String = "Mamabear Test"
    var backendURL: String = "http://localhost:7777/inventory/mamabear"

    init(fleetImage: NSImage, fleetFriendlyName: String) {
        self.fleetImage = fleetImage
        self.fleetFriendlyName = fleetFriendlyName
    }

    init() {
        let appPath = Bundle.main.bundleURL
        if let fleetFriendlyNameData = appPath.extendedAttribute(forName: "io.mamabear.i3.FleetFriendlyName") {
            self.fleetFriendlyName = String(data: fleetFriendlyNameData, encoding: String.Encoding.utf8)!
        }
        if let fleetLogoBase64 = appPath.extendedAttribute(forName: "io.mamabear.i3.FleetLogo") {
            if let fleetLogoData = NSData(base64Encoded: fleetLogoBase64) {
                self.fleetImage = NSImage(data: fleetLogoData as Data)
            }
        }
        if let backendURLData = appPath.extendedAttribute(forName: "io.mamabear.i3.BackendURL") {
            self.backendURL = String(data: backendURLData, encoding: String.Encoding.utf8)!
        }
    }
}
