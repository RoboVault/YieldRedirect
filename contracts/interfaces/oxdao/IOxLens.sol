// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
pragma solidity ^0.8.11;

interface IOxLens {
    function oxPoolBySolidPool(address solidPoolAddress)
        external
        view
        returns (address);
}