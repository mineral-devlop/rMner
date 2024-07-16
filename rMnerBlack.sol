// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;


import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";


contract rMnerBlack is Initializable, OwnableUpgradeable  {
    mapping(address => bool) rMnerBlacks;
    mapping(address => bool) r2MnerBlacks;

    mapping(address => bool) r2MnerRebaseBlacks;

    constructor() initializer() {
         __Ownable_init();
    }

    function isRMnerBlack(address user) public view returns (bool) {
        return rMnerBlacks[user];
    }

    function isR2MnerBlack(address user) public view returns (bool) {
        return r2MnerBlacks[user];
    }

    function isR2MnerRebaseBlack(address user) public view returns (bool) {
        return r2MnerRebaseBlacks[user];
    }

    function setRMnerBlack(address user, bool isBlack) public onlyOwner {
        rMnerBlacks[user] = isBlack;
        emit UpdateRMnerBlack(user, isBlack);
    }

    function setR2MnerBlack(address user, bool isBlack) public onlyOwner {
        r2MnerBlacks[user] = isBlack;
        emit UpdateR2MnerBlack(user, isBlack);
    }

    function setR2MnerRebaseBlack(address user, bool isBlack) public onlyOwner {
        r2MnerRebaseBlacks[user] = isBlack;
        emit UpdateR2MnerRebaseBlack(user, isBlack);
    }

    event UpdateRMnerBlack(address user, bool isBlack);
    event UpdateR2MnerBlack(address user, bool isBlack);
    event UpdateR2MnerRebaseBlack(address user, bool isBlack);
}
