// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {
    SafeERC20,
    SafeMath,
    IERC20,
    Address
} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/math/Math.sol";
import "../interfaces/vaults.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";


// Helpers for vault management 

abstract contract vaultHelpers is Ownable {

    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    mapping(address => uint256) private _balances;
    uint256 private _totalSupply;


    address public keeper;
    address public strategist; 
    address public vaultAddress;
    uint256 safetyFactor = 10100; // when withdrawing from vault to account for potential losses 
    uint256 constant BPS_adj = 10000;

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");
        _totalSupply += amount;
        _balances[account] += amount;
        //emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        _balances[account] = accountBalance - amount;
        _totalSupply -= amount;
        //emit Transfer(account, address(0), amount);

    }

    // modifiers
    modifier onlyAuthorized() {
        require(
            msg.sender == strategist || msg.sender == owner(),
            "!authorized"
        );
        _;
    }

    modifier onlyStrategist() {
        require(msg.sender == strategist, "!strategist");
        _;
    }

    modifier onlyKeepers() {
        require(
            msg.sender == keeper ||
                msg.sender == strategist ||
                msg.sender == owner(),
            "!authorized"
        );
        _;
    }

    function setStrategist(address _strategist) external onlyAuthorized {
        require(_strategist != address(0));
        strategist = _strategist;
    }

    function setKeeper(address _keeper) external onlyAuthorized {
        require(_keeper != address(0));
        keeper = _keeper;
    }

    // deposits underlying asset to VAULT 
    function _depositAsset(uint256 amt) internal {
        Ivault(vaultAddress).deposit(amt);
    }

    function _withdrawAmountBase(uint256 amt) internal {
        uint256 vaultBal = vaultBalance();
        IERC20 vaultToken = IERC20(vaultAddress);
        uint256 vaultTokens = vaultToken.balanceOf(address(this));
        uint256 withdrawAmt;
        withdrawAmt = amt.mul(vaultTokens).div(vaultBal);
        withdrawAmt = withdrawAmt.mul(safetyFactor).div(BPS_adj);
        withdrawAmt = Math.min(withdrawAmt, vaultTokens);
        _withdrawAsset(withdrawAmt);
    }

    function _withdrawAsset(uint256 amt) internal {
        Ivault(vaultAddress).withdraw(amt);
    }

    function _approveNewEarner(address _underlying, address _deployAddress) internal {
        IERC20 underlying = IERC20(_underlying);
        underlying.approve(_deployAddress, uint(-1));
    }

    function _removeApprovals(address _underlying, address _deployAddress) internal {
        IERC20 underlying = IERC20(_underlying);
        underlying.approve(_deployAddress, uint(0));
    }

    function _unlockUnderlying() internal {
        IERC20 vaultToken = IERC20(vaultAddress);
        uint256 vaultTokens = vaultToken.balanceOf(address(this));
 
        Ivault(vaultAddress).withdraw(vaultTokens);
    }

    function vaultBalance() public view returns(uint256){
        IERC20 vaultToken = IERC20(vaultAddress);
        uint256 vaultDecimals = Ivault(vaultAddress).decimals(); 
        uint256 vaultBPS = 10**vaultDecimals;
        uint256 bal = vaultToken.balanceOf(address(this)).mul(Ivault(vaultAddress).pricePerShare()).div(vaultBPS);
        return(bal);
    }

    function _getTokenOutPath(address _token_in, address _token_out, address _weth)
        internal
        view
        returns (address[] memory _path)
    {
        bool is_weth =
            _token_in == _weth || _token_out == _weth;
        _path = new address[](is_weth ? 2 : 3);
        _path[0] = _token_in;
        if (is_weth) {
            _path[1] = _token_out;
        } else {
            _path[1] = _weth;
            _path[2] = _token_out;
        }
    }



}


