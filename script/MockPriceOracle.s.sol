// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MockPriceOracle} from "../src/MockPriceOracle.sol";

contract DeployMockPriceOracle is Script {
    MockPriceOracle public priceOracle;

    uint256 public initialPrice = 118_690_43;
    int256 public minStep = -200;
    int256 public maxStep = 200;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        priceOracle = new MockPriceOracle(initialPrice, minStep, maxStep);

        vm.stopBroadcast();
    }
}
