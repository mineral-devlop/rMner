// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "./IERC20.sol";

interface IR2MNER is IERC20 {
    function mintTo(address to, uint256 _amount) external;

    function burn(uint256 _amount) external;

    function decimals() external returns (uint8);

    function rebase(int256 _amount) external returns (uint256);
}