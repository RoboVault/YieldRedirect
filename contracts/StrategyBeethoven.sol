// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./StrategyAuthorized.sol";
import "./interfaces/uniswap.sol";
import "./interfaces/IRedirectVault.sol";
import "./interfaces/IStrategy.sol";
import {MultiRewards} from "./types/MultiRewards.sol";

interface IMasterChef {
    function poolLength() external view returns (uint256);

    function getMultiplier(uint256 _from, uint256 _to)
        external
        view
        returns (uint256);

    function pendingSpirit(uint256 _pid, address _user)
        external
        view
        returns (uint256);

    function massUpdatePools() external;

    function updatePool(uint256 _pid) external;

    function deposit(uint256 _pid, uint256 _amount) external;

    function withdraw(uint256 _pid, uint256 _amount) external;

    function userInfo(uint256 _pid, address _user)
        external
        view
        returns (uint256, uint256);

    function emergencyWithdraw(uint256 _pid, address _to) external;
}

interface IMasterChefv2 {
    function harvest(uint256 pid, address to) external;

    function withdrawAndHarvest(
        uint256 pid,
        uint256 amount,
        address to
    ) external;

    function emergencyWithdraw(uint256 _pid, address _to) external;

    function deposit(
        uint256 pid,
        uint256 amount,
        address to
    ) external;

    function lpTokens(uint256 pid) external view returns (address);
}

/**
 * @dev Implementation of a strategy to get yields from farming LP Pools in SpookySwap.
 * SpookySwap is an automated market maker (“AMM”) that allows two tokens to be exchanged on Fantom's Opera Network.
 *
 * This strategy deposits whatever funds it receives from the vault into the selected masterChef pool.
 * rewards from providing liquidity are farmed every few minutes, sold and split 50/50.
 * The corresponding pair of assets are bought and more liquidity is added to the masterChef pool.
 *
 * Expect the amount of LP tokens you have to grow over time while you have assets deposit
 */
