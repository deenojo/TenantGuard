# Controls

Every control in the baseline, where it lives, and what enforces it. **Checkov** runs in CI on every push; **Test** is a `terraform test` assertion in `modules/baseline/tests/baseline.tftest.hcl` that fails if the control is weakened; **Policy** is an Azure Policy assignment that keeps enforcing it in the customer's subscription after deployment.

The CIS column names the CIS Microsoft Azure Foundations Benchmark section each control supports. The built-in CIS initiative is also assigned in audit mode, so the customer gets Microsoft's own compliance report against the full benchmark.

## Networking (CIS: Networking)

| Control | Code | Checkov | Test | Policy |
| --- | --- | --- | --- | --- |
| No public IPs (one exempted outbound-only NAT IP) | `network.tf`, `policy.tf` | | `policy_guardrails` | `deny-public-ip` + `tg-nat-egress-ip` exemption |
| Every subnet has an NSG | `network.tf` | CKV2_AZURE_31 | | |
| NSGs explicitly deny internet inbound | `network.tf` | CKV_AZURE_9, 10, 77, 160 | `nothing_is_public` | `deny-internet-inbound-nsg-rules` |
| Subnets don't get implicit default outbound access | `network.tf` | | | |
| Key Vault and storage reached only through private endpoints | `network.tf` | CKV2_AZURE_32, 33 | `nothing_is_public` | |
| App ingress internal only | `app.tf` | | `nothing_is_public` | |
| VNet flow logs, 90-day retention, traffic analytics | `network.tf` | CKV_AZURE_12 | | |

## Identity and access (CIS: Identity and Access Management)

| Control | Code | Checkov | Test | Policy |
| --- | --- | --- | --- | --- |
| Managed identities only, no client secrets | `identity.tf` | | | |
| Workload gets blob access on one container, secrets read on one vault | `identity.tf` | | `least_privilege` | |
| Vendor role scoped to the resource group, no `*` | `identity.tf` | CKV_AZURE_39 | `least_privilege` | |
| Vendor can't change role assignments, networking, the vault or read storage keys | `identity.tf` | | `least_privilege` | |
| No vendor principal means no vendor access | `identity.tf` | | `audit_only_rollout` | |

## Key Vault (CIS: Key Vault)

| Control | Code | Checkov | Test | Policy |
| --- | --- | --- | --- | --- |
| RBAC authorization only (no access policies) | `keyvault.tf` | | `no_shared_secrets_and_strong_crypto` | `deny-weak-key-vault` |
| Purge protection, 90-day soft delete | `keyvault.tf` | CKV_AZURE_42, 110, 111 | `no_shared_secrets_and_strong_crypto` | `deny-weak-key-vault` |
| Public network access off, firewall default deny | `keyvault.tf` | CKV_AZURE_109, 189 | `nothing_is_public` | `deny-weak-key-vault` |
| HSM-backed key, expiry and automatic rotation | `keyvault.tf` | CKV_AZURE_40, 112 | `no_shared_secrets_and_strong_crypto` | |

## Storage (CIS: Storage Accounts)

| Control | Code | Checkov | Test | Policy |
| --- | --- | --- | --- | --- |
| Public network access off, default deny | `storage.tf` | CKV_AZURE_35, 59 | `nothing_is_public` | `deny-public-storage` |
| No anonymous blob access | `storage.tf` | CKV_AZURE_34, 190, CKV2_AZURE_47 | `nothing_is_public` | `deny-public-storage` |
| Shared-key auth off (Entra ID only), short SAS expiry | `storage.tf` | CKV2_AZURE_40, 41 | `no_shared_secrets_and_strong_crypto` | `deny-public-storage` |
| HTTPS only, TLS 1.2 minimum | `storage.tf` | CKV_AZURE_3, 44 | `no_shared_secrets_and_strong_crypto` | `deny-public-storage` |
| Customer-managed key + infrastructure encryption | `storage.tf` | CKV2_AZURE_1 | `no_shared_secrets_and_strong_crypto` | |
| Soft delete and versioning | `storage.tf` | CKV2_AZURE_38 | | |
| No local users, trusted Microsoft services allowed, geo-zone replication | `storage.tf` | CKV_AZURE_36, 206, 244 | | |

## Logging and monitoring (CIS: Logging and Monitoring)

| Control | Code | Checkov | Test | Policy |
| --- | --- | --- | --- | --- |
| Diagnostic settings on every resource (vault, blob and queue services, storage, VNet, app environment, NAT IP, NSGs) | `logging.tf` | | `everything_is_logged_and_alerted` | CIS initiative (audit) |
| Subscription activity log exported | `logging.tf` | | `everything_is_logged_and_alerted` | |
| Log retention 90-730 days (default 365) | `logging.tf`, `variables.tf` | | `rejects_short_log_retention` | |
| Alerts on policy, role, NSG, Key Vault and public IP changes | `logging.tf` | | `everything_is_logged_and_alerted` | |

## Governance

| Control | Code | Checkov | Test | Policy |
| --- | --- | --- | --- | --- |
| Allowed regions | `policy.tf` | | `policy_guardrails` | `allowed-locations` |
| Required `owner` and `environment` tags | `policy.tf`, `variables.tf` | | `rejects_missing_owner_tag` | `require-tag-owner`, `require-tag-environment` |
| Policies enforced by default, audit-only mode for staged rollout | `policy.tf` | | `policy_guardrails`, `audit_only_rollout` | |
| Delete lock on the resource group | `main.tf` | | | |

## Skipped Checkov checks

| Check | Why |
| --- | --- |
| CKV_AZURE_33 (×2): classic Storage Analytics queue logging | Needs shared-key access, which is deliberately disabled. Queue logs go to Log Analytics through diagnostic settings instead. |
| CKV2_AZURE_21: blob read logging | Blob read/write/delete logs are sent by the `blobServices` diagnostic setting; Checkov only recognizes the classic Storage Analytics form. |
