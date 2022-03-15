// // SPDX-License-Identifier: AGPL-3.0
// pragma solidity 0.6.12;
// pragma experimental ABIEncoderV2;

// import './globalHelpers.sol';
// import "../interfaces/farm.sol";
// import "../interfaces/gauge.sol";



// // Helpers for vault management 

// /*
// farmType
// 0 = standard masterchef i.e. SpookyFarm
// 1 = gauge i.e. Spirit Farm
// 2 = LQDR farm
// 3 = Beets farm  
// */


// abstract contract farmHelpers is helpers {

//     address public farmAddress;
//     uint256 pid;
//     uint256 farmType;

//     function farmBalance() public view returns(uint256){
//         return IFarm(farmAddress).userInfo(pid, address(this));
//     }

//     // deposits underlying asset to VAULT 
//     function _depositAsset(uint256 amt) internal {
//         if (farmType == 0){IFarm(farmAddress).deposit(pid, amt);}
//         if (farmType == 1){IGauge(farmAddress).deposit(amt);}
//         if (farmType == 2){IFarmPain(farmAddress).deposit(pid, amt, address(this));}
//         if (farmType == 3){IFarmPain(farmAddress).deposit(pid, amt, address(this));}
//     }

//     function _withdrawAmountBase(uint256 amt) internal {
//         if (farmType == 0){IFarm(farmAddress).withdraw(pid, amt);}
//         if (farmType == 1){IGauge(farmAddress).withdrawAll();}
//         if (farmType == 2){IFarmPain(farmAddress).withdraw(pid, amt, address(this));}
//         if (farmType == 3){IFarmPain(farmAddress).withdrawAndHarvest(pid, amt,address(this));}   
//     }

//     function _harvest() internal {
//         if (farmType == 0){IFarm(farmAddress).withdraw(pid, 0);}
//         if (farmType == 1){IGauge(farmAddress).getReward();}
//         if (farmType == 2){IFarmPain(farmAddress).harvest(pid, address(this));}
//         if (farmType == 3){IFarmPain(farmAddress).withdrawAndHarvest(pid, 0,address(this));}   
//     }


//     function _approveNewEarner(address _underlying, address _deployAddress) internal {
//         IERC20 underlying = IERC20(_underlying);
//         underlying.approve(_deployAddress, uint(-1));
//     }

//     function _removeApprovals(address _underlying, address _deployAddress) internal {
//         IERC20 underlying = IERC20(_underlying);
//         underlying.approve(_deployAddress, uint(0));
//     }

// }


