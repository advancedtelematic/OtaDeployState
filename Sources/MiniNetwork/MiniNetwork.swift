import Foundation
import PromiseKit
import SwiftyRequest
import enum SwiftyRequest.Result


public protocol MiniNetworkError: Error {
    var details: Error { get }
    var code: Int? { get }
}

open class MiniNetwork {
    public init() {}
    public struct ErrorObject: MiniNetworkError {
        public let code: Int?
        public let details: Error
    }

    open func errorObj(code: Int?, details: Error) -> MiniNetworkError {
        return ErrorObject(code: code, details: details)
    }

    public func defaultHandler<T: Decodable>(method: String, url: String, seal: Resolver<T>, response: RestResponse<T>) {
        switch response.result {
        case .success(let ret):
            seal.fulfill(ret)
        case .failure(let error):
            print("error during \(method) to \(url)")
            seal.reject(errorObj(code: response.response?.statusCode, details: error))
        }
    }

    public func asyncGet<T: Decodable>(url: String, token: String? = nil) -> Promise<T>  {
        return Promise<T> { seal in
            let request = RestRequest(method: .get, url: url)
            print("get to \(url)")
            if token != nil {
                request.credentials = .bearerAuthentication(token: token!)
            }
            request.responseObject { (response: RestResponse<T>) in
                self.defaultHandler(method: "get", url: url, seal: seal, response: response)
            }
        }
    }

    public func asyncPost<B: Encodable, R: Decodable>(url: String, body: B, token: String? = nil) -> Promise<R>  {
        return asyncSend(method: .post, url: url, body: body, token: token)
    }
    public func asyncPut<B: Encodable, R: Decodable>(url: String, body: B, token: String? = nil) -> Promise<R>  {
        return asyncSend(method: .put, url: url, body: body, token: token)
    }

    public func asyncSend<B: Encodable, R: Decodable>(method: HTTPMethod, url: String, body: B, token: String? = nil) -> Promise<R>  {
        return Promise<R> { seal in
            let request = RestRequest(method: method, url: url)
            print("post to \(url)")
            request.messageBody = try JSONEncoder().encode(body)
            if token != nil {
                request.credentials = .bearerAuthentication(token: token!)
            }
            // print(String(data: request.messageBody!, encoding: .utf8))
            request.responseObject { (response: RestResponse<R>) in
                self.defaultHandler(method: method.rawValue, url: url, seal: seal, response: response)
            }
        }
    }

    public func asyncPostForm<T: Decodable>(url: String, body: String, clientId: String, clientSecret: String) -> Promise<T>  {
        return Promise<T> { seal in
            let request = RestRequest(method: .post, url: url)
            // TODO: Handle auth credentials better
            request.credentials = .basicAuthentication(username: clientId, password: clientSecret)
            request.headerParameters = ["Content-Type" : "application/x-www-form-urlencoded; charset=utf-8"]
            request.messageBody = body.data(using: .utf8)
            print("post form to \(url)")
            request.responseObject { (response: RestResponse<T>) in
                self.defaultHandler(method: "post", url: url, seal: seal, response: response)
            }
        }
    }
}
