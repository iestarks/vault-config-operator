# Vault Agent Governance Example

This bundle establishes the integration boundary described in the architecture
guide:

- `vault-config-operator` is the sole writer of Vault configuration.
- The Vault agent receives a read-only policy through Kubernetes auth.
- Agent-proposed changes are committed as CRDs and reviewed before the operator
  reconciles them.
- Emergency seal and unseal remain dedicated, explicitly authorized operations;
  they are not granted by this policy.

Review the namespace, service account, auth mount path, and operator
authentication role before applying:

```bash
kubectl apply -f vault-agent-readonly.yaml
kubectl -n vault-agents wait --for=condition=Ready \
  policy/vault-agent-readonly --timeout=120s
```

The resources are intentionally committed together so policy and role changes
receive one Git review and one auditable operator reconciliation.