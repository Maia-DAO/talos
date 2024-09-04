// SPDX-License-Identifier: MIT
// Logic inspired by Popsicle Finance Contracts (PopsicleV3Optimizer/contracts/popsicle-v3-optimizer/PopsicleV3Optimizer.sol)
pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

import {ITalosOptimizer} from "./interfaces/ITalosOptimizer.sol";
import {PoolVariables} from "./libraries/PoolVariables.sol";

import {TalosStrategySimple, TalosBaseStrategy} from "./strategies/TalosStrategySimple.sol";

/// @title Deploy Vanilla
/// @notice This library deploys TALOS vanilla strategies
library DeployVanilla {
    function createTalosV3Vanilla(
        IUniswapV3Pool pool,
        ITalosOptimizer optimizer,
        INonfungiblePositionManager nonfungiblePositionManager,
        address strategyManager,
        address owner,
        bytes32 _salt
    ) external returns (TalosBaseStrategy) {
        bytes32 salt = keccak256(abi.encodePacked(pool, optimizer, strategyManager, owner, _salt));
        return new TalosStrategyVanilla{salt: salt}(pool, optimizer, nonfungiblePositionManager, strategyManager, owner);
    }
}

/// @notice Tokenized Vault implementation for Uniswap V3 Non Fungible Positions.
/// @author Maia DAO (https://github.com/Maia-DAO)
contract TalosStrategyVanilla is TalosStrategySimple {
    using PoolVariables for IUniswapV3Pool;

    /// @notice The protocol's fee in hundredths of a bip, i.e. 1e-6
    uint256 private constant PROTOCOL_FEE = 2 * 1e5; // 20%
    uint256 private constant GLOBAL_DIVISIONER = 1e6;

    /**
     * @notice Constructs a new TalosStrategyVanilla contract.
     * @param _pool The Uniswap V3 pool to manage.
     * @param _optimizer The optimizer contract to use.
     * @param _nonfungiblePositionManager The Uniswap V3 Non Fungible Position Manager contract.
     * @param _strategyManager The strategy manager contract.
     * @param _owner The owner of the contract.
     */
    constructor(
        IUniswapV3Pool _pool,
        ITalosOptimizer _optimizer,
        INonfungiblePositionManager _nonfungiblePositionManager,
        address _strategyManager,
        address _owner
    ) TalosStrategySimple(_pool, _optimizer, _nonfungiblePositionManager, _strategyManager, _owner) {}

    /*//////////////////////////////////////////////////////////////
                          INTERNAL HOOKS LOGIC
    ///////////////////////////////////////////////////////////////*/

    /// @notice Performs the necessary actions before a withdrawal can take place
    /// @param _tokenId position id that the user is trying to withdraw from
    function beforeRedeem(uint256 _tokenId, address) internal override {
        _earnFees(_tokenId);
        _compoundFees(_tokenId);
    }

    /// @notice Performs the necessary actions after a withdrawal takes place
    function afterRedeem(uint256) internal override {}

    /// @notice Performs the necessary actions before a deposit can take place
    /// @param _tokenId position id that the user wants to deposit in
    function beforeDeposit(uint256 _tokenId, address) internal override {
        _earnFees(_tokenId);
        _compoundFees(_tokenId);
    }

    /// @notice Performs the necessary actions after a deposit takes place
    function afterDeposit(uint256) internal override {}

    /// @notice Performs the necessary actions before a re-range can take place
    /// @param _tokenId position id that the user wants to re-range
    function beforeRerange(uint256 _tokenId) internal override {
        _earnFees(_tokenId);
    }

    /// @notice Performs the necessary actions after a re-range takes place
    function afterRerange(uint256) internal override {}

    /// @notice Collects fees from the pool to the protocol.
    /// @param _tokenId position id that the user wants to collect fees from
    function _earnFees(uint256 _tokenId) internal {
        if (liquidity == 0) return; // no fees to collect when liquidity is zero

        (uint256 collect0, uint256 collect1) = nonfungiblePositionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: _tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        // Calculate protocol's fees
        uint256 earnedProtocolFees0 = (collect0 * PROTOCOL_FEE) / GLOBAL_DIVISIONER;
        uint256 earnedProtocolFees1 = (collect1 * PROTOCOL_FEE) / GLOBAL_DIVISIONER;
        protocolFees0 += earnedProtocolFees0;
        protocolFees1 += earnedProtocolFees1;
        emit CollectFees(earnedProtocolFees0, earnedProtocolFees1, collect0, collect1);
    }

    /// @notice Compounds fees from the pool from a user perspective
    /// @param _tokenId position id that the user wants to compound fees from
    function _compoundFees(uint256 _tokenId) internal returns (uint256, uint256) {
        uint256 balance0 = token0.balanceOf(address(this)) - protocolFees0;
        uint256 balance1 = token1.balanceOf(address(this)) - protocolFees1;

        emit Snapshot(balance0, balance1);

        // Get Liquidity for Optimizer's balances
        uint128 _liquidity = pool.liquidityForAmounts(balance0, balance1, tickLower, tickUpper);

        if (_liquidity == 0) return (0, 0); // no fees to compound when liquidity is zero

        // Add liquidity to the pool
        (uint128 liquidityDifference, uint256 amount0, uint256 amount1) = nonfungiblePositionManager.increaseLiquidity(
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: _tokenId,
                amount0Desired: balance0,
                amount1Desired: balance1,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );

        liquidity += liquidityDifference;
        emit CompoundFees(amount0, amount1);

        return (amount0, amount1);
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    ///////////////////////////////////////////////////////////////*/

    /// @notice Emitted when fees are collected from the pool
    /// @param feesFromPool0 Total amount of fees collected in terms of token 0
    /// @param feesFromPool1 Total amount of fees collected in terms of token 1
    /// @param usersFees0 Total amount of fees collected by users in terms of token 0
    /// @param usersFees1 Total amount of fees collected by users in terms of token 1
    event CollectFees(
        uint256 indexed feesFromPool0, uint256 indexed feesFromPool1, uint256 indexed usersFees0, uint256 usersFees1
    );

    /// @notice Emitted when fees are compounded to the pool
    /// @param amount0 Total amount of fees compounded in terms of token 0
    /// @param amount1 Total amount of fees compounded in terms of token 1
    event CompoundFees(uint256 indexed amount0, uint256 indexed amount1);
}
