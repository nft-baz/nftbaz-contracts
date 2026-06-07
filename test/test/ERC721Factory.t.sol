// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC721Collection} from "../src/ERC721Collection.sol";
import {ERC721Factory} from "../src/ERC721Factory.sol";

contract ERC721FactoryTest is Test {
    ERC721Collection internal impl;
    ERC721Factory internal factory;

    address internal owner = makeAddr("factoryOwner");
    address internal deployer = makeAddr("deployer");
    address internal collOwner = makeAddr("collOwner");
    address internal royaltyRecipient = makeAddr("royalty");

    event CollectionCreated(
        address indexed creator,
        address indexed clone,
        address indexed implementation_,
        string name,
        string symbol,
        string contractURI,
        bytes32 salt
    );

    function setUp() public {
        impl = new ERC721Collection();
        factory = new ERC721Factory(address(impl), owner);
    }

    function test_constructor_rejectsZeroImpl() public {
        vm.expectRevert(ERC721Factory.InvalidImplementation.selector);
        new ERC721Factory(address(0), owner);
    }

    function test_createCollection_initializes_andEmitsEvent() public {
        vm.expectEmit(true, false, true, false);
        emit CollectionCreated(
            deployer, address(0), address(impl), "Name", "SYM", "ipfs://meta", bytes32(0)
        );
        vm.prank(deployer);
        address clone = factory.createCollection(
            "Name", "SYM", collOwner, "ipfs://base/", "ipfs://meta",
            royaltyRecipient, 250, 0
        );
        ERC721Collection c = ERC721Collection(clone);
        assertEq(c.owner(), collOwner);
        assertEq(c.name(), "Name");
        assertEq(c.symbol(), "SYM");
        assertEq(c.contractURI(), "ipfs://meta");
    }

    function test_clones_haveIndependentState() public {
        vm.startPrank(deployer);
        address a = factory.createCollection("A", "A", collOwner, "", "", royaltyRecipient, 100, 0);
        address b = factory.createCollection("B", "B", collOwner, "", "", royaltyRecipient, 200, 0);
        vm.stopPrank();

        ERC721Collection ca = ERC721Collection(a);
        ERC721Collection cb = ERC721Collection(b);

        vm.prank(collOwner);
        ca.mint(deployer, 1, "");
        assertEq(ca.totalSupply(), 1);
        assertEq(cb.totalSupply(), 0);
    }

    function test_createCollectionDeterministic_matchesPrediction() public {
        bytes32 salt = keccak256("my-collection-1");
        address predicted = factory.predictDeterministicAddress(salt);
        vm.prank(deployer);
        address actual = factory.createCollectionDeterministic(
            salt, "Name", "SYM", collOwner, "", "", royaltyRecipient, 0, 0
        );
        assertEq(actual, predicted);
    }

    function test_createCollectionDeterministic_sameSalt_secondCall_reverts() public {
        bytes32 salt = keccak256("dup-salt");
        vm.prank(deployer);
        factory.createCollectionDeterministic(
            salt, "Name", "SYM", collOwner, "", "", royaltyRecipient, 0, 0
        );
        vm.expectRevert(); // ERC1167FailedCreateClone or FailedDeployment
        vm.prank(deployer);
        factory.createCollectionDeterministic(
            salt, "Other", "OTH", collOwner, "", "", royaltyRecipient, 0, 0
        );
    }

    function test_setImplementation_onlyOwner() public {
        ERC721Collection newImpl = new ERC721Collection();
        vm.expectRevert();
        factory.setImplementation(address(newImpl));
        vm.prank(owner);
        factory.setImplementation(address(newImpl));
        assertEq(factory.implementation(), address(newImpl));
    }

    function test_setImplementation_rejectsZero() public {
        vm.expectRevert(ERC721Factory.InvalidImplementation.selector);
        vm.prank(owner);
        factory.setImplementation(address(0));
    }

    function test_setImplementation_doesNotAffectExistingClones() public {
        vm.prank(deployer);
        address cloneAddr = factory.createCollection(
            "A", "A", collOwner, "", "", royaltyRecipient, 0, 0
        );
        ERC721Collection newImpl = new ERC721Collection();
        vm.prank(owner);
        factory.setImplementation(address(newImpl));
        // Existing clone still points at old impl bytecode; mint still works.
        vm.prank(collOwner);
        ERC721Collection(cloneAddr).mint(deployer, 1, "");
        assertEq(ERC721Collection(cloneAddr).ownerOf(1), deployer);
    }
}
