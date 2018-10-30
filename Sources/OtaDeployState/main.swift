import Foundation
import PromiseKit
import AuthPlus

let pmkQ = DispatchQueue(label: "pmkQ", qos: .default, attributes: .concurrent)
PromiseKit.conf.Q = (map: pmkQ, return: pmkQ)

let authPlus = AuthPlus()

authPlus.machine.state = .unknown

// TODO: Fix process from exiting instantly
sleep(10)
