import "@thrackle-io/forte-rules-engine/src/client/RulesEngineClient.sol";

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

/**
 * @title Template Contract for Testing the Rules Engine
 * @author @mpetersoCode55, @ShaneDuncan602, @TJ-Everett, @VoR0220
 * @dev This file serves as a template for dynamically injecting custom Solidity modifiers into smart contracts.
 *              It defines an abstract contract that extends the `RulesEngineClient` contract, providing a placeholder
 *              for modifiers that are generated and injected programmatically.
 */
abstract contract RulesEngineClientCustom is RulesEngineClient {
    modifier checkRulesBeforeliquidatePosition(address trader, uint256 size) {
        bytes memory encoded = abi.encodeWithSelector(msg.sig, trader, size);
        _invokeRulesEngine(encoded);
        _;
    }

    modifier checkRulesAfterliquidatePosition(address trader, uint256 size) {
        bytes memory encoded = abi.encodeWithSelector(msg.sig, trader, size);
        _;
        _invokeRulesEngine(encoded);
    }
}
