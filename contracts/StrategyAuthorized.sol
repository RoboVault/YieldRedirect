// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/Context.sol";

abstract contract StrategyAuthorized is Context {
    address private _strategist;

    event UpdateGovernance(address indexed governance);
    event UpdateManagement(address indexed management);

    constructor() {
        _strategist = _msgSender();
    }

    modifier onlyGovernance() {
        require(
            governance() == _msgSender(),
            "Authorized: caller is not the governance"
        );
        _;
    }

    modifier onlyAuthorized() {
        require(
            governance() == _msgSender() || strategist() == _msgSender(),
            "Authorized: caller is not the authorized"
        );
        _;
    }

    function governance() public view virtual returns (address);

    function strategist() public view returns (address) {
        return _strategist;
    }

    function isAuthorized(address _addr) public view returns (bool) {
        return governance() == _addr || strategist() == _addr;
    }

    function setStrategist(address newStrategist) external onlyAuthorized {
        _strategist = newStrategist;
        emit UpdateManagement(_strategist);
    }
}
