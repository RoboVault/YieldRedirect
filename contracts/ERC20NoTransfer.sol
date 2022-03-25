// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20NoTransfer is ERC20 {
    constructor(string memory name_, string memory symbol_)
        ERC20(name_, symbol_)
    {}

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        revert("Transfer Not Supported");
    }
}
