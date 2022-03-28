// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interfaces/ISolidlyRouter01.sol";
import "./interfaces/uniswap.sol";
import "./interfaces/IRedirectVault.sol";
import {IVault} from "./interfaces/IVault.sol";
import {MultiRewards} from "./types/MultiRewards.sol";

struct UserInfo {
    uint256 amount; // How many tokens the user has provided.
    uint256 epochStart; // at what Epoch will rewards start
    uint256 depositTime; // when did the user deposit
}

interface IRewardDistributor {
    function isEpochFinished() external view returns (bool);

    function processEpoch(MultiRewards[] calldata _rewards) external;

    function onDeposit(address _user, uint256 _beforeBalance) external;

    function onWithdraw(address _user, uint256 _amount) external;

    function permitRewardToken(address _token) external;

    function unpermitRewardToken(address _token) external;
}

contract RewardDistributor is ReentrancyGuard, IRewardDistributor {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    /*///////////////////////////////////////////////////////////////
                                IMMUTABLES
    //////////////////////////////////////////////////////////////*/
    IERC20 public targetToken;
    IERC20 public tokenOut;
    IVault public targetVault;
    address public redirectVault;
    address public router;
    ISolidlyRouter01 public constant solidlyRouter = ISolidlyRouter01(0xa38cd27185a464914D3046f0AB9d43356B34829D);
    address public weth = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83;
    address public oxd = 0xc5A9848b9d145965d821AaeC8fA32aaEE026492d;

    // tracks total balance of base that is eligible for rewards in given epoch (as new deposits won't receive rewards until next epoch)
    uint256 public eligibleEpochRewards;
    uint256 public epoch = 0;
    uint256 public lastEpoch;
    uint256 constant BPS_ADJ = 10000;
    uint256 public timeForKeeperToConvert = 3600;

    mapping(address => UserInfo) public userInfo;
    // tracks rewards of traget token for given Epoch
    mapping(uint256 => uint256) public epochRewards;
    /// tracks the total balance eligible for rewards for given epoch
    mapping(uint256 => uint256) public epochBalance;
    /// tracks total tokens claimed by user
    mapping(address => uint256) public totalClaimed;

    event UserHarvested(address user, uint256 rewards);

    /*///////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _redirectVault,
        address _router,
        address _targetToken,
        address _targetVault,
        address _feeAddress
    ) {
        router = _router;
        redirectVault = _redirectVault;
        targetToken = IERC20(_targetToken);
        targetVault = IVault(_targetVault);
        feeAddress = _feeAddress;
        require(
            _targetToken == IVault(targetVault).token(),
            "Vault.token() miss-match"
        );

        useTargetVault = false;

        IERC20(oxd).approve(address(solidlyRouter), type(uint256).max);
        IERC20(weth).approve(address(router), type(uint256).max);

        if (_targetVault == address(0)) {
            useTargetVault = false;
            tokenOut = targetToken;
        } else {
            useTargetVault = true;
            // Approve allowance for the vault
            tokenOut = IERC20(_targetVault);
            targetToken.safeApprove(_targetVault, type(uint256).max);
        }
    }

    /*///////////////////////////////////////////////////////////////
                        USE TARGET VAULT CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Set to true to enable deposits into the target vault
    bool public useTargetVault = true;
    bool public emergencyExitVault = false; 
    uint256 public emergencyExitEpoch;
    uint256 public emergencyTargetOut;
    uint256 public emergencyVaultBalance;

    function emergencyDisableVault() external onlyAuthorized {
        require(useTargetVault);
        useTargetVault = false;
        emergencyExitVault = true;
        emergencyExitEpoch = epoch;
        tokenOut = targetToken;
        emergencyVaultBalance = targetVault.balanceOf(address(this));
        uint256 targetBalanceBefore = targetToken.balanceOf(address(this));
        targetVault.withdraw();
        uint256 targetBalanceAfter = targetToken.balanceOf(address(this));
        emergencyTargetOut = targetBalanceAfter.sub(targetBalanceBefore);

    }

    /*///////////////////////////////////////////////////////////////
                        FEE ADDRESS CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice address which fees are sent each epoch
    address public feeAddress;

    /// @notice set feeAddress
    /// @param _feeAddress The new feeAddress setting
    function setFeeAddress(address _feeAddress) external onlyAuthorized {
        feeAddress = _feeAddress;
    }

    /*///////////////////////////////////////////////////////////////
                        SET EPOCH TIME CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice timePerEpoch sets the minimum time that must elapsed betweem
    /// harvests. During harvests the rewards tokens are swapped into the
    /// targetToken and user reward balances are updated.
    uint256 public timePerEpoch = 60 * 60 * 3; // 3 Hours
    uint256 constant timePerEpochLimit = 259200;

    /// @notice set timePerEpoch
    /// @param _epochTime todo
    function setEpochDuration(uint256 _epochTime) external onlyAuthorized {
        require(_epochTime <= timePerEpochLimit);
        timePerEpoch = _epochTime;
    }

    // amount of profit converted each Epoch (don't convert everything to smooth returns)
    uint256 public profitConversionPercent = 10000; // 100% default
    uint256 public minProfitThreshold; // minimum amount of profit in order to conver to target token
    uint256 public profitFee = 500; // 5% default
    uint256 constant profitFeeMax = 2000; // 20% max

    function setParamaters(
        uint256 _profitConversionPercent,
        uint256 _profitFee,
        uint256 _minProfitThreshold
    ) external onlyAuthorized {
        require(_profitConversionPercent <= BPS_ADJ);
        require(_profitFee <= profitFeeMax);

        profitConversionPercent = _profitConversionPercent;
        minProfitThreshold = _minProfitThreshold;
        profitFee = _profitFee;
    }

    /// @notice Returns true if the epoch is complete and un processsed.
    /// @dev epoch is processed by processEpoch()
    function isEpochFinished() public view returns (bool) {
        return ((block.timestamp >= lastEpoch.add(timePerEpoch)));
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return IRedirectVault(redirectVault).owner();
    }

    /// @notice Throws if called by any account other than the vault.
    modifier onlyVault() {
        require(redirectVault == msg.sender, "!redirectVault");
        _;
    }

    /// @notice Throws if called by any account other than the managment or governance
    /// of the redirect vault
    modifier onlyAuthorized() {
        require(
            IRedirectVault(redirectVault).isAuthorized(msg.sender),
            "!authorized"
        );
        _;
    }

    /// @notice Only called by the vault. The vault sends harvest rewards to the
    /// reward distributor, and processEpoch() redirects the rewards to the targetToken
    /// @dev epoch is processed by processEpoch()
    function processEpoch(MultiRewards[] calldata _rewards) external onlyVault {
        uint256 preSwapBalance = targetBalance();

        // only convert profits if there is sufficient profit & users are eligible to start receiving rewards this epoch
        if (eligibleEpochRewards > 0) {
            _redirectProfits(_rewards);
            _deposit();
        }
        _updateRewardData(preSwapBalance);
        _incrementEpoch();
    }

    function targetBalance() public view returns (uint256) {
        return tokenOut.balanceOf(address(this));
    }

    function targetVaultBalance() public view returns (uint256) {
        if (address(targetVault) == address(0)) {
            return 0;
        }
        return
            targetVault
                .balanceOf(address(this))
                .mul(targetVault.pricePerShare())
                .div(10**targetVault.decimals());
    }

    function totalTargetBalance() public view returns (uint256) {
        return targetBalance().add(targetVaultBalance());
    }

    function _redirectProfits(MultiRewards[] calldata _rewards) internal {
        for (uint256 i = 0; i < _rewards.length; i++) {
            _swapTokenToTargetUniV2(_rewards[i].token);
        }
    }

    function manualRedirect(address token) external onlyAuthorized {
        require(token != address(targetToken));
        _sellRewards(token);
    }

    function _sellRewards(address token) internal {
        if (token == oxd) {
            _convert0xd();
        } else {
            _swapTokenToTargetUniV2(token);
        }
    }

    function _convert0xd() internal {
        uint256 swapAmount = IERC20(oxd).balanceOf(address(this));
        solidlyRouter.swapExactTokensForTokensSimple(
            swapAmount,
            uint(0),
            oxd,
            weth,
            true,
            address(this),
            block.timestamp
        );

        if (address(targetToken) != weth) {
            _swapTokenToTargetUniV2(weth);
        }

    }

    function _swapTokenToTargetUniV2(address token) internal {
        IERC20 rewardToken = IERC20(token);
        uint256 swapAmt = rewardToken
            .balanceOf(address(this))
            .mul(profitConversionPercent)
            .div(BPS_ADJ);
        uint256 fee = swapAmt.mul(profitFee).div(BPS_ADJ);
        rewardToken.transfer(feeAddress, fee);
        if (swapAmt > 0) {
            IUniswapV2Router01(router).swapExactTokensForTokens(
                swapAmt.sub(fee),
                0,
                _getTokenOutPath(
                    address(rewardToken),
                    address(targetToken),
                    weth
                ),
                address(this),
                block.timestamp
            );
        }
    }

    function onDeposit(address _user, uint256 _beforeBalance)
        external
        onlyVault
    {
        uint256 rewards = getUserRewards(_user);

        if (rewards > 0) {
            // claims all rewards
            _disburseRewards(_user, rewards);
        }

        if (userInfo[_user].epochStart < epoch) {
            _updateEligibleEpochRewards(_beforeBalance);
        }
        // to prevent users leaching i.e. deposit just before epoch rewards distributed user will start to be eligible for rewards following epoch
        _updateUserInfo(_user, epoch + 1);
    }

    function onWithdraw(address _user, uint256 _amount) external onlyVault {
        uint256 rewards = getUserRewards(_user);

        if (rewards > 0) {
            // claims all rewards
            _disburseRewards(_user, rewards);
        }

        if (userInfo[_user].epochStart < epoch) {
            _updateEligibleEpochRewards(_amount);
        }

        _updateUserInfo(_user, epoch);
    }

    function harvest() public nonReentrant {
        address user = msg.sender;
        uint256 rewards = getUserRewards(user);
        require(rewards > 0, "user must have balance to claim");
        _disburseRewards(user, rewards);
        /// updates reward information so user rewards start from current EPOCH
        _updateUserInfo(user, epoch);
        emit UserHarvested(user, rewards);
    }

    function _disburseRewards(address _user, uint256 _rewards) internal {
        tokenOut.transfer(_user, _rewards);
        _updateAmountClaimed(_user, _rewards);
    }

    function getUserRewards(address _user) public view returns (uint256) {
        UserInfo memory user = userInfo[_user];
        uint256 rewardStart = user.epochStart;
        if (rewardStart == 0) {
            return 0;
        }

        uint256 rewards = 0;
        uint256 userEpochRewards;
        if (epoch > rewardStart) {
            for (uint256 i = rewardStart; i < epoch; i++) {
                userEpochRewards = _calcUserEpochRewards(i, user.amount);
                if (emergencyExitVault && i < emergencyExitEpoch) { 
                    userEpochRewards = userEpochRewards.mul(emergencyTargetOut).div(emergencyVaultBalance);
                }
                rewards = rewards.add(userEpochRewards);
            }
        }
        return (rewards);
    }

    function _calcUserEpochRewards(uint256 _epoch, uint256 _amt)
        internal
        view
        returns (uint256)
    {
        
        uint256 rewards = epochRewards[_epoch].mul(_amt).div(
            epochBalance[_epoch]
        );
        return (rewards);
    }

    function _updateAmountClaimed(address _user, uint256 _rewardsPaid)
        internal
    {
        totalClaimed[_user] = totalClaimed[_user] + _rewardsPaid;
    }

    function _updateEligibleEpochRewards(uint256 amt) internal {
        eligibleEpochRewards = eligibleEpochRewards.sub(amt);
    }

    function _updateUserInfo(address _user, uint256 _epoch) internal {
        userInfo[_user] = UserInfo(
            IRedirectVault(redirectVault).balanceOf(_user),
            _epoch,
            block.timestamp
        );
    }

    function _incrementEpoch() internal {
        epoch = epoch.add(1);
        lastEpoch = block.timestamp;
    }

    /// @notice Updates the rewards and eligible balance for the epoch just passed.
    /// @dev Only called when an epoch is being processed
    /// @param _preSwapBalance targetToken balance prior to the swap
    function _updateRewardData(uint256 _preSwapBalance) internal {
        uint256 amountOut = targetBalance().sub(_preSwapBalance);

        epochRewards[epoch] = amountOut;
        /// we use this instead of total Supply as users that just deposited in current epoch are not eligible for rewards
        epochBalance[epoch] = eligibleEpochRewards;
        /// set to equal total Supply as all current users with deposits are eligible for next epoch rewards
        eligibleEpochRewards = IRedirectVault(redirectVault).totalSupply();
    }

    function _deposit() internal {
        if (useTargetVault) {
            uint256 bal = targetToken.balanceOf(address(this));
            IVault(address(targetVault)).deposit(bal);
        }
    }

    function _getTokenOutPath(
        address _token_in,
        address _token_out,
        address _weth
    ) internal view returns (address[] memory _path) {
        bool is_weth = _token_in == _weth || _token_out == _weth;
        _path = new address[](is_weth ? 2 : 3);
        _path[0] = _token_in;
        if (is_weth) {
            _path[1] = _token_out;
        } else {
            _path[1] = _weth;
            _path[2] = _token_out;
        }
    }

    function permitRewardToken(address _token) external onlyAuthorized {
        IERC20(_token).safeApprove(router, type(uint256).max);
    }

    function unpermitRewardToken(address _token) external onlyAuthorized {
        IERC20(_token).safeApprove(router, 0);
    }
}
