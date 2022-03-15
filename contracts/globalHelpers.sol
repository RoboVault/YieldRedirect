// // SPDX-License-Identifier: AGPL-3.0
// pragma solidity 0.6.12;
// pragma experimental ABIEncoderV2;

// import {
//     SafeERC20,
//     SafeMath,
//     IERC20,
//     Address
// } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
// import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import {Math} from "@openzeppelin/contracts/math/Math.sol";
// import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";


// abstract contract helpers is Ownable {

//     using SafeERC20 for IERC20;
//     using Address for address;
//     using SafeMath for uint256;

//     mapping(address => uint256) private _balances;
//     uint256 private _totalSupply;
//     bool public isActive;
//     uint256 public tvlLimit = uint(-1);

//     address public keeper;
//     address public strategist; 
//     uint256 constant BPS_adj = 10000;

//     // have stripped out basic ERC20 functionality for tracking balances upon deposits 
//     // have removed transfer as this will complicate tracking of rewards i.e. edge cases whne transferring to user that has just deposited 

//     function totalSupply() public view returns (uint256) {
//         return _totalSupply;
//     }

//     function balanceOf(address account) public view returns (uint256) {
//         return _balances[account];
//     }

//     function _mint(address account, uint256 amount) internal virtual {
//         require(account != address(0), "ERC20: mint to the zero address");
//         _totalSupply += amount;
//         _balances[account] += amount;
//         //emit Transfer(address(0), account, amount);
//     }

//     function _burn(address account, uint256 amount) internal virtual {
//         require(account != address(0), "ERC20: burn from the zero address");

//         uint256 accountBalance = _balances[account];
//         require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
//         _balances[account] = accountBalance - amount;
//         _totalSupply -= amount;
//         //emit Transfer(account, address(0), amount);

//     }

//     // modifiers
//     modifier onlyAuthorized() {
//         require(
//             msg.sender == strategist || msg.sender == owner(),
//             "!authorized"
//         );
//         _;
//     }

//     modifier onlyStrategist() {
//         require(msg.sender == strategist, "!strategist");
//         _;
//     }

//     modifier onlyKeepers() {
//         require(
//             msg.sender == keeper ||
//                 msg.sender == strategist ||
//                 msg.sender == owner(),
//             "!authorized"
//         );
//         _;
//     }

//     function setStrategist(address _strategist) external onlyAuthorized {
//         require(_strategist != address(0));
//         strategist = _strategist;
//     }

//     function setKeeper(address _keeper) external onlyAuthorized {
//         require(_keeper != address(0));
//         keeper = _keeper;
//     }

//     // this is used when completing the swap redirecting yield from base asset or farming reward to target asset 

//     function _getTokenOutPath(address _token_in, address _token_out, address _weth)
//         internal
//         view
//         returns (address[] memory _path)
//     {
//         bool is_weth =
//             _token_in == _weth || _token_out == _weth;
//         _path = new address[](is_weth ? 2 : 3);
//         _path[0] = _token_in;
//         if (is_weth) {
//             _path[1] = _token_out;
//         } else {
//             _path[1] = _weth;
//             _path[2] = _token_out;
//         }
//     }

// }


