// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TalosOptimizer} from "../TalosOptimizer.sol";

import {IOptimizerFactory} from "../interfaces/IOptimizerFactory.sol";

/// @title Optimizer Factory for Talos Optimizers
/// @author Maia DAO (https://github.com/Maia-DAO)
contract OptimizerFactory is IOptimizerFactory {
    /*//////////////////////////////////////////////////////////////
                        OPTIMIZER FACTORY STATE
    ///////////////////////////////////////////////////////////////*/

    TalosOptimizer[] public optimizers;

    mapping(TalosOptimizer optimizer => uint256 optimizerId) public optimizerIds;

    function getOptimizers() external view returns (TalosOptimizer[] memory) {
        return optimizers;
    }

    /**
     * @notice Construct a new Optimizer Factory contract.
     */
    constructor() {
        optimizers.push(TalosOptimizer(address(0)));
    }

    /*//////////////////////////////////////////////////////////////
                            CREATE LOGIC
    ///////////////////////////////////////////////////////////////*/

    /// @notice Creates a new optimizer
    /// @param owner The owner of the optimizer
    function createTalosOptimizer(
        uint32 _twapDuration,
        int24 _maxTwapDeviation,
        int24 _tickRangeMultiplier,
        uint24 _priceImpactPercentage,
        uint256 _maxTotalSupply,
        address owner,
        bytes32 _salt
    ) external {
        bytes32 salt = keccak256(
            abi.encodePacked(
                _twapDuration,
                _maxTwapDeviation,
                _tickRangeMultiplier,
                _priceImpactPercentage,
                _maxTotalSupply,
                owner,
                _salt
            )
        );
        TalosOptimizer optimizer = new TalosOptimizer{salt: salt}(
            _twapDuration, _maxTwapDeviation, _tickRangeMultiplier, _priceImpactPercentage, _maxTotalSupply, owner
        );

        optimizerIds[optimizer] = optimizers.length;
        optimizers.push(optimizer);

        emit OptimizerCreated(
            optimizer,
            _twapDuration,
            _maxTwapDeviation,
            _tickRangeMultiplier,
            _priceImpactPercentage,
            _maxTotalSupply,
            owner
        );
    }
}
