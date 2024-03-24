pragma solidity ^0.8.0;

error NOT_ENOUGH_TOKEN_TO_TRANSFER();

library LibAppStorage {
    event Transfer(address indexed _from, address indexed _to, uint256 _amount);

    struct AuctionDetail {
        uint8 auctionId;
        uint256 duration;
        uint256 startingBid;
        uint256 currentBid;
        uint256 nftTokenId;
        bool hasEnded;
        address auctionCreator;
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

    function layoutStorage() internal pure returns (Layout storage l) {
        assembly {
            l.slot := 0
        }
    }

    function _transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        Layout storage l = layoutStorage();
        uint256 balance = l.balances[msg.sender];

        if (balance < _amount) {
            revert NOT_ENOUGH_TOKEN_TO_TRANSFER();
        }
        l.balances[_from] = balance - _amount;
        l.balances[_to] += _amount;
        emit Transfer(_from, _to, _amount);
    }
}
