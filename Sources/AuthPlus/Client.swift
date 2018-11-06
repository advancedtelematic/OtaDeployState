import Kube
import PromiseKit

public struct ClientState {
    let kube: Kube
    let authPlusApi: AuthPlusApi

    public init(kube: Kube?, authPlusApi: AuthPlusApi?) {
        self.kube = kube ?? Kube()
        self.authPlusApi = authPlusApi ?? AuthPlusApi()
    }

    public enum State {
        case created(AuthPlusApi.ClientMetadata)
        case inK8sOnly(AuthPlusApi.ClientMetadata)
        case doesNotExist(AuthPlusApi.ClientMetadata)
    }

    public func checkState(clientMetadata: AuthPlusApi.ClientMetadata) -> Promise<State> {
        return Promise<State> { seal in
            firstly {
                self.kube.fetchSecret(name: clientMetadata.clientName) as Promise<Kube.Secret<AuthPlusApi.Client>>
            }.then({ secret in
                self.authPlusApi.fetchClient(clientId: secret.data.clientId)
            }).done({ client in
                seal.fulfill(State.created(clientMetadata))
            }).catch({ (error) in
                switch error {
                case is AuthPlusHttpError:
                    print("some auth plus error")
                    seal.fulfill(State.inK8sOnly(clientMetadata))
                case is KubeHttpError:
                    print("some kube error")
                    seal.fulfill(State.doesNotExist(clientMetadata))
                default:
                    print("some other error")
                    seal.reject(error)
                }
            })
        }
    }
}
