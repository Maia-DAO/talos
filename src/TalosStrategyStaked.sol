// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

import {IERC20Boost} from "@ERC20/interfaces/IERC20Boost.sol";

import {FlywheelCoreInstant} from "@rewards/FlywheelCoreInstant.sol";
import {MultiRewardsDepot} from "@rewards/depots/MultiRewardsDepot.sol";
import {FlywheelInstantRewards} from "@rewards/rewards/FlywheelInstantRewards.sol";

import {IUniswapV3Staker} from "@v3-staker/interfaces/IUniswapV3Staker.sol";

import {BoostAggregator} from "./boost-aggregator/BoostAggregator.sol";
import {TalosStrategySimple, TalosBaseStrategy} from "./strategies/TalosStrategySimple.sol";

import {ITalosOptimizer} from "./interfaces/ITalosOptimizer.sol";
import {ITalosStrategyStaked} from "./interfaces/ITalosStrategyStaked.sol";

library DeployStaked {
    function createTalosV3Staked(
        IUniswapV3Pool pool,
        ITalosOptimizer optimizer,
        BoostAggregator boostAggregator,
        address strategyManager,
        FlywheelCoreInstant flywheel,
        address owner,
        bytes32 _salt
    ) external returns (TalosBaseStrategy) {
        bytes32 salt = keccak256(abi.encodePacked(pool, optimizer, strategyManager, flywheel, owner, _salt));
        return new TalosStrategyStaked{salt: salt}(pool, optimizer, boostAggregator, strategyManager, flywheel, owner);
    }
}

