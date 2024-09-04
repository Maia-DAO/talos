// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

import {bHermesBoost} from "@hermes/tokens/bHermesBoost.sol";
import {UniswapV3Staker} from "@v3-staker/UniswapV3Staker.sol";

import {IBoostAggregator} from "../interfaces/IBoostAggregator.sol";

/// @title Boost Aggregator for Uniswap V3 NFTs
contract BoostAggregator is Ownable, IBoostAggregator {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                        BOOST AGGREGATOR STATE
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBoostAggregator
    INonfungiblePositionManager public immutable override nonfungiblePositionManager;

    /// @inheritdoc IBoostAggregator
    UniswapV3Staker public immutable override uniswapV3Staker;

    /// @inheritdoc IBoostAggregator
    bHermesBoost public immutable override hermesGaugeBoost;

    /// @inheritdoc IBoostAggregator
    ERC20 public immutable override hermes;

    /// @inheritdoc IBoostAggregator
    mapping(address user => address depot) public override userToRewardsDepot;

    /// @inheritdoc IBoostAggregator
    mapping(uint256 tokenId => address user) public override tokenIdToUser;

    /// @inheritdoc IBoostAggregator
    mapping(uint256 tokenId => uint256 rewardsCheckpoint) public override tokenIdRewards;

    /// @inheritdoc IBoostAggregator
    mapping(address user => bool allowed) public override allowlistedAddresses;

    /// @inheritdoc IBoostAggregator
    uint256 public override protocolRewards;

    /// @inheritdoc IBoostAggregator
    uint256 public override protocolFee = 2000; // 20%
    // divisioner for protocol fee
    uint256 private constant DIVISIONER = 10_000;

    uint256 public immutable maxFee;

    /**
     * @notice Creates a new BoostAggregator
     * @param _uniswapV3Staker The UniswapV3Staker contract
     * @param _hermes The hermes token contract
     * @param _owner The owner of this contract
     */
    constructor(UniswapV3Staker _uniswapV3Staker, ERC20 _hermes, address _owner, uint256 _maxFee) {
        _initializeOwner(_owner);
        uniswapV3Staker = _uniswapV3Staker;
        hermesGaugeBoost = uniswapV3Staker.hermesGaugeBoost();
        nonfungiblePositionManager = uniswapV3Staker.nonfungiblePositionManager();
        hermes = _hermes;
        // maxFee is capped at 100%
        maxFee = _maxFee > DIVISIONER ? DIVISIONER : _maxFee;
        protocolFee = protocolFee > maxFee ? maxFee : protocolFee;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL HOOKS
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC721Receiver
    /// @dev msg.sender not validated to be nonfungiblePositionManager in order to allow
    ///      allowlisted addresses to retrieve NFTs incorrectly sent to this contract
    function onERC721Received(address, address from, uint256 tokenId, bytes calldata)
        external
        override
        onlyAllowlisted(from)
        returns (bytes4)
    {
        // update tokenIdRewards prior to staking
        tokenIdRewards[tokenId] = uniswapV3Staker.tokenIdRewards(tokenId);
        // map tokenId to user
        tokenIdToUser[tokenId] = from;
        // stake NFT to Uniswap V3 Staker
        nonfungiblePositionManager.safeTransferFrom(address(this), address(uniswapV3Staker), tokenId);

        return this.onERC721Received.selector;
    }

    /*//////////////////////////////////////////////////////////////
                        REWARD DEPOTS LOGIC
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBoostAggregator
    function setOwnRewardsDepot(address rewardsDepot) external override {
        userToRewardsDepot[msg.sender] = rewardsDepot;

        emit ChangedRewardsDepot(msg.sender, rewardsDepot);
    }

    /*//////////////////////////////////////////////////////////////
                            UNSTAKE LOGIC
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBoostAggregator
    function unstakeAndWithdraw(uint256 tokenId) external override {
        address user = tokenIdToUser[tokenId];
        if (user != msg.sender) revert NotTokenIdOwner();
        tokenIdToUser[tokenId] = address(0);

        // unstake NFT from Uniswap V3 Staker
        uniswapV3Staker.unstakeToken(tokenId);

        uint256 pendingRewards = uniswapV3Staker.tokenIdRewards(tokenId) - tokenIdRewards[tokenId];

        uint256 newProtocolRewards = (pendingRewards * protocolFee) / DIVISIONER;
        /// @dev protocol rewards stay in stake contract
        protocolRewards += newProtocolRewards;
        // never overflows because protocolFee <= DIVISIONER
        pendingRewards -= newProtocolRewards;

        // Only claim rewards if there are any
        // or it would claim all accrued rewards in the staker belonging to the boost aggregator
        if (pendingRewards > 0) {
            address rewardsDepot = userToRewardsDepot[user];
            if (rewardsDepot != address(0)) {
                // claim rewards to user's rewardsDepot
                uniswapV3Staker.claimReward(rewardsDepot, pendingRewards);
            } else {
                // claim rewards to user
                uniswapV3Staker.claimReward(user, pendingRewards);
            }
        }

        // withdraw rewards from Uniswap V3 Staker
        uniswapV3Staker.withdrawToken(tokenId, user, "");
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN LOGIC
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBoostAggregator
    function addAllowlistedAddress(address user) external override onlyOwner {
        allowlistedAddresses[user] = true;

        emit AddedAllowlistedAddress(user);
    }

    /// @inheritdoc IBoostAggregator
    function removeAllowlistedAddress(address user) external override onlyOwner {
        delete allowlistedAddresses[user];

        emit RemovedAllowlistedAddress(user);
    }

    /// @inheritdoc IBoostAggregator
    function setProtocolFee(uint256 _protocolFee) external override onlyOwner {
        if (_protocolFee > maxFee) revert FeeTooHigh();
        protocolFee = _protocolFee;

        emit ChangedProtocolFee(_protocolFee);
    }

    /// @inheritdoc IBoostAggregator
    function withdrawProtocolFees(address to) external override onlyOwner {
        uint256 fees = protocolRewards;
        if (fees > 0) {
            uniswapV3Staker.claimReward(to, fees);
            delete protocolRewards;
        }
    }

    /// @inheritdoc IBoostAggregator
    function withdrawAllGaugeBoost(address to) external override onlyOwner {
        /// @dev May run out of gas.
        hermesGaugeBoost.decrementAllGaugesAllBoost();
        address(hermesGaugeBoost).safeTransfer(to, hermesGaugeBoost.balanceOf(address(this)));
    }

    /// @inheritdoc IBoostAggregator
    function withdrawGaugeBoost(address to, uint256 amount) external override onlyOwner {
        /// @dev May run out of gas.
        hermesGaugeBoost.decrementAllGaugesBoost(amount);
        hermesGaugeBoost.updateUserBoost(address(this));
        address(hermesGaugeBoost).safeTransfer(to, amount);
    }

    /// @inheritdoc IBoostAggregator
    function decrementGaugesBoostIndexed(uint256 boost, uint256 offset, uint256 num) external override onlyOwner {
        hermesGaugeBoost.decrementGaugesBoostIndexed(boost, offset, num);
    }

    /*///////////////////////////////////////////////////////////////
                                MODIFIERS
    ///////////////////////////////////////////////////////////////*/

    /// @dev Only allowlisted addresses
    /// @param from The address who the NFT is being transferred from
    modifier onlyAllowlisted(address from) {
        if (!allowlistedAddresses[from]) revert Unauthorized();
        _;
    }
}
