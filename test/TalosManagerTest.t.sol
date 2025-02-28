// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {Ownable} from "solady/auth/Ownable.sol";

import {
    IUniswapV3Pool,
    UniswapV3Staker,
    IUniswapV3Staker,
    IncentiveTime,
    IncentiveId,
    bHermesBoost
} from "@v3-staker/UniswapV3Staker.sol";

import {ITalosBaseStrategy, TalosBaseStrategy} from "@talos/base/TalosBaseStrategy.sol";
import {ITalosOptimizer} from "@talos/interfaces/ITalosOptimizer.sol";
import {ITalosManager} from "@talos/interfaces/ITalosManager.sol";

import {TalosManager} from "@talos/TalosManager.sol";

interface AutomationCompatibleInterface {
    function checkUpkeep(bytes calldata checkData)
        external
        view
        returns (bool upkeepNeeded, bytes memory performData);
    function performUpkeep(bytes calldata performData) external;
}

// =======================
// Mocks for Testing
// =======================

contract MockPool {
    int24 private _currentTick;
    int56 private _cumulativeTick0;
    int56 private _cumulativeTick1;
    bool public revertSlot0;

    function setCurrentTick(int24 _tick) public {
        _currentTick = _tick;
    }

    function slot0() external view returns (uint160, int24, uint16, uint16, uint16, uint8, bool) {
        if (revertSlot0) revert("slot0 revert");
        return (0, _currentTick, 0, 0, 0, 0, false);
    }

    function setTickCumulatives(int24 _tick0, int24 _tick1) public {
        _cumulativeTick0 = _tick0;
        _cumulativeTick1 = _tick1;
    }

    function observe(uint32[] calldata secondsAgos)
        external
        view
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s)
    {
        tickCumulatives = new int56[](2);
        tickCumulatives[0] = _cumulativeTick0;
        tickCumulatives[1] = _cumulativeTick1;
        secondsPerLiquidityCumulativeX128s = new uint160[](0);
    }
}

contract MockOptimizer {
    uint256 private _maxTwapDeviation;
    uint256 private _twapDuration;

    function setValues(uint256 maxDeviation, uint256 duration) public {
        _maxTwapDeviation = maxDeviation;
        _twapDuration = duration;
    }

    function maxTwapDeviation() external view returns (uint256) {
        return _maxTwapDeviation;
    }

    function twapDuration() external view returns (uint256) {
        return _twapDuration;
    }
}

contract MockStrategy {
    IUniswapV3Pool private _pool;
    int24 private _tickLower;
    int24 private _tickUpper;
    ITalosOptimizer private _optimizer;

    bool private _rebalanceCalled;
    bool private _rerangeCalled;
    bool private _optimizerRevert;

    constructor(IUniswapV3Pool pool_, ITalosOptimizer optimizer_, int24 tickLower_, int24 tickUpper_) {
        _pool = pool_;
        _optimizer = optimizer_;
        _tickLower = tickLower_;
        _tickUpper = tickUpper_;
    }

    // --- Setter for tick bounds ---
    function setTicks(int24 tickLower_, int24 tickUpper_) public {
        _tickLower = tickLower_;
        _tickUpper = tickUpper_;
    }

    // --- Reset call flags ---
    function resetCalls() public {
        _rebalanceCalled = false;
        _rerangeCalled = false;
    }

    // --- ITalosBaseStrategy interface ---
    function pool() external view returns (IUniswapV3Pool) {
        return _pool;
    }

    function tickLower() external view returns (int24) {
        return _tickLower;
    }

    function tickUpper() external view returns (int24) {
        return _tickUpper;
    }

    function optimizer() external view returns (ITalosOptimizer) {
        if (_optimizerRevert) revert("optimizer revert");
        return _optimizer;
    }

    function rebalance() external {
        _rebalanceCalled = true;
    }

    function rerange() external {
        _rerangeCalled = true;
    }

    // --- Helpers to inspect call flags ---
    function rebalanceCalled() public view returns (bool) {
        return _rebalanceCalled;
    }

    function rerangeCalled() public view returns (bool) {
        return _rerangeCalled;
    }

    function setOptimizerRevert(bool flag) public {
        _optimizerRevert = flag;
    }
}

