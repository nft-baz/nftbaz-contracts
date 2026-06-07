// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {ERC1155Collection} from "./ERC1155Collection.sol";

/// @title EIP-1167 minimal-proxy factory for `ERC1155Collection`.
/// @notice Same pattern as ERC721Factory — see that file for design notes.
contract ERC1155Factory is Ownable {
    using Clones for address;

    address public implementation;

    error InvalidImplementation();

    event ImplementationUpdated(
        address indexed oldImplementation, address indexed newImplementation
    );

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

    function setImplementation(address newImpl) external onlyOwner {
        if (newImpl == address(0)) revert InvalidImplementation();
        address old = implementation;
        implementation = newImpl;
        emit ImplementationUpdated(old, newImpl);
    }

    function createCollection(
        string calldata name,
        string calldata symbol,
        address owner_,
        string calldata baseTokenURI,
        string calldata contractURI,
        address royaltyRecipient,
        uint96 royaltyBps
    ) external returns (address clone) {
        address impl = implementation;
        clone = impl.clone();
        ERC1155Collection(clone).initialize(
            name,
            symbol,
            owner_,
            baseTokenURI,
            contractURI,
            royaltyRecipient,
            royaltyBps
        );
        emit CollectionCreated(
            msg.sender, clone, impl, name, symbol, contractURI, bytes32(0)
        );
    }

    function createCollectionDeterministic(
        bytes32 salt,
        string calldata name,
        string calldata symbol,
        address owner_,
        string calldata baseTokenURI,
        string calldata contractURI,
        address royaltyRecipient,
        uint96 royaltyBps
    ) external returns (address clone) {
        address impl = implementation;
        clone = impl.cloneDeterministic(salt);
        ERC1155Collection(clone).initialize(
            name,
            symbol,
            owner_,
            baseTokenURI,
            contractURI,
            royaltyRecipient,
            royaltyBps
        );
        emit CollectionCreated(msg.sender, clone, impl, name, symbol, contractURI, salt);
    }

    function predictDeterministicAddress(bytes32 salt) external view returns (address) {
        return implementation.predictDeterministicAddress(salt, address(this));
    }
}
