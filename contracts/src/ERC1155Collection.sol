// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC1155Upgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {ERC1155URIStorageUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155URIStorageUpgradeable.sol";
import {ERC1155SupplyUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import {ERC2981Upgradeable} from
    "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";

import {IContractURI} from "./interfaces/IContractURI.sol";
import {IERC4906} from "./interfaces/IERC4906.sol";

/// @title Gateway's canonical ERC-1155 collection implementation.
/// @notice Same lifecycle + metadata story as ERC721Collection. Cloned by
///         ERC1155Factory (EIP-1167) so per-collection state is independent.
///
/// Features:
///   - Initializable (no constructor)
///   - ERC-1155 + URIStorage (per-id URI override) + Supply tracking
///     (so totalSupply / exists / maxSupply work) + ERC-2981 royalties
///   - OpenSea contractURI() collection-metadata standard
///   - ERC-4906 MetadataUpdate / BatchMetadataUpdate events on any URI mutation
///   - Optional per-id max supply (separate from base ERC1155Supply totals)
contract ERC1155Collection is
    Initializable,
    ERC1155Upgradeable,
    ERC1155URIStorageUpgradeable,
    ERC1155SupplyUpgradeable,
    ERC2981Upgradeable,
    OwnableUpgradeable,
    IContractURI,
    IERC4906
{
    // ---------- storage ----------

    string private _name;
    string private _symbol;
    string private _contractURI;
    /// @dev Per-id supply cap (0 = unlimited).
    mapping(uint256 => uint256) private _maxSupply;

    // ---------- errors ----------

    error MaxSupplyExceeded(uint256 id, uint256 attempted, uint256 cap);
    error InvalidBatch();
    error InvalidRoyaltyRecipient();

    // ---------- events ----------

    event ContractURIUpdated(string newContractURI);
    event BaseURIUpdated(string newBaseURI);
    event MaxSupplySet(uint256 indexed id, uint256 cap);

    // ---------- initialization ----------

    /// @param name_              Display name (ERC-1155 does not have an on-chain name; we expose one for parity)
    /// @param symbol_            Display symbol
    /// @param owner_             Initial collection admin
    /// @param baseTokenURI_      Optional base URI (per-id URIs override)
    /// @param contractURI_       OpenSea collection-metadata URI
    /// @param royaltyRecipient_  EIP-2981 royalty receiver (zero = no royalties)
    /// @param royaltyBps_        Royalty in basis points (0..10000)
    function initialize(
        string calldata name_,
        string calldata symbol_,
        address owner_,
        string calldata baseTokenURI_,
        string calldata contractURI_,
        address royaltyRecipient_,
        uint96 royaltyBps_
    ) external initializer {
        __ERC1155_init(baseTokenURI_);
        __ERC1155URIStorage_init();
        __ERC1155Supply_init();
        __ERC2981_init();
        __Ownable_init(owner_);

        _name = name_;
        _symbol = symbol_;
        _contractURI = contractURI_;

        if (royaltyRecipient_ != address(0) && royaltyBps_ > 0) {
            _setDefaultRoyalty(royaltyRecipient_, royaltyBps_);
        }
        if (bytes(contractURI_).length > 0) emit ContractURIUpdated(contractURI_);
        if (bytes(baseTokenURI_).length > 0) {
            _setBaseURI(baseTokenURI_);
            emit BaseURIUpdated(baseTokenURI_);
        }
    }

    // ---------- mint / burn ----------

    function mint(address to, uint256 id, uint256 amount, bytes calldata data)
        external
        onlyOwner
    {
        _enforceSupply(id, amount);
        _mint(to, id, amount, data);
        emit MetadataUpdate(id);
    }

    function mintBatch(
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external onlyOwner {
        if (ids.length == 0 || ids.length != amounts.length) revert InvalidBatch();
        for (uint256 i; i < ids.length; ++i) {
            _enforceSupply(ids[i], amounts[i]);
        }
        _mintBatch(to, ids, amounts, data);
        emit BatchMetadataUpdate(ids[0], ids[ids.length - 1]);
    }

    function burn(address from, uint256 id, uint256 amount) external {
        if (msg.sender != from && !isApprovedForAll(from, msg.sender)) {
            revert ERC1155MissingApprovalForAll(msg.sender, from);
        }
        _burn(from, id, amount);
    }

    function burnBatch(address from, uint256[] calldata ids, uint256[] calldata amounts)
        external
    {
        if (msg.sender != from && !isApprovedForAll(from, msg.sender)) {
            revert ERC1155MissingApprovalForAll(msg.sender, from);
        }
        _burnBatch(from, ids, amounts);
    }

    // ---------- admin: metadata + royalty + supply ----------

    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        _setBaseURI(newBaseURI);
        emit BaseURIUpdated(newBaseURI);
        emit BatchMetadataUpdate(0, type(uint256).max);
    }

    function setURI(uint256 id, string calldata uri_) external onlyOwner {
        _setURI(id, uri_);
        emit MetadataUpdate(id);
    }

    function setContractURI(string calldata newContractURI) external onlyOwner {
        _contractURI = newContractURI;
        emit ContractURIUpdated(newContractURI);
    }

    function setRoyalty(address recipient, uint96 feeNumerator) external onlyOwner {
        if (recipient == address(0)) revert InvalidRoyaltyRecipient();
        _setDefaultRoyalty(recipient, feeNumerator);
    }

    function setTokenRoyalty(uint256 id, address recipient, uint96 feeNumerator)
        external
        onlyOwner
    {
        _setTokenRoyalty(id, recipient, feeNumerator);
    }

    /// @notice One-way cap raise for a given id; cannot drop below existing supply.
    function setMaxSupply(uint256 id, uint256 cap) external onlyOwner {
        if (cap != 0 && cap < totalSupply(id)) {
            revert MaxSupplyExceeded(id, totalSupply(id), cap);
        }
        _maxSupply[id] = cap;
        emit MaxSupplySet(id, cap);
    }

    // ---------- views ----------

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function contractURI() external view override returns (string memory) {
        return _contractURI;
    }

    function maxSupply(uint256 id) external view returns (uint256) {
        return _maxSupply[id];
    }

    function uri(uint256 id)
        public
        view
        override(ERC1155Upgradeable, ERC1155URIStorageUpgradeable)
        returns (string memory)
    {
        return super.uri(id);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Upgradeable, ERC2981Upgradeable)
        returns (bool)
    {
        return interfaceId == bytes4(0x49064906) || super.supportsInterface(interfaceId);
    }

    // ---------- required overrides ----------

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override(ERC1155Upgradeable, ERC1155SupplyUpgradeable) {
        super._update(from, to, ids, values);
    }

    // ---------- internal ----------

    function _enforceSupply(uint256 id, uint256 amount) internal view {
        uint256 cap = _maxSupply[id];
        if (cap != 0 && totalSupply(id) + amount > cap) {
            revert MaxSupplyExceeded(id, totalSupply(id) + amount, cap);
        }
    }
}
