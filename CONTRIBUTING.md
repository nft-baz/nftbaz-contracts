# 🤝 Contributing

Thanks for your interest in contributing! This document covers how to set up the project, propose changes, and what we expect from contributors.

---

## 🚀 Quick Start

```bash
git clone https://github.com/YOUR_ORG/contracts.git
cd contracts
forge install
forge test
```

If `forge test` passes, you're set up.

---

## 🛠️ Workflow

1. **Fork** the repo and create a branch off `develop`:
   ```bash
   git checkout -b feature/your-change develop
   ```

2. Make your changes following the [Code Style](#code-style) below.

3. **Add tests** for any new functionality.

4. Ensure all checks pass locally:
   ```bash
   forge fmt --check
   forge build --sizes
   forge test -vvv
   ```

5. Open a **Pull Request** against `develop`.

---

## 📏 Code Style

### Solidity

- **Version:** `^0.8.24`
- **Formatter:** `forge fmt` (config in `.fmt.toml`)
- **NatSpec:** required on every public/external function
- **Error messages:** custom errors, not strings (gas-optimal)
- **Imports:** named imports only (`import {Foo} from "./Foo.sol"`)
- **Visibility:** explicit on every storage variable

### Example

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title  MyContract
/// @notice Brief description of what this does.
/// @dev    Implementation notes for other devs.
contract MyContract is Ownable {
    error MyContract_InvalidInput();

    uint256 public immutable myValue;

    /// @notice Set the immutable value at construction time.
    /// @param _value The value to store.
    constructor(uint256 _value) Ownable(msg.sender) {
        if (_value == 0) revert MyContract_InvalidInput();
        myValue = _value;
    }
}
```

---

## 🧪 Testing Rules

### Required

- ✅ Every public/external function needs unit tests
- ✅ Every state-changing function needs reverting tests for each `require`/`revert`
- ✅ Integration tests for cross-contract flows
- ✅ Fuzz tests on numeric inputs
- ✅ Gas snapshots updated (`forge snapshot`)

### Coverage

We require **>95% line coverage** on `contracts/`. Check yours:
```bash
forge coverage --report summary
```

### Forking mainnet

For tests against real Seaport / WETH:
```bash
ETH_RPC_URL="https://your-rpc" forge test --match-contract Fork -vvv
```

---

## 🔐 Security Review

Every PR touching `contracts/` triggers:
- ✅ Slither static analysis
- ✅ Contract size check (must be under 24 KB)
- ✅ Gas snapshot comparison

PRs introducing breaking changes need:
- 📋 Detailed description of the change
- ⏰ 7-day discussion period before merge
- 🛡️ Security review from a CODEOWNER

---

## 📝 Commit Conventions

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(factory):       add createDeterministic with custom salt
fix(collection):     reject zero address on royalty recipient
docs(architecture):  update sequence diagram for offer accept
test(integration):   add fork-test for Seaport listing
chore:               bump solidity to 0.8.24
```

Types: `feat`, `fix`, `docs`, `test`, `refactor`, `chore`, `style`.

---

## 🚨 Security Issues

**DO NOT** open public PRs/issues for vulnerabilities.

Email: **security@nftbaz.com** (see [`SECURITY.md`](./SECURITY.md))

---

## 🔧 Repository Layout

```
contracts/
├── interfaces/      # External interfaces
├── *.sol            # Production contracts
└── mocks/           # Test-only mocks
test/
├── unit/            # Per-contract unit tests
├── integration/     # Multi-contract flows
└── fork/            # Forked-mainnet tests
script/
├── Deploy.s.sol     # Production deployment
└── DeployLocal.s.sol # Anvil deployment
docs/                # Markdown docs + diagrams
audit/               # Third-party + internal audit reports
```

---

## 👥 Code Owners

Defined in `.github/CODEOWNERS`. Some areas require review by specific maintainers:

| Path | Owner |
|------|-------|
| `contracts/` | `@security-lead`, `@cto` |
| `audit/` | `@security-lead` |
| `script/Deploy.*` | `@cto`, `@founder` |

---

## 📋 PR Checklist

Copy-paste this when opening a PR:

```markdown
- [ ] Code compiles (`forge build`)
- [ ] All tests pass (`forge test`)
- [ ] Formatter ok (`forge fmt --check`)
- [ ] Slither clean
- [ ] Coverage maintained (>95%)
- [ ] Gas snapshot updated
- [ ] NatSpec on every public function
- [ ] Tests added for new functionality
- [ ] No breaking changes — OR breaking changes documented in PR description
- [ ] CHANGELOG.md updated
```

---

## 🎓 Learning Resources

If you're new to Foundry / Solidity:
- [Foundry Book](https://book.getfoundry.sh/)
- [Solidity Docs](https://docs.soliditylang.org/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/5.x/)
- [Cyfrin Updraft](https://updraft.cyfrin.io/) — free security course

---

## 📜 License

By contributing, you agree your contributions will be licensed under the [MIT License](./LICENSE).

---

## 🙏 Thanks

Every contribution makes the project stronger. Thank you for helping us build a more secure NFT ecosystem.
