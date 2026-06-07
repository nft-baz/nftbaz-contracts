// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {ERC721Collection} from "../src/ERC721Collection.sol";

contract ERC721CollectionVoucherTest is Test {
    ERC721Collection internal impl;
    ERC721Collection internal coll;

    address internal collOwner;
    uint256 internal collOwnerPk;
    address internal buyer = makeAddr("buyer");
    address internal royaltyRecipient = makeAddr("royalty");

    bytes32 internal constant VOUCHER_TYPEHASH = keccak256(
        "LazyMintVoucher(uint256 tokenId,string tokenURI,uint256 price,address currency,uint256 validUntil,address signer)"
    );

    function setUp() public {
        // Use a deterministic private key so we can sign vouchers off-chain.
        collOwnerPk = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
        collOwner = vm.addr(collOwnerPk);

        impl = new ERC721Collection();
        coll = ERC721Collection(Clones.clone(address(impl)));
        coll.initialize(
            "Lazy",
            "LZY",
            collOwner,
            "ipfs://base/",
            "ipfs://meta",
            royaltyRecipient,
            500,
            0
        );

        vm.deal(buyer, 100 ether);
    }

    function _domainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes("NftBaz LazyMint")),
                keccak256(bytes("1")),
                block.chainid,
                address(coll)
            )
        );
    }

    function _hashVoucher(ERC721Collection.LazyMintVoucher memory v) internal view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(
                VOUCHER_TYPEHASH,
                v.tokenId,
                keccak256(bytes(v.tokenURI)),
                v.price,
                v.currency,
                v.validUntil,
                v.signer
            )
        );
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparator(), structHash));
    }

    function _sign(uint256 pk, bytes32 digest) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        return abi.encodePacked(r, s, v);
    }

    function _makeVoucher(uint256 tokenId, uint256 price, uint256 validUntil)
        internal
        view
        returns (ERC721Collection.LazyMintVoucher memory v)
    {
        v.tokenId = tokenId;
        v.tokenURI = "ipfs://Qm.../v1.json";
        v.price = price;
        v.currency = address(0); // native
        v.validUntil = validUntil;
        v.signer = collOwner;
    }

    function test_redeem_happyPath_native() public {
        ERC721Collection.LazyMintVoucher memory v = _makeVoucher(1, 1 ether, block.timestamp + 1 days);
        bytes32 digest = _hashVoucher(v);
        bytes memory sig = _sign(collOwnerPk, digest);

        uint256 sellerBefore = collOwner.balance;

        vm.prank(buyer);
        bytes32 returnedDigest = coll.redeemVoucher{value: 1 ether}(v, sig);

        assertEq(returnedDigest, digest);
        assertEq(coll.ownerOf(1), buyer);
        assertEq(coll.tokenURI(1), v.tokenURI);
        assertEq(collOwner.balance - sellerBefore, 1 ether);
        assertTrue(coll.isVoucherRedeemed(digest));
    }

    function test_redeem_refundsOverpayment() public {
        ERC721Collection.LazyMintVoucher memory v = _makeVoucher(2, 1 ether, block.timestamp + 1 days);
        bytes memory sig = _sign(collOwnerPk, _hashVoucher(v));

        uint256 buyerBefore = buyer.balance;
        vm.prank(buyer);
        coll.redeemVoucher{value: 3 ether}(v, sig);

        // Buyer pays 1 ether net; should receive 2 ether back (ignoring gas in the test).
        assertEq(buyer.balance, buyerBefore - 1 ether);
    }

    function test_redeem_free_zeroPrice() public {
        ERC721Collection.LazyMintVoucher memory v = _makeVoucher(3, 0, block.timestamp + 1 days);
        bytes memory sig = _sign(collOwnerPk, _hashVoucher(v));
        vm.prank(buyer);
        coll.redeemVoucher{value: 0}(v, sig);
        assertEq(coll.ownerOf(3), buyer);
    }

    function test_redeem_replayRejected() public {
        ERC721Collection.LazyMintVoucher memory v = _makeVoucher(4, 1 ether, block.timestamp + 1 days);
        bytes memory sig = _sign(collOwnerPk, _hashVoucher(v));

        vm.prank(buyer);
        coll.redeemVoucher{value: 1 ether}(v, sig);

        vm.expectRevert(); // VoucherAlreadyRedeemed
        vm.prank(buyer);
        coll.redeemVoucher{value: 1 ether}(v, sig);
    }

    function test_redeem_expiredRejected() public {
        ERC721Collection.LazyMintVoucher memory v = _makeVoucher(5, 1 ether, block.timestamp + 1 days);
        bytes memory sig = _sign(collOwnerPk, _hashVoucher(v));
        vm.warp(block.timestamp + 2 days);
        vm.expectRevert();
        vm.prank(buyer);
        coll.redeemVoucher{value: 1 ether}(v, sig);
    }

    function test_redeem_wrongSignerRejected() public {
        // Sign with a different key whose owner is NOT approved.
        uint256 rougePk = 0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef;
        ERC721Collection.LazyMintVoucher memory v = _makeVoucher(6, 1 ether, block.timestamp + 1 days);
        v.signer = vm.addr(rougePk);
        bytes memory sig = _sign(rougePk, _hashVoucher(v));

        vm.expectRevert(); // VoucherSignerNotAuthorized
        vm.prank(buyer);
        coll.redeemVoucher{value: 1 ether}(v, sig);
    }

    function test_redeem_insufficientPaymentRejected() public {
        ERC721Collection.LazyMintVoucher memory v = _makeVoucher(7, 1 ether, block.timestamp + 1 days);
        bytes memory sig = _sign(collOwnerPk, _hashVoucher(v));
        vm.expectRevert();
        vm.prank(buyer);
        coll.redeemVoucher{value: 0.5 ether}(v, sig);
    }

    function test_redeem_erc20Voucher_rejectedInV1() public {
        ERC721Collection.LazyMintVoucher memory v = _makeVoucher(8, 1 ether, block.timestamp + 1 days);
        v.currency = makeAddr("usdc");
        bytes memory sig = _sign(collOwnerPk, _hashVoucher(v));
        vm.expectRevert(); // WrongCurrency
        vm.prank(buyer);
        coll.redeemVoucher{value: 0}(v, sig);
    }

    function test_redeem_approvedForAllSignerAccepted() public {
        // Authorize a second signer via setApprovalForAll.
        uint256 delegatePk = 0xabc123abc123abc123abc123abc123abc123abc123abc123abc123abc123abc1;
        address delegate = vm.addr(delegatePk);
        vm.prank(collOwner);
        coll.setApprovalForAll(delegate, true);

        ERC721Collection.LazyMintVoucher memory v = _makeVoucher(9, 0, block.timestamp + 1 days);
        v.signer = delegate;
        bytes memory sig = _sign(delegatePk, _hashVoucher(v));

        vm.prank(buyer);
        coll.redeemVoucher{value: 0}(v, sig);
        assertEq(coll.ownerOf(9), buyer);
    }
}
