// SPDX-License-Identifier: AGPL-3.0

pragma solidity >=0.8.0;

interface IVault {
    function deposit(uint256 amount) external;

    //function withdraw() external;
    function withdraw(uint256 maxShares) external;

    function withdrawAll() external;

    function pricePerShare() external view returns (uint256);

    function balanceOf(address _address) external view returns (uint256);

    function token() external view returns (address);

    function decimals() external view returns (uint256);
}
