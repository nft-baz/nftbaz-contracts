// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC1155Collection} from "../src/ERC1155Collection.sol";
import {ERC1155Factory} from "../src/ERC1155Factory.sol";

contract ERC1155FactoryTest is Test {
    ERC1155Collection internal impl;
    ERC1155Factory internal factory;

    address internal owner = makeAddr("factoryOwner");
    address internal deployer = makeAddr("deployer");
    address internal collOwner = makeAddr("collOwner");
    address internal royaltyRecipient = makeAddr("royalty");

    function setUp() public {
        impl = new ERC1155Collection();
        factory = new ERC1155Factory(address(impl), owner);
    }

    function test_constructor_rejectsZeroImpl() public {
        vm.expectRevert(ERC1155Factory.InvalidImplementation.selector);
        new ERC1155Factory(address(0), owner);
    }

    function test_createCollection_initializes() public {
        vm.prank(deployer);
        address clone = factory.createCollection(
            "Multi", "MLT", collOwner, "ipfs://base/", "ipfs://meta", royaltyRecipient, 750
        );
        ERC1155Collection c = ERC1155Collection(clone);
        assertEq(c.name(), "Multi");
        assertEq(c.symbol(), "MLT");
        assertEq(c.owner(), collOwner);
        assertEq(c.contractURI(), "ipfs://meta");
        (address recv, uint256 amount) = c.royaltyInfo(1, 10_000);
        assertEq(recv, royaltyRecipient);
        assertEq(amount, 750);
    }

    function test_createCollectionDeterministic_matchesPrediction() public {
        bytes32 salt = keccak256("1155-deterministic");
        address predicted = factory.predictDeterministicAddress(salt);
        vm.prank(deployer);
        address actual = factory.createCollectionDeterministic(
            salt, "N", "S", collOwner, "", "", royaltyRecipient, 0
        );
        assertEq(actual, predicted);
    }

    function test_clones_independent() public {
        vm.startPrank(deployer);
        address a = factory.createCollection("A", "A", collOwner, "", "", royaltyRecipient, 0);
        address b = factory.createCollection("B", "B", collOwner, "", "", royaltyRecipient, 0);
        vm.stopPrank();
        vm.prank(collOwner);
        ERC1155Collection(a).mint(deployer, 1, 10, "");
        assertEq(ERC1155Collection(a).totalSupply(1), 10);
        assertEq(ERC1155Collection(b).totalSupply(1), 0);
    }

    function test_setImplementation_onlyOwner() public {
        ERC1155Collection newImpl = new ERC1155Collection();
        vm.expectRevert();
        factory.setImplementation(address(newImpl));
        vm.prank(owner);
        factory.setImplementation(address(newImpl));
        assertEq(factory.implementation(), address(newImpl));
    }
}
