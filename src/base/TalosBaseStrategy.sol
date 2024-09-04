// SPDX-License-Identifier: MIT
// Logic inspired by Popsicle Finance Contracts (PopsicleV3Optimizer/contracts/popsicle-v3-optimizer/PopsicleV3Optimizer.sol)
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

import {PoolVariables} from "../libraries/PoolVariables.sol";
import {PoolActions} from "../libraries/PoolActions.sol";

import {ITalosBaseStrategy} from "../interfaces/ITalosBaseStrategy.sol";
import {ITalosOptimizer} from "../interfaces/ITalosOptimizer.sol";

/// @title Tokenized Vault implementation for Uniswap V3 Non Fungible Positions.
abstract contract TalosBaseStrategy is Ownable, ERC20, ReentrancyGuard, ITalosBaseStrategy {
    using SafeTransferLib for address;
    using PoolVariables for IUniswapV3Pool;
    using PoolActions for INonfungiblePositionManager;

    /*//////////////////////////////////////////////////////////////
                        TALOS BASE STRATEGY STATE
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITalosBaseStrategy
    uint256 public override tokenId;
    /// @inheritdoc ITalosBaseStrategy
    uint256 public override protocolFees0;
    /// @inheritdoc ITalosBaseStrategy
    uint256 public override protocolFees1;

    /// @inheritdoc ITalosBaseStrategy
    uint128 public override liquidity;

    /// @notice Current tick lower of Optimizer pool position
    /// @inheritdoc ITalosBaseStrategy
    int24 public override tickLower;
    /// @notice Current tick higher of Optimizer pool position
    /// @inheritdoc ITalosBaseStrategy
    int24 public override tickUpper;

    /// @notice Checks if Optimizer is initialized
    bool private initialized;

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITalosBaseStrategy
    ERC20 public immutable override token0;
    /// @inheritdoc ITalosBaseStrategy
    ERC20 public immutable override token1;
    /// @inheritdoc ITalosBaseStrategy
    int24 public immutable override tickSpacing;
    /// @inheritdoc ITalosBaseStrategy
    uint24 public immutable override poolFee;
    /// @inheritdoc ITalosBaseStrategy
    IUniswapV3Pool public immutable override pool;
    /// @inheritdoc ITalosBaseStrategy
    ITalosOptimizer public immutable override optimizer;
    /// @inheritdoc ITalosBaseStrategy
    address public immutable strategyManager;
    /// @inheritdoc ITalosBaseStrategy
    INonfungiblePositionManager public immutable override nonfungiblePositionManager;

    uint24 internal constant MULTIPLIER = 1e6;

    constructor(
        IUniswapV3Pool _pool,
        ITalosOptimizer _optimizer,
        INonfungiblePositionManager _nonfungiblePositionManager,
        address _strategyManager,
        address _owner
    ) ERC20("TALOS LP", "TLP", 18) {
        _initializeOwner(_owner);
        optimizer = _optimizer;
        strategyManager = _strategyManager;
        pool = _pool;
        tickSpacing = _pool.tickSpacing();
        poolFee = _pool.fee();

        nonfungiblePositionManager = _nonfungiblePositionManager;
        ERC20 _token0 = ERC20(_pool.token0());
        ERC20 _token1 = ERC20(_pool.token1());
        (token0, token1) = (_token0, _token1);
        address(_token0).safeApprove(address(_nonfungiblePositionManager), type(uint256).max);
        address(_token1).safeApprove(address(_nonfungiblePositionManager), type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITalosBaseStrategy
    function init(
        uint256 amount0Desired,
        uint256 amount1Desired,
        address receiver,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 deadline
    ) external virtual override checkDeviation returns (uint256 shares, uint256 amount0, uint256 amount1) {
        if (initialized) revert AlreadyInitialized();
        initialized = true;

        // Transfer desired token amounts.
        address(token0).safeTransferFrom(msg.sender, address(this), amount0Desired);
        address(token1).safeTransferFrom(msg.sender, address(this), amount1Desired);

        uint256 _tokenId;
        uint128 _liquidity;
        (tickLower, tickUpper, amount0, amount1, _tokenId, _liquidity) = nonfungiblePositionManager.rerange(
            PoolActions.ActionParams(pool, optimizer, token0, token1, tickSpacing, 0, 0),
            PoolActions.RerangeParams(PoolVariables.getInitialTicks, amount0Min, amount1Min, deadline, poolFee)
        );
        (tokenId, liquidity) = (_tokenId, _liquidity);

        if (amount0 == 0) if (amount1 == 0) revert AmountsAreZero();

        shares = _liquidity * MULTIPLIER;

        if (shares == 0) revert NoSharesMinted();
        if (shares > optimizer.maxTotalSupply()) revert ExceedingMaxTotalSupply();
        _mint(receiver, shares);

        emit Initialize(_tokenId, msg.sender, receiver, amount0, amount1, shares);

        afterDeposit(_tokenId);

        // Refund in both assets.
        if (amount0 < amount0Desired) {
            uint256 refund0;
            unchecked {
                refund0 = amount0Desired - amount0;
            }
            address(token0).safeTransfer(msg.sender, refund0);
        }

        if (amount1 < amount1Desired) {
            uint256 refund1;
            unchecked {
                refund1 = amount1Desired - amount1;
            }
            address(token1).safeTransfer(msg.sender, refund1);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITalosBaseStrategy
    function deposit(
        uint256 amount0Desired,
        uint256 amount1Desired,
        address receiver,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 deadline
    ) public virtual override nonReentrant checkDeviation returns (uint256 shares, uint256 amount0, uint256 amount1) {
        uint256 _tokenId = tokenId;

        beforeDeposit(_tokenId, receiver);

        // Transfer desired token amounts.
        address(token0).safeTransferFrom(msg.sender, address(this), amount0Desired);
        address(token1).safeTransferFrom(msg.sender, address(this), amount1Desired);

        uint128 liquidityDifference;

        (liquidityDifference, amount0, amount1) = nonfungiblePositionManager.increaseLiquidity(
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: _tokenId,
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: amount0Min,
                amount1Min: amount1Min,
                deadline: deadline
            })
        );

        if (amount0 == 0) if (amount1 == 0) revert AmountsAreZero();

        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.
        shares = supply == 0 ? liquidityDifference * MULTIPLIER : (liquidityDifference * supply) / liquidity;
        liquidity = liquidity + liquidityDifference;

        if (shares == 0) revert NoSharesMinted();
        _mint(receiver, shares);
        if (totalSupply > optimizer.maxTotalSupply()) revert ExceedingMaxTotalSupply();

        emit Deposit(msg.sender, receiver, amount0, amount1, shares);

        afterDeposit(_tokenId);

        // Refund in both assets.
        if (amount0 < amount0Desired) {
            uint256 refund0;
            unchecked {
                refund0 = amount0Desired - amount0;
            }
            address(token0).safeTransfer(msg.sender, refund0);
        }

        if (amount1 < amount1Desired) {
            uint256 refund1;
            unchecked {
                refund1 = amount1Desired - amount1;
            }
            address(token1).safeTransfer(msg.sender, refund1);
        }
    }

    /// @inheritdoc ITalosBaseStrategy
    function redeem(
        uint256 shares,
        uint256 amount0Min,
        uint256 amount1Min,
        address receiver,
        address _owner,
        uint256 deadline
    ) public virtual override nonReentrant returns (uint256 amount0, uint256 amount1) {
        if (shares == 0) revert RedeemingZeroShares();
        if (receiver == address(0)) revert ReceiverIsZeroAddress();

        if (msg.sender != _owner) {
            uint256 allowed = allowance[_owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) allowance[_owner][msg.sender] = allowed - shares;
        }

        uint256 _tokenId = tokenId;

        beforeRedeem(_tokenId, _owner);

        {
            uint128 _liquidity = liquidity; // Saves an extra SLOAD.
            uint128 liquidityToDecrease = uint128((_liquidity * shares) / totalSupply);

            nonfungiblePositionManager.decreaseLiquidity(
                INonfungiblePositionManager.DecreaseLiquidityParams({
                    tokenId: _tokenId,
                    liquidity: liquidityToDecrease,
                    amount0Min: amount0Min,
                    amount1Min: amount1Min,
                    deadline: deadline
                })
            );

            _burn(_owner, shares);

            liquidity = _liquidity - liquidityToDecrease;
        }

        (amount0, amount1) = nonfungiblePositionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: _tokenId,
                recipient: receiver,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        if (amount0 == 0) if (amount1 == 0) revert AmountsAreZero();

        emit Redeem(msg.sender, receiver, _owner, amount0, amount1, shares);

        afterRedeem(_tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                        RERANGE/REBALANCE LOGIC
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITalosBaseStrategy
    function rerange() external virtual override nonReentrant checkDeviation onlyStrategyManager {
        uint256 _tokenId = tokenId;
        beforeRerange(_tokenId);
        // Redeem all liquidity from pool to rerange for Optimizer's balances.
        _withdrawAll(_tokenId);

        (uint256 amount0, uint256 amount1) = doRerange();
        emit Rerange(tokenId, tickLower, tickUpper, amount0, amount1);

        afterRerange(tokenId); // tokenId changed in doRerange
    }

    /// @inheritdoc ITalosBaseStrategy
    function rebalance() external virtual override nonReentrant checkDeviation onlyStrategyManager {
        uint256 _tokenId = tokenId;
        beforeRerange(_tokenId);
        // Redeem all liquidity from pool to rerange for Optimizer's balances.
        _withdrawAll(_tokenId);

        (uint256 amount0, uint256 amount1) = doRebalance();
        emit Rerange(tokenId, tickLower, tickUpper, amount0, amount1);

        afterRerange(tokenId); // tokenId changed in doRerange
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL HOOKS
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC721Receiver
    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /// @inheritdoc ITalosBaseStrategy
    function uniswapV3SwapCallback(int256 amount0, int256 amount1, bytes calldata _data) external override {
        if (msg.sender != address(pool)) revert CallerIsNotPool();
        if (amount0 == 0) if (amount1 == 0) revert AmountsAreZero();

        if (abi.decode(_data, (bool))) {
            address(token0).safeTransfer(msg.sender, uint256(amount0));
        } else {
            address(token1).safeTransfer(msg.sender, uint256(amount1));
        }
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL HOOKS LOGIC
    ///////////////////////////////////////////////////////////////*/

    /// @notice Redeems all liquidity for a specific tokenId
    /// @param _tokenId position to withdraw liquidity from
    function _withdrawAll(uint256 _tokenId) internal {
        uint128 _liquidity = liquidity; // Saves an extra SLOAD if totalSupply is non-zero.
        if (_liquidity == 0) return;

        nonfungiblePositionManager.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: _tokenId,
                liquidity: _liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );

        delete liquidity;

        nonfungiblePositionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: _tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );
    }

    function beforeDeposit(uint256 _tokenId, address _receiver) internal virtual;

    function afterDeposit(uint256 _tokenId) internal virtual;

    function beforeRedeem(uint256 _tokenId, address _owner) internal virtual;

    function afterRedeem(uint256 _tokenId) internal virtual;

    function beforeRerange(uint256 _tokenId) internal virtual;

    function afterRerange(uint256 _tokenId) internal virtual;

    function doRerange() internal virtual returns (uint256 amount0, uint256 amount1);

    function doRebalance() internal virtual returns (uint256 amount0, uint256 amount1);

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITalosBaseStrategy
    function collectProtocolFees(uint256 amount0, uint256 amount1) external override nonReentrant onlyOwner {
        uint256 _protocolFees0 = protocolFees0;
        uint256 _protocolFees1 = protocolFees1;

        if (amount0 > _protocolFees0) {
            revert Token0AmountIsBiggerThanProtocolFees();
        }
        if (amount1 > _protocolFees1) {
            revert Token1AmountIsBiggerThanProtocolFees();
        }

        unchecked {
            protocolFees0 = _protocolFees0 - amount0;
            protocolFees1 = _protocolFees1 - amount1;
        }

        emit RewardPaid(msg.sender, amount0, amount1);

        if (amount0 > 0) address(token0).safeTransfer(msg.sender, amount0);
        if (amount1 > 0) address(token1).safeTransfer(msg.sender, amount1);
    }

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    ///////////////////////////////////////////////////////////////*/

    /// @notice Modifier that checks if price has not moved a lot recently.
    modifier checkDeviation() {
        _checkDeviation();
        _;
    }

    /// @notice Modifier that checks if msg.sender is the strategy manager.
    modifier onlyStrategyManager() {
        _onlyStrategyManager();
        _;
    }

    /// @notice Function that checks if price has not moved a lot recently.
    /// This mitigates price manipulation during rebalance and also prevents placing orders when it's too volatile.
    function _checkDeviation() internal view {
        pool.checkDeviation(optimizer.maxTwapDeviation(), optimizer.twapDuration());
    }

    /// @notice Function that checks if msg.sender is the strategy manager.
    function _onlyStrategyManager() internal view {
        if (msg.sender != strategyManager) revert NotStrategyManager();
    }
}
