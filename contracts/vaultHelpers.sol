// // SPDX-License-Identifier: AGPL-3.0
// pragma solidity 0.6.12;
// pragma experimental ABIEncoderV2;

// import './globalHelpers.sol';
// import "../interfaces/vaults.sol";


// // Helpers for vault management 

// abstract contract vaultHelpers is helpers {

//     address public vaultAddress;
//     uint256 safetyFactor = 10100; // when withdrawing from vault to account for potential losses 

//     // deposits underlying asset to VAULT 
//     function _depositAsset(uint256 amt) internal {
//         Ivault(vaultAddress).deposit(amt);
//     }

//     function _withdrawAmountBase(uint256 amt) internal {
//         uint256 vaultBal = vaultBalance();
//         IERC20 vaultToken = IERC20(vaultAddress);
//         uint256 vaultTokens = vaultToken.balanceOf(address(this));
//         uint256 withdrawAmt;
//         withdrawAmt = amt.mul(vaultTokens).div(vaultBal);
//         withdrawAmt = withdrawAmt.mul(safetyFactor).div(BPS_adj);
//         withdrawAmt = Math.min(withdrawAmt, vaultTokens);
//         _withdrawAsset(withdrawAmt);
//     }

//     function _withdrawAsset(uint256 amt) internal {
//         Ivault(vaultAddress).withdraw(amt);
//     }

//     function _approveNewEarner(address _underlying, address _deployAddress) internal {
//         IERC20 underlying = IERC20(_underlying);
//         underlying.approve(_deployAddress, uint(-1));
//     }

//     function _removeApprovals(address _underlying, address _deployAddress) internal {
//         IERC20 underlying = IERC20(_underlying);
//         underlying.approve(_deployAddress, uint(0));
//     }

//     function _unlockUnderlying() internal {
//         IERC20 vaultToken = IERC20(vaultAddress);
//         uint256 vaultTokens = vaultToken.balanceOf(address(this));
 
//         Ivault(vaultAddress).withdraw(vaultTokens);
//     }

//     function vaultBalance() public view returns(uint256){
//         IERC20 vaultToken = IERC20(vaultAddress);
//         uint256 vaultDecimals = Ivault(vaultAddress).decimals(); 
//         uint256 vaultBPS = 10**vaultDecimals;
//         uint256 bal = vaultToken.balanceOf(address(this)).mul(Ivault(vaultAddress).pricePerShare()).div(vaultBPS);
//         return(bal);
//     }


// }


