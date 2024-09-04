// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TalosManager} from "../TalosManager.sol";

import {ITalosManagerFactory} from "../interfaces/ITalosManagerFactory.sol";

/// @title Factory for Talos Managers
/// @author Maia DAO (https://github.com/Maia-DAO)
contract TalosManagerFactory is ITalosManagerFactory {
    /*//////////////////////////////////////////////////////////////
                        MANAGER FACTORY STATE
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITalosManagerFactory
    TalosManager[] public managers;

    /// @inheritdoc ITalosManagerFactory
    mapping(TalosManager manager => uint256 managerId) public managerIds;

    /// @inheritdoc ITalosManagerFactory
    function getManagers() external view returns (TalosManager[] memory) {
        return managers;
    }

    /**
     * @notice Construct a new manager Factory contract.
     */
    constructor() {
        managers.push(TalosManager(address(0)));
    }

    /*//////////////////////////////////////////////////////////////
                            CREATE LOGIC
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITalosManagerFactory
    function createTalosManager(
        address _owner,
        int24 _ticksFromLowerRebalance,
        int24 _ticksFromUpperRebalance,
        int24 _ticksFromLowerRerange,
        int24 _ticksFromUpperRerange,
        bytes32 _salt
    ) external {
        bytes32 salt = keccak256(
            abi.encodePacked(
                msg.sender,
                _owner,
                _ticksFromLowerRebalance,
                _ticksFromUpperRebalance,
                _ticksFromLowerRerange,
                _ticksFromUpperRerange,
                _salt
            )
        );

        TalosManager manager = new TalosManager{salt: salt}(
            _owner, _ticksFromLowerRebalance, _ticksFromUpperRebalance, _ticksFromLowerRerange, _ticksFromUpperRerange
        );

        managerIds[manager] = managers.length;
        managers.push(manager);

        emit TalosManagerCreated(
            manager,
            msg.sender,
            _owner,
            _ticksFromLowerRebalance,
            _ticksFromUpperRebalance,
            _ticksFromLowerRerange,
            _ticksFromUpperRerange
        );
    }
}
