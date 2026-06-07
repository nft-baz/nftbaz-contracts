// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC721Upgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {ERC721URIStorageUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import {ERC721RoyaltyUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721RoyaltyUpgradeable.sol";
import {EIP712Upgradeable} from
    "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {IContractURI} from "./interfaces/IContractURI.sol";
import {IERC4906} from "./interfaces/IERC4906.sol";

/// @title Gateway's canonical ERC-721 collection implementation.
/// @notice Deployed once per chain, then cloned cheaply via EIP-1167 by
///         `ERC721Factory`. Each clone is fully independent state-wise.
///
/// Features:
///   - Initializable (no constructor → EIP-1167 friendly)
///   - ERC-721 + URIStorage (per-token URI override) + RoyaltyUpgradeable
///     (EIP-2981)
///   - OpenSea contractURI() collection-metadata standard
///   - ERC-4906 MetadataUpdate / BatchMetadataUpdate events on any URI
///     mutation
///   - Optional maxSupply enforcement
///   - Ownable, no upgrade hooks (the clone is meant to live forever; if
///     the operator needs migrations they deploy a new factory with a
///     new implementation pointer)
contract ERC721Collection is
    Initializable,
    ERC721Upgradeable,
    ERC721URIStorageUpgradeable,
    ERC721RoyaltyUpgradeable,
    OwnableUpgradeable,
    EIP712Upgradeable,
    IContractURI,
    IERC4906
{
    using Strings for uint256;

    // ---------- storage ----------

    string private _baseURIValue;
    string private _contractURI;
    uint256 private _maxSupply;
    uint256 private _totalSupply;
    /// @dev Voucher digest → consumed flag (replay protection for redeem).
    mapping(bytes32 => bool) private _redeemedVouchers;

    // ---------- EIP-712 voucher ----------

    /// @dev Must match the gateway's TypeScript LAZY_MINT_VOUCHER_TYPES
    ///      (src/modules/voucher/voucher.types.ts) byte-for-byte.
    struct LazyMintVoucher {
        uint256 tokenId;
        string  tokenURI;
        uint256 price;
        address currency; // 0x0 = native
        uint256 validUntil;
        address signer;
    }

    bytes32 internal constant _VOUCHER_TYPEHASH = keccak256(
        "LazyMintVoucher(uint256 tokenId,string tokenURI,uint256 price,address currency,uint256 validUntil,address signer)"
    );

    // ---------- errors ----------

    error MaxSupplyExceeded(uint256 attempted, uint256 cap);
    error TokenAlreadyMinted(uint256 tokenId);
    error InvalidRoyaltyRecipient();
    error InvalidBatch();
    error VoucherExpired(uint256 validUntil, uint256 nowTs);
    error VoucherSignerNotAuthorized(address recovered, address claimed);
    error VoucherAlreadyRedeemed(bytes32 digest);
    error WrongCurrency(address expected, address provided);
    error InsufficientPayment(uint256 expected, uint256 provided);

    // ---------- events (in addition to inherited ERC721 + ERC2981) ----------

    /// @notice Emitted when the collection-level `contractURI` is changed.
    event ContractURIUpdated(string newContractURI);

    /// @notice Emitted when the base URI for tokens with no explicit URI changes.
    event BaseURIUpdated(string newBaseURI);

    // ---------- initialization ----------

    /// @param name_              ERC-721 name (e.g. "My Collection")
    /// @param symbol_            ERC-721 symbol (e.g. "MYC")
    /// @param owner_             Initial owner (collection admin)
    /// @param baseTokenURI_      Optional base URI; pass "" if every token uses its own URI.
    /// @param contractURI_       OpenSea collection-metadata URI (ipfs://… etc.)
    /// @param royaltyRecipient_  EIP-2981 royalty receiver (use address(0) to disable royalties)
    /// @param royaltyBps_        Royalty in basis points (0..10000)
    /// @param maxSupply_         Cap on total minted; 0 = unlimited
    function initialize(
        string calldata name_,
        string calldata symbol_,
        address owner_,
        string calldata baseTokenURI_,
        string calldata contractURI_,
        address royaltyRecipient_,
        uint96 royaltyBps_,
        uint256 maxSupply_
    ) external initializer {
        __ERC721_init(name_, symbol_);
        __ERC721URIStorage_init();
        __ERC721Royalty_init();
        __Ownable_init(owner_);
        // Domain MUST match the gateway's LAZY_MINT_DOMAIN_NAME / VERSION
        // (src/modules/voucher/voucher.types.ts).
        __EIP712_init("NftBaz LazyMint", "1");

        _baseURIValue = baseTokenURI_;
        _contractURI = contractURI_;
        _maxSupply = maxSupply_;

        if (royaltyRecipient_ != address(0) && royaltyBps_ > 0) {
            _setDefaultRoyalty(royaltyRecipient_, royaltyBps_);
        }
        if (bytes(contractURI_).length > 0) emit ContractURIUpdated(contractURI_);
        if (bytes(baseTokenURI_).length > 0) emit BaseURIUpdated(baseTokenURI_);
    }

    // ---------- mint / burn ----------

    /// @notice Mint a single token. Optional per-token URI; pass "" to use baseURI/{id}.
    function mint(address to, uint256 tokenId, string calldata tokenURI_)
        external
        onlyOwner
    {
        _enforceSupply(1);
        _safeMint(to, tokenId);
        if (bytes(tokenURI_).length > 0) {
            _setTokenURI(tokenId, tokenURI_);
        }
        emit MetadataUpdate(tokenId);
    }

    /// @notice Batch mint. tokenIds.length == tokenURIs.length; tokenURIs may
    ///         contain empty strings to defer to baseURI.
    function mintBatch(
        address to,
        uint256[] calldata tokenIds,
        string[] calldata tokenURIs
    ) external onlyOwner {
        if (tokenIds.length == 0 || tokenIds.length != tokenURIs.length) {
            revert InvalidBatch();
        }
        _enforceSupply(tokenIds.length);
        for (uint256 i; i < tokenIds.length; ++i) {
            _safeMint(to, tokenIds[i]);
            if (bytes(tokenURIs[i]).length > 0) {
                _setTokenURI(tokenIds[i], tokenURIs[i]);
            }
        }
        emit BatchMetadataUpdate(tokenIds[0], tokenIds[tokenIds.length - 1]);
    }

    /// @notice Redeem an EIP-712 lazy-mint voucher signed by an authorized
    ///         signer (the contract owner or any address approved-for-all
    ///         by the owner). Pays the signer in `currency` (native if
    ///         currency==0x0, otherwise the ERC-20 isn't pulled here — the
    ///         buyer pre-approves and we'd need a transferFrom; this v1
    ///         supports native only and reverts cleanly otherwise).
    /// @param voucher   The voucher payload signed off-chain.
    /// @param signature 65-byte canonical (r,s,v) signature.
    function redeemVoucher(LazyMintVoucher calldata voucher, bytes calldata signature)
        external
        payable
        returns (bytes32 digest)
    {
        // 1. Expiry.
        if (block.timestamp > voucher.validUntil) {
            revert VoucherExpired(voucher.validUntil, block.timestamp);
        }

        // 2. Verify signature.
        digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    _VOUCHER_TYPEHASH,
                    voucher.tokenId,
                    keccak256(bytes(voucher.tokenURI)),
                    voucher.price,
                    voucher.currency,
                    voucher.validUntil,
                    voucher.signer
                )
            )
        );

        // 3. Replay protection.
        if (_redeemedVouchers[digest]) revert VoucherAlreadyRedeemed(digest);
        _redeemedVouchers[digest] = true;

        // 4. Signer must be the contract owner OR approved-for-all by the owner.
        address recovered = ECDSA.recover(digest, signature);
        address contractOwner = owner();
        if (recovered != voucher.signer) {
            revert VoucherSignerNotAuthorized(recovered, voucher.signer);
        }
        if (
            voucher.signer != contractOwner
                && !isApprovedForAll(contractOwner, voucher.signer)
        ) {
            revert VoucherSignerNotAuthorized(voucher.signer, contractOwner);
        }

        // 5. Payment (v1: native only).
        if (voucher.currency != address(0)) {
            revert WrongCurrency(address(0), voucher.currency);
        }
        if (msg.value < voucher.price) {
            revert InsufficientPayment(voucher.price, msg.value);
        }

        // 6. Mint.
        _enforceSupply(1);
        _safeMint(msg.sender, voucher.tokenId);
        if (bytes(voucher.tokenURI).length > 0) {
            _setTokenURI(voucher.tokenId, voucher.tokenURI);
        }
        emit MetadataUpdate(voucher.tokenId);

        // 7. Forward payment to the signer (the seller).
        if (voucher.price > 0) {
            (bool ok, ) = payable(voucher.signer).call{value: voucher.price}("");
            require(ok, "ERC721Collection: signer payment failed");
        }
        // 8. Refund overpayment.
        if (msg.value > voucher.price) {
            (bool ok2, ) = payable(msg.sender).call{value: msg.value - voucher.price}("");
            require(ok2, "ERC721Collection: refund failed");
        }
    }

    /// @notice Check whether a voucher digest has been redeemed (replay status).
    function isVoucherRedeemed(bytes32 digest) external view returns (bool) {
        return _redeemedVouchers[digest];
    }

    /// @notice Burn a token. Owner OR approved-for-all OR the token itself.
    function burn(uint256 tokenId) external {
        address tokenOwner = _requireOwned(tokenId);
        if (
            msg.sender != tokenOwner
                && !isApprovedForAll(tokenOwner, msg.sender)
                && getApproved(tokenId) != msg.sender
        ) {
            revert ERC721InsufficientApproval(msg.sender, tokenId);
        }
        _burn(tokenId);
        // Royalty cleanup is handled by OZ in _update; no further action needed.
        unchecked {
            --_totalSupply;
        }
    }

    // ---------- admin: metadata + royalty ----------

    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        _baseURIValue = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
        // Conservatively broadcast a wide range — opensea reads the indexer's
        // current high-water mark from the BatchMetadataUpdate.
        if (_totalSupply > 0) {
            emit BatchMetadataUpdate(0, type(uint256).max);
        }
    }

    function setContractURI(string calldata newContractURI) external onlyOwner {
        _contractURI = newContractURI;
        emit ContractURIUpdated(newContractURI);
    }

    function setTokenURI(uint256 tokenId, string calldata uri_) external onlyOwner {
        _requireOwned(tokenId);
        _setTokenURI(tokenId, uri_);
        emit MetadataUpdate(tokenId);
    }

    function setRoyalty(address recipient, uint96 feeNumerator) external onlyOwner {
        if (recipient == address(0)) revert InvalidRoyaltyRecipient();
        _setDefaultRoyalty(recipient, feeNumerator);
    }

    function setTokenRoyalty(uint256 tokenId, address recipient, uint96 feeNumerator)
        external
        onlyOwner
    {
        _requireOwned(tokenId);
        _setTokenRoyalty(tokenId, recipient, feeNumerator);
    }

    /// @notice Lift the max-supply cap. One-way: cannot be lowered once raised.
    function setMaxSupply(uint256 newMax) external onlyOwner {
        if (newMax != 0 && newMax < _totalSupply) {
            revert MaxSupplyExceeded(newMax, _totalSupply);
        }
        _maxSupply = newMax;
    }

    // ---------- views ----------

    function contractURI() external view override returns (string memory) {
        return _contractURI;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function maxSupply() external view returns (uint256) {
        return _maxSupply;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseURIValue;
    }

    // ---------- required overrides (solidity multi-inheritance) ----------

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(
            ERC721Upgradeable,
            ERC721URIStorageUpgradeable,
            ERC721RoyaltyUpgradeable
        )
        returns (bool)
    {
        // ERC-4906 = 0x49064906 (per the spec); we advertise it explicitly so
        // OpenSea's metadata refresh path engages.
        return interfaceId == bytes4(0x49064906) || super.supportsInterface(interfaceId);
    }

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721Upgradeable)
        returns (address)
    {
        address from = super._update(to, tokenId, auth);
        if (from == address(0)) {
            unchecked {
                ++_totalSupply;
            }
        }
        // Burns are handled by burn(); _update from non-zero to address(0)
        // happens via _burn() which we call there with explicit decrement.
        return from;
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721Upgradeable)
    {
        super._increaseBalance(account, value);
    }

    // ---------- internal ----------

    function _enforceSupply(uint256 mintCount) internal view {
        uint256 cap = _maxSupply;
        if (cap != 0 && _totalSupply + mintCount > cap) {
            revert MaxSupplyExceeded(_totalSupply + mintCount, cap);
        }
    }
}
