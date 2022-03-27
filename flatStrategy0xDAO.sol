pragma experimental ABIEncoderV2;

// File: Address.sol

// OpenZeppelin Contracts (last updated v4.5.0) (utils/Address.sol)

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// File: Context.sol

// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// File: IERC20.sol

// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// File: IMultiRewards.sol

interface IMultiRewards {
    struct Reward {
        address rewardsDistributor;
        uint256 rewardsDuration;
        uint256 periodFinish;
        uint256 rewardRate;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
    }

    function stake(uint256) external;

    function withdraw(uint256) external;

    function getReward() external;

    function stakingToken() external view returns (address);

    function balanceOf(address) external view returns (uint256);

    function earned(address, address) external view returns (uint256);

    function initialize(address, address) external;

    function rewardRate(address) external view returns (uint256);

    function getRewardForDuration(address) external view returns (uint256);

    function rewardPerToken(address) external view returns (uint256);

    function rewardData(address) external view returns (Reward memory);

    function rewardTokensLength() external view returns (uint256);

    function rewardTokens(uint256) external view returns (address);

    function totalSupply() external view returns (uint256);

    function addReward(
        address _rewardsToken,
        address _rewardsDistributor,
        uint256 _rewardsDuration
    ) external;

    function notifyRewardAmount(address, uint256) external;

    function recoverERC20(address tokenAddress, uint256 tokenAmount) external;

    function setRewardsDuration(address _rewardsToken, uint256 _rewardsDuration)
        external;

    function exit() external;
}
// File: IOxLens.sol

interface IOxLens {
    function oxPoolBySolidPool(address solidPoolAddress)
        external
        view
        returns (address);
}
// File: IOxPool.sol

interface IOxPool {
    function stakingAddress() external view returns (address);

    function solidPoolAddress() external view returns (address);

    function depositLpAndStake(uint256) external;

    function depositLp(uint256) external;

    function withdrawLp(uint256) external;

    function syncBribeTokens() external;

    function notifyBribeOrFees() external;

    function initialize(
        address,
        address,
        address,
        string memory,
        string memory,
        address,
        address
    ) external;

    function gaugeAddress() external view returns (address);

    function balanceOf(address) external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);
}

// File: IRedirectVault.sol

interface IRedirectVault {
    function owner() external view returns (address);

    function isAuthorized(address _addr) external view returns (bool);

    function governance() external view returns (address);

    function totalSupply() external view returns (uint256);

    function balanceOf(address _account) external view returns (uint256);
}

// File: ISolidlyRouter01.sol

interface IBaseV1Pair {
    function metadata() external view returns (uint dec0, uint dec1, uint r0, uint r1, bool st, address t0, address t1);
    function transferFrom(address src, address dst, uint amount) external returns (bool);
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function burn(address to) external returns (uint amount0, uint amount1);
    function mint(address to) external returns (uint liquidity);
    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast);
    function getAmountOut(uint, address) external view returns (uint);
}

struct Route {
    address from;
    address to;
    bool stable;
}

interface ISolidlyRouter01 {

