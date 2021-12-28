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
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

struct UserInfo {
    uint256 amount;     // How many tokens the user has provided.
    uint256 epochStart; // at what Epoch will rewards start 
    uint256 depositTime; // when did the user deposit 
}

abstract contract rewardDistributor is ReentrancyGuard {
    
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;
    IERC20 public targetToken;
    address public router;
    address public weth; 
    
    // tracks total balance of base that is eligible for rewards in given epoch (as new deposits won't receive rewards until next epoch)
    uint256 eligibleEpochRewards;
    uint256 public epoch = 0;
    uint256 public lastEpoch;
    uint256 public timePerEpoch = 1; // 
    uint256 constant timePerEpochLimit = 259200;
    //uint256 public timePerEpoch = 86400;
    uint256 public timeForKeeperToConvert = 3600;

    
    mapping (address => UserInfo) public userInfo;
    // tracks rewards of traget token for given Epoch
    mapping (uint256 => uint256) public epochRewards; 
    /// tracks the total balance eligible for rewards for given epoch
    mapping (uint256 => uint256) public epochBalance; 
    /// tracks total tokens claimed by user 
    mapping (address => uint256) public totalClaimed;


    function claimRewards() public nonReentrant {
        uint256 pendingRewards = getUserRewards(msg.sender);
        require(pendingRewards > 0, "user must have balance to claim"); 
        _disburseRewards(msg.sender);
    }
    

    function _disburseRewards(address _user) internal {
        uint256 rewards = getUserRewards(_user);
        targetToken.transfer(_user, rewards);
        _updateAmountClaimed(_user, rewards);
    }


    function getUserRewards(address _user) public view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 rewardStart = user.epochStart;
        uint256 rewards = 0;
        uint256 userEpochRewards;
        require(epoch > rewardStart);
        for (uint i=rewardStart; i<epoch; i++) {
            userEpochRewards = _calcUserEpochRewards(i, user.amount);
            rewards = rewards.add(userEpochRewards);
        }
        rewards = rewards.sub(totalClaimed[_user]);
        return(rewards);      
    }

    function _calcUserEpochRewards(uint256 _epoch, uint256 _amt) internal view returns(uint256) {
        uint256 rewards = epochRewards[_epoch].mul(_amt).div(epochBalance[_epoch]);
        return(rewards);
    }

    function _updateAmountClaimed(address _user, uint256 _rewardsPaid) internal {
        totalClaimed[_user] = totalClaimed[_user] + _rewardsPaid;
    }


}
