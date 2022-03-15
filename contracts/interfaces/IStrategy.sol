// SPDX-License-Identifier: agpl-3.0
import { MultiRewards } from "../types/MultiRewards.sol";

pragma solidity 0.8.11;

interface IStrategy {
    // deposits all funds into the farm
    function deposit() external;

    // vault only - withdraws funds from the strategy
    function withdraw(uint256 _amount) external;

    // returns the balance of all tokens managed by the strategy
    function balanceOf() external view returns (uint256);

    // Claims farmed tokens and sends them to the vault. Only callable from 
    // the vault
    function claim() external returns (MultiRewards[] calldata _rewards);

    // withdraws all tokens and sends them back to the vault
    function retireStrat() external;

    // pauses deposits, resets allowances, and withdraws all funds from farm
    function panic() external;

    // pauses deposits and resets allowances
    function pause() external;

    // unpauses deposits and maxes out allowances again
    function unpause() external;

    // updates Total Fee
    function updateTotalFee(uint256 _totalFee) external;
}