    function factory() external view returns (address);
    function wftm() external view returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function swapExactTokensForTokensSimple(
        uint amountIn,
        uint amountOutMin,
        address tokenFrom,
        address tokenTo,
        bool stable,
        address to,
        uint deadline
    ) external returns (uint[] calldata amounts);

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        Route[] calldata routes,
        address to,
        uint deadline
    ) external returns (uint[] calldata amounts);

    // function sortTokens(address tokenA, address tokenB) public pure returns (address token0, address token1) {
    //     require(tokenA != tokenB, 'BaseV1Router: IDENTICAL_ADDRESSES');
    //     (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    //     require(token0 != address(0), 'BaseV1Router: ZERO_ADDRESS');
    // }

    // // calculates the CREATE2 address for a pair without making any external calls
    // function pairFor(address tokenA, address tokenB, bool stable) public view returns (address pair) {
    //     (address token0, address token1) = sortTokens(tokenA, tokenB);
    //     pair = address(uint160(uint256(keccak256(abi.encodePacked(
    //         hex'ff',
    //         factory,
    //         keccak256(abi.encodePacked(token0, token1, stable)),
    //         pairCodeHash // init code hash
    //     )))));
    // }

    // // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    // function quoteLiquidity(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
    //     require(amountA > 0, 'BaseV1Router: INSUFFICIENT_AMOUNT');
    //     require(reserveA > 0 && reserveB > 0, 'BaseV1Router: INSUFFICIENT_LIQUIDITY');
    //     amountB = amountA * reserveB / reserveA;
    // }

    // // fetches and sorts the reserves for a pair
    // function getReserves(address tokenA, address tokenB, bool stable) public view returns (uint reserveA, uint reserveB) {
    //     (address token0,) = sortTokens(tokenA, tokenB);
    //     (uint reserve0, uint reserve1,) = IBaseV1Pair(pairFor(tokenA, tokenB, stable)).getReserves();
    //     (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    // }

    // // performs chained getAmountOut calculations on any number of pairs
    // function getAmountOut(uint amountIn, address tokenIn, address tokenOut) external view returns (uint amount, bool stable) {
    //     address pair = pairFor(tokenIn, tokenOut, true);
    //     uint amountStable;
    //     uint amountVolatile;
    //     if (IBaseV1Factory(factory).isPair(pair)) {
    //         amountStable = IBaseV1Pair(pair).getAmountOut(amountIn, tokenIn);
    //     }
    //     pair = pairFor(tokenIn, tokenOut, false);
    //     if (IBaseV1Factory(factory).isPair(pair)) {
    //         amountVolatile = IBaseV1Pair(pair).getAmountOut(amountIn, tokenIn);
    //     }
    //     return amountStable > amountVolatile ? (amountStable, true) : (amountVolatile, false);
    // }

    // // performs chained getAmountOut calculations on any number of pairs
    // function getAmountsOut(uint amountIn, route[] memory routes) public view returns (uint[] memory amounts) {
    //     require(routes.length >= 1, 'BaseV1Router: INVALID_PATH');
    //     amounts = new uint[](routes.length+1);
    //     amounts[0] = amountIn;
    //     for (uint i = 0; i < routes.length; i++) {
    //         address pair = pairFor(routes[i].from, routes[i].to, routes[i].stable);
    //         if (IBaseV1Factory(factory).isPair(pair)) {
    //             amounts[i+1] = IBaseV1Pair(pair).getAmountOut(amounts[i], routes[i].from);
    //         }
    //     }
    // }

    // function isPair(address pair) external view returns (bool) {
    //     return IBaseV1Factory(factory).isPair(pair);
    // }

    // function quoteAddLiquidity(
    //     address tokenA,
    //     address tokenB,
    //     bool stable,
    //     uint amountADesired,
    //     uint amountBDesired
    // ) external view returns (uint amountA, uint amountB, uint liquidity) {
    //     // create the pair if it doesn't exist yet
    //     address _pair = IBaseV1Factory(factory).getPair(tokenA, tokenB, stable);
    //     (uint reserveA, uint reserveB) = (0,0);
    //     uint _totalSupply = 0;
    //     if (_pair != address(0)) {
    //         _totalSupply = erc20(_pair).totalSupply();
    //         (reserveA, reserveB) = getReserves(tokenA, tokenB, stable);
    //     }
    //     if (reserveA == 0 && reserveB == 0) {
    //         (amountA, amountB) = (amountADesired, amountBDesired);
    //         liquidity = Math.sqrt(amountA * amountB) - MINIMUM_LIQUIDITY;
    //     } else {

    //         uint amountBOptimal = quoteLiquidity(amountADesired, reserveA, reserveB);
    //         if (amountBOptimal <= amountBDesired) {
    //             (amountA, amountB) = (amountADesired, amountBOptimal);
    //             liquidity = Math.min(amountA * _totalSupply / reserveA, amountB * _totalSupply / reserveB);
    //         } else {
    //             uint amountAOptimal = quoteLiquidity(amountBDesired, reserveB, reserveA);
    //             (amountA, amountB) = (amountAOptimal, amountBDesired);
    //             liquidity = Math.min(amountA * _totalSupply / reserveA, amountB * _totalSupply / reserveB);
    //         }
    //     }
    // }

    // function quoteRemoveLiquidity(
    //     address tokenA,
    //     address tokenB,
    //     bool stable,
    //     uint liquidity
    // ) external view returns (uint amountA, uint amountB) {
    //     // create the pair if it doesn't exist yet
    //     address _pair = IBaseV1Factory(factory).getPair(tokenA, tokenB, stable);

    //     if (_pair == address(0)) {
    //         return (0,0);
    //     }

    //     (uint reserveA, uint reserveB) = getReserves(tokenA, tokenB, stable);
    //     uint _totalSupply = erc20(_pair).totalSupply();

    //     amountA = liquidity * reserveA / _totalSupply; // using balances ensures pro-rata distribution
    //     amountB = liquidity * reserveB / _totalSupply; // using balances ensures pro-rata distribution

    // }

    // function _addLiquidity(
    //     address tokenA,
    //     address tokenB,
    //     bool stable,
    //     uint amountADesired,
    //     uint amountBDesired,
    //     uint amountAMin,
    //     uint amountBMin
    // ) internal returns (uint amountA, uint amountB) {
    //     require(amountADesired >= amountAMin);
    //     require(amountBDesired >= amountBMin);
    //     // create the pair if it doesn't exist yet
    //     address _pair = IBaseV1Factory(factory).getPair(tokenA, tokenB, stable);
    //     if (_pair == address(0)) {
    //         _pair = IBaseV1Factory(factory).createPair(tokenA, tokenB, stable);
    //     }
    //     (uint reserveA, uint reserveB) = getReserves(tokenA, tokenB, stable);
    //     if (reserveA == 0 && reserveB == 0) {
    //         (amountA, amountB) = (amountADesired, amountBDesired);
    //     } else {
    //         uint amountBOptimal = quoteLiquidity(amountADesired, reserveA, reserveB);
    //         if (amountBOptimal <= amountBDesired) {
    //             require(amountBOptimal >= amountBMin, 'BaseV1Router: INSUFFICIENT_B_AMOUNT');
    //             (amountA, amountB) = (amountADesired, amountBOptimal);
    //         } else {
    //             uint amountAOptimal = quoteLiquidity(amountBDesired, reserveB, reserveA);
    //             assert(amountAOptimal <= amountADesired);
    //             require(amountAOptimal >= amountAMin, 'BaseV1Router: INSUFFICIENT_A_AMOUNT');
    //             (amountA, amountB) = (amountAOptimal, amountBDesired);
    //         }
    //     }
    // }

    // function addLiquidity(
    //     address tokenA,
    //     address tokenB,
    //     bool stable,
    //     uint amountADesired,
    //     uint amountBDesired,
    //     uint amountAMin,
    //     uint amountBMin,
    //     address to,
    //     uint deadline
    // ) external ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
    //     (amountA, amountB) = _addLiquidity(tokenA, tokenB, stable, amountADesired, amountBDesired, amountAMin, amountBMin);
    //     address pair = pairFor(tokenA, tokenB, stable);
    //     _safeTransferFrom(tokenA, msg.sender, pair, amountA);
    //     _safeTransferFrom(tokenB, msg.sender, pair, amountB);
    //     liquidity = IBaseV1Pair(pair).mint(to);
    // }

    // function addLiquidityFTM(
    //     address token,
    //     bool stable,
    //     uint amountTokenDesired,
    //     uint amountTokenMin,
    //     uint amountFTMMin,
    //     address to,
    //     uint deadline
    // ) external payable ensure(deadline) returns (uint amountToken, uint amountFTM, uint liquidity) {
    //     (amountToken, amountFTM) = _addLiquidity(
    //         token,
    //         address(wftm),
    //         stable,
    //         amountTokenDesired,
    //         msg.value,
    //         amountTokenMin,
    //         amountFTMMin
    //     );
    //     address pair = pairFor(token, address(wftm), stable);
    //     _safeTransferFrom(token, msg.sender, pair, amountToken);
    //     wftm.deposit{value: amountFTM}();
    //     assert(wftm.transfer(pair, amountFTM));
    //     liquidity = IBaseV1Pair(pair).mint(to);
    //     // refund dust eth, if any
    //     if (msg.value > amountFTM) _safeTransferFTM(msg.sender, msg.value - amountFTM);
    // }

    // // **** REMOVE LIQUIDITY ****
    // function removeLiquidity(
    //     address tokenA,
    //     address tokenB,
    //     bool stable,
    //     uint liquidity,
    //     uint amountAMin,
    //     uint amountBMin,
    //     address to,
    //     uint deadline
    // ) public ensure(deadline) returns (uint amountA, uint amountB) {
    //     address pair = pairFor(tokenA, tokenB, stable);
    //     require(IBaseV1Pair(pair).transferFrom(msg.sender, pair, liquidity)); // send liquidity to pair
    //     (uint amount0, uint amount1) = IBaseV1Pair(pair).burn(to);
    //     (address token0,) = sortTokens(tokenA, tokenB);
    //     (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
    //     require(amountA >= amountAMin, 'BaseV1Router: INSUFFICIENT_A_AMOUNT');
    //     require(amountB >= amountBMin, 'BaseV1Router: INSUFFICIENT_B_AMOUNT');
    // }

    // function removeLiquidityFTM(
    //     address token,
    //     bool stable,
    //     uint liquidity,
    //     uint amountTokenMin,
    //     uint amountFTMMin,
    //     address to,
    //     uint deadline
    // ) public ensure(deadline) returns (uint amountToken, uint amountFTM) {
    //     (amountToken, amountFTM) = removeLiquidity(
    //         token,
    //         address(wftm),
    //         stable,
    //         liquidity,
    //         amountTokenMin,
    //         amountFTMMin,
    //         address(this),
    //         deadline
    //     );
    //     _safeTransfer(token, to, amountToken);
    //     wftm.withdraw(amountFTM);
    //     _safeTransferFTM(to, amountFTM);
    // }

    // function removeLiquidityWithPermit(
    //     address tokenA,
    //     address tokenB,
    //     bool stable,
    //     uint liquidity,
    //     uint amountAMin,
    //     uint amountBMin,
    //     address to,
    //     uint deadline,
    //     bool approveMax, uint8 v, bytes32 r, bytes32 s
    // ) external returns (uint amountA, uint amountB) {
    //     address pair = pairFor(tokenA, tokenB, stable);
    //     {
    //         uint value = approveMax ? type(uint).max : liquidity;
    //         IBaseV1Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
    //     }

    //     (amountA, amountB) = removeLiquidity(tokenA, tokenB, stable, liquidity, amountAMin, amountBMin, to, deadline);
    // }

    // function removeLiquidityFTMWithPermit(
    //     address token,
    //     bool stable,
    //     uint liquidity,
    //     uint amountTokenMin,
    //     uint amountFTMMin,
    //     address to,
    //     uint deadline,
    //     bool approveMax, uint8 v, bytes32 r, bytes32 s
    // ) external returns (uint amountToken, uint amountFTM) {
    //     address pair = pairFor(token, address(wftm), stable);
    //     uint value = approveMax ? type(uint).max : liquidity;
    //     IBaseV1Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
    //     (amountToken, amountFTM) = removeLiquidityFTM(token, stable, liquidity, amountTokenMin, amountFTMMin, to, deadline);
    // }

    // // **** SWAP ****
    // // requires the initial amount to have already been sent to the first pair
    // function _swap(uint[] memory amounts, route[] memory routes, address _to) internal virtual {
    //     for (uint i = 0; i < routes.length; i++) {
    //         (address token0,) = sortTokens(routes[i].from, routes[i].to);
    //         uint amountOut = amounts[i + 1];
    //         (uint amount0Out, uint amount1Out) = routes[i].from == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
    //         address to = i < routes.length - 1 ? pairFor(routes[i+1].from, routes[i+1].to, routes[i+1].stable) : _to;
    //         IBaseV1Pair(pairFor(routes[i].from, routes[i].to, routes[i].stable)).swap(
    //             amount0Out, amount1Out, to, new bytes(0)
    //         );
    //     }
    // }

    // function swapExactFTMForTokens(uint amountOutMin, route[] calldata routes, address to, uint deadline)
    // external
    // payable
    // ensure(deadline)
    // returns (uint[] memory amounts)
    // {
    //     require(routes[0].from == address(wftm), 'BaseV1Router: INVALID_PATH');
    //     amounts = getAmountsOut(msg.value, routes);
    //     require(amounts[amounts.length - 1] >= amountOutMin, 'BaseV1Router: INSUFFICIENT_OUTPUT_AMOUNT');
    //     wftm.deposit{value: amounts[0]}();
    //     assert(wftm.transfer(pairFor(routes[0].from, routes[0].to, routes[0].stable), amounts[0]));
    //     _swap(amounts, routes, to);
    // }

    // function swapExactTokensForFTM(uint amountIn, uint amountOutMin, route[] calldata routes, address to, uint deadline)
    // external
    // ensure(deadline)
    // returns (uint[] memory amounts)
    // {
    //     require(routes[routes.length - 1].to == address(wftm), 'BaseV1Router: INVALID_PATH');
    //     amounts = getAmountsOut(amountIn, routes);
    //     require(amounts[amounts.length - 1] >= amountOutMin, 'BaseV1Router: INSUFFICIENT_OUTPUT_AMOUNT');
    //     _safeTransferFrom(
    //         routes[0].from, msg.sender, pairFor(routes[0].from, routes[0].to, routes[0].stable), amounts[0]
    //     );
    //     _swap(amounts, routes, address(this));
    //     wftm.withdraw(amounts[amounts.length - 1]);
    //     _safeTransferFTM(to, amounts[amounts.length - 1]);
    // }

    // function UNSAFE_swapExactTokensForTokens(
    //     uint[] memory amounts,
    //     route[] calldata routes,
    //     address to,
    //     uint deadline
    // ) external ensure(deadline) returns (uint[] memory) {
    //     _safeTransferFrom(routes[0].from, msg.sender, pairFor(routes[0].from, routes[0].to, routes[0].stable), amounts[0]);
    //     _swap(amounts, routes, to);
    //     return amounts;
    // }

    // function _safeTransferFTM(address to, uint value) internal {
    //     (bool success,) = to.call{value:value}(new bytes(0));
    //     require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    // }

    // function _safeTransfer(address token, address to, uint256 value) internal {
    //     require(token.code.length > 0);
    //     (bool success, bytes memory data) =
    //     token.call(abi.encodeWithSelector(erc20.transfer.selector, to, value));
    //     require(success && (data.length == 0 || abi.decode(data, (bool))));
    // }

    // function _safeTransferFrom(address token, address from, address to, uint256 value) internal {
    //     require(token.code.length > 0);
    //     (bool success, bytes memory data) =
    //     token.call(abi.encodeWithSelector(erc20.transferFrom.selector, from, to, value));
    //     require(success && (data.length == 0 || abi.decode(data, (bool))));
    // }
}

