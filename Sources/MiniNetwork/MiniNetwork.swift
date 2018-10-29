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

public func asyncPost<B: Encodable, R: Decodable>(url: String, body: B) -> Promise<R>  {
    return Promise<R> { seal in
        let request = RestRequest(method: .post, url: url)
        print("post to \(url)")
        request.messageBody = try JSONEncoder().encode(body)
        request.responseObject { (response: RestResponse<R>) in
            defaultHandler(method: "post", url: url, seal: seal, result: response.result)
        }
    }
}

public func asyncPostForm<T: Decodable>(url: String, body: String) -> Promise<T>  {
    return Promise<T> { seal in
        let request = RestRequest(method: .post, url: url)
        let clientId = "foo"
        let clientSecet = "bar"
        request.credentials = .basicAuthentication(username: clientId, password: clientSecet)
        request.headerParameters = ["Content-Type" : "application/x-www-form-urlencoded; charset=utf-8"]
        request.messageBody = body.data(using: .utf8)
        print("post form to \(url)")
        request.responseObject { (response: RestResponse<T>) in
            defaultHandler(method: "post", url: url, seal: seal, result: response.result)
        }
    }
}
