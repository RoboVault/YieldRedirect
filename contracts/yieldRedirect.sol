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

import "../interfaces/uniswap.sol";
import "../interfaces/vaults.sol";
import './rewardDistributor.sol';
import './vaultHelpers.sol';


/*
The vault container allows users to deposit funds which are then deployed to a single asset vault i.e YEARN / ROBOVAULT 
at each EPOCH any yield / profit generate from the strategy is then used to purchase the TARGET Token of the users choice 
For example this would give users the ability to deposit into a USDC vault while their USDC balance will remain the same extra USDC could be used to buy 
a target token such as OHM 
Additionally some mechanics on vesting of the target tokens are built in encouraging users to keep their assets in the vault container over a longer period
*/


contract yieldRedirect is helpers, ERC20, rewardDistributor {

    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    IERC20 public base;

    uint256 public profitFee = 300; // 3% default
    uint256 constant profitFeeMax = 1000; // 10%
    uint256 public reserveAllocation = 500; // 5% default
    uint256 public tvlLimit;
    // amount of profit converted each Epoch (don't convert everything to smooth returns)
    uint256 public profitConversionPercent = 5000; // 50% default 
    uint256 public minProfitThreshold; // minimum amount of profit in order to conver to target token
    address public rewards; 

    constructor(
        string memory _name, 
        string memory _symbol,
        address _base,
        address _targetToken,
        address _vault,
        address _router,
        address _weth

    ) public ERC20(_name, _symbol) {
        base = IERC20(_base);
        targetToken = IERC20(_targetToken);
        vaultAddress = _vault;
        router = _router;
        base.approve(vaultAddress, uint(-1));
        base.approve(router, uint(-1));
        weth = _weth;
        rewards = owner();

    }

    // user deposits token to yield redirector in exchange for pool shares which can later be redeemed for assets + accumulated yield
    function deposit(uint256 _amount) public nonReentrant
    {
        require(_amount > 0, "deposit must be greater than 0");
        bool withinTvlLimit = _amount.add(estimatedTotalAssets()) >= tvlLimit;
        require(withinTvlLimit, "deposit greater than TVL Limit");

        if (balanceOf(msg.sender) > 0) {
            // claims all rewards 
            _disburseRewards(msg.sender);
        }
        base.transferFrom(msg.sender, address(this), _amount);    
        uint256 shares = _amount;
        _mint(msg.sender, shares);

        // to prevent users leaching i.e. deposit just before epoch rewards distributed user will start to be eligible for rewards following epoch
        // also as a result if user has balance & then deposits again will skip one epoch of rewards 
        _updateUserInfo(msg.sender);
    }

    function depositAll() public {
        uint256 balance = base.balanceOf(msg.sender); 
        deposit(balance); 
    }
    
    // for simplicity in tracking Epoch positions when withdrawing user must withdraw ALl 
    function withdraw() public nonReentrant
    {
        uint256 ibalance = balanceOf(msg.sender);
        require(ibalance > 0, "withdraw must be greater than 0");
        _burn(msg.sender, ibalance);

        // Check balance
        uint256 b = base.balanceOf(address(this));
        if (b < ibalance) {
        uint256 withdrawAmt = ibalance.sub(b);
        _withdrawAmountBase(withdrawAmt);
        }

        base.safeTransfer(msg.sender, ibalance);
        _disburseRewards(msg.sender);
        _updateUserInfo(msg.sender);
        _updateEligibleEpochRewards(ibalance);
    }

    function _updateEligibleEpochRewards(uint256 amtWithdrawn) internal {
      eligibleEpochRewards = eligibleEpochRewards.sub(amtWithdrawn);

    }

    function setRewards(address _rewards) external onlyAuthorized {
        require(_rewards != address(0));
        rewards = _rewards;
    }

    function setParamaters(
        uint256 _reserveAllocation,
        uint256 _profitConversionPercent,
        uint256 _profitFee,
        uint256 _minProfitThreshold
    ) external onlyAuthorized {
        require(_reserveAllocation <= BPS_adj);
        require(_profitConversionPercent <= BPS_adj);
        require(_profitFee <= profitFeeMax);

        reserveAllocation = _reserveAllocation;
        profitFee = _profitFee;
        profitConversionPercent = _profitConversionPercent;
        minProfitThreshold = _minProfitThreshold;
    }

    function setEpochDuration(uint256 _epochTime) external onlyAuthorized{
        require(_epochTime <= timePerEpochLimit);
        timePerEpoch = _epochTime;
    }

    function setTvlLimit(uint256 _tvlLimit) external onlyAuthorized {
        tvlLimit = _tvlLimit;
    }

    function _updateUserInfo(address _user) internal {
        userInfo[_user] = UserInfo(balanceOf(_user), epoch + 1, block.timestamp);
    }

    function deployStrat() external onlyKeepers {
        uint256 bal = base.balanceOf(address(this));
        uint256 totalBal = estimatedTotalAssets();
        uint256 reserves = totalBal.mul(reserveAllocation).div(BPS_adj);
        if (bal > reserves) {
            _deployCapital(bal.sub(reserves));
        }
    }

    function _deployCapital(uint256 _amount) internal {
        _depositAsset(_amount);
    }

    function estimatedTotalAssets() public view returns(uint256) {
        uint256 bal = base.balanceOf(address(this));
        bal = bal.add(vaultBalance());
        return(bal);
    }

    function convertProfits() external onlyKeepers nonReentrant {
        require(isEpochFinished()); 
        _convertProfitsInternal();

    }

    // allow public to convert profits if keeper hasn't executed within 1 hour (as per timeForKeeperToConvert variable)
    function convertProfitsPublic() public nonReentrant {
        require(isEpochOverdue()); 
        _convertProfitsInternal();
    }

    function _convertProfitsInternal() internal {
        uint256 profits = _calcEpochProfits();
        uint256 preSwapBalance = targetToken.balanceOf(address(this));

        bool sufficientProfits = profits > minProfitThreshold;
        bool depositorsEligible = eligibleEpochRewards > 0;

        // only convert profits if there is sufficient profit & users are eligible to start receiving rewards this epoch
        if (sufficientProfits && depositorsEligible){
            _swapToTarget(profits);
        }
        _updateRewardData(preSwapBalance);
        _updateEpoch();
    }

    function isEpochFinished() public view returns (bool){
        return((block.timestamp >= lastEpoch.add(timePerEpoch)));
    }

    function isEpochOverdue() public view returns (bool){
        return((block.timestamp >= lastEpoch.add(timePerEpoch.add(timeForKeeperToConvert))));
    }

    function _swapToTarget(uint256 _profits) internal {
        
        uint256 profitConverted = _profits.mul(profitConversionPercent).div(BPS_adj);
        if (base.balanceOf(address(this)) < profitConverted) {
            uint256 withdrawAmt = profitConverted.sub(base.balanceOf(address(this)));
            _withdrawAmountBase(withdrawAmt);
        }

        uint256 swapAmt = Math.min(profitConverted, base.balanceOf(address(this)));
        uint256 amountOutMin = 0; // TO DO make sure don't get front run 
        address[] memory path = _getTokenOutPath(address(base), address(targetToken), weth);
        IUniswapV2Router01(router).swapExactTokensForTokens(swapAmt, amountOutMin, path, address(this), now);
    }

    function _updateRewardData(uint256 _preSwapBalance) internal {
        uint256 amountOut = (targetToken.balanceOf(address(this)).sub(_preSwapBalance));
        uint256 fee = _calcFee(amountOut);
        targetToken.transfer(rewards, fee);
        epochRewards[epoch] = amountOut.sub(fee); 
        /// we use this instead of total Supply as users that just deposited in current epoch are not eligible for rewards 
        epochBalance[epoch] = eligibleEpochRewards;
        /// set to equal total Supply as all current users with deposits are eligible for next epoch rewards 
        eligibleEpochRewards = totalSupply();

    }

    function _updateEpoch() internal {
        epoch = epoch.add(1);
        lastEpoch = block.timestamp;
    }

    function _calcFee(uint256 _amount) internal view returns (uint256) {
        uint256 _fee = _amount.mul(profitFee).div(BPS_adj);
        return(_fee);
    }

    function _calcEpochProfits() public view returns(uint256) {
        uint256 profit = estimatedTotalAssets().sub(totalSupply()); 
        return(profit);
    }

}