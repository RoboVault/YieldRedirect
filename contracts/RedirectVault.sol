// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./interfaces/IStrategy.sol";
import "./types/MultiRewards.sol";
import "./Authorized.sol";
import { IRewardDistributor, RewardDistributor } from "./RewardDistributor.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @dev Implementation of a vault to deposit funds for yield optimizing.
 * This is the contract that receives funds and that users interface with.
 * The yield optimizing strategy itself is implemented in a separate 'Strategy.sol' contract.
 */
contract RedirectVault is ERC20, Authorized, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address public strategy;
    IRewardDistributor public distributor;

    uint256 public depositFee;
    uint256 public constant PERCENT_DIVISOR = 10000;
    uint256 public tvlCap;

    /**
     * @dev The stretegy's initialization status.
     */
    bool public initialized = false;

    // The token the vault accepts and looks to maximize.
    IERC20 public token;

    /**
     * @dev simple mappings used to determine PnL denominated in LP tokens,
     * as well as keep a generalized history of a user's protocol usage.
     */
    mapping(address => uint256) public cumulativeDeposits;
    mapping(address => uint256) public cumulativeWithdrawals;

    event TvlCapUpdated(uint256 newTvlCap);

    event DepositsIncremented(address user, uint256 amount, uint256 total);
    event WithdrawalsIncremented(address user, uint256 amount, uint256 total);
    event RewardsClaimed(MultiRewards[] rewards);

    /**
     * @dev Sets the value of {token} to the token that the vault will
     * hold as underlying value. It initializes the vault's own 'moo' token.
     * This token is minted when someone does a deposit. It is burned in order
     * to withdraw the corresponding portion of the underlying assets.
     * @param _token the token to maximize.
     * @param _name the name of the vault token.
     * @param _symbol the symbol of the vault token.
     * @param _depositFee one-time fee taken from deposits to this vault (in basis points)
     * @param _tvlCap initial deposit cap for scaling TVL safely
     */
    constructor(
        address _token,
        string memory _name,
        string memory _symbol,
        uint256 _depositFee,
        uint256 _tvlCap,
        address _router,
        address _targetToken,
        address _targetVault
    ) ERC20(string(_name), string(_symbol)) {
        token = IERC20(_token);
        depositFee = _depositFee;
        tvlCap = _tvlCap;
        distributor = new RewardDistributor(
            address(this),
            _router,
            _targetToken,
            _targetVault
        );
    }

    /**
     * @dev Connects the vault to its initial strategy. One use only.
     * @param _strategy the vault's initial strategy
     */

    function initialize(address _strategy) public onlyGovernance returns (bool) {
        require(!initialized, "Contract is already initialized.");
        strategy = _strategy;
        initialized = true;
        return true;
    }

    /**
     * @dev It calculates the total underlying value of {token} held by the system.
     * It takes into account the vault contract balance, the strategy contract balance
     *  and the balance deployed in other contracts as part of the strategy.
     */
    function balance() public view returns (uint256) {
        return
            token.balanceOf(address(this)).add(IStrategy(strategy).balanceOf());
    }

    /**
     * @dev Custom logic in here for how much the vault allows to be borrowed.
     * We return 100% of tokens for now. Under certain conditions we might
     * want to keep some of the system funds at hand in the vault, instead
     * of putting them to work.
     */
    function available() public view returns (uint256) {
        return token.balanceOf(address(this));
    }

    /**
     * @dev Function for various UIs to display the current value of one of our yield tokens.
     * Returns an uint256 with 18 decimals of how much underlying asset one vault share represents.
     */
    function getPricePerFullShare() public view returns (uint256) {
        return
            totalSupply() == 0 ? 1e18 : balance().mul(1e18).div(totalSupply());
    }

    /**
     * @dev A helper function to call deposit() with all the sender's funds.
     */
    function depositAll() external {
        deposit(token.balanceOf(msg.sender));
    }

    /**
     * @dev The entrypoint of funds into the system. People deposit with this function
     * into the vault. The vault is then in charge of sending funds into the strategy.
     * @notice the _before and _after variables are used to account properly for
     * 'burn-on-transaction' tokens.
     * @notice to ensure 'owner' can't sneak an implementation past the timelock,
     * it's set to true
     */
    function deposit(uint256 _amount) public nonReentrant {
        require(_amount != 0, "please provide amount");
        uint256 _pool = balance();
        require(_pool.add(_amount) <= tvlCap, "vault is full!");

        uint256 _before = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 _after = token.balanceOf(address(this));
        _amount = _after.sub(_before);
        uint256 _amountAfterDeposit = (
            _amount.mul(PERCENT_DIVISOR.sub(depositFee))
        ).div(PERCENT_DIVISOR);
        uint256 shares = 0;
        if (totalSupply() == 0) {
            shares = _amountAfterDeposit;
        } else {
            shares = (_amountAfterDeposit.mul(totalSupply())).div(_pool);
        }
        _mint(msg.sender, shares);
        IRewardDistributor(distributor).onDeposit(msg.sender, _before);
        earn();
        incrementDeposits(_amount);
    }

    /**
     * @dev Function to send funds into the strategy and put them to work. It's primarily called
     * by the vault's deposit() function.
     */
    function earn() public {
        uint256 _bal = available();
        token.safeTransfer(strategy, _bal);
        IStrategy(strategy).deposit();
    }

    /**
     * @dev A helper function to call withdraw() with all the sender's funds.
     */
    function withdrawAll() external {
        withdraw(balanceOf(msg.sender));
    }

    /**
     * @dev Function to exit the system. The vault will withdraw the required tokens
     * from the strategy and pay up the token holder. A proportional number of IOU
     * tokens are burned in the process.
     */
    function withdraw(uint256 _shares) public nonReentrant {
        require(_shares > 0, "please provide amount");
        uint256 r = (balance().mul(_shares)).div(totalSupply());
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
        IRewardDistributor(distributor).onWithdraw(msg.sender, _shares);
        incrementWithdrawals(r);
    }

    function updateDepositFee(uint256 fee) public onlyAuthorized {
        depositFee = fee;
    }

    /**
     * @dev pass in max value of uint to effectively remove TVL cap
     */
    function updateTvlCap(uint256 _newTvlCap) public onlyAuthorized {
        tvlCap = _newTvlCap;
        emit TvlCapUpdated(tvlCap);
    }

    /**
     * @dev helper function to remove TVL cap
     */
    function removeTvlCap() external onlyAuthorized {
        updateTvlCap(type(uint256).max);
    }


    /** 
     *
     */
    function harvestTrigger() public returns (bool) {
        return IRewardDistributor(distributor).isEpochFinished();
    }


    /** 
     *
     */
    function harvest() public onlyAuthorized {
        // Must wait for the epoch to complete before harvesting
        require (distributor.isEpochFinished(), "Epoch not finished");

        MultiRewards[] memory rewards = IStrategy(strategy).claim();

        // Test the strategy is being honest
        for (uint i = 0; i < rewards.length; i++) {
            uint256 rewardBalance = IERC20(rewards[i].token).balanceOf(address(this));
            require (rewardBalance >= rewards[i].amount, "Dishonest Strategy");
        }
        emit RewardsClaimed(rewards);

        // Send rewards to reward distributor
        for (uint i = 0; i < rewards.length; i++) {
            uint256 rewardBalance = IERC20(rewards[i].token).balanceOf(address(this));
            IERC20(rewards[i].token).safeTransfer(address(distributor), rewardBalance);
        }
        
        // send profit to reward distributor
        distributor.processEpoch(rewards);
    }


    /*
     * @dev functions to increase user's cumulative deposits and withdrawals
     * @param _amount number of LP tokens being deposited/withdrawn
     */
    function incrementDeposits(uint256 _amount) internal returns (bool) {
        uint256 initial = cumulativeDeposits[tx.origin];
        uint256 newTotal = initial + _amount;
        cumulativeDeposits[tx.origin] = newTotal;
        emit DepositsIncremented(tx.origin, _amount, newTotal);
        return true;
    }

    function incrementWithdrawals(uint256 _amount) internal returns (bool) {
        uint256 initial = cumulativeWithdrawals[tx.origin];
        uint256 newTotal = initial + _amount;
        cumulativeWithdrawals[tx.origin] = newTotal;
        emit WithdrawalsIncremented(tx.origin, _amount, newTotal);
        return true;
    }

    /**
     * @dev Rescues random funds stuck that the strat can't handle.
     * @param _token address of the token to rescue.
     */
    function inCaseTokensGetStuck(address _token) external onlyGovernance {
        require(_token != address(token), "!token");

        uint256 amount = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(msg.sender, amount);
    }
}