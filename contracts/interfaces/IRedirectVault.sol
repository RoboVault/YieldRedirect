// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.11;

interface IRedirectVault {
    function isAuthorized(address _addr) external view returns (bool);

    function governance() external view returns (address);

    function totalSupply() external view returns (uint256);

    function balanceOf(address _account) external view returns (uint256);

    function targetToken() external view returns (address);

    function targetVault() external view returns (address);
}
