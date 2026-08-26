# 🏗️ Vault Integration Architecture Guide

**A Browser-Friendly Interactive Guide to Vault-Agent + USEA + Operator + MCP Policy-Gate**

Deployable manifests for the recommended read-only agent boundary are in
[`docs/examples/vault-agent-governance`](examples/vault-agent-governance/README.md).
The agent may recommend these resources, but only the operator reconciles them
to Vault.

---

## 📊 Quick Overview

Three complementary systems for managing HashiCorp Vault in production:

```mermaid
graph TB
    subgraph Systems["🏛️ Three Systems"]
        Agent["🤖 Vault-Agent<br/>(CRD Renderer)"]
        USEA["🧭 USEA<br/>(Validation + Routing)"]
        Operator["⚙️ Vault-Operator<br/>(Kubernetes Native)"]
        Bridge["🔌 Operator Bridge<br/>(Primary Delivery)"]
        Gate["🛡️ MCP Policy-Gate<br/>(AI-SDLC Governance)"]
    end
    
    subgraph Vault["🔑 Vault Cluster"]
        VaultAPI["Vault API<br/>(Source of Truth)"]
    end
    
    subgraph DevOps["👥 User Workflows"]
        Chat["💬 Interactive Chat<br/>(Agent)"]
        GitOps["📦 Git-First<br/>(Operator)"]
        Review["🔍 PR Review<br/>(Policy-Gate)"]
    end
    
    Agent -->|Render only<br/>apply: false| USEA
    USEA -->|Validate allowlisted CRD| Bridge
    Bridge -->|Accepted manifest| Operator
    USEA -.->|Fallback on absent, unreachable, or 5xx| GitOps
    Operator -->|Declarative| VaultAPI
    Gate -->|Governs| Agent
    Gate -->|Governs| USEA
    Gate -->|Governs| Operator
    
    Chat -->|Explicit admin request| Agent
    GitOps -->|Reviewed manifest| Operator
    Review -->|Uses| Gate
    
    style Agent fill:#667eea,color:#fff,stroke:#764ba2,stroke-width:2px
    style USEA fill:#17a2b8,color:#fff,stroke:#117a8b,stroke-width:2px
    style Operator fill:#28a745,color:#fff,stroke:#1e7e34,stroke-width:2px
    style Bridge fill:#20c997,color:#fff,stroke:#138f70,stroke-width:2px
    style Gate fill:#ffc107,color:#000,stroke:#ff9800,stroke-width:2px
    style VaultAPI fill:#dc3545,color:#fff,stroke:#b71c1c,stroke-width:2px
```

---

## 🎯 The Problem

An ungoverned direct agent write could collide with the operator's declarative
state. The integration blocks that path and routes configuration requests
through USEA validation:

```mermaid
graph LR
    subgraph Problem["❌ COLLISION RISK"]
        Agent["Agent: 'Configure<br/>AWS auth'<br/>(direct write blocked)"]
        Operator["Operator: 'Apply<br/>AWSConfig CRD'"]
        Vault["Vault<br/>Config"]
    end
    
    Agent -.->|Direct write blocked| Vault
    Operator -->|Writes| Vault
    
    Vault -->|"Last Write<br/>Wins"| Conflict["⚠️ CONFLICT<br/>Lost Changes<br/>No Audit Trail"]
    
    style Agent fill:#ff6b6b,color:#fff
    style Operator fill:#ff6b6b,color:#fff
    style Vault fill:#ffc107,color:#000
    style Conflict fill:#dc3545,color:#fff
```

**Consequences:**
- ❌ Conflicting writes (last update wins)
- ❌ Lost configuration changes
- ❌ No audit trail for manual edits
- ❌ Credentials scattered across systems
- ❌ No drift detection or auto-repair

---

## ✅ The Solution: Complementary Model

**Give each system a distinct responsibility:**

