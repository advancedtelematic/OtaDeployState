import Foundation
import SwiftyRequest

import PromiseKit
import PMKFoundation

import AuthPlus
import Kube


let pmkQ = DispatchQueue(label: "pmkQ", qos: .default, attributes: .concurrent)
PromiseKit.conf.Q = (map: pmkQ, return: pmkQ)

let x = AuthPlusApi().isInitialised()

let authPlus = AuthPlus()

print(authPlus.machine.state)

x.done { initStatus in
    print("done block∫")

    print(initStatus)

    switch initStatus.isInitialised {
    case .initialised:
        authPlus.machine.state = .s_initialised
    case .uninitialised:
        authPlus.machine.state = .s_uninitialised
    }
}.catch {_ in
        print("done error")
        authPlus.machine.state = .s_unavailable
}

do {
    print("waiting")
    let initStatus = try x.wait()
    print(initStatus)

    switch initStatus.isInitialised {
    case .initialised:
        authPlus.machine.state = .s_initialised
    case .uninitialised:
        authPlus.machine.state = .s_uninitialised
    }

} catch {
    print("Unexpected error: \(error).")
    authPlus.machine.state = .s_unavailable
}


let cert = ClientCertificate(name: "ca.crt", path: "ca.crt")

let request = RestRequest(method: .get, url: "http://127.0.0.1:8001", containsSelfSignedCert: true, clientCertificate: cert)

request.responseData { response in
    switch response.result {
    case .success(let retval):
        print(String(data: retval, encoding: .utf8))
    case .failure(let error):
        print("Failed to get data response: \(error)")
    }
}

print(authPlus.machine.state)

sleep(10)
