pragma solidity ^0.5.13;

import "../helpers/DecimalMath.sol";
import "./Staking.sol";


/// @title Griefing
/// @author Stephane Gosselin (@thegostep) for Numerai Inc
/// @dev Security contact: security@numer.ai
/// @dev Version: 1.2.0
/// @dev State Machine: https://github.com/erasureprotocol/erasure-protocol/blob/v1.2.0/docs/state-machines/modules/Griefing.png
contract Griefing is Staking {

    enum RatioType { NaN, Inf, Dec }

    mapping (address => GriefRatio) private _griefRatio;
    struct GriefRatio {
        uint256 ratio;
        RatioType ratioType;
   }

    event RatioSet(address staker, uint256 ratio, RatioType ratioType);
    event Griefed(address punisher, address staker, uint256 punishment, uint256 cost, bytes message);

    uint256 internal constant e18 = uint256(10) ** uint256(18);

    // state functions

    /// @notice Set the grief ratio and type for a given staker
    /// @param staker Address of the staker
    /// @param ratio Uint256 number (18 decimals)
    ///              NOTE: ratio must be 0 if ratioType is Inf or NaN
    /// @param ratioType Griefing.RatioType number. Ratio Type must be one of the following three values:
    ///                   - Dec: Ratio is a decimal number with 18 decimals
    ///                   - Inf: Punishment at no cost
    ///                   - NaN: No Punishment
    function _setRatio(address staker, uint256 ratio, RatioType ratioType) internal {
        if (ratioType == RatioType.NaN || ratioType == RatioType.Inf) {
            require(ratio == 0, "ratio must be 0 when ratioType is NaN or Inf");
        }

        // set data in storage
        _griefRatio[staker].ratio = ratio;
        _griefRatio[staker].ratioType = ratioType;

        // emit event
        emit RatioSet(staker, ratio, ratioType);
    }

    /// @notice Punish a stake through griefing
    ///         NOTE: the cost of the punishment is taken form the account of the punisher. This therefore requires appropriate ERC-20 token approval.
    /// @param punisher Address of the punisher
    /// @param staker Address of the staker
    /// @param punishment Amount of NMR (18 decimals) to punish
    /// @param message Bytes reason string for the punishment
    /// @return cost Amount of NMR (18 decimals) to pay
    function _grief(
        address punisher,
        address staker,
        uint256 punishment,
        bytes memory message
    ) internal returns (uint256 cost) {
        // get grief data from storage
        uint256 ratio = _griefRatio[staker].ratio;
        RatioType ratioType = _griefRatio[staker].ratioType;

        require(ratioType != RatioType.NaN, "no punishment allowed");

        // calculate cost
        // getCost also acts as a guard when _setRatio is not called before
        cost = getCost(ratio, punishment, ratioType);

        // burn the cost from the punisher's balance
        BurnNMR._burnFrom(punisher, cost);

        // burn the punishment from the target's stake
        Staking._burnStake(staker, punishment);

        // emit event
        emit Griefed(punisher, staker, punishment, cost, message);

        // return
        return cost;
    }

    // view functions

    /// @notice Get the ratio of a staker
    /// @param staker Address of the staker
    /// @return ratio Uint256 number (18 decimals)
    /// @return ratioType Griefing.RatioType number. Ratio Type must be one of the following three values:
    ///                   - Dec: Ratio is a decimal number with 18 decimals
    ///                   - Inf: Punishment at no cost
    ///                   - NaN: No Punishment
    function getRatio(address staker) public view returns (uint256 ratio, RatioType ratioType) {
        // get stake data from storage
        return (_griefRatio[staker].ratio, _griefRatio[staker].ratioType);
    }

    // pure functions

    /// @notice Get exact cost for a given punishment and ratio
    /// @param ratio Uint256 number (18 decimals)
    /// @param punishment Amount of NMR (18 decimals) to punish
    /// @param ratioType Griefing.RatioType number. Ratio Type must be one of the following three values:
    ///                   - Dec: Ratio is a decimal number with 18 decimals
    ///                   - Inf: Punishment at no cost
    ///                   - NaN: No Punishment
    /// @return cost Amount of NMR (18 decimals) to pay
    function getCost(uint256 ratio, uint256 punishment, RatioType ratioType) public pure returns(uint256 cost) {
        if (ratioType == RatioType.Dec) {
            return DecimalMath.mul(SafeMath.mul(punishment, e18), ratio) / e18;
        }
        if (ratioType == RatioType.Inf)
            return 0;
        if (ratioType == RatioType.NaN)
            revert("ratioType cannot be RatioType.NaN");
    }

    /// @notice Get approximate punishment for a given cost and ratio.
    ///         The punishment is an approximate value due to quantization / rounding.
    /// @param ratio Uint256 number (18 decimals)
    /// @param cost Amount of NMR (18 decimals) to pay
    /// @param ratioType Griefing.RatioType number. Ratio Type must be one of the following three values:
    ///                   - Dec: Ratio is a decimal number with 18 decimals
    ///                   - Inf: Punishment at no cost
    ///                   - NaN: No Punishment
    /// @return punishment Approximate amount of NMR (18 decimals) to punish
    function getPunishment(uint256 ratio, uint256 cost, RatioType ratioType) public pure returns(uint256 punishment) {
        if (ratioType == RatioType.Dec) {
            return DecimalMath.div(SafeMath.mul(cost, e18), ratio) / e18;
        }
        if (ratioType == RatioType.Inf)
            revert("ratioType cannot be RatioType.Inf");
        if (ratioType == RatioType.NaN)
            revert("ratioType cannot be RatioType.NaN");
    }

}
