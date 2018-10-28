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

let isInit = authPlusApi.fetchInitialised()
let fetchClient = authPlusApi.fetchClient(clientId: "93a01ec8-7c6e-417b-aaf5-d2ce30d5bc29")

print(authPlus.machine.state)

isInit.done { initStatus in
    print("init done block")

    print(initStatus)
    if initStatus.initialized {
        authPlus.machine.state = .s_initialised
    } else {
        authPlus.machine.state = .s_uninitialised
    }
}.catch{ error in
    print("init error")
    print(error)
    authPlus.machine.state = .s_unavailable
}

fetchClient.done { client in
    print(client)
}.catch {_ in
    print("fetch client done error")
    authPlus.machine.state = .s_unavailable
}

let requiredSecrets = [    "auth-plus-client-app",
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

sleep(10)
