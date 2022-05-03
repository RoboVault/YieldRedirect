// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./interfaces/IStrategy.sol";
import "./types/MultiRewards.sol";
import "./ERC20NoTransfer.sol";
import "./Authorized.sol";
import {IRewardDistributor, RewardDistributor} from "./RewardDistributor.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/// @notice Implementation of a vault to deposit funds for yield optimizing.
/// This is the contract that receives funds and that users interface with.
/// The yield optimizing strategy itself is implemented in a separate 'Strategy.sol' contract.
contract RedirectVault is ERC20NoTransfer, Authorized, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    struct StratCandidate {
        address implementation;
        uint256 proposedTime;
    }

    /*///////////////////////////////////////////////////////////////
                            IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Percentage scalar
    uint256 public constant PERCENT_DIVISOR = 10000;

    /// @notice The token the vault accepts and looks to maximize.
    IERC20 public token;

    /// @notice Timelock delay needed for a new strategy to be accepted (seconds)
    uint256 public immutable approvalDelay;

    /// @notice The reward distributor contract. All rewards are sent to this contract
    /// and users interact with it to harvest their rewards
    IRewardDistributor public distributor;

    /// @notice Underlying target token, eg USDC. This is what the rewards will be converted to,
    /// afterwhich the rewards may be deposited to a vault if one is configured
    address public immutable targetToken;

    /// @notice the target vault for pending rewards to be deposited into.
    address public immutable targetVault;

    /*///////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The last proposed strategy to switch to.
    StratCandidate public stratCandidate;

    /// @notice The active strategy
    address public strategy;

    /// @notice TVL limit for the vault
    uint256 public tvlCap;

    /// @notice The stretegy's initialization status.
    bool public initialized = false;

    /// @notice simple mappings used to determine PnL denominated in LP tokens,
    /// as well as keep a generalized history of a user's protocol usage.
    mapping(address => uint256) public cumulativeDeposits;
    mapping(address => uint256) public cumulativeWithdrawals;

    /*///////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event TvlCapUpdated(uint256 newTvlCap);
    event NewStratCandidate(address implementation);
    event UpgradeStrat(address implementation);
    event DepositsIncremented(address user, uint256 amount, uint256 total);
    event WithdrawalsIncremented(address user, uint256 amount, uint256 total);
    event RewardsClaimed(address distributor, MultiRewards[] rewards);

    /// @notice Sets the value of {token} to the token that the vault will
    /// hold as underlying value. It initializes the vault's own 'moo' token.
    /// This token is minted when someone does a deposit. It is burned in order
    /// to withdraw the corresponding portion of the underlying assets.
    /// @param _token the token to maximize.
    /// @param _name the name of the vault token.
    /// @param _symbol the symbol of the vault token.
    /// @param _tvlCap initial deposit cap for scaling TVL safely
    /// @param _targetToken Target token - eg USDC
    /// @param _targetVault Target vault - wg yvUSDC. Set this to the zero address if no vault is needed
    /// @param _approvalDelay new strategy timelock period in seconds
    constructor(
        address _token,
        string memory _name,
        string memory _symbol,
        uint256 _tvlCap,
        address _targetToken,
        address _targetVault,
        uint256 _approvalDelay
    ) ERC20NoTransfer(string(_name), string(_symbol)) {
        token = IERC20(_token);
        tvlCap = _tvlCap;
        approvalDelay = _approvalDelay;
        targetToken = _targetToken;
        targetVault = _targetVault;
    }

    /// @notice Connects the vault to its initial strategy. One use only.
    /// @param _strategy the vault's initial strategy
    function initialize(address _strategy, address _distributor)
        public
        onlyGovernance
        returns (bool)
    {
        require(!initialized, "Contract is already initialized.");
        distributor = IRewardDistributor(_distributor);
        require(distributor.redirectVault() == address(this), "!vault");
        strategy = _strategy;
        initialized = true;
        return true;
    }

    /// @notice It calculates the total underlying value of {token} held by the system.
    /// It takes into account the vault contract balance, the strategy contract balance
    ///  and the balance deployed in other contracts as part of the strategy.
    function totalBalance() public view returns (uint256) {
        return
            token.balanceOf(address(this)).add(IStrategy(strategy).balanceOf());
    }

    /// @notice Returns the version string
    function version() public view returns (string memory) {
        return "V0.2";
    }

    /// @notice Custom logic in here for how much the vault allows to be borrowed.
    /// We return 100% of tokens for now. Under certain conditions we might
    /// want to keep some of the system funds at hand in the vault, instead
    /// of putting them to work.
    function available() public view returns (uint256) {
        return token.balanceOf(address(this));
    }

    /// @notice Function for various UIs to display the current value of one of our yield tokens.
    /// Returns an uint256 with 18 decimals of how much underlying asset one vault share represents.
    function getPricePerFullShare() public view returns (uint256) {
        return
            totalSupply() == 0
                ? 1e18
                : totalBalance().mul(1e18).div(totalSupply());
    }

    /// @notice Function for various UIs to display the current value of one of our yield tokens.
    /// Returns an uint256 with 18 decimals of how much underlying asset one vault share represents.
    function totalAssets() public view returns (uint256) {
        return
            totalSupply() == 0
                ? 1e18
                : totalBalance().mul(1e18).div(totalSupply());
    }

    /// @notice A helper function to call deposit() with all the sender's funds.
    function depositAll() external {
        deposit(token.balanceOf(msg.sender));
    }

    /// @notice The entrypoint of funds into the system. People deposit with this function
    /// into the vault. The vault is then in charge of sending funds into the strategy.
    /// @notice the _before and _after variables are used to account properly for
    /// 'burn-on-transaction' tokens.
    function deposit(uint256 _amount) public nonReentrant {
        require(_amount != 0, "please provide amount");
        uint256 _pool = totalBalance();
        require(_pool.add(_amount) <= tvlCap, "vault is full!");
        uint256 _sharesBefore = balanceOf(msg.sender);

        uint256 _before = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 _after = token.balanceOf(address(this));
        _amount = _after.sub(_before);
        uint256 shares = 0;
        if (totalSupply() == 0) {
            shares = _amount;
        } else {
            shares = (_amount.mul(totalSupply())).div(_pool);
        }
        _mint(msg.sender, shares);
        distributor.onDeposit(msg.sender, _sharesBefore);
        earn();
        incrementDeposits(_amount);
    }

    /// @notice Function to send funds into the strategy and put them to work. It's primarily called
    /// by the vault's deposit() function.
    /// TODO - Can this be internal, why is it public? What's the benefit
    function earn() public {
        uint256 _bal = available();
        token.safeTransfer(strategy, _bal);
        IStrategy(strategy).deposit();
    }

    /// @notice A helper function to call withdraw() with all the sender's funds.
    function withdrawAll() external {
        withdraw(balanceOf(msg.sender));
    }

    /// @notice Function to exit the system. The vault will withdraw the required tokens
    /// from the strategy and pay up the token holder. A proportional number of IOU
    /// tokens are burned in the process.
    function withdraw(uint256 _shares) public nonReentrant {
        require(_shares > 0, "please provide amount");
        uint256 r = (totalBalance().mul(_shares)).div(totalSupply());
        _burn(msg.sender, _shares);

        uint256 b = token.balanceOf(address(this));
        if (b < r) {
            uint256 _withdraw = r.sub(b);
            IStrategy(strategy).withdraw(_withdraw);
            uint256 _after = token.balanceOf(address(this));
            uint256 _diff = _after.sub(b);
            if (_diff < _withdraw) {
                r = b.add(_diff);
            }
        }
        token.safeTransfer(msg.sender, r);
        distributor.onWithdraw(msg.sender, _shares);
        incrementWithdrawals(r);
    }

    /// @notice Emergency function to withdraw a users funds and
    /// discard their rewards. This should only be called if there
    /// is an issue with the Reward Distributor contract
    function emergencyWithdrawAll() public nonReentrant {
        uint256 _shares = balanceOf(msg.sender);
        require(_shares > 0, "please provide amount");
        uint256 r = (totalBalance().mul(_shares)).div(totalSupply());
        _burn(msg.sender, _shares);

        uint256 b = token.balanceOf(address(this));
        if (b < r) {
            uint256 _withdraw = r.sub(b);
            IStrategy(strategy).withdraw(_withdraw);
            uint256 _after = token.balanceOf(address(this));
            uint256 _diff = _after.sub(b);
            if (_diff < _withdraw) {
                r = b.add(_diff);
            }
        }
        token.safeTransfer(msg.sender, r);
        distributor.onEmergencyWithdraw(msg.sender, _shares);
        incrementWithdrawals(r);
    }

    /// @notice pass in max value of uint to effectively remove TVL cap
    function updateTvlCap(uint256 _newTvlCap) public onlyAuthorized {
        tvlCap = _newTvlCap;
        emit TvlCapUpdated(tvlCap);
    }

    /// @notice Helper function to remove TVL cap
    function removeTvlCap() external onlyAuthorized {
        updateTvlCap(type(uint256).max);
    }

    /// @notice Returns true if an epoch is complete harvest can be called
    function harvestTrigger() public view returns (bool) {
        return distributor.isEpochFinished();
    }

    /// @notice Harvests rewards and send them to the reward distributor
    function harvest() public onlyKeeper {
        /// @dev Must wait for the epoch to complete before harvesting
        require(distributor.isEpochFinished(), "Epoch not finished");

        MultiRewards[] memory rewards = IStrategy(strategy).claim(
            address(distributor)
        );

        // Test the strategy is being honest
        for (uint256 i = 0; i < rewards.length; i++) {
            uint256 rewardBalance = IERC20(rewards[i].token).balanceOf(
                address(distributor)
            );
            require(rewardBalance >= rewards[i].amount, "Dishonest Strategy");
        }
        emit RewardsClaimed(address(distributor), rewards);

        // send profit to reward distributor
        distributor.processEpoch(rewards);
    }

    /// @notice function to increase user's cumulative deposits
    /// @param _amount number of LP tokens being deposited/withdrawn
    function incrementDeposits(uint256 _amount) internal returns (bool) {
        uint256 initial = cumulativeDeposits[tx.origin];
        uint256 newTotal = initial + _amount;
        cumulativeDeposits[tx.origin] = newTotal;
        emit DepositsIncremented(tx.origin, _amount, newTotal);
        return true;
    }

    /// @notice function to increase user's cumulative withdrawals
    /// @param _amount number of LP tokens being deposited/withdrawn
    function incrementWithdrawals(uint256 _amount) internal returns (bool) {
        uint256 initial = cumulativeWithdrawals[tx.origin];
        uint256 newTotal = initial + _amount;
        cumulativeWithdrawals[tx.origin] = newTotal;
        emit WithdrawalsIncremented(tx.origin, _amount, newTotal);
        return true;
    }

    /// @notice Rescues random funds stuck that the strat can't handle.
    /// @param _token address of the token to rescue.
    function inCaseTokensGetStuck(address _token) external onlyGovernance {
        require(_token != address(token), "!token");

        uint256 amount = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(msg.sender, amount);
    }

    /// @notice Sets the candidate for the new strat to use with this vault.
    /// @param _implementation The address of the candidate strategy.
    function proposeStrat(address _implementation) external onlyGovernance {
        stratCandidate = StratCandidate({
            implementation: _implementation,
            proposedTime: block.timestamp
        });
        emit NewStratCandidate(_implementation);
    }

    /// @notice It switches the active strat for the strat candidate. After upgrading, the
    /// candidate implementation is set to the 0x00 address, and proposedTime to a time
    /// happening in +100 years for safety.
    function upgradeStrat() external onlyGovernance {
        require(
            stratCandidate.implementation != address(0),
            "There is no candidate"
        );
        require(
            stratCandidate.proposedTime.add(approvalDelay) < block.timestamp,
            "Delay has not passed"
        );

        emit UpgradeStrat(stratCandidate.implementation);

        IStrategy(strategy).retireStrat();

        // TODO - Add loss arg and check there hasn't been more than
        // "loss" lost when retiring the strat
        strategy = stratCandidate.implementation;
        stratCandidate.implementation = address(0);
        stratCandidate.proposedTime = 5000000000;

        earn();
    }
}
