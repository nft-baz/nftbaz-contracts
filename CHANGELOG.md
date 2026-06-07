# 📜 Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- Initial monorepo structure
- ERC721Factory with EIP-1167 minimal proxy clones
- ERC1155Factory with EIP-1167 minimal proxy clones
- EIP-2981 royalty support in both collection templates
- Lazy-mint via EIP-712 signed vouchers

### Security
- Reentrancy guards on all state-changing external functions
- Multisig + timelock model for admin operations
- Pausable circuit-breaker

---

## [1.0.0] — 2026-XX-XX

### Added
- 🎉 Initial mainnet deployment
- Deployed on Ethereum, Polygon, Base
- Audit completed by [Audit Firm Name] — see [`audit/2026-XX-XX-firm-name.pdf`](./audit/2026-XX-XX-firm-name.pdf)

### Deployed Contracts
- ERC721Factory: see [`DEPLOYMENT.md`](./DEPLOYMENT.md)
- ERC1155Factory: see [`DEPLOYMENT.md`](./DEPLOYMENT.md)

---

## [0.9.0] — 2026-XX-XX — Testnet Beta

### Added
- Testnet deployments on Sepolia + Polygon Amoy + Base Sepolia
- Bug bounty program live on Immunefi

### Changed
- Switched to OpenZeppelin Contracts 5.0.2 (from 4.9.x)

### Fixed
- Reentrancy vector on `mintBatch` (reported by @whitehat_handle)
- Off-by-one in voucher expiry check

---

## [0.8.0] — 2026-XX-XX

### Added
- Voucher-based lazy minting (EIP-712)
- Public testnet on Sepolia

### Changed
- Royalty cap reduced from 15% to 10%

---

## How to read this

- **Added** — new features
- **Changed** — changes in existing functionality
- **Deprecated** — soon-to-be removed features
- **Removed** — removed features
- **Fixed** — bug fixes
- **Security** — security-related changes

---

[Unreleased]: https://github.com/YOUR_ORG/contracts/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/YOUR_ORG/contracts/releases/tag/v1.0.0
[0.9.0]: https://github.com/YOUR_ORG/contracts/releases/tag/v0.9.0
[0.8.0]: https://github.com/YOUR_ORG/contracts/releases/tag/v0.8.0