```mermaid
graph TB
    subgraph Architecture["✅ COMPLEMENTARY ARCHITECTURE"]
      Agent["🤖 AGENT<br/>Render proposal<br/>(Never applies)"]
      USEA["🧭 USEA<br/>Validate + route"]
      Bridge["🔌 OPERATOR BRIDGE<br/>Primary delivery"]
        Operator["⚙️ OPERATOR<br/>Declarative State<br/>Management<br/>(Write Authority)"]
        Gate["🛡️ POLICY-GATE<br/>Safety Governance<br/>(Oversight)"]
    end
    
    subgraph Vault["🔑 Vault Cluster"]
        VaultAPI["Vault API"]
    end
    
    subgraph Git["📦 Git<br/>Single Source of Truth"]
        CRDs["Reviewed CRD Manifests<br/>in Git"]
        Policies["Policies<br/>in Git"]
    end
    
    Agent -->|Render only<br/>apply: false| USEA
    USEA -->|Validate allowlisted CRD| Bridge
    Bridge -->|Accepted CRD| Operator
    USEA -.->|Absent, unreachable, or 5xx| CRDs
    
    Operator -->|Reads/Writes| VaultAPI
    Operator -->|Reconciles| CRDs
    Operator -->|Manages| Policies
    
    Gate -->|Reviews<br/>Blocks| Agent
    Gate -->|Reviews<br/>Blocks| USEA
    Gate -->|Reviews<br/>Blocks| Operator
    Gate -->|Reviews<br/>Blocks| CRDs
    Gate -->|Reviews<br/>Blocks| Policies
    
    CRDs -->|Source| Operator
    Policies -->|Source| Operator
    
    style Agent fill:#667eea,color:#fff,stroke:#764ba2,stroke-width:3px
    style USEA fill:#17a2b8,color:#fff,stroke:#117a8b,stroke-width:3px
    style Bridge fill:#20c997,color:#fff,stroke:#138f70,stroke-width:3px
    style Operator fill:#28a745,color:#fff,stroke:#1e7e34,stroke-width:3px
    style Gate fill:#ffc107,color:#000,stroke:#ff9800,stroke-width:3px
    style VaultAPI fill:#dc3545,color:#fff,stroke:#b71c1c,stroke-width:2px
    style CRDs fill:#764ba2,color:#fff,stroke:#667eea,stroke-width:2px
    style Policies fill:#764ba2,color:#fff,stroke:#667eea,stroke-width:2px
```

**Key Boundaries:**
- ✅ **Operator** = Sole authority for writing Vault config
- ✅ **Agent** = Read-only, except rare emergency seal/unseal
- ✅ **Policy-Gate** = Governs prompts, policies, and CRDs

---

## 🔍 System Deep-Dive

### 1️⃣ Vault-Agent (LLM-Powered Interactive Agent)

**What it does:**
- Real-time chat interface for Vault cluster management
- Diagnostics and troubleshooting (LLM-powered)
- Emergency operations (seal/unseal)
- Interactive decision-making with human approval

**Architecture:**
```mermaid
graph LR
    User["👤 User<br/>(Google Sign-In)"]
    AAD["🔐 Azure AD<br/>Groups"]
    Web["💬 FastAPI<br/>Web UI"]
    CLI["⌨️ CLI<br/>Mode"]
    LLM["🤖 LangChain<br/>Agent + CrewAI"]
    
    Tools["🛠️ Tools"]
    VaultAPI["🔑 Vault API"]
    
    User -->|Auth| AAD
    AAD -->|admin/readonly| Web
    AAD -->|admin/readonly| CLI
    Web --> LLM
    CLI --> LLM
    LLM --> Tools
    Tools --> VaultAPI
    
    style User fill:#667eea,color:#fff
    style AAD fill:#764ba2,color:#fff
    style Web fill:#667eea,color:#fff
    style CLI fill:#667eea,color:#fff
    style LLM fill:#764ba2,color:#fff
    style Tools fill:#ff6b6b,color:#fff
    style VaultAPI fill:#dc3545,color:#fff
```

**Available Tools:**
| Tool | Purpose | Permission |
|------|---------|-----------|
| `get_cluster_snapshot()` | Monitor cluster health | Everyone |
| `run_vault_command()` | Execute Vault CLI | ACL-gated |
| `seal_node()` | Emergency seal | Admin-only |
| `unseal_node()` | Emergency unseal | Admin-only |

**✅ Strengths:**
- 🧠 Intelligence: LLM diagnoses problems
- 🎯 Interactive: Real-time chat with dry-run mode
- ⚡ Agile: Ad-hoc operations without YAML boilerplate
- 🌍 Multi-provider: Claude, Gemini, OpenAI

**❌ Weaknesses:**
- 📝 No version control: Config lives in Vault API, not git
- 🔄 No drift detection: Manual changes survive forever
- 🔑 Credential sprawl: Pod needs full Vault admin token
- 👥 Single-instance: Can't isolate by team/namespace

---

### 2️⃣ Vault Config Operator (Kubernetes-Native)

**What it does:**
- Declarative infrastructure-as-code via CRDs
- Continuous drift detection and auto-repair
- GitOps-native (Helm, Kustomize, ArgoCD)
- Multi-tenant namespace isolation

