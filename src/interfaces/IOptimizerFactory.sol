// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TalosOptimizer} from "../TalosOptimizer.sol";

/**
 * @title Talos Optimizer Factory
 *  @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice This contract is responsible for creating new Talos Optimizers.
 */
interface IOptimizerFactory {
    /*//////////////////////////////////////////////////////////////
                        OPTIMIZER FACTORY STATE
    ///////////////////////////////////////////////////////////////*/

    /// @notice list of all created optimizers
    function optimizers(uint256) external view returns (TalosOptimizer);

    /// @notice mapping of optimizer to its index in the optimizers array
    function optimizerIds(TalosOptimizer) external view returns (uint256);

    /// @notice Returns all optimizers created by the factory.
    function getOptimizers() external view returns (TalosOptimizer[] memory);

    /*//////////////////////////////////////////////////////////////
                            CREATE LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates a new optimizer
     * @param _twapDuration The duration of the TWAP
     * @param _maxTwapDeviation The maximum deviation of the TWAP
     * @param _tickRangeMultiplier The tick range multiplier
     * @param _priceImpactPercentage The price impact percentage
     * @param _maxTotalSupply The maximum total supply for Talos LPs
     * @param owner The owner of the optimizer
     * @param _salt The salt to use for the optimizer
     */
    function createTalosOptimizer(
        uint32 _twapDuration,
        int24 _maxTwapDeviation,
        int24 _tickRangeMultiplier,
        uint24 _priceImpactPercentage,
        uint256 _maxTotalSupply,
        address owner,
        bytes32 _salt
    ) external;

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    ///////////////////////////////////////////////////////////////*/
    /**
     * @notice Emitted when a new optimizer is created.
     * @param optimizer The newly created optimizer.
     * @param twapDuration The duration of the TWAP.
     * @param maxTwapDeviation The maximum deviation of the TWAP.
     * @param tickRangeMultiplier The tick range multiplier.
     * @param priceImpactPercentage The price impact percentage.
     * @param maxTotalSupply The maximum total supply for Talos LPs.
     * @param owner The owner of the optimizer.
     */
    event OptimizerCreated(
        TalosOptimizer indexed optimizer,
        uint32 twapDuration,
        int24 maxTwapDeviation,
        int24 tickRangeMultiplier,
        uint24 priceImpactPercentage,
        uint256 indexed maxTotalSupply,
        address indexed owner
    );
}
