# ⚡ Work in Progress

This repository is under active development.

Nothing is final yet — everything is subject to change.

---


# 🎨 NFTBaz Smart Contracts (**WIP**)



> Production-grade smart contracts powering the NFTBaz NFT marketplace — fully open source, audited, and verified on-chain.

[![CI](https://img.shields.io/github/actions/workflow/status/YOUR_ORG/contracts/ci.yml?branch=main&label=tests)](./.github/workflows/ci.yml)
[![Slither](https://img.shields.io/github/actions/workflow/status/YOUR_ORG/contracts/slither.yml?branch=main&label=slither)](./.github/workflows/slither.yml)
[![Coverage](https://img.shields.io/codecov/c/github/YOUR_ORG/contracts)](https://codecov.io/gh/YOUR_ORG/contracts)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Solidity ^0.8.24](https://img.shields.io/badge/solidity-0.8.24-lightgrey.svg)](https://soliditylang.org/)

---

## 🎯 Overview

NFTBaz is a multi-chain NFT marketplace built on Seaport 1.6 architecture. This repository contains all smart contracts deployed on production networks.

### Key Features

- **🏭 Factory pattern** for gas-efficient collection deployments (EIP-1167 minimal proxies)
- **🎨 ERC-721 + ERC-1155** support with on-chain royalty enforcement (EIP-2981)
- **🛒 Seaport 1.6 marketplace** for trustless trading
- **💰 Lazy-minting** via signed vouchers (EIP-712)
- **🔒 Audited** by [Audit Firm Name] (see [`audit/`](./audit))
- **✅ Verified** on Etherscan, Polygonscan, Basescan

---

## 📋 Deployed Contracts

### Mainnet

| Network | Contract | Address | Verified |
|---------|----------|---------|----------|
| Ethereum | ERC721Factory | [`0x000...`](https://etherscan.io/address/0x000) | ✅ |
| Ethereum | ERC1155Factory | [`0x000...`](https://etherscan.io/address/0x000) | ✅ |
| Polygon | ERC721Factory | [`0x000...`](https://polygonscan.com/address/0x000) | ✅ |
| Polygon | ERC1155Factory | [`0x000...`](https://polygonscan.com/address/0x000) | ✅ |
| Base | ERC721Factory | [`0x000...`](https://basescan.org/address/0x000) | ✅ |

### Implementation Templates (used by factories)

| Network | Template | Address |
|---------|----------|---------|
| Ethereum | ERC721Collection v1 | [`0x000...`](https://etherscan.io/address/0x000) |
| Ethereum | ERC1155Collection v1 | [`0x000...`](https://etherscan.io/address/0x000) |

### Marketplace

Powered by [Seaport 1.6](https://github.com/ProjectOpenSea/seaport) — canonical address on every EVM chain:

```
0x0000000000000068F116a894984e2DB1123eB395
```

Full deployment history: [`DEPLOYMENT.md`](./DEPLOYMENT.md)

---

## 🏗️ Architecture

```
                ┌─────────────────────┐
                │   ERC721Factory     │  immutable, audited
                │   ───────────────   │
                │   • createCollection │
                │   • createDeterministic│
                └──────────┬──────────┘
                           │ clones via EIP-1167
                           ▼
                ┌─────────────────────┐
                │  ERC721Collection   │  each clone independent
                │  ─────────────────  │
                │  • mint             │
                │  • lazyMintVoucher  │
                │  • setBaseURI       │
                │  • EIP-2981 royalty │
                └──────────┬──────────┘
                           │ trades via
                           ▼
                ┌─────────────────────┐
                │  Seaport 1.6        │  external, proven
                │  ─────────────────  │
                │  • fulfillOrder     │
                │  • cancel           │
                │  • bulkCancel       │
                └─────────────────────┘
```

Detailed architecture: [`ARCHITECTURE.md`](./ARCHITECTURE.md)

---

## 🛡️ Security

### Audit Reports
- 📄 [Audit Firm Name](./audit/2026-XX-XX-firm-name.pdf) — *Date*
- 📄 [Internal Audit](./audit/internal-2026-XX-XX.md) — *Date*

### Reporting Vulnerabilities

Please report security vulnerabilities to **security@nftbaz.com**.  
**Do NOT** open public issues for security bugs.

See [`SECURITY.md`](./SECURITY.md) for full policy + bug bounty.

### Security Properties

- ✅ Reentrancy guards on every state-changing external function
- ✅ Pull-payment pattern for ETH transfers
- ✅ Multisig (3-of-5) for all admin operations
- ✅ 48-hour timelock on upgrade proposals
- ✅ Pausable in emergencies (multisig only)
- ✅ EIP-2981 royalty enforcement
- ✅ Signature replay protection (nonces + EIP-712 domain)

---

## 🚀 Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (forge, cast, anvil)
- Node.js 20+ (for some scripts)

### Build

```bash
git clone https://github.com/YOUR_ORG/contracts.git
cd contracts
forge install
forge build
```

### Test

```bash
# Run the full suite
forge test -vvv

# Coverage report
forge coverage --report summary

# Gas snapshots
forge snapshot
```

### Local development

```bash
# Start a local fork of Polygon mainnet
anvil --fork-url https://polygon.publicnode.com

# Deploy on the fork
forge script script/Deploy.s.sol \
  --rpc-url http://localhost:8545 \
  --broadcast
```

---

## 🔍 Verification — How to confirm what you see is what's deployed

### 1. Read the source code here
Browse [`src/`](./src) — every line of every deployed contract is here.

### 2. Verify the deployed bytecode matches
On Etherscan/Polygonscan, click any deployed contract above. You'll see:
- A green ✓ **Contract Verified**
- The source code (matches this repo)
- The compiler version + optimization settings

### 3. Reproduce the build yourself
```bash
forge build --use 0.8.24 --optimize --optimizer-runs 200
# Compare the output bytecode with what's on-chain
```

If bytecode matches → you can trust the verified source matches our `src/`.

---

## 📚 Documentation

| Document | Description |
|---|---|
| [`ARCHITECTURE.md`](./ARCHITECTURE.md) | Contract relationships and data flow |
| [`DEPLOYMENT.md`](./DEPLOYMENT.md) | All deployed addresses with TX hashes |
| [`SECURITY.md`](./SECURITY.md) | Security policy + bug bounty |
| [`CONTRIBUTING.md`](./CONTRIBUTING.md) | How to contribute |
| [`CHANGELOG.md`](./CHANGELOG.md) | Version history |
| [`audit/`](./audit) | Third-party + internal audit reports |
| [`docs/`](./docs) | Developer guides + integration examples |

---

## 🛠️ Integration Examples

### Mint an NFT (ethers.js)

```javascript
import { ethers } from 'ethers';

const FACTORY = '0xYOUR_FACTORY';
const factory = new ethers.Contract(FACTORY, FactoryABI, signer);

const tx = await factory.createCollection(
  'My Collection',     // name
  'MYC',               // symbol
  signer.address,      // owner
  'ipfs://meta.json',  // contractURI
  '',                  // baseURI
  0,                   // maxSupply (0 = unlimited)
  signer.address,      // royaltyRecipient
  250                  // royalty 2.5%
);

const receipt = await tx.wait();
const event = receipt.logs.find(l => l.eventName === 'CollectionCreated');
console.log('New collection:', event.args.clone);
```

### List on the marketplace (Seaport)

See [`docs/marketplace-listing.md`](./docs/marketplace-listing.md).

---

## 📊 Stats

- **Contracts:** 4 core + 8 interfaces
- **Lines of Solidity:** ~1,800
- **Test coverage:** XX% (see [coverage.json](./coverage.json))
- **External dependencies:** OpenZeppelin Contracts 5.0.2 ([audited](https://github.com/OpenZeppelin/openzeppelin-contracts/tree/master/audits))

---

## 🤝 Used By

- 🌐 **[NFTBaz Marketplace](https://nftbaz.com)** — primary deployment
- 📱 **[NFTBaz Mobile](https://nftbaz.com/mobile)** — read-only client

Want to integrate? Read [`docs/integration.md`](./docs/integration.md).

---

## 📜 License

MIT — see [LICENSE](./LICENSE).

> The MIT License does NOT mean the deployed contracts are upgradeable or pausable by you. Source license ≠ contract control. Admin operations are restricted to our multisig on-chain.

---

## 🙏 Acknowledgments

Built on the shoulders of giants:
- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts)
- [Seaport 1.6](https://github.com/ProjectOpenSea/seaport)
- [Foundry](https://book.getfoundry.sh/)
- [Solady](https://github.com/Vectorized/solady) — gas-optimized helpers

---

## 📬 Contact

- 🌐 Website: https://nftbaz.com
- 📧 Email: contact@nftbaz.com
- 🐦 Twitter: [@nftbaz](https://twitter.com/nftbaz)
- 💬 Discord: https://discord.gg/nftbaz

For security-only: **security@nftbaz.com** (encrypted with our [PGP key](./security-pgp.asc))



## Feedback

Issues and pull requests are welcome.

> Built in public. Evolving fast.