**Reconciliation Flow:**
```mermaid
graph TD
    A["📋 Developer Commits<br/>CRD to Git"]
    B["👁️ Operator Watches<br/>K8s API"]
    C["🔍 Read Current<br/>Vault State"]
    D["🔀 Diff Desired<br/>vs Actual"]
    E["✏️ WriteIfDifferent<br/>to Vault"]
    F["✨ Update Status<br/>Conditions"]
    G["✅ Success"]
    
    A --> B
    B -->|Trigger| C
    C --> D
    D -->|Different?| E
    D -->|Same?| G
    E --> F
    F --> G
    
    style A fill:#667eea,color:#fff
    style B fill:#764ba2,color:#fff
    style C fill:#667eea,color:#fff
    style D fill:#667eea,color:#fff
    style E fill:#764ba2,color:#fff
    style F fill:#667eea,color:#fff
    style G fill:#28a745,color:#fff
```

**CRD Types (100+ available):**
```
Authentication Engines:
  - AuthEngineMount
  - KubernetesAuthEngineConfig
  - AzureAuthEngineConfig
  - LDAPAuthEngineConfig

Secret Engines:
  - SecretEngineMount
  - DatabaseSecretEngineConfig
  - AWSSecretEngineConfig
  - AzureSecretEngineConfig

Identity & Policy:
  - Policy
  - Entity / EntityAlias
  - Group / GroupAlias
  - PasswordPolicy
```

**Example Configuration:**
```yaml
apiVersion: redhatcop.redhat.io/v1alpha1
kind: AWSSecretEngineConfig
metadata:
  name: aws-prod
  namespace: vault-infra
spec:
  path: aws
  authentication:
    role: vault-admin
    path: kubernetes
  accessKey: AKIA...
  region: us-east-1
  rootCredentials:
    secret:
      name: aws-credentials
```

**✅ Strengths:**
- 📚 Declarative: All config in git with audit trail
- 🔄 Drift detection: Auto-repairs every 10 hours
- 🚀 GitOps-native: Works with ArgoCD, Helm, Kustomize
- 📦 Bulk provisioning: Apply 100+ CRDs in one commit
- 👥 Multi-tenant: Namespace isolation via Vault roles
- ✨ Idempotent: Safe to reconcile repeatedly

**❌ Weaknesses:**
- 🤔 No diagnostics: Can't ask "why is this failing?"
- 📋 Rigid workflow: Must create CRDs; no one-off commands
- 📚 Learning curve: 100+ CRD types, 30+ fields each
- ⏱️ Slow feedback: 10-hour drift cycle

---

### 3️⃣ MCP Policy-Gate (AI-SDLC Governance)

**What it does:**
- Policy-as-code enforcement for LLM agents
- Four policy gates (prompt, tools, MCP servers, evals)
- Prevents jailbreaks, classifies tools, enforces safety
- Regression testing via golden transcripts

**Four Gates:**
```mermaid
graph LR
    Prompt["🎯 Gate 1:<br/>Prompt Review"]
    Tools["📋 Gate 2:<br/>Tool Manifest"]
    MCP["🔍 Gate 3:<br/>MCP Vetting"]
    Eval["✅ Gate 4:<br/>Eval Suite"]
    
    PR["📝 Pull Request"]
    
    PR -->|Runs in CI| Prompt
    PR -->|Runs in CI| Tools
    PR -->|Runs in CI| MCP
    PR -->|Runs in CI| Eval
    
    Prompt -->|Forbidden<br/>Patterns?| Block{"❌ Blocked<br/>or<br/>✅ Approved?"}
    Tools -->|New Tools<br/>Classified?| Block
    MCP -->|Server<br/>Allowlist?| Block
    Eval -->|Regression<br/>Detected?| Block
    
    Block -->|Pass| Merge["✅ Merge<br/>to Main"]
    Block -->|Fail| Review["🔍 Developer<br/>Fixes & Retries"]
    
    style Prompt fill:#667eea,color:#fff
    style Tools fill:#764ba2,color:#fff
    style MCP fill:#ff6b6b,color:#fff
    style Eval fill:#28a745,color:#fff
    style Block fill:#ffc107,color:#000
    style Merge fill:#28a745,color:#fff
    style Review fill:#ff6b6b,color:#fff
```

**Gate 1: Prompt Review**
```yaml
forbidden_patterns:
  - "ignore (all|any|previous) instructions"  # Jailbreak prevention
  - "disable (safety|guardrails)"             # Safety enforcement
  
required_patterns:
  - "mask"      # Must mask sensitive values
  - "risk"      # Must assess risk before acting
  
max_length_chars: 4000
```

