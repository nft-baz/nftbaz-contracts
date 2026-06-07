# 🏛️ Architecture

This document describes the system architecture, contract relationships, and design decisions.

---

## 📐 High-Level Diagram

```
                       ┌──────────────────────────────┐
                       │       Off-chain (Gateway)     │
                       │  ─────────────────────────   │
                       │  • REST API                  │
                       │  • Job queue + signer (KMS)  │
                       │  • Webhook notifier          │
                       └──────────────┬───────────────┘
                                      │
                                      ▼ tx submission
        ┌──────────────────────────────────────────────────────┐
        │              EVM Blockchain (Polygon / Ethereum)      │
        │                                                       │
        │  ┌─────────────────┐     ┌──────────────────────┐    │
        │  │   ERC721Factory │     │   ERC1155Factory     │    │
        │  │  ──────────────  │     │  ──────────────────  │    │
        │  │  • Immutable    │     │  • Immutable         │    │
        │  │  • EIP-1167     │     │  • EIP-1167          │    │
        │  │  • CREATE2 opt  │     │  • CREATE2 opt       │    │
        │  └────────┬────────┘     └──────────┬───────────┘    │
        │           │ clones                   │ clones         │
        │           ▼                          ▼                │
        │  ┌─────────────────┐     ┌──────────────────────┐    │
        │  │ ERC721Collection│     │  ERC1155Collection   │    │
        │  │ ──────────────  │     │  ──────────────────  │    │
        │  │ Immutable clone │     │  Immutable clone     │    │
        │  │  • mint         │     │  • mint              │    │
        │  │  • mintBatch    │     │  • mintBatch         │    │
        │  │  • lazyMint     │     │  • burn              │    │
        │  │  • EIP-2981     │     │  • EIP-2981          │    │
        │  │  • Pausable     │     │  • Pausable          │    │
        │  └────────┬────────┘     └──────────┬───────────┘    │
        │           │                          │                │
        │           └────────────┬─────────────┘                │
        │                        │ trades via                   │
        │                        ▼                              │
        │              ┌──────────────────────┐                 │
        │              │   Seaport 1.6        │                 │
        │              │  ─────────────────   │                 │
        │              │  • fulfillOrder      │                 │
        │              │  • cancel            │                 │
        │              │  • bulkCancel        │                 │
        │              │  • External contract │                 │
        │              └──────────────────────┘                 │
        └──────────────────────────────────────────────────────┘
```

---

## 📦 Contracts

### 1. ERC721Factory

**Purpose:** Deploy minimal proxy clones of `ERC721Collection` via EIP-1167.

**Why a factory?**
- Each NFT collection deploys for ~50,000 gas (vs ~3M for a full deployment)
- All clones share the same audited implementation
- Implementation is set at factory deploy and cannot change → no rug-pull risk

**Methods:**
| Method | Access | Description |
|--------|--------|-------------|
| `createCollection(...)` | Public | Deploy a clone with auto-generated salt |
| `createDeterministic(salt, ...)` | Public | Deploy a clone with user-supplied salt (CREATE2) |
| `predictAddress(salt, ...)` | View | Compute the address before deploying |

**Events:**
- `CollectionCreated(creator, clone, implementation, name, symbol, contractURI, salt)`

**Storage:**
- `address public immutable implementation;` — cannot be changed
- No upgradability — factory is fully immutable

---

### 2. ERC721Collection

**Purpose:** An immutable, gas-optimized ERC-721 NFT collection.

**Standards implemented:**
- ✅ ERC-721 (NFT)
- ✅ ERC-721Metadata
- ✅ ERC-2981 (Royalty)
- ✅ ERC-165 (Introspection)

**Role-based access:**
| Role | Purpose |
|------|---------|
| `OWNER_ROLE` | Set base URI, royalty, pause |
| `MINTER_ROLE` | Mint tokens |
| `BURNER_ROLE` | Burn tokens (optional) |

**Pausable:** All transfers + mints can be paused by `PAUSER_ROLE`.

**Lazy Mint via Voucher (EIP-712):**
```solidity
struct LazyMintVoucher {
    uint256 tokenId;
    string tokenURI;
    uint256 price;
    address currency;
    uint256 validUntil;
    address signer;
}
```
A signer signs offline → buyer pays + mints atomically on-chain.

---

### 3. ERC1155Factory

Same pattern as ERC721Factory but for multi-token (semi-fungible) collections.

---

### 4. ERC1155Collection

Same pattern as ERC721Collection but supporting multiple tokens per ID.

**Additional methods:**
- `mintBatch(to, ids[], amounts[], data)`
- `burnBatch(from, ids[], amounts[])`

---

## 🔐 Access Control Model

### Multisig at the top

