pragma solidity ^0.8.0;

library LibAppConstant {
    //PERCENTAGE
    uint8 public constant TOTAL_FEE = 10;
    uint8 public constant BURNABLE = 2;
    uint8 public constant DAO = 2;
    uint8 public constant TEAM_WALLET = 2;
    uint8 public constant PREVIOUS_BIDDER = 3;
    uint8 public constant LAST_INTERACTOR = 1;

    //address
    address public constant DAO_WALLET =
        0xd9dBe0daa503Caa6e061f1902a7AF22af096E645;
    address public constant TEAM_WALLET_ADDRESS =
        0xbe03CE9d6001D27BE41fc87e3E3f777d04e70Fe2;
}
