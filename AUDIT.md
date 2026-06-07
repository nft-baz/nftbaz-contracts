# 🔍 Audit Reports

Every audit, every finding, every fix.

---

## Active Audits

### v1.0 Mainnet Audit — [Audit Firm Name]

| | |
|---|---|
| **Auditor** | [Audit Firm Name](https://auditfirm.com) |
| **Engagement period** | 2026-XX-XX → 2026-XX-XX |
| **Commits reviewed** | [`abc1234`](https://github.com/YOUR_ORG/contracts/tree/abc1234) → [`def5678`](https://github.com/YOUR_ORG/contracts/tree/def5678) |
| **Report** | [`2026-XX-XX-firm-name.pdf`](./audit/2026-XX-XX-firm-name.pdf) |
| **Cost** | $XX,000 |
| **Lines audited** | ~1,800 |

#### Findings Summary

| Severity | Reported | Resolved | Outstanding |
|----------|----------|----------|-------------|
| Critical | 0 | 0 | **0** ✅ |
| High | 0 | 0 | **0** ✅ |
| Medium | 2 | 2 | **0** ✅ |
| Low | 5 | 5 | **0** ✅ |
| Informational | 12 | 10 | 2 (acknowledged) |

#### Resolution Details

**M-01: Royalty receiver could be set to address(0)**  
Status: ✅ Resolved in [`fix(collection): zero-address royalty check`](https://github.com/YOUR_ORG/contracts/commit/COMMIT_HASH)

**M-02: Lazy-mint voucher could be replayed across chains**  
Status: ✅ Resolved by adding `chainId` to EIP-712 domain separator. See [PR #XX](https://github.com/YOUR_ORG/contracts/pull/XX).

**L-01..L-05:** All low-severity findings resolved before mainnet deployment.

**I-11, I-12 (informational, acknowledged):** Naming convention preferences (auditor's style ≠ ours). Documented in [`docs/style-deviations.md`](./docs/style-deviations.md).

---

## Internal Audits

### 2026-XX-XX — Pre-mainnet self-audit

| | |
|---|---|
| **Auditor** | Internal security team |
| **Tools** | Slither, Mythril, Echidna |
| **Report** | [`internal-2026-XX-XX.md`](./audit/internal-2026-XX-XX.md) |

#### Tooling Output

- **Slither**: 0 medium+, 3 informational (false positives)
- **Mythril**: 0 issues
- **Echidna**: All invariants hold over 1M random inputs

---

## Bug Bounty (Live)

Active program on [Immunefi](https://immunefi.com/bounty/YOUR-PROGRAM).

Disclosed bugs that earned rewards (since program launch):

| Date | Reporter | Severity | Reward | Status |
|------|----------|----------|--------|--------|
| 2026-XX-XX | [@whitehat](https://twitter.com/whitehat) | Medium | $5,000 | ✅ Patched in v0.9.1 |

> **Be the first to find a bug for the v1.0 release** — bounty up to $250k for critical findings. See [`SECURITY.md`](./SECURITY.md).

---

## Audit Methodology

Every audit (internal or external) follows this process:

### 1. Pre-audit
- Code freeze on `audit-vX.Y` branch
- Full test suite passes
- Slither clean
- Documentation complete

### 2. Audit
- Auditor accesses code via pinned commit
- Weekly progress sync
- Findings logged in private GitHub issue

### 3. Post-audit
- All findings receive fix or written justification
- Fixes go to `develop`, not directly to audited branch
- Re-audit of fixes (free pass by most firms)

### 4. Public release
- Final report published in `audit/`
- Findings + fixes summarized in this file
- Tweet announcement + LinkedIn post

---

## Verifiable Audit Artifacts

For each audit:

| Artifact | What it proves |
|----------|----------------|
| `audit/REPORT.pdf` | Final auditor report (signed) |
| `audit/COMMIT.txt` | Exact commit hash audited |
| `audit/SIGNED.asc` | Auditor's PGP signature of the report |

To verify:
```bash
# Verify report signature
gpg --verify audit/SIGNED.asc audit/REPORT.pdf

# Check the audited commit was what you think
git log --oneline $(cat audit/COMMIT.txt) -1
```

---

## Schedule

| Audit type | Frequency | Last | Next |
|------------|-----------|------|------|
| External (full) | Annual | 2026-XX-XX | 2027-XX-XX |
| External (delta) | Per major release | 2026-XX-XX | TBD |
| Internal (Slither + Echidna) | Per PR (CI) | Continuous | Continuous |
| Internal (deep review) | Quarterly | 2026-XX-XX | 2026-XX-XX |

---

## Why we publish all this

Transparency is the foundation of Web3.

- ✅ Users can see exactly what's been reviewed
- ✅ Other security researchers can build on past findings
- ✅ Future auditors don't re-audit what's already been audited
- ✅ Regulatory clarity if/when Web3 compliance frameworks emerge

If we ever go through an audit and the findings make us look bad — **we still publish them**. Because hiding them is worse.