```
                ┌──────────────────────┐
                │  3-of-5 Multisig     │  Safe (Gnosis Safe)
                │  ─────────────────   │
                │  Signers:            │
                │    • Founder         │
                │    • CTO             │
                │    • Security Lead   │
                │    • Advisor 1       │
                │    • Advisor 2       │
                └──────────┬───────────┘
                           │ holds
                           ▼
                ┌──────────────────────┐
                │  DEFAULT_ADMIN_ROLE  │
                └──────────┬───────────┘
                           │ grants
                ┌──────────┴──────────┐
                ▼                     ▼
        ┌─────────────┐       ┌──────────────┐
        │ PAUSER_ROLE │       │ MINTER_ROLE  │
        │  ─────────  │       │  ──────────  │
        │ multisig    │       │ Collection   │
        │ (emergency) │       │ owner only   │
        └─────────────┘       └──────────────┘
```

### Timelocks

| Operation | Delay |
|-----------|-------|
| Grant role | 48 hours |
| Revoke role | 48 hours |
| Change royalty cap | 24 hours |
| Marketplace fee change | 24 hours |
| Emergency pause | **instant** (2-of-5 override) |

---

## 🔄 Data Flow: Mint → List → Sell

### Step 1: Mint
```
User → Factory.createCollection() → emits CollectionCreated
                ↓
         clone address X
                ↓
User → Collection[X].mint(to, tokenId, tokenURI) → emits Transfer(0, to, tokenId)
```

### Step 2: Approve Marketplace
```
Owner → Collection[X].setApprovalForAll(Seaport, true)
        → emits ApprovalForAll(owner, Seaport, true)
```

### Step 3: Sign Listing (off-chain)
```
Owner generates Seaport Order:
  - offer: [Collection[X], tokenId]
  - consideration: [native, priceWei, owner]
  - signed via EIP-712

Order stored off-chain (no gas).
```

### Step 4: Buyer Fulfills
```
Buyer → Seaport.fulfillOrder{value: price}(order) →
  Seaport transfers NFT from owner → buyer
  Seaport transfers ETH from buyer → owner
  Seaport extracts royalty per EIP-2981
```

### Step 5: NFT Moves On-chain
```
Transfer event emitted from Collection[X]:
  Transfer(owner, buyer, tokenId)
```

---

## 🧮 Gas Optimization

### EIP-1167 Minimal Proxy

Instead of deploying a full contract per collection (~3M gas):
```
Clone deployment cost: ~50,000 gas
Implementation: deployed ONCE (~3M gas total)
```

Per-collection savings: **~98%**.

### Storage Packing

ERC721Collection packs frequently-accessed fields into single slots:
```solidity
struct CollectionMeta {
    uint128 maxSupply;      // 16 bytes
    uint64 totalSupply;     // 8 bytes
    uint16 royaltyBps;      // 2 bytes
    address royaltyRecipient; // 20 bytes
    // Total: 46 bytes → fits in 2 storage slots
}
```

### Batch Operations

`mintBatch` / `burnBatch` save gas via:
- Single SSTORE per array element
- One Transfer event per token (batched)
- One supply update at the end

---

## 🔭 Upgradability Strategy

### Immutable contracts (factories + collections)
- ✅ No proxy
- ✅ No admin can change code
- ✅ Maximum trust

### Why we chose this
- NFT collections are user-owned → no central authority should be able to upgrade
- Factory implementation is fixed → no risk of factory deploying malicious clones in future

### What can be changed?
| | |
|---|---|
| Collection name | ❌ Immutable |
| Collection symbol | ❌ Immutable |
| Base URI | ✅ By owner (no timelock) |
| Royalty | ✅ By owner (capped at 10%) |
| Royalty recipient | ✅ By owner |
| Max supply | ✅ By owner (only downward) |

---

## 🧪 Testing Strategy

### Unit tests (`test/*.t.sol`)

- One test contract per source contract
- Fuzz testing for all numeric parameters
- Invariant testing for supply tracking

### Integration tests (`test/integration/`)

- Factory → Collection deployment flow
- Mint → Approve → List → Fulfill end-to-end
- Voucher signing + redemption

### Fork tests (`test/fork/`)

- Test against mainnet Seaport
- Test interaction with real WETH/WMATIC

### Coverage target: **>95%** line + branch

---

## 🌐 Cross-chain Considerations

The same source compiles to identical bytecode on every chain. Deployment is per-chain:

| Chain | Factory ERC721 | Why we support it |
|-------|----------------|-------------------|
| Ethereum | 0x... | Highest liquidity |
| Polygon | 0x... | Low fees |
| Base | 0x... | Coinbase user base |
| Arbitrum | 0x... | Active L2 community |
| Optimism | 0x... | Active L2 community |
| BSC | 0x... | Large user base |

No cross-chain bridges in this scope. Each chain operates independently.

---

## 📚 References

- [EIP-1167 Minimal Proxy](https://eips.ethereum.org/EIPS/eip-1167)
- [EIP-2981 Royalty Standard](https://eips.ethereum.org/EIPS/eip-2981)
- [EIP-712 Typed Data Signing](https://eips.ethereum.org/EIPS/eip-712)
- [Seaport Protocol](https://github.com/ProjectOpenSea/seaport)
- [OpenZeppelin Contracts 5.x](https://docs.openzeppelin.com/contracts/5.x/)
