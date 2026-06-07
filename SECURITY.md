# 🛡️ Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in any of our contracts, **please do not open a public GitHub issue**.

### How to report

Email: **security@nftbaz.com**

For sensitive reports, encrypt with our PGP key:
- Key ID: `0x1234567890ABCDEF`
- Fingerprint: `1234 5678 90AB CDEF 1234 5678 90AB CDEF 1234 5678`
- Download: [security-pgp.asc](./security-pgp.asc)

Include in your report:
1. **Affected contract(s)** and version (commit hash)
2. **Step-by-step reproduction** with a PoC if possible
3. **Impact assessment** — what's at risk?
4. **Suggested mitigation** (if you have one)
5. **Your contact info** for follow-up

### Response timeline

| Severity | Initial response | Patch released | Disclosure |
|----------|-----------------|----------------|------------|
| **Critical** (drain funds, mint freely) | < 24 hours | < 72 hours | After patch + 7 days |
| **High** (DoS, role escalation) | < 48 hours | < 7 days | After patch + 14 days |
| **Medium** (gas griefing, edge cases) | < 5 days | < 30 days | After patch + 30 days |
| **Low** (UX, optimization) | < 14 days | Next release | Public PR |

---

## 💰 Bug Bounty

We run a public bug bounty on [Immunefi](https://immunefi.com/bounty/YOUR-PROGRAM).

### Rewards 

| Severity | Reward |
|----------|--------|
| Critical | **-** |
| High | **-** |
| Medium | **-** |
| Low | **-** |

### Scope

**In scope:**
- Any deployed contract listed in [`DEPLOYMENT.md`](./DEPLOYMENT.md)
- Smart contract source in this repository
- Off-chain signature verification flows

**Out of scope:**
- Issues in third-party dependencies (report upstream)
- UI/UX issues on the marketplace website
- Social engineering attacks
- Already-known issues in published audits

### Eligibility

- Reproducible vulnerability with PoC
- First reporter only (no duplicates)
- Responsible disclosure: do not exploit, do not share publicly until patched
- Not affiliated with NFTBaz team

---

## 🔒 Security Properties

### Code-level safeguards

| Property | Implementation |
|----------|----------------|
| **Reentrancy protection** | OpenZeppelin `ReentrancyGuard` on every state-changing external function |
| **Access control** | OpenZeppelin `AccessControl` with role separation (MINTER, PAUSER, OWNER) |
| **Pausable** | All transfers + mints pausable by `PAUSER_ROLE` (multisig only) |
| **Royalty enforcement** | EIP-2981 standard, validated on every secondary sale |
| **Signature replay** | EIP-712 typed data + nonces per signer + chain ID |
| **Integer overflow** | Solidity 0.8.24+ built-in overflow checks |
| **Pull payments** | Funds pulled by users, never pushed (no `transfer` revert grief) |

### Operational safeguards

- **Multisig** (3-of-5) on `OWNER_ROLE` — addresses listed in [`DEPLOYMENT.md`](./DEPLOYMENT.md)
- **48-hour timelock** on any role grant/revoke
- **24-hour timelock** on parameter changes (royalty caps, marketplace fees)
- **Emergency pause** with 2-of-5 multisig override (for active incidents only)
- **Quarterly internal audit** by the development team
- **Annual external audit** by [Audit Firm Name]

---

## 🛂 Privileged Roles

| Role | Holder | Power |
|------|--------|-------|
| `DEFAULT_ADMIN_ROLE` | 3-of-5 multisig | Grant/revoke other roles (timelocked) |
| `PAUSER_ROLE` | 3-of-5 multisig | Pause/unpause contracts |
| `MINTER_ROLE` | Collection owner (each clone) | Mint NFTs in that collection |
| `ROYALTY_ADMIN_ROLE` | Collection owner | Update royalty for own collection |

**No address can:**
- Modify existing NFT ownership without owner signature
- Withdraw user funds (no honeypot)
- Change pricing on existing listings
- Upgrade an immutable Collection contract (factories deploy immutable clones)

---

## 📋 Audit History

| Date | Auditor | Report | Findings |
|------|---------|--------|----------|
| 2026-XX-XX | [Audit Firm Name] | [PDF](./audit/2026-XX-XX-firm-name.pdf) | 0 critical, 0 high, 2 medium (resolved), 5 low (resolved) |
| 2026-XX-XX | Internal team | [MD](./audit/internal-2026-XX-XX.md) | Slither + Echidna clean |

---

## 🎓 Security Resources

For developers integrating with our contracts:

- [SWC Registry](https://swcregistry.io/) — Smart Contract Weakness Classification
- [Trail of Bits Smart Contract Pitfalls](https://github.com/crytic/building-secure-contracts)
- [Consensys Best Practices](https://consensys.github.io/smart-contract-best-practices/)
- [Rekt News](https://rekt.news/) — learn from others' mistakes

---

## 📞 Questions?

For non-security questions, see [`CONTRIBUTING.md`](./CONTRIBUTING.md) or our Discord.

For security questions: **security@nftbaz.com**
