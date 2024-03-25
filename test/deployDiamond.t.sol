// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";

import "../contracts/facets/AUCTokenFacet.sol";
import "../contracts/facets/AuctionFacet.sol";
import "../contracts/MyNft.sol";

import "forge-std/Test.sol";
import "../contracts/Diamond.sol";

import "../contracts/libraries/LibAppStorage.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

contract DiamondDeployer is Test, IDiamondCut {
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    AUCTokenFacet aucTokenFacet;
    AuctionFacet auctionFacet;
    MyNft nft;

    address A = address(0xa);
    address B = address(0xb);
    address C = address(0xc);
    address D = address(0xd);
    address E = address(0xe);
    address F = address(0xf);

    AuctionFacet boundAuction;

    function setUp() public {
        //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        aucTokenFacet = new AUCTokenFacet();
        auctionFacet = new AuctionFacet();
        nft = new MyNft();

        //upgrade diamond with facets

        //build cut struct
        FacetCut[] memory cut = new FacetCut[](4);

        cut[0] = (
            FacetCut({
                facetAddress: address(dLoupe),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("DiamondLoupeFacet")
            })
        );

        cut[1] = (
            FacetCut({
                facetAddress: address(ownerF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("OwnershipFacet")
            })
        );
        cut[2] = (
            FacetCut({
                facetAddress: address(aucTokenFacet),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("AUCTokenFacet")
            })
        );
        cut[3] = (
            FacetCut({
                facetAddress: address(auctionFacet),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("AuctionFacet")
            })
        );

        //upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        //set NFT
        diamond.setNFTToken(address(nft));

        //set users
        A = mkaddr("user a");
        B = mkaddr("user b");
        C = mkaddr("user c");
        D = mkaddr("user d");
        E = mkaddr("user e");
        F = mkaddr("user f");

        //mint test tokens
        AUCTokenFacet(address(diamond)).mintTo(A);
        AUCTokenFacet(address(diamond)).mintTo(B);
        AUCTokenFacet(address(diamond)).mintTo(C);
        AUCTokenFacet(address(diamond)).mintTo(D);

        boundAuction = AuctionFacet(address(diamond));
    }

    function testAucTokenFacet() public {
        uint256 userA_Bal = AUCTokenFacet(address(diamond)).balanceOf(A);
        uint256 userB_Bal = AUCTokenFacet(address(diamond)).balanceOf(B);
        uint256 userC_Bal = AUCTokenFacet(address(diamond)).balanceOf(C);
        uint256 userD_Bal = AUCTokenFacet(address(diamond)).balanceOf(D);

        uint256 totalSupply = userA_Bal + userB_Bal + userC_Bal + userD_Bal;

        assertEq(userA_Bal, 100_000_000e18);
        assertEq(userB_Bal, 100_000_000e18);
        assertEq(userC_Bal, 100_000_000e18);
        assertEq(userD_Bal, 100_000_000e18);
        assertEq(AUCTokenFacet(address(diamond)).totalSupply(), totalSupply);

        switchSigner(A);
        AUCTokenFacet(address(diamond)).transfer(E, 100_000e18);
        uint256 userE_Bal = AUCTokenFacet(address(diamond)).balanceOf(E);
        uint256 userA_BalAfterTx = AUCTokenFacet(address(diamond)).balanceOf(A);
        assertEq(userE_Bal, 100_000e18);
        assertEq(userA_Bal, (userA_BalAfterTx + userE_Bal));
    }

    function testNFT() public {
        switchSigner(C);
        MyNft(address(nft)).safeMint(C);
        address owner = MyNft(address(nft)).ownerOf(0);
        assertEq(owner, C);
    }

    function testAuctionCreationFailure1() public {
        switchSigner(A);
        MyNft(address(nft)).safeMint(A);
        address owner = MyNft(address(nft)).ownerOf(0);
        assertEq(owner, A);

        uint256 durationInSeconds = 60;
        uint256 auctionAmount = 100e18;
        uint256 tokenId = 0;

        IERC721(address(nft)).approve(address(diamond), tokenId);

        //wrong duration failure

        vm.expectRevert(
            abi.encodeWithSelector(AuctionFacet.WRONG_DURATION_ENTERED.selector)
        );

        boundAuction.createAuction(durationInSeconds, auctionAmount, tokenId);
    }

    function testAuctionCreationFailure2() public {
        switchSigner(A);
        MyNft(address(nft)).safeMint(A);
        address owner = MyNft(address(nft)).ownerOf(0);
        assertEq(owner, A);

        uint256 durationInSeconds = 604800;
        uint256 auctionAmount = 0;
        uint256 tokenId = 0;

        IERC721(address(nft)).approve(address(diamond), tokenId);

        //wrong initial starting bid amount failure
        vm.expectRevert(
            abi.encodeWithSelector(AuctionFacet.WRONG_PRICE_ENTERED.selector)
        );

        boundAuction.createAuction(durationInSeconds, auctionAmount, tokenId);
    }

    function testAuctionCreationFailure3() public {
        switchSigner(A);
        MyNft(address(nft)).safeMint(A);
        address owner = MyNft(address(nft)).ownerOf(0);
        assertEq(owner, A);

        uint256 durationInSeconds = 604800;
        uint256 auctionAmount = 100e18;
        uint256 tokenId = 0;

        IERC721(address(nft)).approve(address(diamond), tokenId);

        switchSigner(B);

        //owner of token check
        vm.expectRevert(
            abi.encodeWithSelector(
                AuctionFacet.NOT_OWNER_OF_TOKEN_ENTERED.selector
            )
        );

        boundAuction.createAuction(durationInSeconds, auctionAmount, tokenId);
    }

    function testAuctionCreation() public {
        switchSigner(A);
        MyNft(address(nft)).safeMint(A);
        address owner = MyNft(address(nft)).ownerOf(0);
        assertEq(owner, A);

        uint256 durationInSeconds = 604800;
        uint256 auctionAmount = 100e18;
        uint256 tokenId = 0;

        IERC721(address(nft)).approve(address(diamond), tokenId);

        boundAuction.createAuction(durationInSeconds, auctionAmount, tokenId);

        uint8 index = 1;
        bool isAuctionCreated = boundAuction.doesAuctionExist(index);

        assertTrue(isAuctionCreated);
        assertEq(isAuctionCreated, true);
    }

    function testBidFailures1() public {
        switchSigner(A);
        MyNft(address(nft)).safeMint(A);
        address owner = MyNft(address(nft)).ownerOf(0);
        assertEq(owner, A);

        uint256 durationInSeconds = 604800;
        uint256 auctionAmount = 100e18;
        uint256 tokenId = 0;

        IERC721(address(nft)).approve(address(diamond), tokenId);

        //auction creation
        boundAuction.createAuction(durationInSeconds, auctionAmount, tokenId);

        uint8 index = 1;
        bool isAuctionCreated = boundAuction.doesAuctionExist(index);

        assertTrue(isAuctionCreated);
        assertEq(isAuctionCreated, true);

        //bidding
        //bid check on non existent auction
        vm.expectRevert(
            abi.encodeWithSelector(
                AuctionFacet.AUCTION_BY_INDEX_DOES_NOT_EXIST.selector
            )
        );

        boundAuction.bidOnAuctionedItem(1000e18, 3);
    }

    function testBidFailures2() public {
        switchSigner(A);
        MyNft(address(nft)).safeMint(A);
        address owner = MyNft(address(nft)).ownerOf(0);
        assertEq(owner, A);

        uint256 durationInSeconds = 604800;
        uint256 auctionAmount = 100e18;
        uint256 tokenId = 0;

        IERC721(address(nft)).approve(address(diamond), tokenId);

        //auction creation
        boundAuction.createAuction(durationInSeconds, auctionAmount, tokenId);

        uint8 index = 1;
        bool isAuctionCreated = boundAuction.doesAuctionExist(index);

        assertTrue(isAuctionCreated);
        assertEq(isAuctionCreated, true);

        //bidding
        //checking if duration has elasped
        vm.expectRevert(
            abi.encodeWithSelector(
                AuctionFacet.AUCTION_TIME_HAVE_ELASPED.selector
            )
        );
        vm.warp(704800);

        boundAuction.bidOnAuctionedItem(1000e18, 1);
    }

    function testBidFailures3() public {
        switchSigner(A);
        MyNft(address(nft)).safeMint(A);
        address owner = MyNft(address(nft)).ownerOf(0);
        assertEq(owner, A);

        uint256 durationInSeconds = 604800;
        uint256 auctionAmount = 100e18;
        uint256 tokenId = 0;

        IERC721(address(nft)).approve(address(diamond), tokenId);

        //auction creation
        boundAuction.createAuction(durationInSeconds, auctionAmount, tokenId);

        uint8 index = 1;
        bool isAuctionCreated = boundAuction.doesAuctionExist(index);

        assertTrue(isAuctionCreated);
        assertEq(isAuctionCreated, true);

        //bidding
        //checking if user bid amount is less than starting bid
        vm.expectRevert(
            abi.encodeWithSelector(
                AuctionFacet.YOUR_BID_IS_LESS_THAN_THE_STARTING_BID.selector
            )
        );

        boundAuction.bidOnAuctionedItem(10e18, 1);
    }

    function testBidFailures4() public {
        switchSigner(B);
        MyNft(address(nft)).safeMint(B);
        address owner = MyNft(address(nft)).ownerOf(0);
        assertEq(owner, B);

        uint256 durationInSeconds = 604800;
        uint256 auctionAmount = 100e18;
        uint256 tokenId = 0;

        IERC721(address(nft)).approve(address(diamond), tokenId);

        //auction creation
        boundAuction.createAuction(durationInSeconds, auctionAmount, tokenId);

        uint8 index = 1;
        bool isAuctionCreated = boundAuction.doesAuctionExist(index);

        assertTrue(isAuctionCreated);
        assertEq(isAuctionCreated, true);

        //bidding
        //checking if user bidder token balance is enough
        vm.expectRevert(
            abi.encodeWithSelector(
                AuctionFacet.TOKEN_BALANCE_IS_NOT_ENOUGH.selector
            )
        );

        boundAuction.bidOnAuctionedItem(100_000_000_000e18, 1);
    }

    function testOneSuccessfulBid() public {
        switchSigner(B);
        MyNft(address(nft)).safeMint(B);
        address owner = MyNft(address(nft)).ownerOf(0);
        assertEq(owner, B);

        uint256 durationInSeconds = 604800;
        uint256 auctionAmount = 100e18;
        uint256 tokenId = 0;

        IERC721(address(nft)).approve(address(diamond), tokenId);

        //auction creation
        boundAuction.createAuction(durationInSeconds, auctionAmount, tokenId);

        uint8 index = 1;
        bool isAuctionCreated = boundAuction.doesAuctionExist(index);

        assertTrue(isAuctionCreated);
        assertEq(isAuctionCreated, true);

        uint256 userB_BalBefore = AUCTokenFacet(address(diamond)).balanceOf(B);
        //One successful Bidding
        uint256 lastestBid = boundAuction.bidOnAuctionedItem(1000e18, 1);

        uint256 userB_BalAfter = AUCTokenFacet(address(diamond)).balanceOf(B);

        assertEq(userB_BalBefore, userB_BalAfter + 1000e18);
        assertEq(lastestBid, 1000e18);
    }

    function testIfSecondBidAmountIsEnough() public {
        // switching to the first bidder
        switchSigner(A);
        MyNft(address(nft)).safeMint(A);
        address owner = MyNft(address(nft)).ownerOf(0);
        assertEq(owner, A);

        uint256 durationInSeconds = 604800;
        uint256 auctionAmount = 100e18;
        uint256 tokenId = 0;

        IERC721(address(nft)).approve(address(diamond), tokenId);

        //auction creation
        boundAuction.createAuction(durationInSeconds, auctionAmount, tokenId);

        uint8 index = 1;
        bool isAuctionCreated = boundAuction.doesAuctionExist(index);

        assertTrue(isAuctionCreated);
        assertEq(isAuctionCreated, true);

        uint256 userA_BalBefore = AUCTokenFacet(address(diamond)).balanceOf(A);
        //One successful Bidding
        uint256 lastestBid = boundAuction.bidOnAuctionedItem(1000e18, 1);

        uint256 userA_BalAfter = AUCTokenFacet(address(diamond)).balanceOf(A);

        assertEq(userA_BalBefore, userA_BalAfter + 1000e18);
        assertEq(lastestBid, 1000e18);

        // switching to the second bidder
        switchSigner(B);

        //checking if user bidder token balance is enough
        vm.expectRevert(
            abi.encodeWithSelector(AuctionFacet.YOUR_BID_IS_NOT_ENOUGH.selector)
        );
        //One successful Bidding
        boundAuction.bidOnAuctionedItem(1001e18, 1);
    }

    function testSuccessfulBidForTwoBidders() public {
        // switching to the first bidder
        switchSigner(A);
        MyNft(address(nft)).safeMint(A);
        address owner = MyNft(address(nft)).ownerOf(0);
        assertEq(owner, A);

        uint256 durationInSeconds = 604800;
        uint256 auctionAmount = 100e18;
        uint256 tokenId = 0;

        IERC721(address(nft)).approve(address(diamond), tokenId);

        //auction creation
        boundAuction.createAuction(durationInSeconds, auctionAmount, tokenId);

        uint8 index = 1;
        bool isAuctionCreated = boundAuction.doesAuctionExist(index);

        assertTrue(isAuctionCreated);
        assertEq(isAuctionCreated, true);

        uint256 userA_BalBefore = AUCTokenFacet(address(diamond)).balanceOf(A);
        //One successful Bidding
        uint256 lastestBid = boundAuction.bidOnAuctionedItem(1000e18, 1);

        uint256 userA_BalAfter = AUCTokenFacet(address(diamond)).balanceOf(A);

        assertEq(userA_BalBefore, userA_BalAfter + 1000e18);
        assertEq(lastestBid, 1000e18);

        // switching to the second bidder
        switchSigner(B);

        uint256 userB_BalBefore = AUCTokenFacet(address(diamond)).balanceOf(B);
        //One successful Bidding
        uint256 lastestBid2 = boundAuction.bidOnAuctionedItem(10000e18, 1);

        uint256 userB_BalAfter = AUCTokenFacet(address(diamond)).balanceOf(B);

        assertGt(userB_BalBefore, userB_BalAfter);
        assertEq(lastestBid2, 10000e18);
    }

    function testSuccessfulBidForFourBiddersAndWinner() public {
        // switching to the first bidder
        switchSigner(A);
        MyNft(address(nft)).safeMint(A);
        address owner = MyNft(address(nft)).ownerOf(0);
        assertEq(owner, A);

        uint256 durationInSeconds = 604800;
        uint256 auctionAmount = 100e18;
        uint256 tokenId = 0;

        IERC721(address(nft)).approve(address(diamond), tokenId);

        //auction creation
        boundAuction.createAuction(durationInSeconds, auctionAmount, tokenId);

        uint8 index = 1;
        bool isAuctionCreated = boundAuction.doesAuctionExist(index);

        assertTrue(isAuctionCreated);
        assertEq(isAuctionCreated, true);

        uint256 userA_BalBefore = AUCTokenFacet(address(diamond)).balanceOf(A);
        //One successful Bidding
        uint256 lastestBid = boundAuction.bidOnAuctionedItem(1000e18, 1);

        uint256 userA_BalAfter = AUCTokenFacet(address(diamond)).balanceOf(A);

        assertEq(userA_BalBefore, userA_BalAfter + 1000e18);
        assertEq(lastestBid, 1000e18);

        // switching to the second bidder
        switchSigner(B);

        uint256 userB_BalBefore = AUCTokenFacet(address(diamond)).balanceOf(B);
        //One successful Bidding
        uint256 lastestBid2 = boundAuction.bidOnAuctionedItem(10000e18, 1);

        uint256 userB_BalAfter = AUCTokenFacet(address(diamond)).balanceOf(B);

        assertGt(userB_BalBefore, userB_BalAfter);
        assertEq(lastestBid2, 10000e18);

        // switching to the third bidder
        switchSigner(C);

        uint256 userC_BalBefore = AUCTokenFacet(address(diamond)).balanceOf(C);
        //One successful Bidding
        uint256 lastestBid3 = boundAuction.bidOnAuctionedItem(100_000e18, 1);

        uint256 userC_BalAfter = AUCTokenFacet(address(diamond)).balanceOf(C);

        assertGt(userC_BalBefore, userC_BalAfter);
        assertEq(lastestBid3, 100_000e18);

        // switching to the fourth bidder
        switchSigner(D);

        uint256 userD_BalBefore = AUCTokenFacet(address(diamond)).balanceOf(D);
        //One successful Bidding
        uint256 lastestBid4 = boundAuction.bidOnAuctionedItem(1000_000e18, 1);

        uint256 userD_BalAfter = AUCTokenFacet(address(diamond)).balanceOf(D);

        assertGt(userD_BalBefore, userD_BalAfter);
        assertEq(lastestBid4, 1000_000e18);

        // time warp
        vm.warp(804800);

        boundAuction.collectAuctionItem(1);
    }

    function testCollectAuctionItemFailure1() public {
        // switching to the first bidder
        switchSigner(A);
        MyNft(address(nft)).safeMint(A);
        address owner = MyNft(address(nft)).ownerOf(0);
        assertEq(owner, A);

        uint256 durationInSeconds = 604800;
        uint256 auctionAmount = 100e18;
        uint256 tokenId = 0;

        IERC721(address(nft)).approve(address(diamond), tokenId);

        //auction creation
        boundAuction.createAuction(durationInSeconds, auctionAmount, tokenId);

        uint8 index = 1;
        bool isAuctionCreated = boundAuction.doesAuctionExist(index);

        assertTrue(isAuctionCreated);
        assertEq(isAuctionCreated, true);

        uint256 userA_BalBefore = AUCTokenFacet(address(diamond)).balanceOf(A);
        //One successful Bidding
        uint256 lastestBid = boundAuction.bidOnAuctionedItem(1000e18, 1);

        uint256 userA_BalAfter = AUCTokenFacet(address(diamond)).balanceOf(A);

        assertEq(userA_BalBefore, userA_BalAfter + 1000e18);
        assertEq(lastestBid, 1000e18);

        // switching to the second bidder
        switchSigner(B);

        uint256 userB_BalBefore = AUCTokenFacet(address(diamond)).balanceOf(B);
        //One successful Bidding
        uint256 lastestBid2 = boundAuction.bidOnAuctionedItem(10000e18, 1);

        uint256 userB_BalAfter = AUCTokenFacet(address(diamond)).balanceOf(B);

        assertGt(userB_BalBefore, userB_BalAfter);
        assertEq(lastestBid2, 10000e18);

        // switching to the third bidder
        switchSigner(C);

        uint256 userC_BalBefore = AUCTokenFacet(address(diamond)).balanceOf(C);
        //One successful Bidding
        uint256 lastestBid3 = boundAuction.bidOnAuctionedItem(100_000e18, 1);

        uint256 userC_BalAfter = AUCTokenFacet(address(diamond)).balanceOf(C);

        assertGt(userC_BalBefore, userC_BalAfter);
        assertEq(lastestBid3, 100_000e18);

        // switching to the fourth bidder
        switchSigner(D);

        uint256 userD_BalBefore = AUCTokenFacet(address(diamond)).balanceOf(D);
        //One successful Bidding
        uint256 lastestBid4 = boundAuction.bidOnAuctionedItem(1000_000e18, 1);

        uint256 userD_BalAfter = AUCTokenFacet(address(diamond)).balanceOf(D);

        assertGt(userD_BalBefore, userD_BalAfter);
        assertEq(lastestBid4, 1000_000e18);

        // time warp
        vm.warp(804800);

        //should revert on entering the wrong index
        vm.expectRevert(
            abi.encodeWithSelector(
                AuctionFacet.AUCTION_BY_INDEX_DOES_NOT_EXIST.selector
            )
        );

        boundAuction.collectAuctionItem(2);
    }

    function testCollectAuctionItemFailure2() public {
        // switching to the first bidder
        switchSigner(A);
        MyNft(address(nft)).safeMint(A);
        address owner = MyNft(address(nft)).ownerOf(0);
        assertEq(owner, A);

        uint256 durationInSeconds = 604800;
        uint256 auctionAmount = 100e18;
        uint256 tokenId = 0;

        IERC721(address(nft)).approve(address(diamond), tokenId);

        //auction creation
        boundAuction.createAuction(durationInSeconds, auctionAmount, tokenId);

        uint8 index = 1;
        bool isAuctionCreated = boundAuction.doesAuctionExist(index);

        assertTrue(isAuctionCreated);
        assertEq(isAuctionCreated, true);

        uint256 userA_BalBefore = AUCTokenFacet(address(diamond)).balanceOf(A);
        //One successful Bidding
        uint256 lastestBid = boundAuction.bidOnAuctionedItem(1000e18, 1);

        uint256 userA_BalAfter = AUCTokenFacet(address(diamond)).balanceOf(A);

        assertEq(userA_BalBefore, userA_BalAfter + 1000e18);
        assertEq(lastestBid, 1000e18);

        // switching to the second bidder
        switchSigner(B);

        uint256 userB_BalBefore = AUCTokenFacet(address(diamond)).balanceOf(B);
        //One successful Bidding
        uint256 lastestBid2 = boundAuction.bidOnAuctionedItem(10000e18, 1);

        uint256 userB_BalAfter = AUCTokenFacet(address(diamond)).balanceOf(B);

        assertGt(userB_BalBefore, userB_BalAfter);
        assertEq(lastestBid2, 10000e18);

        // switching to the third bidder
        switchSigner(C);

        uint256 userC_BalBefore = AUCTokenFacet(address(diamond)).balanceOf(C);
        //One successful Bidding
        uint256 lastestBid3 = boundAuction.bidOnAuctionedItem(100_000e18, 1);

        uint256 userC_BalAfter = AUCTokenFacet(address(diamond)).balanceOf(C);

        assertGt(userC_BalBefore, userC_BalAfter);
        assertEq(lastestBid3, 100_000e18);

        // switching to the fourth bidder
        switchSigner(D);

        uint256 userD_BalBefore = AUCTokenFacet(address(diamond)).balanceOf(D);
        //One successful Bidding
        uint256 lastestBid4 = boundAuction.bidOnAuctionedItem(1000_000e18, 1);

        uint256 userD_BalAfter = AUCTokenFacet(address(diamond)).balanceOf(D);

        assertGt(userD_BalBefore, userD_BalAfter);
        assertEq(lastestBid4, 1000_000e18);

        // time warp
        vm.warp(804800);

        switchSigner(E);
        //should revert when the collector is not the highest bidder
        vm.expectRevert(
            abi.encodeWithSelector(
                AuctionFacet.YOU_ARE_NOT_THE_HIGHEST_BIDDER.selector
            )
        );

        boundAuction.collectAuctionItem(1);
    }

    function testCollectAuctionItemFailure3() public {
        // switching to the first bidder
        switchSigner(A);
        MyNft(address(nft)).safeMint(A);
        address owner = MyNft(address(nft)).ownerOf(0);
        assertEq(owner, A);

        uint256 durationInSeconds = 604800;
        uint256 auctionAmount = 100e18;
        uint256 tokenId = 0;

        IERC721(address(nft)).approve(address(diamond), tokenId);

        //auction creation
        boundAuction.createAuction(durationInSeconds, auctionAmount, tokenId);

        uint8 index = 1;
        bool isAuctionCreated = boundAuction.doesAuctionExist(index);

        assertTrue(isAuctionCreated);
        assertEq(isAuctionCreated, true);

        uint256 userA_BalBefore = AUCTokenFacet(address(diamond)).balanceOf(A);
        //One successful Bidding
        uint256 lastestBid = boundAuction.bidOnAuctionedItem(1000e18, 1);

        uint256 userA_BalAfter = AUCTokenFacet(address(diamond)).balanceOf(A);

        assertEq(userA_BalBefore, userA_BalAfter + 1000e18);
        assertEq(lastestBid, 1000e18);

        // switching to the second bidder
        switchSigner(B);

        uint256 userB_BalBefore = AUCTokenFacet(address(diamond)).balanceOf(B);
        //One successful Bidding
        uint256 lastestBid2 = boundAuction.bidOnAuctionedItem(10000e18, 1);

        uint256 userB_BalAfter = AUCTokenFacet(address(diamond)).balanceOf(B);

        assertGt(userB_BalBefore, userB_BalAfter);
        assertEq(lastestBid2, 10000e18);

        // switching to the third bidder
        switchSigner(C);

        uint256 userC_BalBefore = AUCTokenFacet(address(diamond)).balanceOf(C);
        //One successful Bidding
        uint256 lastestBid3 = boundAuction.bidOnAuctionedItem(100_000e18, 1);

        uint256 userC_BalAfter = AUCTokenFacet(address(diamond)).balanceOf(C);

        assertGt(userC_BalBefore, userC_BalAfter);
        assertEq(lastestBid3, 100_000e18);

        // switching to the fourth bidder
        switchSigner(D);

        uint256 userD_BalBefore = AUCTokenFacet(address(diamond)).balanceOf(D);
        //One successful Bidding
        uint256 lastestBid4 = boundAuction.bidOnAuctionedItem(1000_000e18, 1);

        uint256 userD_BalAfter = AUCTokenFacet(address(diamond)).balanceOf(D);

        assertGt(userD_BalBefore, userD_BalAfter);
        assertEq(lastestBid4, 1000_000e18);

        //should revert if the auction has not ended
        vm.expectRevert(
            abi.encodeWithSelector(
                AuctionFacet.AUCTION_TIME_HAVE_NOT_ELASPED.selector
            )
        );

        boundAuction.collectAuctionItem(1);
    }

    function generateSelectors(
        string memory _facetName
    ) internal returns (bytes4[] memory selectors) {
        string[] memory cmd = new string[](3);
        cmd[0] = "node";
        cmd[1] = "scripts/genSelectors.js";
        cmd[2] = _facetName;
        bytes memory res = vm.ffi(cmd);
        selectors = abi.decode(res, (bytes4[]));
    }

    function mkaddr(string memory name) public returns (address) {
        address addr = address(
            uint160(uint256(keccak256(abi.encodePacked(name))))
        );
        vm.label(addr, name);
        return addr;
    }

    function switchSigner(address _newSigner) public {
        address foundrySigner = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
        if (msg.sender == foundrySigner) {
            vm.startPrank(_newSigner);
        } else {
            vm.stopPrank();
            vm.startPrank(_newSigner);
        }
    }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}
