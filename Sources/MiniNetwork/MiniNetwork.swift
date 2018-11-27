import Foundation
import PromiseKit
import SwiftyRequest
import enum SwiftyRequest.Result
import SwiftyBeaver

let log = SwiftyBeaver.self

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

    func logError(method: String, url: String, data: Data?, response: HTTPURLResponse?) {
        log.error("Error during \(method) to \(url)")
        if let r = response {
            log.error(String(r.statusCode))
        }
        if let d = data {
            log.debug(String(data: d, encoding: .utf8) ?? "Failed to decode error Data")
        }
    }

    public func defaultHandler<T: Decodable>(method: String, url: String, seal: Resolver<T>, response: RestResponse<T>) {
        switch response.result {
        case .success(let ret):
            seal.fulfill(ret)
        case .failure(let error):
            logError(method: method, url: url, data: response.data, response: response.response)
            seal.reject(errorObj(code: response.response?.statusCode, details: error))
        }
    }

    public func voidHandler(method: String, url: String, seal: Resolver<Void>, response: RestResponse<Void>) {
        switch response.result {
        case .success(_):
            seal.fulfill(Void())
        case .failure(let error):
            logError(method: method, url: url, data: response.data, response: response.response)
            seal.reject(errorObj(code: response.response?.statusCode, details: error))
        }
    }

    public func asyncGet<T: Decodable>(url: String, token: String? = nil, headerParameters: [String: String]? = nil) -> Promise<T>  {
        return Promise<T> { seal in
            let request = RestRequest(method: .get, url: url)
            log.debug("GET to \(url)")
            if token != nil {
                request.credentials = .bearerAuthentication(token: token!)
            }
            if headerParameters != nil {
                request.headerParameters = headerParameters!
            }
            request.responseObject { (response: RestResponse<T>) in
                self.defaultHandler(method: "get", url: url, seal: seal, response: response)
            }
        }
    }

    public func asyncPost<B: Encodable, R: Decodable>(url: String, body: B, token: String? = nil,  headerParameters: [String: String]? = nil) -> Promise<R>  {
        return asyncSend(method: .post, url: url, body: body, token: token, headerParameters: headerParameters)
    }
    public func asyncPut<B: Encodable, R: Decodable>(url: String, body: B, token: String? = nil, headerParameters: [String: String]? = nil) -> Promise<R>  {
        return asyncSend(method: .put, url: url, body: body, token: token, headerParameters: headerParameters)
    }

    public func asyncPutVoid<B: Encodable>(url: String, body: B, token: String? = nil, headerParameters: [String: String]? = nil) -> Promise<Void>  {
        return asyncSendVoid(method: .put, url: url, body: body, token: token, headerParameters: headerParameters)
    }


    public func asyncSend<B: Encodable, R: Decodable>(method: HTTPMethod, url: String, body: B, token: String? = nil, headerParameters: [String: String]? = nil) -> Promise<R>  {
        return attempt {
            return Promise<R> { seal in
                let request = RestRequest(method: method, url: url)
                log.debug("\(method) to \(url)")
                request.messageBody = try JSONEncoder().encode(body)
                if token != nil {
                    request.credentials = .bearerAuthentication(token: token!)
                }
                if headerParameters != nil {
                    request.headerParameters = headerParameters!
                }
                request.responseObject { (response: RestResponse<R>) in
                    self.defaultHandler(method: method.rawValue, url: url, seal: seal, response: response)
                }
            }
        }
    }

    public func asyncSendVoid<B: Encodable>(method: HTTPMethod, url: String, body: B, token: String? = nil, headerParameters: [String: String]? = nil) -> Promise<Void>  {
        return attempt {
            return Promise<Void> { seal in
                let request = RestRequest(method: method, url: url)
                log.debug("\(method) to \(url)")
                request.messageBody = try JSONEncoder().encode(body)
                if token != nil {
                    request.credentials = .bearerAuthentication(token: token!)
                }
                if headerParameters != nil {
                    request.headerParameters = headerParameters!
                }
                request.responseVoid(completionHandler: { (reponse: RestResponse<Void>) in
                    self.voidHandler(method: method.rawValue, url: url, seal: seal, response: reponse)
                })
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
            log.debug("POST form to \(url)")
            request.responseObject { (response: RestResponse<T>) in
                self.defaultHandler(method: "post", url: url, seal: seal, response: response)
            }
        }
    }
}

public extension String {
    func fromBase64() -> String? {
        guard let data = Data(base64Encoded: self) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func toBase64() -> String {
        return Data(self.utf8).base64EncodedString()
    }
}

public func getEnvironmentVar(_ name: String) -> String? {
    guard let rawValue = getenv(name) else { return nil }
    return String(utf8String: rawValue)
}

func attempt<T>(maximumRetryCount: Int = 3, delayBeforeRetry: DispatchTimeInterval = .seconds(2), _ body: @escaping () -> Promise<T>) -> Promise<T> {
    var attempts = 0
    func attempt() -> Promise<T> {
        attempts += 1
        return body().recover { error -> Promise<T> in
            guard attempts < maximumRetryCount else { throw error }
            log.debug("Retrying.")
            return after(delayBeforeRetry).then(on: nil, attempt)
        }
    }
    return attempt()
}

