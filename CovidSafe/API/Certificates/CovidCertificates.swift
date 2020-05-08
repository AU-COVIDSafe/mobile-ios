//
//  Certificates.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import Foundation
struct CovidCertificates {
    
    static let AmazonRootCA1: SecCertificate = CovidCertificates.certificate(filename: "AmazonRootCA1")
    static let AmazonRootCA2: SecCertificate = CovidCertificates.certificate(filename: "AmazonRootCA2")
    static let AmazonRootCA3: SecCertificate = CovidCertificates.certificate(filename: "AmazonRootCA3")
    static let AmazonRootCA4: SecCertificate = CovidCertificates.certificate(filename: "AmazonRootCA4")
    static let SFSRootCA: SecCertificate = CovidCertificates.certificate(filename: "SFSRootCAG2")
    
    private static func certificate(filename: String) -> SecCertificate {
        
        let filePath = Bundle.main.path(forResource: filename, ofType: "cer")!
        let data = try! Data(contentsOf: URL(fileURLWithPath: filePath))
        let certificate = SecCertificateCreateWithData(nil, data as CFData)!
        
        return certificate
    }
}
