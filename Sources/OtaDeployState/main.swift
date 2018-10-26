import Foundation
import SwiftyRequest
import AuthPlus
import PromiseKit
import PMKFoundation

let x = AuthPlusApi().isInitialised()

let authPlus = AuthPlus()


print(authPlus.machine.state)


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

print(authPlus.machine.state)

sleep(10)
