// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @title EIP-4906 — Metadata Update Extension
/// @notice OpenSea + the major marketplaces watch these events to invalidate
///         cached metadata after a tokenURI / baseURI change.
interface IERC4906 is IERC165 {
    /// @dev Emitted when the metadata of a token is changed.
    event MetadataUpdate(uint256 _tokenId);

    /// @dev Emitted when the metadata of `fromTokenId` ... `toTokenId` is changed.
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);
}
