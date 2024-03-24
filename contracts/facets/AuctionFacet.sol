// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibAppConstant} from "../libraries/LibAppConstant.sol";

error WRONG_DURATION_ENTERED();
error WRONG_PRICE_ENTERED();
error NOT_OWNER_OF_TOKEN_ENTERED();
error AUCTION_TIME_HAS_ELASPED();
error AUCTION_BY_INDEX_DOES_NOT_EXIST();
error YOUR_BID_IS_LESS_THAN_THE_STARTING_BID();
error TOKEN_BALANCE_IS_NOT_ENOUGH();
error YOUR_BID_IS_NOT_ENOUGH();
error AUCTION_HAS_NOT_ENDED();
error YOU_ARE_NOT_THE_HIGHEST_BIDDER();

contract AuctionFacet {
    LibAppStorage.Layout internal l;

    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed itemLister,
        uint256 tokenId,
        uint256 auctionPrice
    );

    event PreviousBidderPaid(
        address indexed previousBidder,
        uint256 indexed amount
    );

    event PercentageBurn(address from, address to, uint256 amount);
    event DAOPercentage(address from, address to, uint256 amount);
    event TeamWalletPercentage(address from, address to, uint256 amount);
    event LastInteractorPercentage(address from, address to, uint256 amount);
    event HighestBidderUpdated(
        address indexed newHighestBidder,
        uint256 amount,
        uint256 time
    );
    event AuctionEnded(uint256 auctionId);
    event AuctionItemCollected(
        uint256 auctionId,
        address collector,
        uint256 tokenId
    );
    event AuctionItemRetrievedBack(
        uint256 auctionId,
        address creator,
        uint256 tokenId
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

        uint8 _newId = l.auctionIndex + 1;
        LibAppStorage.AuctionDetail storage a = l.auctions[_newId];

        a.auctionId = _newId;
        a.duration = _duration;
        a.startingBid = _startingBid;
        a.nftTokenId = _tokenId;
        a.auctionCreator = msg.sender;

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
        if (l.auctions[_auctionId].auctionCreator == address(0)) {
            revert AUCTION_BY_INDEX_DOES_NOT_EXIST();
        }

        LibAppStorage.AuctionDetail storage a = l.auctions[_auctionId];

        //checking if the duration has elasped
        if (block.timestamp > a.duration) {
            a.hasEnded = true;
            emit AuctionEnded(a.auctionId);
            revert AUCTION_TIME_HAS_ELASPED();
        }

        if (_amount < a.startingBid) {
            revert YOUR_BID_IS_LESS_THAN_THE_STARTING_BID();
        }

        uint256 balance = l.balances[msg.sender];

        if (balance < _amount) {
            revert TOKEN_BALANCE_IS_NOT_ENOUGH();
        }

        //transfering the token from the msg.sender to the address(this)
        LibAppStorage._transferFrom(msg.sender, address(this), _amount);

        if (a.currentBid == 0) {
            a.highestBidder = msg.sender;
            a.currentBid = _amount;

            emit HighestBidderUpdated(
                a.highestBidder,
                a.currentBid,
                block.timestamp
            );
        } else {
            uint check = (a.currentBid * 20) / 100;
            uint estimate = a.currentBid + check;
            if (_amount < estimate) {
                revert YOUR_BID_IS_NOT_ENOUGH();
            }

            a.previousBidder = a.highestBidder;

            // calculations
            //paying back previous bidder
            payPreviousBidder(_amount, _auctionId);
            //percentage distribution
            noLossDistribution(_amount);

            a.currentBid = _amount;
            a.highestBidder = msg.sender;

            emit HighestBidderUpdated(
                a.highestBidder,
                a.currentBid,
                block.timestamp
            );
        }
    }

    //method to pay back previous bidder
    function payPreviousBidder(uint256 _amount, uint8 _auctionId) private {
        LibAppStorage.AuctionDetail storage a = l.auctions[_auctionId];

        uint256 nextBidderPercent = (_amount * LibAppConstant.PREVIOUS_BIDDER) /
            100;

        uint256 accruedAmount = nextBidderPercent + a.currentBid;

        //send back previous bidder's amount
        LibAppStorage._transferFrom(
            address(this),
            a.previousBidder,
            a.currentBid
        );

        emit PreviousBidderPaid(a.previousBidder, accruedAmount);
    }

    //method to calculate percentage distribution
    function noLossDistribution(uint256 _amount) private {
        // Handle Burn
        uint256 burnableAmount = (_amount * LibAppConstant.BURNABLE) / 100;
        LibAppStorage._transferFrom(address(this), address(0), burnableAmount);
        emit PercentageBurn(address(this), address(0), burnableAmount);

        //handle DAO
        uint256 daoAmount = (_amount * LibAppConstant.DAO) / 100;
        LibAppStorage._transferFrom(
            address(this),
            LibAppConstant.DAO_WALLET,
            daoAmount
        );
        emit DAOPercentage(address(this), LibAppConstant.DAO_WALLET, daoAmount);

        // Handle team fees
        uint256 teamAmount = (_amount * LibAppConstant.TEAM_WALLET) / 100;
        LibAppStorage._transferFrom(
            address(this),
            LibAppConstant.TEAM_WALLET_ADDRESS,
            teamAmount
        );
        emit TeamWalletPercentage(
            address(this),
            LibAppConstant.TEAM_WALLET_ADDRESS,
            teamAmount
        );

        //Last interactor
        uint256 lastInteractorAmount = (_amount *
            LibAppConstant.LAST_INTERACTOR) / 100;

        LibAppStorage._transferFrom(
            address(this),
            msg.sender,
            lastInteractorAmount
        );
        emit LastInteractorPercentage(
            address(this),
            msg.sender,
            lastInteractorAmount
        );
    }

    //collecting the auctioned item when the highest bidder
    function collectAuctionItem(uint8 _auctionId) external {
        //checking auction by index exist
        if (l.auctions[_auctionId].auctionCreator == address(0)) {
            revert AUCTION_BY_INDEX_DOES_NOT_EXIST();
        }
        if (!l.auctions[_auctionId].hasEnded) {
            revert AUCTION_HAS_NOT_ENDED();
        }
        if (l.auctions[_auctionId].highestBidder != msg.sender) {
            revert YOU_ARE_NOT_THE_HIGHEST_BIDDER();
        }

        //transfering the token from the address(this) to highest bidder
        IERC721(l.nftContractAddress).safeTransferFrom(
            address(this),
            l.auctions[_auctionId].highestBidder,
            l.auctions[_auctionId].nftTokenId
        );

        l.auctions[_auctionId].hasEnded = true;

        emit AuctionItemCollected(
            _auctionId,
            msg.sender,
            l.auctions[_auctionId].nftTokenId
        );
    }

    //collecting the auctioned item if no bidder
    function collectAuctionedItemIfNoBidder(uint8 _auctionId) external {
        //checking auction by index exist
        if (l.auctions[_auctionId].auctionCreator == address(0)) {
            revert AUCTION_BY_INDEX_DOES_NOT_EXIST();
        }
        if (block.timestamp > l.auctions[_auctionId].duration) {
            if (l.auctions[_auctionId].currentBid == 0) {
                //transfering the token from the address(this) to highest bidder
                IERC721(l.nftContractAddress).safeTransferFrom(
                    address(this),
                    l.auctions[_auctionId].auctionCreator,
                    l.auctions[_auctionId].nftTokenId
                );

                l.auctions[_auctionId].hasEnded = true;

                emit AuctionItemRetrievedBack(
                    l.auctions[_auctionId].auctionId,
                    l.auctions[_auctionId].auctionCreator,
                    l.auctions[_auctionId].nftTokenId
                );
            }
        } else {
            revert AUCTION_HAS_NOT_ENDED();
        }
    }
}
