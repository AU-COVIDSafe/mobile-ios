//
//  DataUploadS3.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import Foundation

class DataUploadS3 {
    static func uploadJSONData(data: Data, presignedUrl: String, completion: @escaping (Bool, Swift.Error?) -> Void) {
        guard let url = URL(string: presignedUrl) else {
            completion(false, nil)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        
        let uploadRequest = CovidNetworking.shared.session.upload(data,
                                                                  with: request,
                                                                  interceptor: CovidRequestRetrier(retries: 3)
        ).validate().response { (response) in
            switch response.result {
            case .success:
                completion(true, nil)
            case let .failure(error):
                completion(false, error)
            }
        }
        uploadRequest.resume()
    }
}
