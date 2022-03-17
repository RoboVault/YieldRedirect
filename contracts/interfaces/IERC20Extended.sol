// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC20Extended is IERC20 {
    function decimals() external view returns (uint8);
}
