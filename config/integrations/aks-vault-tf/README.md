# AKS Vault Integration (vault-tf)

Declarative management of the `kubernetes/` auth engine on the Hashicorp-Azure-LLM
AKS Vault (`https://vault.starksenterprise.com`) by this operator, replacing the
manual `vault auth` CLI bootstrap performed on 2026-08-26.

## Architecture

| Concern | Mechanism |
|---|---|
| Vault reachability | Public hostname resolves (LE SAN match); traffic pinned in-cluster via `hostAliases` -> `vault-tf-active` ClusterIP (`10.0.54.10`) |
| Trust | Namespace Secret `vault-internal-ca` holds the served chain (`ca.crt`); referenced through `spec.connection.tLSConfig.tlsSecretName` |
| Operator identity | Its own ServiceAccount JWT through the existing `kubernetes/` mount, role `vault-config-operator-manager` (periodic 24h token, policy `vault-config-operator-mgmt`) |
| Least privilege | Bootstrap role is pre-created out-of-band (see README "Bootstrap"); all later policy/role objects reconcile here |

## One-time prerequisites

```bash
CTX=vault-aks-260709-h687xe2-v2-tf-admin
# 1. Deploy operator (ServiceMonitor excluded until prometheus CRDs exist)
make deploy IMG=quay.io/redhat-cop/vault-config-operator:v1.0.2 KUBE_CONTEXT=$CTX || true
./bin/kubectl --context $CTX apply -f <(./bin/kustomize build config/default | grep -v 'kind: ServiceMonitor')
# 2. Pin Vault LB IP to the ClusterIP so the LE SAN matches over cluster-local routing
VIPC=$(kubectl --context $CTX get svc vault-tf-active -n vault-tf -o jsonpath='{.spec.clusterIP}')
kubectl --context $CTX -n vault-config-operator patch deploy vault-config-operator-controller-manager \
  --type merge -p "{\"spec\":{\"template\":{\"spec\":{\"hostAliases\":[{\"hostnames\":[\"vault.starksenterprise.com\"],\"ip\":\"$VIPC\"}]}}}}"
# 3. CA trust material for verification
echo | openssl s_client -connect vault.starksenterprise.com:443 -showcerts 2>/dev/null \
 | sed -n '/BEGIN CERT/,/END CERT/p' \
 | kubectl --context $CTX create secret generic vault-internal-ca -n vault-config-operator \
     --from-file=ca.crt=/dev/stdin
```

## Bootstrap (performed once with admin credentials, then never again needed)

Policy `vault-config-operator-mgmt` + role bound to the controller SA:

```bash
export VAULT_ADDR=https://vault.starksenterprise.com VAULT_TOKEN=<admin>
vault policy write vault-config-operator-mgmt - <<'EOF'
path "sys/policies/acl/*" { capabilities = ["create","read","update","delete","list","sudo"] }
path "auth/kubernetes/*" { capabilities = ["create","read","update","delete","list","sudo"] }
path "sys/auth"          { capabilities = ["read","sudo"] }
path "sys/auth/*"        { capabilities = ["read","sudo"] }
EOF
vault write auth/kubernetes/role/vault-config-operator-manager \
  bound_service_account_names=vault-config-operator-controller-manager \
  bound_service_account_namespaces=vault-config-operator \
  policies=vault-config-operator-mgmt ttl=1h period=24h
```

## Apply

```bash
kubectl --context $CTX apply -k config/integrations/aks-vault-tf
```

Reconciliation recreates (or ensures) the following Vault server-side objects:

* ACL policy `agent-a` (read/list on `kv2/agents/*`)
* `KubernetesAuthEngineConfig` on mount `kubernetes`
* `KubernetesAuthEngineRole agent-a` bound to `system:serviceaccount:agents:agent-a`

Then apply the sample workload:

```bash
kubectl --context $CTX apply -f config/integrations/aks-vault-tf/agent-workload.yaml
```

## Validation (observed live)

* Operator SA login to Vault succeeds and returns policy `vault-config-operator-mgmt`.
* Reconciled role + policy land in Vault:
  `vault read auth/kubernetes/role/agent-a` → namespaces `[agents]`, policies `[agent-a]`.
* End-to-end from the pod:
  `POST /v1/auth/kubernetes/login` → `client_token` → `GET kv2/data/agents/demo`
  returns the seeded `agents/agent-a` identity.

## Known environmental caveat (cluster, not config)

On this AKS cluster the operator pod is **cluster-scoped** and must sync caches for
~78 CRD types + cluster secrets/configmaps/namespaces/endpoints within
controller-runtime's 2-minute startup window. On very small node pools (2 nodes),
cache-sync can time out and the manager crash-loops. Mitigations:

* `make deploy` installs exactly the CRD+RBAC set this branch declares (no gap).
* For sustained operation, run the operator in a cluster with ≥3 control-plane
  nodes, or build+push this fork's image (`make docker-build`/`make docker-push`)
  so the binary watches only this repo's CRD set (the fork source does not
  include kerberos/cf/aliyun/radius/oci reconcilers).

