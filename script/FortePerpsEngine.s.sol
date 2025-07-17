// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {FortePerpsEngine} from "../src/FortePerpsEngine.sol";

contract DeployFortePerpsEngine is Script {
    FortePerpsEngine public perpsEngine;

    address public priceOracle = vm.envAddress("PRICE_ORACLE");

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        perpsEngine = new FortePerpsEngine(priceOracle);

        vm.stopBroadcast();
    }
}
