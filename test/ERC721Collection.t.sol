// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {ERC721Collection} from "../src/ERC721Collection.sol";

contract ERC721CollectionTest is Test {
    ERC721Collection internal impl;
    ERC721Collection internal coll;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob   = makeAddr("bob");
    address internal royaltyRecipient = makeAddr("royalty");

    string constant NAME = "Test Collection";
    string constant SYMBOL = "TEST";
    string constant BASE_URI = "ipfs://baseuri/";
    string constant CONTRACT_URI = "ipfs://contractmeta/collection.json";
    uint96 constant ROYALTY_BPS = 500; // 5%

    // ERC-4906 events we want to assert on.
    event MetadataUpdate(uint256 _tokenId);
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);

    function setUp() public {
        impl = new ERC721Collection();
        coll = ERC721Collection(Clones.clone(address(impl)));
        coll.initialize(
            NAME,
            SYMBOL,
            owner,
            BASE_URI,
            CONTRACT_URI,
            royaltyRecipient,
            ROYALTY_BPS,
            0
        );
    }

    // ---------- initialization ----------

    function test_initialize_setsAllFields() public view {
        assertEq(coll.name(), NAME);
        assertEq(coll.symbol(), SYMBOL);
        assertEq(coll.owner(), owner);
        assertEq(coll.contractURI(), CONTRACT_URI);
        assertEq(coll.totalSupply(), 0);
        assertEq(coll.maxSupply(), 0);
        (address recv, uint256 bps) = coll.royaltyInfo(1, 10_000);
        assertEq(recv, royaltyRecipient);
        assertEq(bps, 500); // 5% of 10,000
    }

    function test_initialize_rejectsDoubleInit() public {
        vm.expectRevert(); // OZ Initializable: InvalidInitialization()
        coll.initialize(NAME, SYMBOL, owner, BASE_URI, CONTRACT_URI, royaltyRecipient, ROYALTY_BPS, 0);
    }

    function test_initialize_zeroRoyaltyRecipient_skipsRoyalty() public {
        ERC721Collection c = ERC721Collection(Clones.clone(address(impl)));
        c.initialize(NAME, SYMBOL, owner, BASE_URI, CONTRACT_URI, address(0), 0, 0);
        (address recv,) = c.royaltyInfo(1, 10_000);
        assertEq(recv, address(0));
    }

    // ---------- mint ----------

    function test_mint_singleToken_emitsERC4906() public {
        vm.expectEmit(true, false, false, true);
        emit MetadataUpdate(42);
        vm.prank(owner);
        coll.mint(alice, 42, "");
        assertEq(coll.ownerOf(42), alice);
        assertEq(coll.totalSupply(), 1);
        // Falls back to baseURI/{id}.
        assertEq(coll.tokenURI(42), string.concat(BASE_URI, "42"));
    }

    function test_mint_withTokenURI_overridesBase() public {
        vm.prank(owner);
        coll.mint(alice, 1, "ipfs://Qm.../1.json");
        assertEq(coll.tokenURI(1), "ipfs://Qm.../1.json");
    }

    function test_mint_nonOwner_reverts() public {
        vm.expectRevert();
        vm.prank(alice);
        coll.mint(alice, 1, "");
    }

    function test_mintBatch_emitsBatchERC4906_andSetsRange() public {
        uint256[] memory ids = new uint256[](3);
        ids[0] = 10; ids[1] = 11; ids[2] = 12;
        string[] memory uris = new string[](3);
        uris[0] = ""; uris[1] = ""; uris[2] = "";
        vm.expectEmit(true, true, false, true);
        emit BatchMetadataUpdate(10, 12);
        vm.prank(owner);
        coll.mintBatch(alice, ids, uris);
        assertEq(coll.totalSupply(), 3);
        assertEq(coll.ownerOf(11), alice);
    }

    function test_mintBatch_lengthMismatch_reverts() public {
        uint256[] memory ids = new uint256[](2);
        string[] memory uris = new string[](1);
        vm.expectRevert(ERC721Collection.InvalidBatch.selector);
        vm.prank(owner);
        coll.mintBatch(alice, ids, uris);
    }

    // ---------- max supply ----------

    function test_maxSupply_enforced() public {
        ERC721Collection cap = ERC721Collection(Clones.clone(address(impl)));
        cap.initialize(NAME, SYMBOL, owner, BASE_URI, CONTRACT_URI, royaltyRecipient, ROYALTY_BPS, 2);
        vm.startPrank(owner);
        cap.mint(alice, 1, "");
        cap.mint(alice, 2, "");
        vm.expectRevert(abi.encodeWithSelector(ERC721Collection.MaxSupplyExceeded.selector, 3, 2));
        cap.mint(alice, 3, "");
        vm.stopPrank();
    }

    function test_setMaxSupply_cannotDropBelowCurrent() public {
        vm.startPrank(owner);
        coll.mint(alice, 1, "");
        coll.mint(alice, 2, "");
        vm.expectRevert(abi.encodeWithSelector(ERC721Collection.MaxSupplyExceeded.selector, 1, 2));
        coll.setMaxSupply(1);
        vm.stopPrank();
    }

    function test_setMaxSupply_canRaiseOrUncap() public {
        vm.prank(owner);
        coll.setMaxSupply(100);
        assertEq(coll.maxSupply(), 100);
        vm.prank(owner);
        coll.setMaxSupply(0); // uncap
        assertEq(coll.maxSupply(), 0);
    }

    // ---------- burn ----------

    function test_burn_byOwnerOfToken() public {
        vm.prank(owner);
        coll.mint(alice, 1, "");
        vm.prank(alice);
        coll.burn(1);
        assertEq(coll.totalSupply(), 0);
        vm.expectRevert();
        coll.ownerOf(1);
    }

    function test_burn_byApproved() public {
        vm.prank(owner);
        coll.mint(alice, 1, "");
        vm.prank(alice);
        coll.approve(bob, 1);
        vm.prank(bob);
        coll.burn(1);
        assertEq(coll.totalSupply(), 0);
    }

    function test_burn_unauthorized_reverts() public {
        vm.prank(owner);
        coll.mint(alice, 1, "");
        vm.expectRevert();
        vm.prank(bob);
        coll.burn(1);
    }

    // ---------- royalty ----------

    function test_setRoyalty_updatesRecipient() public {
        address newRecv = makeAddr("newRoyaltyRecv");
        vm.prank(owner);
        coll.setRoyalty(newRecv, 1000); // 10%
        (address recv, uint256 amount) = coll.royaltyInfo(1, 10_000);
        assertEq(recv, newRecv);
        assertEq(amount, 1000);
    }

    function test_setRoyalty_zeroRecipient_reverts() public {
        vm.expectRevert(ERC721Collection.InvalidRoyaltyRecipient.selector);
        vm.prank(owner);
        coll.setRoyalty(address(0), 500);
    }

    function test_setTokenRoyalty_overridesDefault() public {
        vm.prank(owner);
        coll.mint(alice, 1, "");
        address newRecv = makeAddr("perTokenRecv");
        vm.prank(owner);
        coll.setTokenRoyalty(1, newRecv, 200);
        (address recv, uint256 amount) = coll.royaltyInfo(1, 10_000);
        assertEq(recv, newRecv);
        assertEq(amount, 200);
    }

    // ---------- metadata ----------

    function test_setBaseURI_emitsBatchUpdate() public {
        vm.prank(owner);
        coll.mint(alice, 1, "");
        vm.expectEmit(true, true, false, true);
        emit BatchMetadataUpdate(0, type(uint256).max);
        vm.prank(owner);
        coll.setBaseURI("ipfs://newbase/");
    }

    function test_setContractURI() public {
        vm.prank(owner);
        coll.setContractURI("ipfs://newmeta/");
        assertEq(coll.contractURI(), "ipfs://newmeta/");
    }

    function test_setTokenURI_emitsMetadataUpdate() public {
        vm.prank(owner);
        coll.mint(alice, 1, "");
        vm.expectEmit(true, false, false, true);
        emit MetadataUpdate(1);
        vm.prank(owner);
        coll.setTokenURI(1, "ipfs://updated/");
        assertEq(coll.tokenURI(1), "ipfs://updated/");
    }

    // ---------- ownership ----------

    function test_transferOwnership() public {
        vm.prank(owner);
        coll.transferOwnership(bob);
        assertEq(coll.owner(), bob);
        // Old owner can no longer mint.
        vm.expectRevert();
        vm.prank(owner);
        coll.mint(alice, 1, "");
    }

    // ---------- interface support ----------

    function test_supportsInterface_advertisesERC4906() public view {
        assertTrue(coll.supportsInterface(bytes4(0x49064906)));
    }

    function test_supportsInterface_advertisesERC721AndERC2981() public view {
        // ERC721 = 0x80ac58cd, ERC2981 = 0x2a55205a
        assertTrue(coll.supportsInterface(0x80ac58cd));
        assertTrue(coll.supportsInterface(0x2a55205a));
    }

    // ---------- isolation: two clones are independent ----------

    function test_clones_haveIndependentState() public {
        ERC721Collection a = ERC721Collection(Clones.clone(address(impl)));
        ERC721Collection b = ERC721Collection(Clones.clone(address(impl)));
        a.initialize("A", "A", owner, BASE_URI, CONTRACT_URI, royaltyRecipient, 100, 0);
        b.initialize("B", "B", owner, BASE_URI, CONTRACT_URI, royaltyRecipient, 200, 0);
        vm.prank(owner);
        a.mint(alice, 1, "");
        assertEq(a.totalSupply(), 1);
        assertEq(b.totalSupply(), 0);
        (, uint256 royA) = a.royaltyInfo(1, 10_000);
        (, uint256 royB) = b.royaltyInfo(1, 10_000);
        assertEq(royA, 100);
        assertEq(royB, 200);
    }
}
