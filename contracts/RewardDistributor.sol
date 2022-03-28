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

    function onEmergencyWithdraw(address _user, uint256 _amount) external;

    function permitRewardToken(address _token) external;

    function unpermitRewardToken(address _token) external;
}

/// @title Manages reward distribution for a RedirectVault
/// @author Robovault
/// @notice You can use this contract to tract and distribut rewards
/// for RedirectVault users
/// @dev Design to isolate the reward distribution from the vault and
/// strategy so as to minimise impact if there are issues with the
/// RewardDistributor
contract RewardDistributor is ReentrancyGuard, IRewardDistributor {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    /*///////////////////////////////////////////////////////////////
                                IMMUTABLES
    //////////////////////////////////////////////////////////////*/
    /// @notice Underlying target token, eg USDC. This is what the rewards will be converted to,
    /// afterwhich the rewards may be deposited to a vault if one is configured
    IERC20 public immutable targetToken;

    /// @notice the target vault for pending rewards to be deposited into.
    IVault public immutable targetVault;

    /// @notice if a vault is configured this is set to targetVault, otherwise this will be targetToken. This
    /// is the token users will withdraw when harvesting. If there is an issue with the vault, authorized roles
    /// can call emergencyDisableVault() which will change tokenOut to targetToken.
    IERC20 public tokenOut;

    /// @notice contract address for the parent redurect vault.
    address public immutable redirectVault;

    /// @notice univ2 router used for swaps
    address public immutable router;

    /// @notice solidly router used for swapping only OXD when it is a reward token
    ISolidlyRouter01 public constant solidlyRouter =
        ISolidlyRouter01(0xa38cd27185a464914D3046f0AB9d43356B34829D);

    /// @notice weth (wftm address) for determining univ2 swap paths
    address public constant weth = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83;

    /// @notice oxd v2 contract address
    address public constant oxd = 0xc5A9848b9d145965d821AaeC8fA32aaEE026492d;

    /*///////////////////////////////////////////////////////////////
                                STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice tracks total balance of base that is eligible for rewards in given epoch.
    /// New deposits won't receive rewards until next epoch.
    uint256 public eligibleEpochRewards;

    /// @notice Tracks the epoch number. This is incremented each time processEpoch is called
    uint256 public epoch = 0;

    /// @notice timestamp of the previous epoch
    uint256 public lastEpoch;

    /// @notice BIPS Scalar
    uint256 constant BPS_ADJ = 10000;

    /// @notice mapping user info to user addresses
    mapping(address => UserInfo) public userInfo;

    /// @notice tracks rewards of traget token for given Epoch
    mapping(uint256 => uint256) public epochRewards;

    /// @notice tracks the total balance eligible for rewards for given epoch
    mapping(uint256 => uint256) public epochBalance;

    /// @notice tracks total tokens claimed by user
    mapping(address => uint256) public totalClaimed;

    /*///////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice User Harvrest Event
    event UserHarvested(
        address indexed user,
        uint256 indexed rewards,
        address indexed token
    );

    /// @notice Epoch Processed Event
    event EpochProcessed(
        uint256 indexed epoch,
        uint256 indexed amountOut,
        uint256 indexed eligibleEpochRewards
    );

    /*///////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice The Reward Distributor constructor initialises the immutables
    /// and validates the configuration of the contract.
    /// @param _redirectVault RedirectVault contract
    /// @param _router univ2 router (Spooky or Spirit)
    /// @param _targetToken Target token - eg USDC
    /// @param _targetVault Target vault - wg yvUSDC. Set this to the zero address if no vault is needed
    /// @param _feeAddress Address for which the fees are sent
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

    /// @notice flags if a vault is configured and that it's not in
    /// emergency exit.
    bool public useTargetVault = true;

    /// @notice flags a vault is in emergency exit and will no longer be used.
    bool public emergencyExitVault = false;

    /// @notice state and accounting values to track rewards before and after
    /// an emergency exit
    uint256 public emergencyExitEpoch;
    uint256 public emergencyTargetOut;
    uint256 public emergencyVaultBalance;

    /// @notice if there is an issue with the vault deposits, authorized users
    /// can call this function to perminantly remove the user of the vault. After
    /// this function is called, all rewards will be swapped into targetToken
    /// and remain there until harvested.
    function emergencyDisableVault() external onlyAuthorized {
        require(useTargetVault);

        // Disable use of the vault
        useTargetVault = false;
        emergencyExitVault = true;

        // Flag the epoch and current vault balance so rewards for epochs
        // prior to the emergency exit are calculated properly
        emergencyExitEpoch = epoch;
        emergencyVaultBalance = targetVault.balanceOf(address(this));

        // Update token out to the underlying.
        tokenOut = targetToken;

        // Withdraw from the vault and capture the withdraw amount
        uint256 targetBalanceBefore = targetToken.balanceOf(address(this));
        targetVault.withdraw();
        uint256 targetBalanceAfter = targetToken.balanceOf(address(this));
        emergencyTargetOut = targetBalanceAfter.sub(targetBalanceBefore);

        // Revoke vault approvals
        targetToken.safeApprove(address(targetVault), 0);
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

    /// @notice Throws if called by any account other than the governance
    /// of the redirect vault
    modifier onlyGovernance() {
        require(
            IRedirectVault(redirectVault).governance() == msg.sender,
            "!governance"
        );
        _;
    }

    /// @notice Only called by the vault. The vault sends harvest rewards to the
    /// reward distributor, and processEpoch() redirects the rewards to the targetToken
    /// @dev epoch is processed by processEpoch()
    /// @param _rewards and array of the rewards that have been sent to this contract
    /// that need to be converted to tokenOut
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

    /// @notice returns the targetOut balance
    /// @return targetOut balance of this contract
    function targetBalance() public view returns (uint256) {
        return tokenOut.balanceOf(address(this));
    }

    /// @notice swaps the rewards tokens to the targetToken
    /// @param _rewards and array of the rewards
    function _redirectProfits(MultiRewards[] calldata _rewards) internal {
        for (uint256 i = 0; i < _rewards.length; i++) {
            _sellRewards(_rewards[i].token);
        }
    }

    /// @notice Manual call to sell rewards incase there are some that aren't captured
    /// @param _token token to sell
    function manualRedirect(address _token) external onlyAuthorized {
        require(_token != address(targetToken));
        _sellRewards(_token);
    }

    /// @notice swaps rewards depending on whether the token is oxd or not.
    /// @param _token token to swaps
    function _sellRewards(address _token) internal {
        if (_token == oxd) {
            _convert0xd();
        } else {
            _swapTokenToTargetUniV2(_token);
        }
    }

    /// @notice swaps any oxd in this contract into the targetToken
    function _convert0xd() internal {
        uint256 swapAmount = IERC20(oxd).balanceOf(address(this));
        solidlyRouter.swapExactTokensForTokensSimple(
            swapAmount,
            uint256(0),
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

    /// @notice swaps any _token in this contract into the targetToken
    /// @param _token ERC20 token to be swapped into targetToken
    function _swapTokenToTargetUniV2(address _token) internal {
        IERC20 rewardToken = IERC20(_token);
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
                _getTokenOutPath(_token, address(targetToken), weth),
                address(this),
                block.timestamp
            );
        }
    }

    /// @notice This must be called by the Redirect Vault anytime a user deposits
    /// @dev This will disperse any pending rewards and update the user accounting varaibles
    /// @param _user address of the user depositing
    /// @param _beforeBalance the balance of the user before depositing. Measured in the vault.token()
    function onDeposit(address _user, uint256 _beforeBalance)
        external
        onlyVault
    {
        uint256 rewards = getUserRewards(_user);

        if (rewards > 0) {
            // claims all rewards
            _disburseRewards(_user, rewards);
        }

        /// @dev a caviat of the account approach is that anytime a user deposits the are withdrawing
        /// their claim in the current epoch. This is necessary to ensure the rewards accounting is sound.
        if (userInfo[_user].epochStart < epoch) {
            _updateEligibleEpochRewards(_beforeBalance);
        }

        // To prevent users leaching i.e. deposit just before epoch rewards distributed user will start to be eligible for rewards following epoch
        _updateUserInfo(_user, epoch + 1);
    }

    /// @notice This must be called by the Redirect Vault anytime a user withdraws
    /// @dev This will disperse any pending rewards and update the user accounting varaibles
    /// @param _user address of the user depositing
    /// @param _amount the amount the user withdrew
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

    function onEmergencyWithdraw(address _user, uint256 _amount)
        external
        onlyVault
    {
        // here we just make sure they don't continue earning rewards in future epochs
        _updateUserInfo(_user, epoch);
    }

    /// @notice users call this to claim their pending rewards. They will be redeemed in targetToken or targetVault
    function harvest() public nonReentrant {
        address user = msg.sender;
        uint256 rewards = getUserRewards(user);
        require(rewards > 0, "user must have balance to claim");
        _disburseRewards(user, rewards);
        /// updates reward information so user rewards start from current EPOCH
        _updateUserInfo(user, epoch);
        emit UserHarvested(user, rewards, address(tokenOut));
    }

    /// @notice transfers the _rewards to the _user and updates their reward balance
    /// @param _rewards amount of the tokenOut needs to be sent to the user
    /// @param _user the user calling harvest()
    function _disburseRewards(address _user, uint256 _rewards) internal {
        tokenOut.transfer(_user, _rewards);
        _updateAmountClaimed(_user, _rewards);
    }

    /// @notice returns the sum of a users pending rewards in the tokenOut units
    /// @param _user the user calling harvest()
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
                    userEpochRewards = userEpochRewards
                        .mul(emergencyTargetOut)
                        .div(emergencyVaultBalance);
                }
                rewards = rewards.add(userEpochRewards);
            }
        }
        return (rewards);
    }

    /// @notice helper function to calculate a users reward for a give epoch
    /// @param _epoch epoch number to calculate the rewards for
    /// @param _amt the users vault.token() balance for that epoch
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

    /// @notice Updates the total amount claimed by a user
    /// @param _user user address
    /// @param _rewardsPaid amount the totalClaimed amount needs to be incremented by for _user
    function _updateAmountClaimed(address _user, uint256 _rewardsPaid)
        internal
    {
        totalClaimed[_user] = totalClaimed[_user] + _rewardsPaid;
    }

    /// @notice updates the eligible rewards for this epoch
    /// @dev eligibleEpochRewards = token.balanceOf(vault) - SUM{ Balance of users deposited this epoch (and have remained in the vault) }
    /// @param _amount amount the user deposited
    function _updateEligibleEpochRewards(uint256 _amount) internal {
        eligibleEpochRewards = eligibleEpochRewards.sub(_amount);
    }

    /// @notice update the userInfo state for a user. This is uses to maintain accounting for the users rewards
    /// @param _user user address
    /// @param _epoch epoch the user joined the accounting records
    function _updateUserInfo(address _user, uint256 _epoch) internal {
        userInfo[_user] = UserInfo(
            IRedirectVault(redirectVault).balanceOf(_user),
            _epoch,
            block.timestamp
        );
    }

    /// @notice Increments the epoch by 1
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

        emit EpochProcessed(epoch, amountOut, eligibleEpochRewards);
    }

    /// @notice deposits targetToken into the targetVault if a vault is configured and enabled
    function _deposit() internal {
        if (useTargetVault) {
            uint256 bal = targetToken.balanceOf(address(this));
            IVault(address(targetVault)).deposit(bal);
        }
    }

    /// @notice helper function to get the univ2 token path
    /// @param _token_in input token (token being swapped)
    /// @param _token_out out token (desired token)
    /// @param _weth wftm
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

    /// @notice approves the router to transfer _token
    /// @param _token token to be approved
    function permitRewardToken(address _token) external onlyAuthorized {
        IERC20(_token).safeApprove(router, type(uint256).max);
    }

    /// @notice revokes the routers approval to transfer _token
    /// @param _token token to be revoked
    function unpermitRewardToken(address _token) external onlyAuthorized {
        IERC20(_token).safeApprove(router, 0);
    }

    /// @notice emergancy function to recover funds from the contract. Worst-case scenario.
    /// **** RUG RISK ****
    /// governance must be a trusted party!!!
    /// @dev todo - remove this function in future releases once there is more confidence in RewardDistributor
    /// @param _token token to be revoked
    function emergencySweep(address _token, address _to)
        external
        onlyGovernance
    {
        uint256 balance = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transfer(_to, balance);
    }
}
