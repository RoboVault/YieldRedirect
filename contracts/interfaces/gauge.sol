// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

interface IGauge {
    function deposit(uint256 _amount) external;

    function depositAll() external;

    function getReward() external;

    function withdraw(uint256 _amount) external;

    function withdrawAll() external;
}
