// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Sanity} from "../src/Sanity.sol";

contract SanityTest is Test {
    function test_version_constant() public {
        Sanity s = new Sanity();
        assertEq(s.VERSION(), 1);
    }
}