// =======================
// Test Contract
// =======================
contract TalosManagerTest is Test {
    TalosManager manager;
    IUniswapV3Pool mockPool;
    ITalosOptimizer mockOptimizer;
    ITalosBaseStrategy mockStrategy;

    // These are the thresholds passed in the constructor.
    int24 constant TICK_LB_REBAL = -50;
    int24 constant TICK_UB_REBAL = 20;
    int24 constant TICK_LB_RERANGE = -20;
    int24 constant TICK_UB_RERANGE = 50;

    // --- Event for testing setStrategy ---
    event StrategySet(ITalosBaseStrategy strategy);

    // setUp runs before each test.
    function setUp() public {
        mockPool = IUniswapV3Pool(address(new MockPool()));
        mockOptimizer = ITalosOptimizer(address(new MockOptimizer()));
        // Set some default optimizer values so that checkDeviation does not revert.
        MockOptimizer(address(mockOptimizer)).setValues(5, 10);
        // Set default tick bounds for the mock strategy.
        mockStrategy = ITalosBaseStrategy(address(new MockStrategy(mockPool, mockOptimizer, -100, 100)));
        // Deploy manager with the thresholds defined above.
        manager = new TalosManager(address(this), TICK_LB_REBAL, TICK_UB_REBAL, TICK_LB_RERANGE, TICK_UB_RERANGE);
    }

    /// @dev Helper to initialize the strategy using the actual setStrategy call.
    /// Since setStrategy can only be run once, this helper should be used to set the strategy for tests.
    function _initStrategy() internal {
        vm.prank(manager.owner());
        manager.setStrategy(mockStrategy);
    }

    // ------------------------------------------------------------
    // setStrategy tests
    // ------------------------------------------------------------

    /// @notice Test that setStrategy reverts if passed the zero address.
    function test_setStrategy_RevertOnZeroAddress() public {
        vm.prank(manager.owner());
        vm.expectRevert(abi.encodeWithSelector(ITalosManager.AddressZero.selector));
        manager.setStrategy(ITalosBaseStrategy(address(0)));
    }

    /// @notice Test that setStrategy succeeds (emitting the event, updating state, and renouncing ownership)
    /// and that it cannot be called twice.
    function test_setStrategy_Success() public {
        vm.prank(manager.owner());
        vm.expectEmit(true, true, true, true);
        emit StrategySet(mockStrategy);
        manager.setStrategy(mockStrategy);

        // Verify that strategy and pool are set correctly.
        assertEq(address(manager.strategy()), address(mockStrategy));
        assertEq(address(manager.pool()), address(mockPool));
        // Ownership is renounced after a successful call.
        assertEq(manager.owner(), address(0));

        // A subsequent call from the former owner should revert due to onlyOwner.
        vm.prank(address(this));
        vm.expectRevert(Ownable.Unauthorized.selector);
        manager.setStrategy(mockStrategy);
    }

    // ------------------------------------------------------------
    // performUpkeep tests
    // ------------------------------------------------------------
    /// @notice Fuzz test: performUpkeep calls rebalance when the rebalance condition holds.

    function testFuzz_performUpkeep(int16 currentTick, int16 tickLower, int16 tickUpper) public {
        (int24 _currentTick, int24 _tickLower, int24 _tickUpper) =
            (int24(currentTick), int24(tickLower), int24(tickUpper));

        MockPool(address(mockPool)).setCurrentTick(currentTick);
        MockStrategy(address(mockStrategy)).setTicks(tickLower, tickUpper);
        MockStrategy(address(mockStrategy)).resetCalls();
        _initStrategy();

        if (_tickUpper - _currentTick <= TICK_UB_REBAL || _currentTick - _tickLower <= TICK_LB_REBAL) {
            manager.performUpkeep("");
            assertTrue(MockStrategy(address(mockStrategy)).rebalanceCalled());
            assertFalse(MockStrategy(address(mockStrategy)).rerangeCalled());
        } else if (_tickUpper - _currentTick <= TICK_UB_RERANGE || _currentTick - _tickLower <= TICK_LB_RERANGE) {
            manager.performUpkeep("");
            assertFalse(MockStrategy(address(mockStrategy)).rebalanceCalled());
            assertTrue(MockStrategy(address(mockStrategy)).rerangeCalled());
        } else {
            manager.performUpkeep("");
            assertFalse(MockStrategy(address(mockStrategy)).rebalanceCalled());
            assertFalse(MockStrategy(address(mockStrategy)).rerangeCalled());
        }
    }

    function test_performUpkeep_RebalanceUpper() public {
        testFuzz_performUpkeep(0, 0, 20);
        assertTrue(MockStrategy(address(mockStrategy)).rebalanceCalled());
        assertFalse(MockStrategy(address(mockStrategy)).rerangeCalled());
    }

    function test_performUpkeep_RebalanceLower() public {
        testFuzz_performUpkeep(0, 50, 21);
        assertTrue(MockStrategy(address(mockStrategy)).rebalanceCalled());
        assertFalse(MockStrategy(address(mockStrategy)).rerangeCalled());
    }

    function test_performUpkeep_RerangeUpper() public {
        testFuzz_performUpkeep(0, 0, 50);
        assertFalse(MockStrategy(address(mockStrategy)).rebalanceCalled());
        assertTrue(MockStrategy(address(mockStrategy)).rerangeCalled());
    }

    function test_performUpkeep_RerangeLower() public {
        testFuzz_performUpkeep(0, 20, 51);
        assertFalse(MockStrategy(address(mockStrategy)).rebalanceCalled());
        assertTrue(MockStrategy(address(mockStrategy)).rerangeCalled());
    }

    // ------------------------------------------------------------
    // checkUpkeep tests
    // ------------------------------------------------------------
    // /// @notice Fuzz test: if checkDeviation reverts, checkUpkeep returns (false, "").
    // function testFuzz_checkUpkeep_RevertOnDeviation() public {
    //     _initStrategy();
    //     // Cause optimizer() in mockStrategy to revert.
    //     MockStrategy(address(mockStrategy)).setOptimizerRevert(true);
    //     (bool upkeepNeeded, bytes memory data) = manager.checkUpkeep("");
    //     assertFalse(upkeepNeeded);
    //     assertEq(data, "");
    //     // Reset for further tests.
    //     MockStrategy(address(mockStrategy)).setOptimizerRevert(false);
    // }

    // /// @notice Fuzz test: when the rebalance condition holds, checkUpkeep returns true.
    // function testFuzz_checkUpkeep_RebalanceFuzz(int24 currentTick, int24 tickLower, int24 tickUpper) public {
    //     vm.assume(tickLower < currentTick && currentTick < tickUpper);
    //     // For rebalance, require: tickUpper - currentTick <= 50.
    //     vm.assume(tickUpper - currentTick <= 50);
    //     MockPool(address(mockPool)).setCurrentTick(currentTick);
    //     MockStrategy(address(mockStrategy)).setTicks(tickLower, tickUpper);
    //     MockStrategy(address(mockStrategy)).setOptimizerRevert(false);
    //     _initStrategy();
    //     (bool upkeepNeeded,) = manager.checkUpkeep("");
    //     assertTrue(upkeepNeeded);
    // }

    // /// @notice Fuzz test: when no condition holds, checkUpkeep returns false.
    // function testFuzz_checkUpkeep_NoActionFuzz(int24 currentTick, int24 tickLower, int24 tickUpper) public {
    //     vm.assume(tickLower < currentTick && currentTick < tickUpper);
    //     // Neither rebalance nor rerange should trigger.
    //     vm.assume(tickUpper - currentTick > 50);
    //     vm.assume(currentTick - tickLower > -20);
    //     MockPool(address(mockPool)).setCurrentTick(currentTick);
    //     MockStrategy(address(mockStrategy)).setTicks(tickLower, tickUpper);
    //     MockStrategy(address(mockStrategy)).setOptimizerRevert(false);
    //     _initStrategy();
    //     (bool upkeepNeeded,) = manager.checkUpkeep("");
    //     assertFalse(upkeepNeeded);
    // }

    // ------------------------------------------------------------
    // checkDeviation test
    // ------------------------------------------------------------
    // /// @notice Test that checkDeviation works (i.e. does not revert) when optimizer returns valid values.
    // function test_checkDeviation() public {
    //     _initStrategy();
    //     MockOptimizer(address(mockStrategy)).setValues(5, 10);
    //     // Should not revert.
    //     manager.checkDeviation();
    // }
}
