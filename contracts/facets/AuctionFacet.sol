// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {LibAppStorage} from "../libraries/LibAppStorage.sol";

error WRONG_DURATION_ENTERED();
error WRONG_PRICE_ENTERED();
error NOT_OWNER_OF_TOKEN_ENTERED();
error AUCTION_TIME_HAS_ELASPED();
error AUCTION_BY_INDEX_DOES_NOT_EXIST();
error YOUR_BID_IS_LESS_THAN_THE_STARTING_BID();
error TOKEN_BALANCE_IS_NOT_ENOUGH();

contract AuctionFacet {
    LibAppStorage.Layout internal l;

    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed itemLister,
        uint256 tokenId,
        uint256 auctionPrice
    );

    function createAuction(
        uint256 _duration,
        uint256 _startingBid,
        uint256 _tokenId
    ) external {
        //checking if the block timestamp is greater than the duration
        if (block.timestamp > _duration) {
            revert WRONG_DURATION_ENTERED();
        }

        //making sure that the starting bid is greater than 0
        if (_startingBid < 1) {
            revert WRONG_PRICE_ENTERED();
        }

        //making sure that the owner of the token is the msg.sender
        if (IERC721(l.nftContractAddress).ownerOf(_tokenId) != msg.sender) {
            revert NOT_OWNER_OF_TOKEN_ENTERED();
        }

        uint _newId = l.auctionIndex + 1;
        LibAppStorage.AuctionDetail storage a = l.auctions[_newId];

        a.auctionId = _newId;
        a.duration = _duration;
        a.startingBid = _startingBid;
        a.nftTokenId = _tokenId;

        l.auctionIndex = l.auctionIndex + 1;

        //transfering the token from the msg.sender to the address(this)
        IERC721(l.nftContractAddress).safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId
        );

        emit AuctionCreated(_newId, msg.sender, _tokenId, _startingBid);
    }

    function bidOnAuctionedItem(uint256 _amount, uint8 _auctionId) external {
        //checking auction by index exist
        if (!l.auctions[_auctionId]) {
            revert AUCTION_BY_INDEX_DOES_NOT_EXIST();
        }

        LibAppStorage.AuctionDetail storage a = l.auctions[_auctionId];

        //checking if the duration has elasped
        if (block.timestamp > a.duration) {
            revert AUCTION_TIME_HAS_ELASPED();
        }

        if (_amount < a.startingBid) {
            revert YOUR_BID_IS_LESS_THAN_THE_STARTING_BID();
        }

        uint256 balance = l.balances[msg.sender];

        if (balance < _amount) {
            revert TOKEN_BALANCE_IS_NOT_ENOUGH();
        }
    }
}
