# 📍 Deployment Addresses

> Every contract we've deployed, every transaction hash that put it there, and every commit it was built from.  
> Reproducible by anyone with this repo.

---

## 🌐 Mainnet Deployments

### Ethereum Mainnet (chainId 1)

| Contract | Address | TX Hash | Deployer | Block | Commit |
|----------|---------|---------|----------|-------|--------|
| ERC721Factory | [`0xFACTORY_ADDRESS`](https://etherscan.io/address/0xFACTORY_ADDRESS) | [`0xTXHASH`](https://etherscan.io/tx/0xTXHASH) | [`0xMULTISIG`](https://etherscan.io/address/0xMULTISIG) | 18,XXX,XXX | [`abc1234`](https://github.com/YOUR_ORG/contracts/tree/abc1234) |
| ERC721Collection (impl) | [`0xIMPL_ADDRESS`](https://etherscan.io/address/0xIMPL_ADDRESS) | [`0xTXHASH`](https://etherscan.io/tx/0xTXHASH) | [`0xMULTISIG`](https://etherscan.io/address/0xMULTISIG) | 18,XXX,XXX | [`abc1234`](https://github.com/YOUR_ORG/contracts/tree/abc1234) |
| ERC1155Factory | [`0xFACTORY_ADDRESS`](https://etherscan.io/address/0xFACTORY_ADDRESS) | [`0xTXHASH`](https://etherscan.io/tx/0xTXHASH) | [`0xMULTISIG`](https://etherscan.io/address/0xMULTISIG) | 18,XXX,XXX | [`abc1234`](https://github.com/YOUR_ORG/contracts/tree/abc1234) |
| ERC1155Collection (impl) | [`0xIMPL_ADDRESS`](https://etherscan.io/address/0xIMPL_ADDRESS) | [`0xTXHASH`](https://etherscan.io/tx/0xTXHASH) | [`0xMULTISIG`](https://etherscan.io/address/0xMULTISIG) | 18,XXX,XXX | [`abc1234`](https://github.com/YOUR_ORG/contracts/tree/abc1234) |

**Multisig (Gnosis Safe):** [`0xMULTISIG_ADDRESS`](https://etherscan.io/address/0xMULTISIG_ADDRESS) — 3 of 5

---

### Polygon Mainnet (chainId 137)

| Contract | Address | TX Hash | Block | Commit |
|----------|---------|---------|-------|--------|
| ERC721Factory | [`0xFACTORY_ADDRESS`](https://polygonscan.com/address/0xFACTORY_ADDRESS) | [`0xTXHASH`](https://polygonscan.com/tx/0xTXHASH) | 52,XXX,XXX | [`abc1234`](https://github.com/YOUR_ORG/contracts/tree/abc1234) |
| ERC721Collection (impl) | [`0xIMPL_ADDRESS`](https://polygonscan.com/address/0xIMPL_ADDRESS) | [`0xTXHASH`](https://polygonscan.com/tx/0xTXHASH) | 52,XXX,XXX | [`abc1234`](https://github.com/YOUR_ORG/contracts/tree/abc1234) |
| ERC1155Factory | [`0xFACTORY_ADDRESS`](https://polygonscan.com/address/0xFACTORY_ADDRESS) | [`0xTXHASH`](https://polygonscan.com/tx/0xTXHASH) | 52,XXX,XXX | [`abc1234`](https://github.com/YOUR_ORG/contracts/tree/abc1234) |

**Multisig:** [`0xMULTISIG_ADDRESS`](https://polygonscan.com/address/0xMULTISIG_ADDRESS) — 3 of 5

---

### Base Mainnet (chainId 8453)

| Contract | Address | TX Hash | Block | Commit |
|----------|---------|---------|-------|--------|
| ERC721Factory | [`0xFACTORY_ADDRESS`](https://basescan.org/address/0xFACTORY_ADDRESS) | [`0xTXHASH`](https://basescan.org/tx/0xTXHASH) | 10,XXX,XXX | [`abc1234`](https://github.com/YOUR_ORG/contracts/tree/abc1234) |

---

### Arbitrum One (chainId 42161)

| Contract | Address | TX Hash | Block | Commit |
|----------|---------|---------|-------|--------|
| ERC721Factory | [`0xFACTORY_ADDRESS`](https://arbiscan.io/address/0xFACTORY_ADDRESS) | [`0xTXHASH`](https://arbiscan.io/tx/0xTXHASH) | 200,XXX,XXX | [`abc1234`](https://github.com/YOUR_ORG/contracts/tree/abc1234) |

---

## 🧪 Testnet Deployments

### Ethereum Sepolia (chainId 11155111)

| Contract | Address | Verified |
|----------|---------|----------|
| ERC721Factory | [`0xSEPOLIA_FACTORY`](https://sepolia.etherscan.io/address/0xSEPOLIA_FACTORY) | ✅ |
| ERC721Collection (impl) | [`0xSEPOLIA_IMPL`](https://sepolia.etherscan.io/address/0xSEPOLIA_IMPL) | ✅ |

### Polygon Amoy (chainId 80002)

| Contract | Address | Verified |
|----------|---------|----------|
| ERC721Factory | [`0xAMOY_FACTORY`](https://amoy.polygonscan.com/address/0xAMOY_FACTORY) | ✅ |

### Base Sepolia (chainId 84532)

| Contract | Address |
|----------|---------|
| ERC721Factory | [`0xBASE_SEPOLIA_FACTORY`](https://sepolia.basescan.org/address/0xBASE_SEPOLIA_FACTORY) |

---

## 🔍 Verification on Explorer

Every contract listed above has its source verified on the respective block explorer. To verify yourself:

### Manual verification

1. Go to the contract address on the explorer
2. Click the "Contract" tab
3. Look for a **green checkmark** ✓ next to "Contract Source Code Verified"
4. Compare the displayed source with files in this repo at the listed commit

### Automated check

```bash
# Install foundry first: https://book.getfoundry.sh/getting-started/installation
./scripts/verify-deployments.sh
```

This script fetches every address from this file, downloads the verified source from each explorer, and compares it to local source. Output:
```
✓ Ethereum ERC721Factory: bytecode matches commit abc1234
✓ Polygon ERC721Factory: bytecode matches commit abc1234
...
```

---

## 🔨 Reproducible Builds

To produce identical bytecode to what's deployed:

```bash
# Use the exact Foundry version pinned at commit:
foundryup --version $(cat .foundry-version)

# Rebuild with deterministic settings:
forge build \
  --use 0.8.24 \
  --optimize \
  --optimizer-runs 200 \
  --evm-version paris

# Compare your bytecode with on-chain:
cast code 0xFACTORY_ADDRESS --rpc-url $RPC_URL
```

Compiler settings (locked to ensure reproducibility):
- **Solc version:** `0.8.24`
- **Optimizer:** `enabled`, `200` runs
- **EVM version:** `paris`
- **Metadata hash:** `none` (deterministic across machines)

---

## 📜 Deployment History

### v1.0.0 — Initial Mainnet Deployment
- **Date:** 2026-XX-XX
- **Commit:** [`abc1234`](https://github.com/YOUR_ORG/contracts/tree/abc1234)
- **Audited by:** [Audit Firm Name](./audit/2026-XX-XX-firm-name.pdf)
- **Chains:** Ethereum, Polygon, Base
- **Networks added:** Arbitrum (2026-XX-XX), Optimism (2026-XX-XX)

### v0.9.0 — Testnet Beta
- **Date:** 2026-XX-XX
- **Commit:** [`xyz5678`](https://github.com/YOUR_ORG/contracts/tree/xyz5678)
- **Chains:** Sepolia, Amoy, Base Sepolia

---

## 🛂 Privileged Address Registry

These addresses have privileged roles on the deployed contracts. Tracked here for transparency.

### Multisig signers (Ethereum + Polygon + Base)

| Role | Address | Verification |
|------|---------|--------------|
| Founder | `0xFOUNDER_ADDR` | [Signed message](./signatures/founder.sig) |
| CTO | `0xCTO_ADDR` | [Signed message](./signatures/cto.sig) |
| Security Lead | `0xSEC_ADDR` | [Signed message](./signatures/security.sig) |
| Advisor 1 | `0xADV1_ADDR` | [Signed message](./signatures/advisor1.sig) |
| Advisor 2 | `0xADV2_ADDR` | [Signed message](./signatures/advisor2.sig) |

**Multisig threshold:** 3 of 5

### Roles delegated by multisig

| Role | Address | Granted at |
|------|---------|------------|
| `PAUSER_ROLE` | `0xMULTISIG` | Genesis |
| `DEFAULT_ADMIN_ROLE` | `0xMULTISIG` | Genesis |

---

## 🚨 Incident Response

In case of an active exploit:

1. **PAUSER_ROLE** can call `pause()` on any contract (instant, 2-of-5 multisig)
2. Public alert via [@nftbaz](https://twitter.com/nftbaz)
3. Post-mortem published here within 7 days of resolution

Past incidents:
- *None to date* — and if there were any, they'd be listed here transparently.
