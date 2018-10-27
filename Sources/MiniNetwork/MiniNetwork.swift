import PromiseKit
import SwiftyRequest
import enum SwiftyRequest.Result
import os.log

// For auth requests to K8S
let cert = ClientCertificate(name: "ca.crt", path: "ca.crt")
let request = RestRequest(method: .get, url: "http://127.0.0.1:8001", containsSelfSignedCert: true, clientCertificate: cert)

public func defaultHandler<T: Codable>(method: String, url: String, seal: Resolver<T>, result: Result<T>) {
    switch result {
    case .success(let ret):
        seal.fulfill(ret)
    case .failure(let error):
        print("error during \(method) to \(url)")
        seal.reject(error)
    }
}

public func asyncGet<T: Codable>(url: String) -> Promise<T>  {
    return Promise<T> { seal in
        let request = RestRequest(method: .get, url: url)
        print("get to \(url)")
        request.responseObject { (response: RestResponse<T>) in
            defaultHandler(method: "get", url: url, seal: seal, result: response.result)
        }
    }
}
