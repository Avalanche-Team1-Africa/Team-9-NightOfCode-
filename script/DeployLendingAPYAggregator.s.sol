// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {LendingAPYAggregator} from "../src/LendingAPYAggregator.sol";

contract DeployLendingAPYAggregator is Script {
    /// @dev Set these environment variables before running the script:
    ///   export AAVE_POOL_ADDRESS=0x4F01AeD16D97E3aB5ab2B501154DC9bb0F1A5A2C
    ///   export MORPHO_SENDER_ADDRESS=<your_morpho_sender_address>
    ///   export OWNER_ADDRESS=<your_owner_address> # optional
    function run() public {
        address aavePool = vm.envAddress("AAVE_POOL_ADDRESS");
        address morphoSender = vm.envAddress("MORPHO_SENDER_ADDRESS");
        address owner;
        try vm.envAddress("OWNER_ADDRESS") returns (address o) {
            owner = o;
        } catch {
            owner = msg.sender;
        }

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
