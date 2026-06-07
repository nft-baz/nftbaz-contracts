// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title OpenSea collection metadata standard.
/// @notice `contractURI()` is read by OpenSea / Blur / Magic Eden / LooksRare
///         to populate the collection-level metadata (name, image, royalties
///         display, social links, …). Returning an IPFS URI keeps the
///         collection metadata fully decentralized.
interface IContractURI {
    function contractURI() external view returns (string memory);
}
