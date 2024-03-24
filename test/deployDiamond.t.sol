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

        boundAuction = AuctionFacet(address(diamond));
    }

    function testAucTokenFacet() public {
        uint256 userA_Bal = AUCTokenFacet(address(diamond)).balanceOf(A);
        uint256 userB_Bal = AUCTokenFacet(address(diamond)).balanceOf(B);

        uint256 totalSupply = userA_Bal + userB_Bal;

        assertEq(userA_Bal, 100_000_000e18);
        assertEq(userB_Bal, 100_000_000e18);
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

    function testAuctionCreation() public {
        switchSigner(A);
        MyNft(address(nft)).safeMint(A);
        address owner = MyNft(address(nft)).ownerOf(0);
        assertEq(owner, A);

        uint256 durationInSeconds = 604800;
        uint256 auctionAmount = 100e18;
        uint256 tokenId = 0;

        boundAuction.createAuction(durationInSeconds, auctionAmount, tokenId);

        uint8 index = 1;
        bool isAuctionCreated = boundAuction.doesAuctionExist(index);

        assertTrue(isAuctionCreated);
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
