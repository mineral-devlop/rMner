// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

interface IRMNERBlack {
    function isRMnerBlack(address user) external view returns (bool);

    function isR2MnerBlack(address user) external view returns (bool);

    function isR2MnerRebaseBlack(address user) external view returns (bool);
}
