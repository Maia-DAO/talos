// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {ITalosOptimizer} from "../interfaces/ITalosOptimizer.sol";

import {BoostAggregator, BoostAggregatorFactory} from "../factories/BoostAggregatorFactory.sol";
import {FlywheelCoreInstant} from "@rewards/FlywheelCoreInstant.sol";
import {FlywheelInstantRewards} from "@rewards/rewards/FlywheelInstantRewards.sol";

import {TalosBaseStrategy} from "../base/TalosBaseStrategy.sol";

/**
 * @title Talos Strategy Staked Factory
 *  @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice This contract is used to create new TalosStrategyStaked contracts.
 */
interface ITalosStrategyStakedFactory {
    /*//////////////////////////////////////////////////////////////
                        TALOS STAKED STRATEGY STATE
    ///////////////////////////////////////////////////////////////*/

    /// @notice The boostAggregator to stake NFTs in Uniswap V3 Staker
    /// @return boostAggregatorFactory
    function boostAggregatorFactory() external view returns (BoostAggregatorFactory);

    /// @notice flywheel core responsible for assigning strategy rewards
    ///         to its respective users.
    /// @return flywheel
    function flywheel() external view returns (FlywheelCoreInstant);

    /// @notice flywheel core responsible for assigning strategy rewards
    ///         to its respective users.
    /// @return flywheel
    function rewards() external view returns (FlywheelInstantRewards);

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    ///////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new Talos Strategy Staked is created.
    /// @param strategy The newly created Talos Strategy Staked.
    /// @param pool The pool the strategy is using.
    /// @param optimizer The optimizer the strategy is using.
    /// @param strategyManager The strategy manager of the strategy.
    /// @param boostAggregator The boost aggregator of the strategy.
    event StrategyCreated(
        TalosBaseStrategy indexed strategy,
        IUniswapV3Pool indexed pool,
        ITalosOptimizer indexed optimizer,
        address strategyManager,
        BoostAggregator boostAggregator
    );

    /*///////////////////////////////////////////////////////////////
                                ERRORS
    ///////////////////////////////////////////////////////////////*/

    /// @notice Throws when boostAggregator has an invalid nonfungiblePositionManager
    error InvalidNFTManager();
}
