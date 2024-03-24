pragma solidity ^0.8.0;

library LibAppStorage {
    struct AuctionDetail {
        uint8 auctionId;
        uint256 duration;
        uint256 startingBid;
        uint256 currentBid;
        uint256 nftTokenId;
        bool hasEnded;
        address highestBidder;
        address previousBidder;
    }

    struct Layout {
        //ERC20
        string name;
        string symbol;
        uint256 totalSupply;
        uint8 decimals;
        mapping(address => uint256) balances;
        mapping(address => mapping(address => uint256)) allowances;
        //AUCTION
        uint8 auctionIndex;
        address nftContractAddress;
        mapping(uint8 => AuctionDetail) auctions;
    }
}
