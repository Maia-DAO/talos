// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {ITalosOptimizer} from "../interfaces/ITalosOptimizer.sol";

import {BoostAggregator} from "../factories/BoostAggregatorFactory.sol";
import {TalosBaseStrategy} from "../base/TalosBaseStrategy.sol";

/**
 * @title Talos Strategy Vanilla Factory
 *  @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice This contract is used to create new TalosStrategyVanilla contracts.
 */
interface ITalosStrategyVanillaFactory {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    ///////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new Talos Strategy Staked is created.
    /// @param strategy The newly created Talos Strategy Staked.
    /// @param pool The pool the strategy is using.
    /// @param optimizer The optimizer the strategy is using.
    /// @param strategyManager The strategy manager of the strategy.
    event StrategyCreated(
        TalosBaseStrategy indexed strategy,
        IUniswapV3Pool indexed pool,
        ITalosOptimizer indexed optimizer,
        address strategyManager
    );
}
