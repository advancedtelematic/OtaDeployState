import Foundation
import PromiseKit
import AuthPlus
import Vault
import MiniNetwork
import SwiftyBeaver

let log = SwiftyBeaver.self
let console = ConsoleDestination()  // log to Xcode Consol
log.addDestination(console)
console.format = "$DHH:mm:ss.SSS$d $C$L$c $N:$l - $M"

let pmkQ = DispatchQueue(label: "pmkQ", qos: .default, attributes: .concurrent)
PromiseKit.conf.Q = (map: pmkQ, return: pmkQ)

let vaultConfigPath = getEnvironmentVar("VAULT_CONFIG_PATH") ?? "/usr/local/etc/ota-deploy-state/vault.json"
log.info("Vault clients config path: \(vaultConfigPath)")

let authPlusConfigPath = getEnvironmentVar("AUTH_PLUS_CONFIG_PATH") ?? "/usr/local/etc/ota-deploy-state/clients.json"
log.info("Auth plus config path: \(authPlusConfigPath)")

sleep(10)

let pollTime = UInt32(getEnvironmentVar("POLL_TIME") ?? "600") ?? 600

while true {
    log.info("Checking state.")
    let conf = VaultConfigs(path: URL(fileURLWithPath: vaultConfigPath))
    let _ = conf.vaults.map { config -> Vault in
        let vault = Vault(config: config)
        vault.machine.state = .unknown
        return vault
    }

    sleep(10)

    let authPlus = AuthPlus()
    authPlus.clientsConfigPath = authPlusConfigPath
    authPlus.machine.state = .unknown

    fflush(stdout)
    sleep(pollTime)
}