// File: MultiRewards.sol

struct MultiRewards {
    address token;
    uint256 amount;
}

// File: SafeMath.sol

// OpenZeppelin Contracts v4.4.1 (utils/math/SafeMath.sol)

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

// File: IERC20Extended.sol

interface IERC20Extended is IERC20 {
    function decimals() external view returns (uint8);
}

// File: IStrategy.sol

interface IStrategy {
    // deposits all funds into the farm
    function deposit() external;

    // vault only - withdraws funds from the strategy
    function withdraw(uint256 _amount) external;

    // returns the balance of all tokens managed by the strategy
    function balanceOf() external view returns (uint256);

    // Claims farmed tokens and sends them to _to (Reward Distributor). Only callable from
    // the vault
    function claim(address _to)
        external
        returns (MultiRewards[] memory _rewards);

    // withdraws all tokens and sends them back to the vault
    function retireStrat() external;

    // pauses deposits, resets allowances, and withdraws all funds from farm
    function panic() external;

    // pauses deposits and resets allowances
    function pause() external;

    // unpauses deposits and maxes out allowances again
    function unpause() external;
}

// File: Pausable.sol

// OpenZeppelin Contracts v4.4.1 (security/Pausable.sol)

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// File: SafeERC20.sol

// OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// File: StrategyAuthorized.sol

