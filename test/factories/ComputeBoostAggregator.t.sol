// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

import {BoostAggregator} from "@talos/boost-aggregator/BoostAggregator.sol";

library ComputeBoostAggregator {
    /*///////////////////////////////////////////////////////////////
                      COMPUTE VIRTUAL ACCOUNT ADDRESS
    ///////////////////////////////////////////////////////////////*/

    function getInitCodeHash(address uniswapV3Staker, address hermes, address owner, uint256 maxFee)
        internal
        pure
        returns (bytes32 initCodeHash)
    {
        initCodeHash = keccak256(
            abi.encodePacked(type(BoostAggregator).creationCode, abi.encode(uniswapV3Staker, hermes, owner, maxFee))
        );
    }

    function computeAddress(
        address factory,
        address sender,
        address uniswapV3Staker,
        address hermes,
        address owner,
        uint256 maxFee,
        bytes32 salt
    ) internal pure returns (address virtualAccount) {
        console2.logBytes32(
            keccak256(
                abi.encodePacked(
                    bytes1(0xff),
                    factory,
                    keccak256(abi.encodePacked(sender, owner, maxFee, salt)),
                    getInitCodeHash(uniswapV3Staker, hermes, owner, maxFee)
                )
            )
        );
        virtualAccount = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            factory,
                            keccak256(abi.encodePacked(sender, owner, maxFee, salt)),
                            getInitCodeHash(uniswapV3Staker, hermes, owner, maxFee)
                        )
                    )
                )
            )
        );
    }
}
