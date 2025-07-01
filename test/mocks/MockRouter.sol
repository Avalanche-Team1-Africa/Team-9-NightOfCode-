// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {AvalancheMorphoCCIPSender} from "src/avalanche/AvalancheMorphoCCIPSender.sol";
import {BaseMorphoCCIPReceiver} from "src/base/BaseMorphoCCIPReceiver.sol";
import {Client} from "@chainlink/ccip/libraries/Client.sol";

import {IRouterClient} from "@chainlink/ccip/interfaces/IRouterClient.sol";

// Mock router that simulates CCIP delivery
abstract contract MockRouter is IRouterClient {
    address public receiver;

    function setReceiver(address _receiver) external {
        receiver = _receiver;
    }

    function ccipSend(
        uint64, // destinationChainSelector
        Client.EVM2AnyMessage calldata message
    ) external payable override returns (bytes32) {
        // Simulate delivery by calling the receiver directly
        BaseMorphoCCIPReceiver(receiver).ccipReceive(
            Client.Any2EVMMessage({
                sender: abi.encode(msg.sender),
                data: message.data,
                destTokenAmounts: new Client.EVMTokenAmount[](0),
                sourceChainSelector: uint64(0),
                messageId: bytes32(0)
            })
        );
        return keccak256("mock-message-id");
    }

    // ... implement other required functions as no-ops or revert
}