abstract contract StrategyAuthorized is Context {
    address private _strategist;

    event UpdateGovernance(address indexed governance);
    event UpdateManagement(address indexed management);

    constructor() {
        _strategist = _msgSender();
    }

    modifier onlyGovernance() {
        require(
            governance() == _msgSender(),
            "Authorized: caller is not the governance"
        );
        _;
    }

    modifier onlyAuthorized() {
        require(
            governance() == _msgSender() || strategist() == _msgSender(),
            "Authorized: caller is not the authorized"
        );
        _;
    }

    function governance() public view virtual returns (address);

    function strategist() public view returns (address) {
        return _strategist;
    }

    function isAuthorized(address _addr) public view returns (bool) {
        return governance() == _addr || strategist() == _addr;
    }

    function setStrategist(address newStrategist) external onlyAuthorized {
        _strategist = newStrategist;
        emit UpdateManagement(_strategist);
    }
}

// File: uniswap.sol

interface IUniswapV2Router01 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) external pure returns (uint256 amountB);

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut);

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountIn);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountETH);

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

interface IUniswapV2Pair is IERC20Extended {
    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );
}

// File: Strategy0xDAO.sol

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
contract Strategy0xDAO is IStrategy, StrategyAuthorized, Pausable {
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
        address(0xc5A9848b9d145965d821AaeC8fA32aaEE026492d); //0XDAO
    address public rewardToken1 = 
        address(0x888EF71766ca594DED1F0FA3AE64eD2941740A20); // solid
    uint8 public rewardTokens = 2;
    address public lpPair;
    address public lpToken0;
    address public lpToken1;
    IBaseV1Pair pair;

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

    address[] private pools = new address[](1);
    IOxLens public constant oxLens = IOxLens(0xDA00137c79B30bfE06d04733349d98Cf06320e69);
    address public oxPoolAddress;
    address public stakingAddress;
    address public constant solidlyRouter = 0xa38cd27185a464914D3046f0AB9d43356B34829D;

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
        address _lpPair
    ) {

        lpPair = _lpPair;
        vault = _vault;
        pair = IBaseV1Pair(_lpPair);
        (,,,,,  lpToken0,  lpToken1) = pair.metadata();

        if (lpToken0 != wftm) {
            wftmToLp0Route = [wftm, lpToken0];
        }

        if (lpToken1 != wftm) {
            wftmToLp1Route = [wftm, lpToken1];
        }

        /*
        tokenRouter[lpToken0] = spookyRouter;
        tokenRouter[lpToken1] = spookyRouter;
        tokenRouter[rewardToken0] = spiritRouter;
        */
        
        isEmitting[0] = true;
        isEmitting[1] = true;

        pools[0] = lpPair;

        oxPoolAddress = oxLens.oxPoolBySolidPool(lpPair);
        stakingAddress = IOxPool(oxPoolAddress).stakingAddress();

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
            // Deposit 
            IOxPool(oxPoolAddress).depositLp(pairBal);
            // Stake
            IMultiRewards(stakingAddress).stake(pairBal);
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
            IMultiRewards(stakingAddress).withdraw(_amount.sub(pairBal));
            IOxPool(oxPoolAddress).withdrawLp(_amount.sub(pairBal));
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
        IMultiRewards(stakingAddress).getReward();

        uint256 balanceReward0 = IERC20(rewardToken0).balanceOf(address(this));
        if (balanceReward0 > 0) {
            IERC20(rewardToken0).transfer(to, balanceReward0);
        }

        uint256 balanceReward1 = IERC20(rewardToken1).balanceOf(address(this));
        if (balanceReward1 > 0) {
            IERC20(rewardToken1).transfer(to, balanceReward1);
        }
        _rewards = new MultiRewards[](2);
        _rewards[0] = MultiRewards(rewardToken0, balanceReward0);
        _rewards[1] = MultiRewards(rewardToken1, balanceReward1);

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
        return IMultiRewards(stakingAddress).balanceOf(address(this));

    }

    /**
     * @dev Function that has to be called as part of strat migration. It sends all the available funds back to the
     * vault, ready to be migrated to the new strat.
     */
    function retireStrat() external onlyVault {
        uint256 deposited = balanceOfPool();

        IMultiRewards(stakingAddress).withdraw(deposited);
        IOxPool(oxPoolAddress).withdrawLp(deposited);

        uint256 pairBal = IERC20(lpPair).balanceOf(address(this));
        IERC20(lpPair).transfer(vault, pairBal);
    }

    /**
     * @dev Pauses deposits. Withdraws all funds from the masterChef, leaving rewards behind
     */
    function panic() public onlyAuthorized {
        pause();
        uint256 deposited = balanceOfPool();
        IMultiRewards(stakingAddress).withdraw(deposited);
        IOxPool(oxPoolAddress).withdrawLp(deposited);
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
        IERC20(lpPair).safeApprove(address(oxPoolAddress), type(uint256).max);
        IERC20(oxPoolAddress).safeApprove(address(stakingAddress), type(uint256).max);
        IERC20(rewardToken0).safeApprove(solidlyRouter, type(uint256).max);
        IERC20(wftm).safeApprove(spookyRouter, type(uint256).max);

        IERC20(lpToken0).safeApprove(spookyRouter, 0);
        IERC20(lpToken0).safeApprove(spookyRouter, type(uint256).max);

        IERC20(lpToken1).safeApprove(spookyRouter, 0);
        IERC20(lpToken1).safeApprove(spookyRouter, type(uint256).max);
    }

    function removeAllowances() internal {
        IERC20(lpPair).safeApprove(address(oxPoolAddress), 0);
        IERC20(oxPoolAddress).safeApprove(address(stakingAddress), 0);

        IERC20(rewardToken0).safeApprove(solidlyRouter, 0);
        IERC20(wftm).safeApprove(spookyRouter, 0);
        IERC20(lpToken0).safeApprove(spookyRouter, 0);
        IERC20(lpToken1).safeApprove(spookyRouter, 0);
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
