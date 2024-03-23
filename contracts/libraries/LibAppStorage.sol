pragma solidity ^0.8.0;

library LibAppStorage {
    struct Layout {
        //ERC20
        string name;
        string symbol;
        uint256 totalSupply;
        uint8 decimals;
        mapping(address => uint256) balances;
        mapping(address => mapping(address => uint256)) allowances;
        //AUCTION
    }

    // function layoutStorage() internal pure returns (Layout storage l) {
    //     assembly {
    //         l.slot := 0
    //     }
    // }
}
