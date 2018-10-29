import Foundation
import SwiftyRequest

import PromiseKit
import PMKFoundation

import AuthPlus
import Kube
import MiniNetwork

let pmkQ = DispatchQueue(label: "pmkQ", qos: .default, attributes: .concurrent)
PromiseKit.conf.Q = (map: pmkQ, return: pmkQ)

let authPlusApi = AuthPlusApi()
let authPlus = AuthPlus()

authPlus.machine.state = .unknown

print("hello")
/*
let fetchClient = authPlusApi.fetchClient(clientId: "93a01ec8-7c6e-417b-aaf5-d2ce30d5bc29")
fetchClient.done { client in
    print(client)
}.catch {_ in
    print("fetch client done error")
    authPlus.machine.state = .unavailable
}

let token = authPlusApi.createToken()
token.done { token in
    print(token)
}.catch { error in
    print(error)
    print("token done error")
}

let requiredSecrets = [
    "auth-plus-client-app",
//    "auth-plus-client-auditor"
]

let kube = Kube()

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
*/
sleep(10)