contract StrategyBeethoven is IStrategy, StrategyAuthorized, Pausable {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    /**
     * @dev Tokens Used:
     * {wftm} - Required for liquidity routing when doing swaps.
     * {rewardToken} - Token generated by staking our funds.
     * {lpPair} - LP Token that the strategy maximizes.
     * {lpToken0, lpToken1} - Tokens that the strategy maximizes. IUniswapV2Pair tokens.
     */
    address public wftm = address(0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83);
    address public rewardToken0 =
        address(0xF24Bcf4d1e507740041C9cFd2DddB29585aDCe1e); //Beets
    address public rewardToken1;
    uint8 public rewardTokens = 1;
    address public lpPair;
    address public lpToken0;
    address public lpToken1;

    mapping(uint8 => bool) public isEmitting;
    mapping(address => address) tokenRouter;

    /**
     * @dev Third Party Contracts:
     * {router} - the router for target DEX
     * {masterChef} - masterChef contract
     * {poolId} - masterChef pool id
     */
    address public constant spookyRouter =
        address(0xF491e7B69E4244ad4002BC14e878a34207E38c29);
    address public constant spiritRouter =
        address(0x16327E3FbDaCA3bcF7E38F5Af2599D2DDc33aE52);
    address public masterChef = 0x8166994d9ebBe5829EC86Bd81258149B87faCfd3;
    uint8 public poolId;

    /**
     * @dev Associated Contracts:
     * {vault} - Address of the vault that controls the strategy's funds.
     */
    address public vault;

    /**
     * @dev Distribution of fees earned. This allocations relative to the % implemented on
     * Current implementation separates 5% for fees. Can be changed through the constructor
     * Inputs in constructor should be ratios between the Fee and Max Fee, divisble into percents by 10000
     *
     * {callFee} - Percent of the totalFee reserved for the harvester (1000 = 10% of total fee: 0.5% by default)
     * {treasuryFee} - Percent of the totalFee taken by maintainers of the software (9000 = 90% of total fee: 4.5% by default)
     * {securityFee} - Fee taxed when a user withdraws funds. Taken to prevent flash deposit/harvest attacks.
     * These funds are redistributed to stakers in the pool.
     *
     * {totalFee} - divided by 10,000 to determine the % fee. Set to 5% by default and
     * lowered as necessary to provide users with the most competitive APY.
     *
     * {MAX_FEE} - Maximum fee allowed by the strategy. Hard-capped at 5%.
     * {PERCENT_DIVISOR} - Constant used to safely calculate the correct percentages.
     */
    // uint public callFee = 1000;
    // uint public treasuryFee = 9000;
    // uint public securityFee = 10;
    // uint public totalFee = 450;
    // uint constant public MAX_FEE = 500;
    uint256 public constant PERCENT_DIVISOR = 10000;

    /**
     * @dev Routes we take to swap tokens using PanrewardTokenSwap.
     * {rewardTokenToWftmRoute} - Route we take to get from {rewardToken} into {wftm}.
     * {rewardTokenToLp0Route} - Route we take to get from {rewardToken} into {lpToken0}.
     * {rewardTokenToLp1Route} - Route we take to get from {rewardToken} into {lpToken1}.
     */
    address[] public rewardToken0ToWftmRoute = [rewardToken0, wftm];
    address[] public rewardToken1ToWftmRoute = [rewardToken1, wftm];
    address[] public wftmToLp0Route;
    address[] public wftmToLp1Route;

    /**
     * {StratHarvest} Event that is fired each time someone harvests the strat.
     * {TotalFeeUpdated} Event that is fired each time the total fee is updated.
     * {CallFeeUpdated} Event that is fired each time the call fee is updated.
     */
    event TotalFeeUpdated(uint256 newFee);
    event CallFeeUpdated(uint256 newCallFee, uint256 newTreasuryFee);

    /**
     * @dev Initializes the strategy. Sets parameters, saves routes, and gives allowances.
     * @notice see documentation for each variable above its respective declaration.
     */
    constructor(
        address _vault,
        address _lpPair,
        uint8 _poolId
    ) {
        // Check the _poolId matches the _lpPair
        require(
            IMasterChefv2(masterChef).lpTokens(_poolId) == _lpPair,
            "PID LP Token missmatch"
        );

        lpPair = _lpPair;
        poolId = _poolId;
        vault = _vault;

        tokenRouter[lpToken0] = spookyRouter;
        tokenRouter[lpToken1] = spookyRouter;
        tokenRouter[rewardToken0] = spookyRouter;

        isEmitting[0] = true;
        isEmitting[1] = false;

        giveAllowances();
    }

    modifier onlyVault() {
        require(vault == _msgSender(), "!vault");
        _;
    }

    function governance() public view override returns (address) {
        return IRedirectVault(vault).governance();
    }

    /**
     * @dev Function that puts the funds to work.
     * It gets called whenever someone deposits in the strategy's vault contract.
     * It deposits {lpPair} in the masterChef to farm {rewardToken}
     */
    function deposit() public whenNotPaused {
        uint256 pairBal = IERC20(lpPair).balanceOf(address(this));

        if (pairBal > 0) {
            IMasterChefv2(masterChef).deposit(poolId, pairBal, address(this));
        }
    }

    /**
     * @dev Withdraws funds and sents them back to the vault.
     * It withdraws {lpPair} from the masterChef.
     * The available {lpPair} minus fees is returned to the vault.
     */
    function withdraw(uint256 _amount) external onlyVault {
        uint256 pairBal = IERC20(lpPair).balanceOf(address(this));

        if (pairBal < _amount) {
            IMasterChefv2(masterChef).withdrawAndHarvest(
                poolId,
                _amount.sub(pairBal),
                address(this)
            );
            pairBal = IERC20(lpPair).balanceOf(address(this));
        }

        if (pairBal > _amount) {
            pairBal = _amount;
        }
        IERC20(lpPair).safeTransfer(vault, pairBal);
    }

    /**
     * @dev Core function of the strat, in charge of collecting and re-investing rewards.
     * 1. It claims rewards from the masterChef.
     * 2. It charges the system fees to simplify the split.
     * 3. It swaps the {rewardToken} token for {lpToken0} & {lpToken1}
     * 4. Adds more liquidity to the pool.
     * 5. It deposits the new LP tokens.
     */
    function claim(address to)
        external
        onlyVault
        whenNotPaused
        returns (MultiRewards[] memory _rewards)
    {
        // require(!Address.isContract(msg.sender), "!contract");
        IMasterChefv2(masterChef).harvest(poolId, address(this));

        uint256 balanceReward0 = IERC20(rewardToken0).balanceOf(address(this));
        if (balanceReward0 > 0) {
            IERC20(rewardToken0).transfer(to, balanceReward0);
        }
        _rewards = new MultiRewards[](1);
        _rewards[0] = MultiRewards(rewardToken0, balanceReward0);

        // TODO - Support multiple reward tokens
    }

    /**
     * @dev Function to calculate the total underlaying {lpPair} held by the strat.
     * It takes into account both the funds in hand, as the funds allocated in the masterChef.
     */
    function balanceOf() public view returns (uint256) {
        return balanceOfLpPair().add(balanceOfPool());
    }

    /**
     * @dev It calculates how much {lpPair} the contract holds.
     */
    function balanceOfLpPair() public view returns (uint256) {
        return IERC20(lpPair).balanceOf(address(this));
    }

    /**
     * @dev It calculates how much {lpPair} the strategy has allocated in the masterChef
     */
    function balanceOfPool() public view returns (uint256) {
        (uint256 _amount, ) = IMasterChef(masterChef).userInfo(
            poolId,
            address(this)
        );
        return _amount;
    }

    /**
     * @dev Function that has to be called as part of strat migration. It sends all the available funds back to the
     * vault, ready to be migrated to the new strat.
     */
    function retireStrat() external onlyVault {
        uint256 pooledBalance = balanceOfPool();

        if (pooledBalance > 0){
            IMasterChefv2(masterChef).withdrawAndHarvest(
                poolId,
                pooledBalance,
                address(this)
            );
        }

        uint256 pairBal = IERC20(lpPair).balanceOf(address(this));
        if (pairBal > 0 ){
            IERC20(lpPair).transfer(vault, pairBal);
        }
    }

    function emergencyWithdraw() external onlyAuthorized {
        IMasterChefv2(masterChef).emergencyWithdraw(poolId, address(this));
    } 


    /**
     * @dev Pauses deposits. Withdraws all funds from the masterChef, leaving rewards behind
     */
    function panic() public onlyAuthorized {
        pause();
        IMasterChefv2(masterChef).withdrawAndHarvest(poolId, balanceOfPool(), address(this));
    }

    /**
     * @dev Pauses the strat.
     */
    function pause() public onlyAuthorized {
        _pause();
        removeAllowances();
    }

    /**
     * @dev Unpauses the strat.
     */
    function unpause() external onlyAuthorized {
        _unpause();

        giveAllowances();

        deposit();
    }

    function giveAllowances() internal {
        IERC20(lpPair).safeApprove(masterChef, type(uint256).max);
        IERC20(rewardToken0).safeApprove(spookyRouter, type(uint256).max);
        IERC20(wftm).safeApprove(spookyRouter, type(uint256).max);

    }

    function removeAllowances() internal {
        IERC20(lpPair).safeApprove(masterChef, 0);
        IERC20(rewardToken0).safeApprove(spookyRouter, 0);
        IERC20(wftm).safeApprove(spookyRouter, 0);
    }

    function emittance(uint8 _id, bool _status)
        external
        onlyAuthorized
        returns (bool)
    {
        isEmitting[_id] = _status;
        return true;
    }

    function addRewardToken(address _token, address _router)
        external
        onlyAuthorized
        returns (bool)
    {
        rewardToken1 = _token;
        tokenRouter[rewardToken1] = _router;
        IERC20(rewardToken1).safeApprove(
            tokenRouter[rewardToken1],
            type(uint256).max
        );
        rewardToken1ToWftmRoute = [rewardToken1, wftm];
        isEmitting[1] = true;
        rewardTokens = 2;
        return true;
    }
}