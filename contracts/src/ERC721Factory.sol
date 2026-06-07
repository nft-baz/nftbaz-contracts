// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {ERC721Collection} from "./ERC721Collection.sol";

/// @title EIP-1167 minimal-proxy factory for `ERC721Collection`.
/// @notice Deploys cheap clones (~45 bytes) that all delegate execution to a
///         single implementation. The implementation is set at construction
///         and can be rotated by the owner — existing clones are unaffected
///         (clones are bound to the implementation address that was current
///         when they were created).
contract ERC721Factory is Ownable {
    using Clones for address;

    /// @notice Current implementation pointer used for new clones.
    address public implementation;

    error InvalidImplementation();

    event ImplementationUpdated(
        address indexed oldImplementation, address indexed newImplementation
    );

    /// @param creator   Address that minted the clone (always msg.sender).
    /// @param clone     Deployed clone address.
    /// @param implementation_ Implementation in effect at deploy time.
    /// @param name      Collection name.
    /// @param symbol    Collection symbol.
    /// @param contractURI OpenSea collection-metadata URI.
    /// @param salt      CREATE2 salt; 0x0 for non-deterministic deploys.
    event CollectionCreated(
        address indexed creator,
        address indexed clone,
        address indexed implementation_,
        string name,
        string symbol,
        string contractURI,
        bytes32 salt
    );

    constructor(address implementation_, address owner_) Ownable(owner_) {
        if (implementation_ == address(0)) revert InvalidImplementation();
        implementation = implementation_;
        emit ImplementationUpdated(address(0), implementation_);
    }

    /// @notice Update the implementation used by future clones. Existing
    ///         clones still point at the previous implementation forever
    ///         (EIP-1167 hard-codes the target in the bytecode).
    function setImplementation(address newImpl) external onlyOwner {
        if (newImpl == address(0)) revert InvalidImplementation();
        address old = implementation;
        implementation = newImpl;
        emit ImplementationUpdated(old, newImpl);
    }

    /// @notice Deploy a new collection clone (non-deterministic).
    /// @return clone The deployed clone's address.
    function createCollection(
        string calldata name,
        string calldata symbol,
        address owner_,
        string calldata baseTokenURI,
        string calldata contractURI,
        address royaltyRecipient,
        uint96 royaltyBps,
        uint256 maxSupply
    ) external returns (address clone) {
        address impl = implementation;
        clone = impl.clone();
        ERC721Collection(clone).initialize(
            name,
            symbol,
            owner_,
            baseTokenURI,
            contractURI,
            royaltyRecipient,
            royaltyBps,
            maxSupply
        );
        emit CollectionCreated(
            msg.sender, clone, impl, name, symbol, contractURI, bytes32(0)
        );
    }

    /// @notice Deploy a new collection clone via CREATE2 so the address is
    ///         predictable. Useful when the platform needs to reference a
    ///         collection address before the deploy is mined.
    function createCollectionDeterministic(
        bytes32 salt,
        string calldata name,
        string calldata symbol,
        address owner_,
        string calldata baseTokenURI,
        string calldata contractURI,
        address royaltyRecipient,
        uint96 royaltyBps,
        uint256 maxSupply
    ) external returns (address clone) {
        address impl = implementation;
        clone = impl.cloneDeterministic(salt);
        ERC721Collection(clone).initialize(
            name,
            symbol,
            owner_,
            baseTokenURI,
            contractURI,
            royaltyRecipient,
            royaltyBps,
            maxSupply
        );
        emit CollectionCreated(msg.sender, clone, impl, name, symbol, contractURI, salt);
    }

    /// @notice Predict the address `createCollectionDeterministic(salt, …)`
    ///         would return without deploying. Helper for off-chain
    ///         consumers (e.g. the gateway pre-computing addresses for
    ///         pending-deploy UI).
    function predictDeterministicAddress(bytes32 salt) external view returns (address) {
        return implementation.predictDeterministicAddress(salt, address(this));
    }
}
