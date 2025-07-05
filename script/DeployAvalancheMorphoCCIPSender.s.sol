// script/DeployAvalancheMorphoCCIPSender.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {AvalancheMorphoCCIPSender} from "../src/avalanche/AvalancheMorphoCCIPSender.sol";

contract DeployAvalancheMorphoCCIPSender is Script {
    function run() public {
        // Get constructor arguments from environment variables
        address ccipRouter = vm.envAddress("CCIP_ROUTER_AVALANCHE");
        address baseReceiver = vm.envAddress("BASE_RECEIVER_ADDRESS");
        uint64 baseChainSelector = uint64(vm.envUint("BASE_CHAIN_SELECTOR"));

        vm.startBroadcast();

        AvalancheMorphoCCIPSender sender = new AvalancheMorphoCCIPSender(
            ccipRouter,
            baseReceiver,
            baseChainSelector
        );

        console.log("AvalancheMorphoCCIPSender deployed at:", address(sender));

        vm.stopBroadcast();
    }
}
