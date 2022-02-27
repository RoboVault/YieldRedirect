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
import './farmHelpers.sol';

interface IERC20Extended is IERC20 {
    function decimals() external view returns (uint8);
}

/*
The vault container allows users to deposit funds which are then deployed to a single asset vault i.e YEARN / ROBOVAULT 
at each EPOCH any yield / profit generate from the strategy is then used to purchase the TARGET Token of the users choice 
For example this would give users the ability to deposit into a USDC vault while their USDC balance will remain the same extra USDC could be used to buy 
a target token such as OHM 
Additionally some mechanics on vesting of the target tokens are built in encouraging users to keep their assets in the vault container over a longer period
*/
    

contract yieldRedirectFarm is farmHelpers, rewardDistributor {

    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    IERC20 public base;
    IERC20[] public farmTokens;
    IERC20 public swapToken;

    uint256 public profitFee = 300; // 3% default
    uint256 constant profitFeeMax = 500; // 50%
    
    // amount of profit converted each Epoch (don't convert everything to smooth returns)
    uint256 public profitConversionPercent = 5000; // 50% default 
    uint256 public minProfitThreshold; // minimum amount of profit in order to conver to target token
    address public feeToAddress; 
    bool public useTargetVault;

    constructor(
        address _base,
        address _targetToken,
        address _swapToken,
        address _farmAddress,
        address _farmToken,
        address _router,
        address _weth,
        uint256 _pid,
        uint256 _farmType

    ) public {
        base = IERC20(_base);
        targetToken = IERC20(_targetToken);
        IERC20 farmToken = IERC20(_farmToken);
        farmToken.approve(_router, uint(-1));
        farmTokens.push(farmToken);
        swapToken = IERC20(_swapToken);
        useTargetVault = _targetToken != _swapToken;
        if (useTargetVault){
            // approve Vault 
            swapToken.approve(_targetToken, uint(-1));
        }
        farmAddress = _farmAddress;
        router = _router;
        base.approve(_farmAddress, uint(-1));
        weth = _weth;
        feeToAddress = owner();
        farmType = _farmType;

    }

    // emergency function to turn off everything i.e. withdraw everything from farm & set TVL limit to 0
    function deactivate() external onlyAuthorized {
        _withdrawAmountBase(farmBalance());
        isActive = false;
        tvlLimit = 0;
    }

    // if there are multiple reward tokens we can call this 
    function addFarmToken(address _token) external onlyAuthorized {
        IERC20 newFarmToken = IERC20(_token);
        newFarmToken.approve(router, uint(-1));
        farmTokens.push(newFarmToken);
    }

    function _findToken(address _token) internal view returns (uint256) {
        for (uint256 i = 0; i < farmTokens.length; i++){
            if (_token == address(farmTokens[i])){
                return i;
            }
        } 
        return uint256(-1);
    }


    function removeFarmToken(address _token) external onlyAuthorized {
        //require(!paused(), "PAUSED");
        uint256 tokenIndex = _findToken(_token);
        require(tokenIndex != uint256(-1), "NO SUCH TOKEN");

        uint256 i = tokenIndex;
        while(i < farmTokens.length - 1) {
            farmTokens[i] = farmTokens[i + 1];
            i++;
        }
        delete farmTokens[farmTokens.length - 1];
        farmTokens.pop();
    }


    // user deposits token to yield redirector in exchange for pool shares which can later be redeemed for assets + accumulated yield
    function deposit(uint256 _amount) public nonReentrant
    {
        require(_amount > 0, "deposit must be greater than 0");
        bool withinTvlLimit = _amount.add(estimatedTotalAssets()) <= tvlLimit;
        require(withinTvlLimit, "deposit greater than TVL Limit");
        uint256 currrentBalance = balanceOf(msg.sender);

        if (currrentBalance > 0) {
            // claims all rewards 
            _disburseRewards(msg.sender);
            // to make accounting work in tracking rewards for target asset this user isn't eligible for next epoch 
            _updateEligibleEpochRewards(currrentBalance);
        }
        base.transferFrom(msg.sender, address(this), _amount);    
        uint256 shares = _amount;
        _mint(msg.sender, shares);

        // to prevent users leaching i.e. deposit just before epoch rewards distributed user will start to be eligible for rewards following epoch
        _updateUserInfo(msg.sender, epoch + 1);
        /// we automatically deploy token to farm 
        _depositAsset(_amount);

    }

    function depositAll() public {
        uint256 balance = base.balanceOf(msg.sender); 
        deposit(balance); 
    }
    
    // for simplicity in tracking Epoch positions when withdrawing user must withdraw ALl 
    function withdraw(uint256 _amt) public nonReentrant
    {
        uint256 ibalance = balanceOf(msg.sender);
        require(ibalance >= _amt, "must have sufficient balance");
        require(_amt > 0);
        _burn(msg.sender, _amt);

        uint256 withdrawAmt = _amt;
        // check if vault is in loss i.e. due to losses within vault
        if (isVaultInLoss()){
            withdrawAmt = _amt.mul(estimatedTotalAssets()).div(totalSupply());
        }

        // Check balance
        uint256 b = base.balanceOf(address(this));
        if (b < withdrawAmt) {
            // remove required funds from underlying vault 
            uint256 vaultWithdrawAmt = withdrawAmt.sub(b);
            _withdrawAmountBase(vaultWithdrawAmt);
        }

        base.safeTransfer(msg.sender, withdrawAmt);
        _disburseRewards(msg.sender);
        _updateUserInfo(msg.sender, epoch);
        if (userInfo[msg.sender].epochStart < epoch){
            _updateEligibleEpochRewards(_amt);
        }
    }

    function harvest() public nonReentrant {
        uint256 pendingRewards = getUserRewards(msg.sender);
        require(pendingRewards > 0, "user must have balance to claim"); 
        _disburseRewards(msg.sender);
        /// updates reward information so user rewards start from current EPOCH 
        _updateUserInfo(msg.sender, epoch);
    }

    function _updateEligibleEpochRewards(uint256 amt) internal {
      eligibleEpochRewards = eligibleEpochRewards.sub(amt);

    }

    function isVaultInLoss() public view returns(bool) {
        return(estimatedTotalAssets() < totalSupply());
    }

    function setFeeToAddress(address _feeToAddress) external onlyAuthorized {
        require(_feeToAddress != address(0));
        feeToAddress = _feeToAddress;
    }

    function setParamaters(
        uint256 _profitConversionPercent,
        uint256 _profitFee,
        uint256 _minProfitThreshold
    ) external onlyAuthorized {
        require(_profitConversionPercent <= BPS_adj);
        require(_profitFee <= profitFeeMax);

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

    function _updateUserInfo(address _user, uint256 _epoch) internal {
        userInfo[_user] = UserInfo(balanceOf(_user), _epoch, block.timestamp);
    }

    function deployStrat() external onlyKeepers {
        uint256 bal = base.balanceOf(address(this));
        _deployCapital(bal.sub(bal));
    }

    function _deployCapital(uint256 _amount) internal {
        _depositAsset(_amount);
    }

    function estimatedTotalAssets() public view returns(uint256) {
        uint256 bal = base.balanceOf(address(this));
        bal = bal.add(farmBalance());
        return(bal);
    }

    function convertProfits() external onlyKeepers nonReentrant {
        require(isEpochFinished()); 
        _convertProfitsInternal();

    }

    function _convertProfitsInternal() internal {
        _harvest();

        uint256 preSwapBalance = targetToken.balanceOf(address(this));
        bool depositorsEligible = eligibleEpochRewards > 0;

        // only convert profits if there is sufficient profit & users are eligible to start receiving rewards this epoch
        if (depositorsEligible){
            _redirectProfits();
            if (useTargetVault){
                _depositSwapToTargetVault();
            }
        }
        _updateRewardData(preSwapBalance);
        _updateEpoch();
    }

    function isEpochFinished() public view returns (bool){
        return((block.timestamp >= lastEpoch.add(timePerEpoch)));
    }

    function _redirectProfits() internal {
        for (uint i=0; i<farmTokens.length; i++) {
            IERC20 farmToken = farmTokens[i];
            uint256 profitConverted = farmToken.balanceOf(address(this)).mul(profitConversionPercent).div(BPS_adj);
            uint256 swapAmt = Math.min(profitConverted, farmToken.balanceOf(address(this)));
            uint256 fee = swapAmt.mul(profitFee).div(BPS_adj);
            uint256 amountOutMin = 0;
            farmToken.transfer(feeToAddress, fee);
            address[] memory path = _getTokenOutPath(address(farmToken), address(swapToken), weth);
            if (profitConverted > 0){
                IUniswapV2Router01(router).swapExactTokensForTokens(swapAmt.sub(fee), amountOutMin, path, address(this), now);
            }
        }
    }

    function _depositSwapToTargetVault() internal {
        if (useTargetVault){
            uint256 bal = swapToken.balanceOf(address(this));
            Ivault(address(targetToken)).deposit(bal);
        }
    }

    function _updateRewardData(uint256 _preSwapBalance) internal {
        uint256 amountOut = (targetToken.balanceOf(address(this)).sub(_preSwapBalance));
        epochRewards[epoch] = amountOut; 
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