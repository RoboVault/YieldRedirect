// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/Context.sol";


contract Authorized is Context {
    address private _governance;
    address private _management;
    address private _pendingGovernance;

    event UpdateGovernance(address indexed governance);
    event UpdateManagement(address indexed management);

    constructor () {
        _governance = _msgSender();
        _management = _msgSender();
    }

    modifier onlyGovernance() {
        require(governance() == _msgSender(), "Authorized: caller is not the governance");
        _;
    }

    modifier onlyAuthorized() {
        require(
            governance() == _msgSender() || 
            management() == _msgSender(), 
            "Authorized: caller is not the authorized"
        );
        _;
    }

    function governance() public view returns (address) {
        return _governance;
    }

    function management() public view returns (address) {
        return _management;
    }

    function setGoveranance(address newGovernance) external onlyGovernance {
        _pendingGovernance = newGovernance;
    }

    function setManagement(address newManagement) external onlyAuthorized {
        _management = newManagement;
        emit UpdateManagement(_management);
    }

    function acceptGovernance() external onlyGovernance {
        require (_msgSender() == _pendingGovernance);
        _governance = _pendingGovernance;
        emit UpdateGovernance(_governance);
    }
}
