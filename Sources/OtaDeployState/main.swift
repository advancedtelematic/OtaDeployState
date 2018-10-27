import Foundation
import SwiftyRequest

import PromiseKit
import PMKFoundation

import AuthPlus
import Kube


let pmkQ = DispatchQueue(label: "pmkQ", qos: .default, attributes: .concurrent)
PromiseKit.conf.Q = (map: pmkQ, return: pmkQ)

let authPlusApi = AuthPlusApi()
let isInit = authPlusApi.isInitialised()

let fetchClient = authPlusApi.fetchClient(clientId: "93a01ec8-7c6e-417b-aaf5-d2ce30d5bc29")

let authPlus = AuthPlus()

print(authPlus.machine.state)

isInit.done { initStatus in
    print("init done block∫")

    print(initStatus)

    switch initStatus.isInitialised {
    case .initialised:
        authPlus.machine.state = .s_initialised
    case .uninitialised:
        authPlus.machine.state = .s_uninitialised
    }
}.catch {_ in
        print("init done error")
        authPlus.machine.state = .s_unavailable
}

fetchClient.done { client in
    print("fetch done block∫")

    print(client)
    }.catch {_ in
        print("fetch client done error")
        authPlus.machine.state = .s_unavailable
}


do {
    print("waiting")
    let initStatus = try isInit.wait()
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

/*
let cert = ClientCertificate(name: "ca.crt", path: "ca.crt")


let request = RestRequest(method: .get, url: "http://127.0.0.1:8001", containsSelfSignedCert: true, clientCertificate: cert)


*/
let requiredSecrets = [
    "auth-plus-client-app",
    "auth-plus-client-auditor"
]


print(authPlus.machine.state)

let kube = Kube()

//let fetchSecret = kube.fetchSecret(name: "auth-plus-client-app")

let secretPromises = requiredSecrets.map { (name) -> Promise<Kube.Secret> in
    return kube.fetchSecret(name: name)
}


when(fulfilled: secretPromises).done { secrets in
    print("in secrets")
    print(secrets)
}.catch { error in
    print("in error")
    print(error)
}

/*
fetchSecret.done { secret in
    print("fetch secret done block∫")
    print(secret)
    print("print encoder")
    let encoded = try! JSONEncoder().encode(secret)
    print(String(data: encoded, encoding: .utf8))
    print("done printing encoder")
    }.catch {error in
        print("fetch secret done error")
        print(error.localizedDescription)
        print(error)
}*/

sleep(10)
