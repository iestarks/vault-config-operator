# Allow all capabilities on all paths (admin policy)
path "/*" {
  capabilities = ["create", "read", "update", "delete", "list","sudo"]
}

# Explicit permissions for KV secret engine list operations
# This is needed for the preflight capability check used by "vault kv list secret/"
path "secret/" {
  capabilities = ["list"]
}

path "secret/metadata/*" {
  capabilities = ["list", "read", "create", "update", "delete"]
}

path "secret/data/*" {
  capabilities = ["list", "read", "create", "update", "delete"]
}

# Allow UI mounts introspection (required for vault kv commands)
path "sys/internal/ui/mounts/secret" {
  capabilities = ["read", "list"]
}