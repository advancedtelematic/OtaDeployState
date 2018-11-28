# OtaDeployState

Checks the state of Auth Plus and Vault and configures them if needed.

## Env vars

- `AUTH_PLUS_URL`: "http://ota-auth-plus"
- `VAULT_CONFIG_PATH`: "/tmp/vault.json"
- `AUTH_PLUS_CONFIG_PATH`: "/tmp/clients.json"
- `POLL_TIME`: `600`, how often the ota state is checked

## Limitations

For RBAC if you specify `resourceNames` you can't add `create` as a verb. So the choice is give this access to all secrets, or create the secrets before running. The `deploy/generic-secrets.yaml` file creates the needed secrets, which are updated in the state machine.

## License

This code is licensed under the Mozilla Public License 2.0, a copy of which can be found in this repository. All code is copyright 2018 HERE Europe B.V.
