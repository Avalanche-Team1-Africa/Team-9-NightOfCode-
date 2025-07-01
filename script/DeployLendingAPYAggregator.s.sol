// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {LendingAPYAggregator} from "../src/LendingAPYAggregator.sol";

contract DeployLendingAPYAggregator is Script {

    function run() public {
        // You can set these to real or mock addresses as needed
        address aavePool = vm.envAddress("AAVE_POOL_ADDRESS");
        address morphoSender = vm.envAddress("MORPHO_SENDER_ADDRESS");
        address owner = msg.sender; // or vm.envAddress("OWNER_ADDRESS");

        vm.startBroadcast();

        LendingAPYAggregator aggregator = new LendingAPYAggregator(
            aavePool,
            morphoSender,
            owner
        );

        console.log("LendingAPYAggregator deployed at:", address(aggregator));

        vm.stopBroadcast();
    }
}
