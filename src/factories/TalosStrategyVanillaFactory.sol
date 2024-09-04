// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

import {TalosBaseStrategy} from "../base/TalosBaseStrategy.sol";
import {DeployVanilla, TalosStrategyVanilla} from "../TalosStrategyVanilla.sol";

import {OptimizerFactory} from "./OptimizerFactory.sol";
import {TalosBaseStrategyFactory} from "./TalosBaseStrategyFactory.sol";

import {ITalosOptimizer} from "../interfaces/ITalosOptimizer.sol";
import {ITalosStrategyVanillaFactory} from "../interfaces/ITalosStrategyVanillaFactory.sol";

/// @title Talos Strategy Vanilla Factory
contract TalosStrategyVanillaFactory is TalosBaseStrategyFactory, ITalosStrategyVanillaFactory {
    /**
     * @notice Construct a new Talos Strategy Vanilla Factory
     * @param _nonfungiblePositionManager The Uniswap V3 NFT Manager
     * @param _optimizerFactory The Optimizer Factory
     */
    constructor(INonfungiblePositionManager _nonfungiblePositionManager, OptimizerFactory _optimizerFactory)
        TalosBaseStrategyFactory(_nonfungiblePositionManager, _optimizerFactory)
    {}

    /*//////////////////////////////////////////////////////////////
                         GAUGE LOGIC
    ///////////////////////////////////////////////////////////////*/

    /// @notice Internal function responsible for creating a new Talos Strategy
    function _createTalosV3Strategy(
        IUniswapV3Pool pool,
        ITalosOptimizer optimizer,
        address strategyManager,
        bytes32 salt,
        bytes memory
    ) internal override returns (TalosBaseStrategy strategy) {
        strategy = DeployVanilla.createTalosV3Vanilla(
            pool, optimizer, nonfungiblePositionManager, strategyManager, owner(), salt
        );

        emit StrategyCreated(strategy, pool, optimizer, strategyManager);
    }
}
