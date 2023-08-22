//SPDX-License-Identifier: MIT
pragma solidity^0.8.0;

import "./ERC20.sol";


contract ScamCoin is ERC20("$camCoin", "$CAM") {
    uint public startingAmount = 100;
    address public deployer;

    // packages => [0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2, 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db, 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB]
    // packages => [0x79097106642B1f1c02f1675873a3B9dA6fB859DB] metamask check

    constructor (address[] memory packages) {
        for(uint i=0; i<packages.length; i++) {
            deployer = msg.sender;
            initMint(packages[i], startingAmount);
        }
    }

    function initMint(address _package, uint _initialSupply) public  {
        require(deployer == msg.sender, "You are not the deployer");
        _mint(_package, _initialSupply * 10**18);
    }
}