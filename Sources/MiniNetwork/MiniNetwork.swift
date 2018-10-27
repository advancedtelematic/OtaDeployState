import PromiseKit
import SwiftyRequest
import enum SwiftyRequest.Result
import os.log

public func defaultHandler<T: Codable>(seal: Resolver<T>, result: Result<T>) {
    switch result {
    case .success(let ret):
        seal.fulfill(ret)
    case .failure(let error):
        seal.reject(error)
    }
}

public func asyncGet<T: Codable>(url: String) -> Promise<T>  {
    return Promise<T> { seal in
        let request = RestRequest(method: .get, url: url)
        print("get to \(url)")
        request.responseObject { (response: RestResponse<T>) in
            defaultHandler(seal: seal, result: response.result)
        }
    }
}