**Gate 2: Tool Manifest**
- Checks: New tools unclassified? → Fail
- Validates: High/critical changes need sign-off → Fail if missing
- Detects: Drift from baseline → Warn or fail

**Gate 3: MCP Server Vetting**
- Command allowlist verification
- Version pinning validation
- No plaintext secrets in config

**Gate 4: Eval Suite**
- Golden transcripts (static replay, no live LLM)
- Blocking vs warning severities
- Regression detection

**✅ Strengths:**
- 🌍 Universal: Works for any LLM agent (not Vault-specific)
- 📝 Policy-as-code: Rules in YAML, reviewable diffs
- 🛡️ Jailbreak prevention: Catches classic attack patterns
- 🔄 Regression testing: Prevents behavioral drift
- 🚀 CI integration: Gates PRs before merge

**❌ Weaknesses:**
- 🔍 Static analysis: Can't catch runtime issues
- 🏢 Vault-agnostic: No domain-specific rules yet
- ⏱️ PR-time only: Doesn't govern at runtime
- 🚫 No execution control: Can't block mid-call

---

## 🔗 Current Overlaps (Conflicts)

### ❌ 1. Vault Configuration Creation

**Agent Path:**
```
User: "Configure AWS auth engine"
  ↓
LLM selects tool: run_vault_command()
  ↓
Vault API: PUT /auth/aws/config/root
  ↓
Config written (no audit trail)
```

**Operator Path:**
```
Developer: Commits AWSSecretEngineConfig CRD
  ↓
Operator reconciles
  ↓
Vault API: PUT /auth/aws/config/root (same call)
  ↓
K8s etcd + git history (full audit trail)
```

**Collision:** Both write to same Vault endpoint. Last write wins. Changes get lost.

---

### ❌ 2. Policy Management

Both can mutate `/sys/policy/...` in Vault. No coordination → last write wins.

---

### ❌ 3. Secret Creation & Rotation

Agent and `RandomSecret` CRD both create/rotate secrets independently.

---

## ✅ What Each System Should Own (After Integration)

### Agent Exclusive (Read-Only)
- 🔍 Cluster health diagnostics
- 🧠 Root cause analysis ("Why is this failing?")
- ⚠️ AZ-failure detection
- 🔔 Real-time monitoring & alerts
- 🚨 Emergency seal/unseal (rare, explicit approval)

### Operator Exclusive (Write Authority)
- 📋 Declarative config management
- 🔄 Drift detection & auto-repair
- 🌳 GitOps workflows
- 📦 Bulk provisioning
- 👥 Multi-tenant namespace isolation
- 📚 Full audit trail (git + K8s etcd)

### Policy-Gate Exclusive (Governance)
- 🎯 Prompt jailbreak prevention
- 📊 Tool risk classification
- 🔍 MCP server allowlist
- ✅ Regression testing
- 📝 Policy-as-code enforcement

---

## 🏛️ Integration Architecture (Final State)

```mermaid
graph TB
    subgraph Governance["🛡️ POLICY-GATE<br/>(AI-SDLC Safety)"]
        G1["Prompt Review<br/>Jailbreak Prevention"]
        G2["Tool Classification<br/>Risk Management"]
        G3["MCP Vetting<br/>Allowlist Control"]
        G4["Eval Regression<br/>Golden Transcripts"]
    end
    
    subgraph Operator_Layer["⚙️ OPERATOR<br/>(Declarative Authority)"]
        O1["K8s CRDs"]
        O2["Vault Config<br/>Reconciliation"]
        O3["Drift Detection<br/>10hr Cycle"]
        O4["Multi-Tenant<br/>Isolation"]
    end
    
    subgraph Agent_Layer["🤖 AGENT<br/>(Observability)"]
        A1["Cluster Health<br/>Monitoring"]
        A2["LLM Diagnostics<br/>Root Cause"]
        A3["Recommendations<br/>No Direct Apply"]
        A4["Emergency Ops<br/>Rare Seal/Unseal"]
    end
    
    subgraph Git["📦 GIT<br/>(Source of Truth)"]
        git1["CRD Manifests"]
        git2["Vault Policies"]
        git3["Agent Prompts<br/>(Governed)"]
    end
    
    subgraph Vault["🔑 VAULT CLUSTER<br/>(Production)"]
        v1["Auth Engines"]
        v2["Policies"]
        v3["Secrets"]
    end
    
    G1 & G2 & G3 & G4 -->|Blocks unsafe changes| Governance_Check{"Gate<br/>Pass?"}
    Governance_Check -->|✅ Yes| Git
    Governance_Check -->|❌ No| Review["Developer<br/>Review & Fix"]
    Review -->|Retry| Governance_Check
    
    Git -->|CRDs + Policies| O1
    O1 --> O2
    O2 --> O3
    O3 -->|Reconcile| Vault
    
    Vault -->|Read| A1
    A1 -->|Analyze| A2
    A2 -->|Suggest| A3
    A3 -->|"Link to Git<br/>Workflow"| Git
    
    A4 -->|"Rare Seal/<br/>Unseal"| Vault
    
    Agent_Layer -->|Governed by| Governance
    Operator_Layer -->|Governed by| Governance
    Git -->|Governed by| Governance
    
    style Governance fill:#ffc107,color:#000,stroke:#ff9800,stroke-width:3px
    style Operator_Layer fill:#28a745,color:#fff,stroke:#1e7e34,stroke-width:3px
    style Agent_Layer fill:#667eea,color:#fff,stroke:#764ba2,stroke-width:3px
    style Git fill:#764ba2,color:#fff,stroke:#667eea,stroke-width:3px
    style Vault fill:#dc3545,color:#fff,stroke:#b71c1c,stroke-width:2px
    style Governance_Check fill:#ffc107,color:#000,stroke:#ff9800,stroke-width:2px
```

