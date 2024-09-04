// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TalosManager} from "../TalosManager.sol";

/**
 * @title Talos Manager Factory
 *  @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice This contract is responsible for creating new Talos Managers.
 */
interface ITalosManagerFactory {
    /*//////////////////////////////////////////////////////////////
                        MANAGER FACTORY STATE
    ///////////////////////////////////////////////////////////////*/

    /// @notice list of all created managers
    function managers(uint256) external view returns (TalosManager);

    /// @notice mapping of manager to its index in the managers array
    function managerIds(TalosManager) external view returns (uint256);

    /// @notice Returns all managers created by the factory.
    function getManagers() external view returns (TalosManager[] memory);

    /*//////////////////////////////////////////////////////////////
                            CREATE LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates a new manager
     * @param _owner The owner of the manager
     * @param _ticksFromLowerRebalance The ticks from lower rebalance
     * @param _ticksFromUpperRebalance The ticks from upper rebalance
     * @param _ticksFromLowerRerange The ticks from lower rerange
     * @param _ticksFromUpperRerange The ticks from upper rerange
     * @param _salt The salt to use for creating the manager
     */
    function createTalosManager(
        address _owner,
        int24 _ticksFromLowerRebalance,
        int24 _ticksFromUpperRebalance,
        int24 _ticksFromLowerRerange,
        int24 _ticksFromUpperRerange,
        bytes32 _salt
    ) external;

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when a new manager is created.
     * @param sender The sender of the create transaction.
     * @param manager The newly created manager.
     * @param owner The owner of the manager.
     * @param ticksFromLowerRebalance The ticks from lower rebalance.
     * @param ticksFromUpperRebalance The ticks from upper rebalance.
     * @param ticksFromLowerRerange The ticks from lower rerange.
     * @param ticksFromUpperRerange The ticks from upper rerange.
     */
    event TalosManagerCreated(
        TalosManager indexed manager,
        address indexed sender,
        address indexed owner,
        int24 ticksFromLowerRebalance,
        int24 ticksFromUpperRebalance,
        int24 ticksFromLowerRerange,
        int24 ticksFromUpperRerange
    );
}
