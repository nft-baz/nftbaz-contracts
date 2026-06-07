// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {ERC1155Collection} from "../src/ERC1155Collection.sol";

contract ERC1155CollectionTest is Test {
    ERC1155Collection internal impl;
    ERC1155Collection internal coll;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob   = makeAddr("bob");
    address internal royaltyRecipient = makeAddr("royalty");

    string constant NAME = "Multi";
    string constant SYMBOL = "MULTI";
    string constant BASE_URI = "ipfs://multi/";
    string constant CONTRACT_URI = "ipfs://multi/meta.json";

    event MetadataUpdate(uint256 _tokenId);
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);

    function setUp() public {
        impl = new ERC1155Collection();
        coll = ERC1155Collection(Clones.clone(address(impl)));
        coll.initialize(NAME, SYMBOL, owner, BASE_URI, CONTRACT_URI, royaltyRecipient, 500);
    }

    function test_initialize_setsAllFields() public view {
        assertEq(coll.name(), NAME);
        assertEq(coll.symbol(), SYMBOL);
        assertEq(coll.owner(), owner);
        assertEq(coll.contractURI(), CONTRACT_URI);
        (address recv, uint256 amount) = coll.royaltyInfo(1, 10_000);
        assertEq(recv, royaltyRecipient);
        assertEq(amount, 500);
    }

    function test_initialize_rejectsDoubleInit() public {
        vm.expectRevert();
        coll.initialize(NAME, SYMBOL, owner, BASE_URI, CONTRACT_URI, royaltyRecipient, 500);
    }

    function test_mint_emitsERC4906() public {
        vm.expectEmit(true, false, false, true);
        emit MetadataUpdate(7);
        vm.prank(owner);
        coll.mint(alice, 7, 5, "");
        assertEq(coll.balanceOf(alice, 7), 5);
        assertEq(coll.totalSupply(7), 5);
    }

    function test_mintBatch_emitsRange() public {
        uint256[] memory ids = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        ids[0] = 1; ids[1] = 2; ids[2] = 3;
        amounts[0] = 10; amounts[1] = 20; amounts[2] = 30;
        vm.expectEmit(true, true, false, true);
        emit BatchMetadataUpdate(1, 3);
        vm.prank(owner);
        coll.mintBatch(alice, ids, amounts, "");
        assertEq(coll.balanceOf(alice, 2), 20);
    }

    function test_mintBatch_lengthMismatch_reverts() public {
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](1);
        vm.expectRevert(ERC1155Collection.InvalidBatch.selector);
        vm.prank(owner);
        coll.mintBatch(alice, ids, amounts, "");
    }

    function test_mint_nonOwner_reverts() public {
        vm.expectRevert();
        vm.prank(alice);
        coll.mint(alice, 1, 1, "");
    }

    // ---------- per-id supply cap ----------

    function test_setMaxSupply_enforcedAtMint() public {
        vm.prank(owner);
        coll.setMaxSupply(1, 10);
        assertEq(coll.maxSupply(1), 10);
        vm.prank(owner);
        coll.mint(alice, 1, 6, "");
        vm.expectRevert(abi.encodeWithSelector(ERC1155Collection.MaxSupplyExceeded.selector, 1, 11, 10));
        vm.prank(owner);
        coll.mint(alice, 1, 5, "");
    }

    function test_setMaxSupply_cannotDropBelowCurrent() public {
        vm.prank(owner);
        coll.mint(alice, 1, 5, "");
        vm.expectRevert(abi.encodeWithSelector(ERC1155Collection.MaxSupplyExceeded.selector, 1, 5, 3));
        vm.prank(owner);
        coll.setMaxSupply(1, 3);
    }

    // ---------- burn ----------

    function test_burn_self() public {
        vm.prank(owner);
        coll.mint(alice, 1, 10, "");
        vm.prank(alice);
        coll.burn(alice, 1, 4);
        assertEq(coll.balanceOf(alice, 1), 6);
        assertEq(coll.totalSupply(1), 6);
    }

    function test_burn_unauthorized_reverts() public {
        vm.prank(owner);
        coll.mint(alice, 1, 10, "");
        vm.expectRevert();
        vm.prank(bob);
        coll.burn(alice, 1, 1);
    }

    function test_burn_byApprovedAll() public {
        vm.prank(owner);
        coll.mint(alice, 1, 10, "");
        vm.prank(alice);
        coll.setApprovalForAll(bob, true);
        vm.prank(bob);
        coll.burn(alice, 1, 4);
        assertEq(coll.balanceOf(alice, 1), 6);
    }

    function test_burnBatch_self() public {
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = 1; ids[1] = 2;
        amounts[0] = 5; amounts[1] = 10;
        vm.prank(owner);
        coll.mintBatch(alice, ids, amounts, "");
        uint256[] memory burnAmounts = new uint256[](2);
        burnAmounts[0] = 2; burnAmounts[1] = 4;
        vm.prank(alice);
        coll.burnBatch(alice, ids, burnAmounts);
        assertEq(coll.balanceOf(alice, 1), 3);
        assertEq(coll.balanceOf(alice, 2), 6);
    }

    // ---------- metadata ----------

    function test_setURI_perId_emitsERC4906() public {
        vm.prank(owner);
        coll.mint(alice, 5, 1, "");
        vm.expectEmit(true, false, false, true);
        emit MetadataUpdate(5);
        vm.prank(owner);
        coll.setURI(5, "ipfs://override-5");
        assertEq(coll.uri(5), "ipfs://override-5");
    }

    function test_setBaseURI_emitsWideBatchUpdate() public {
        vm.expectEmit(true, true, false, true);
        emit BatchMetadataUpdate(0, type(uint256).max);
        vm.prank(owner);
        coll.setBaseURI("ipfs://new-base/");
    }

    function test_setContractURI() public {
        vm.prank(owner);
        coll.setContractURI("ipfs://new-collection-meta.json");
        assertEq(coll.contractURI(), "ipfs://new-collection-meta.json");
    }

    // ---------- royalty ----------

    function test_setRoyalty_updates() public {
        address newRecv = makeAddr("newRecv");
        vm.prank(owner);
        coll.setRoyalty(newRecv, 250);
        (address recv, uint256 amt) = coll.royaltyInfo(1, 10_000);
        assertEq(recv, newRecv);
        assertEq(amt, 250);
    }

    function test_setRoyalty_zeroRecipient_reverts() public {
        vm.expectRevert(ERC1155Collection.InvalidRoyaltyRecipient.selector);
        vm.prank(owner);
        coll.setRoyalty(address(0), 100);
    }

    function test_setTokenRoyalty_overridesDefault() public {
        address newRecv = makeAddr("newRecv");
        vm.prank(owner);
        coll.setTokenRoyalty(42, newRecv, 600);
        (address recv, uint256 amt) = coll.royaltyInfo(42, 10_000);
        assertEq(recv, newRecv);
        assertEq(amt, 600);
    }

    // ---------- interface support ----------

    function test_supportsInterface() public view {
        // ERC1155 = 0xd9b67a26, ERC2981 = 0x2a55205a, ERC4906 = 0x49064906
        assertTrue(coll.supportsInterface(0xd9b67a26));
        assertTrue(coll.supportsInterface(0x2a55205a));
        assertTrue(coll.supportsInterface(0x49064906));
    }

    // ---------- clone isolation ----------

    function test_clones_haveIndependentState() public {
        ERC1155Collection a = ERC1155Collection(Clones.clone(address(impl)));
        ERC1155Collection b = ERC1155Collection(Clones.clone(address(impl)));
        a.initialize("A", "A", owner, BASE_URI, CONTRACT_URI, royaltyRecipient, 100);
        b.initialize("B", "B", owner, BASE_URI, CONTRACT_URI, royaltyRecipient, 200);
        vm.prank(owner);
        a.mint(alice, 1, 5, "");
        assertEq(a.totalSupply(1), 5);
        assertEq(b.totalSupply(1), 0);
    }
}