---

## 📅 4-Phase Rollout Plan

### Phase 1: Operator Foundation (Days 1-7)
- [ ] Deploy operator in K8s
- [ ] Migrate all policies to `Policy` CRDs (from `policies/` repo)
- [ ] Create auth engine mount CRDs
- [ ] Create secret engine config CRDs
- [ ] Validate all reconciliation succeeds

**Deliverable:** Operator is source of truth for all Vault configs in git

---

### Phase 2: Agent Pivot to Read-Only (Days 8-10)
- [ ] Disable write tools; add read-only mode
- [ ] Add `get_operator_crds()` tool
- [ ] Add `suggest_crd_patch()` tool (no apply)
- [ ] Update system prompt to recommend CRD workflow
- [ ] Test all read operations work, writes fail gracefully

**Deliverable:** Agent becomes observability-only, recommends fixes via git workflow

---

### Phase 3: Policy-Gate Extensions (Days 11-13)
- [ ] Create Vault-specific MCP policy file
- [ ] Add `vet_operator_policies()` gate (validate policy security)
- [ ] Add `vet_agent_vault_instructions()` gate (check prompts)
- [ ] Create `profiles/vault-agent.yaml` in MCP
- [ ] Wire gates into CI/CD pipeline

**Deliverable:** Multi-layer governance: prompts + policies + CRDs all gated

---

### Phase 4: Governance & Rollout (Days 14+)
- [ ] Create runbooks and documentation
- [ ] Update monitoring & alerting
- [ ] User training on new CRD-first workflow
- [ ] Production cutover
- [ ] Monitor for issues & iterate

**Deliverable:** Production-ready with full governance layer

---

## 🎯 Expected Outcomes

| Metric | Before | After |
|--------|--------|-------|
| **Audit Trail** | Chat history only | Git + K8s etcd (compliance-ready) |
| **Rollback Time** | Manual (1+ hour) | Automated (5 minutes) |
| **Multi-Env Support** | Separate agent instances | Single operator + Helm overlays |
| **Incident Recovery** | Manual replay | `kubectl apply -f` (deterministic) |
| **Security** | Admin token sprawl | Scoped roles (agent readonly) |
| **Scalability** | Single-user chatbot | Multi-team with namespace isolation |
| **Governance Layers** | 1 (policy-gate) | 3 (prompts + policies + CRDs) |
| **Agent Focus** | 50% config mgmt | 95% diagnostics + observability |

---

## 📚 Additional Resources

- **Full Analysis:** See `VAULT_OPERATOR_AGENT_INTEGRATION_ANALYSIS.md` for detailed implementation guide
- **Operator Docs:** https://github.com/redhat-cop/vault-config-operator
- **MCP Server:** `/Users/wolfpacker/development/MCP`
- **Policies Repo:** `/Users/wolfpacker/development/policies`
- **Vault-Agent:** `/Users/wolfpacker/development/Hashicorp-Azure-LLM`

---

## 🤝 Next Steps

1. **Review this guide** with the team
2. **Schedule architecture review** meeting
3. **Start Phase 1** (operator deployment)
4. **Iterate on feedback** from stakeholders

---

**Questions?** Open an issue or PR in your repo.

**Created:** 2026-08-19  
**Status:** Ready for Review  
**Audience:** DevOps, Platform Engineers, Security Review