/// @title Tokenized Vault implementation for a staked Uniswap V3 Non-Fungible Positions.
contract TalosStrategyStaked is TalosStrategySimple, ITalosStrategyStaked {
    /*//////////////////////////////////////////////////////////////
                        TALOS STAKED STRATEGY STATE
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITalosStrategyStaked
    BoostAggregator public immutable override boostAggregator;

    /// @notice flywheel core responsible for assigning strategy rewards to its respective users.
    FlywheelCoreInstant public immutable flywheel;

    /// @notice staking flag indicating if the NFT is staked or not.
    bool private stakeFlag = false;

    /**
     * @notice Construct a new Talos Strategy Staked contract.
     * @param _pool Uniswap V3 Pool to manage.
     * @param _optimizer Talos Optimizer to use.
     * @param _boostAggregator BoostAggregator to stake NFTs in Uniswap V3 Staker
     * @param _strategyManager Strategy manager to use.
     * @param _flywheel flywheel core responsible for assigning strategy rewards to its respective users.
     * @param _owner Owner of the contract.
     */
    constructor(
        IUniswapV3Pool _pool,
        ITalosOptimizer _optimizer,
        BoostAggregator _boostAggregator,
        address _strategyManager,
        FlywheelCoreInstant _flywheel,
        address _owner
    ) TalosStrategySimple(_pool, _optimizer, _boostAggregator.nonfungiblePositionManager(), _strategyManager, _owner) {
        flywheel = _flywheel;

        boostAggregator = _boostAggregator;
        _boostAggregator.setOwnRewardsDepot(address(FlywheelInstantRewards(_flywheel.flywheelRewards()).rewardsDepot()));
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL HOOKS LOGIC
    ///////////////////////////////////////////////////////////////*/

    function transfer(address _to, uint256 _amount) public override returns (bool) {
        flywheel.accrue(ERC20(address(this)), msg.sender, _to);
        return super.transfer(_to, _amount);
    }

    function transferFrom(address _from, address _to, uint256 _amount) public override returns (bool) {
        flywheel.accrue(ERC20(address(this)), _from, _to);
        return super.transferFrom(_from, _to, _amount);
    }

    /// @notice Hook that is called before a position is redeemed.
    /// @dev Responsible for collecting and accruing user rewards
    function beforeRedeem(uint256 _tokenId, address _owner) internal override {
        _earnFees(_tokenId);
        flywheel.accrue(_owner);
    }

    /// @notice Hook that is called after a position is redeemed.
    /// @dev Responsible for staking the position in the UniswapV3Staker
    function afterRedeem(uint256 _tokenId) internal override {
        _stake(_tokenId);
    }

    /// @notice Hook that is called before a position is deposited.
    /// @dev Responsible for collecting and accruing user rewards
    function beforeDeposit(uint256 _tokenId, address _receiver) internal override {
        _earnFees(_tokenId);
        flywheel.accrue(_receiver);
    }

    /// @notice Hook that is called after a position is deposited.
    /// @dev Responsible for staking the position in the UniswapV3Staker
    function afterDeposit(uint256 _tokenId) internal override {
        _stake(_tokenId);
    }

    /// @notice Hook that is called before a position is reranged.
    /// @dev Responsible for collecting and accruing strategy rewards
    function beforeRerange(uint256 _tokenId) internal override {
        _earnFees(_tokenId);
        flywheel.accrue(msg.sender);
    }

    /// @notice Hook that is called after a position is reranged.
    /// @dev Responsible for staking the position in the UniswapV3Staker
    function afterRerange(uint256 _tokenId) internal override {
        _stake(_tokenId);
    }

    /// @notice Collects fees from the pool
    /// @param _tokenId where to collect fees from
    function _earnFees(uint256 _tokenId) internal {
        // If not staked, collect fees from the pool
        if (stakeFlag) {
            _unstake(_tokenId);
        } else {
            if (liquidity == 0) return; // no need to collect fees when liquidity is zero

            (uint256 collect0, uint256 collect1) = nonfungiblePositionManager.collect(
                INonfungiblePositionManager.CollectParams({
                    tokenId: _tokenId,
                    recipient: address(this),
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max
                })
            );

            // Calculate protocol's fees
            protocolFees0 += collect0;
            protocolFees1 += collect1;
        }
    }

    /// @notice Unstakes all tokens from a specific tokenId
    /// @param _tokenId where to unstake from
    function _unstake(uint256 _tokenId) internal {
        // Unstaked, withdraws and sends fees to the rewards depot
        boostAggregator.unstakeAndWithdraw(_tokenId);

        stakeFlag = false;
    }

    /// @notice Stakes a specific pre existing position
    /// @param _tokenId position that needs to be staked
    function _stake(uint256 _tokenId) internal {
        if (liquidity == 0) return; // can't stake when liquidity is zero

        // try catch in case this position is not authorized to stake or current incentive does not have rewards
        try nonfungiblePositionManager.safeTransferFrom(address(this), address(boostAggregator), _tokenId) {
            stakeFlag = true; // flag to store staking state to avoid failing to unstake when it is not staked
        } catch (bytes memory reason) {
            // If the reason is not 4 bytes, it is an unexpected error
            if (reason.length != 4) {
                // If the reason is empty, revert with a StakeFailedUnexpectedly error
                if (reason.length == 0) revert StakeFailedUnexpectedly();

                assembly ("memory-safe") {
                    revert(add(32, reason), mload(reason))
                }
            }

            bytes4 reasonError = bytes4(reason);

            // Do not revert if the revert reason is one of the following, it is impossible to stake

            if (reasonError == Ownable.Unauthorized.selector) {
                // The boost aggregator does not have this address authorized to stake, can't stake
                return;
            } else if (reasonError == IUniswapV3Staker.NonExistentIncentiveError.selector) {
                // The week's incentive does not have rewards, can't stake
                return;
            } else if (reasonError == IUniswapV3Staker.RangeTooSmallError.selector) {
                // The range is too small to stake for the current gauge's minimum width, can't stake
                return;
            } else if (reasonError == IERC20Boost.InvalidGauge.selector) {
                // The gauge was never added or was deprecated, can't stake
                return;
            }

            // If the reason is not one of the above, then revert
            assembly ("memory-safe") {
                revert(add(32, reason), mload(reason))
            }
        }
    }
}
