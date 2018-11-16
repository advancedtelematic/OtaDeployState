import Foundation
import PromiseKit
import AuthPlus
import Vault
import MiniNetwork

let pmkQ = DispatchQueue(label: "pmkQ", qos: .default, attributes: .concurrent)
PromiseKit.conf.Q = (map: pmkQ, return: pmkQ)

let vaultConfigPath = getEnvironmentVar("VAULT_CONFIG_PATH") ?? "/usr/local/etc/ota-deploy-state/vault.json"

// TODO: wait for k8s better
sleep(10)

let pollTime = UInt32(getEnvironmentVar("POLL_TIME") ?? "600") ?? 600

while true {

    print("Vault clients config path: \(vaultConfigPath)")
    let conf = VaultConfigs(path: URL(fileURLWithPath: vaultConfigPath))
    let _ = conf.vaults.map { config -> Vault in
        let vault = Vault(config: config)
        vault.machine.state = .unknown
        return vault
    }

    sleep(10)

    let authPlus = AuthPlus()
    authPlus.clientsConfigPath = getEnvironmentVar("AUTH_PLUS_CONFIG_PATH") ?? "/usr/local/etc/ota-deploy-state/clients.json"
    authPlus.machine.state = .unknown

    sleep(pollTime)
}
