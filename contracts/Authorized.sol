// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/Context.sol";

contract Authorized is Context {
    address private _governance;
    address private _management;
    address private _keeper;
    address private _pendingGovernance;

    event UpdateGovernance(address indexed governance);
    event UpdateManagement(address indexed management);
    event UpdateKeeper(address indexed keeper);

    constructor() {
        _governance = _msgSender();
        _management = _msgSender();
        _keeper = _msgSender();
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
            governance() == _msgSender() || management() == _msgSender(),
            "Authorized: caller is not the authorized"
        );
        _;
    }

    modifier onlyKeeper() {
        require(
            governance() == _msgSender() ||
                management() == _msgSender() ||
                keeper() == _msgSender(),
            "Authorized: caller is not the a keeper"
        );
        _;
    }

    function governance() public view returns (address) {
        return _governance;
    }

    function management() public view returns (address) {
        return _management;
    }

    function keeper() public view returns (address) {
        return _keeper;
    }

    function isAuthorized(address _addr) public view returns (bool) {
        return governance() == _addr || management() == _addr;
    }

    function setGoveranance(address newGovernance) external onlyGovernance {
        _pendingGovernance = newGovernance;
    }

    function setManagement(address newManagement) external onlyAuthorized {
        _management = newManagement;
        emit UpdateManagement(_management);
    }

    function setKeeper(address newKeeper) external onlyAuthorized {
        _keeper = newKeeper;
        emit UpdateKeeper(_keeper);
    }

    function acceptGovernance() external onlyGovernance {
        require(_msgSender() == _pendingGovernance);
        _governance = _pendingGovernance;
        emit UpdateGovernance(_governance);
    }
}
