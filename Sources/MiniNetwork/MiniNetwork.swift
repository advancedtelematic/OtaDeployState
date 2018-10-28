import Foundation
import PromiseKit
import SwiftyRequest
import enum SwiftyRequest.Result

public func defaultHandler<T: Decodable>(method: String, url: String, seal: Resolver<T>, result: Result<T>) {
    switch result {
    case .success(let ret):
        seal.fulfill(ret)
    case .failure(let error):
        print("error during \(method) to \(url)")
        seal.reject(error)
    }
}

public func asyncGet<T: Decodable>(url: String) -> Promise<T>  {
    return Promise<T> { seal in
        let request = RestRequest(method: .get, url: url)
        print("get to \(url)")
        request.responseObject { (response: RestResponse<T>) in
            defaultHandler(method: "get", url: url, seal: seal, result: response.result)
        }
    }
}
