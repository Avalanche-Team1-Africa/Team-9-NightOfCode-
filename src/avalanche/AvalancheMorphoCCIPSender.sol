// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IRouterClient} from "@chainlink/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/ccip/libraries/Client.sol";
import {MarketParams} from "lib/morpho-blue/src/interfaces/IMorpho.sol";

/**
 * @dev Sends cross-chain messages from Avalanche to Base for Morpho protocol operations using Chainlink CCIP.
 *      This contract constructs and sends CCIP messages to a receiver contract on Base, encoding Morpho actions and parameters.
 */
contract AvalancheMorphoCCIPSender {
    //The Chainlink CCIP router interface used to send messages.
    IRouterClient public immutable ccipRouter;
    //The address of the receiver contract on Base that will process the messages.
    address public immutable baseReceiver;
    //The Chainlink selector for the Base chain.
    uint64 public immutable baseChainSelector;

    /**
     * @dev Emitted when a message is sent to Base.
     * @param action The action type (0=supply, 1=borrow, 2=repay, 3=withdraw).
     * @param market The Morpho market parameters.
     * @param amount The amount for the operation.
     * @param user The user address for whom the operation is performed.
     * @param receiver The receiver address for borrow/withdraw actions.
     */
    event MessageSent(uint8 action, MarketParams market, uint256 amount, address user, address receiver);

    /**
     * @dev Initializes the sender contract with the CCIP router, Base receiver, and chain selector.
     * @param _ccipRouter The address of the Chainlink CCIP router on Avalanche.
     * @param _baseReceiver The address of the Morpho receiver contract on Base.
     * @param _baseChainSelector The Chainlink selector for the Base chain.
     */

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        address _ccipRouter,
        address _baseReceiver,
        uint64 _baseChainSelector
    ) {
        ccipRouter = IRouterClient(_ccipRouter);
        baseReceiver = _baseReceiver;
        baseChainSelector = _baseChainSelector;
    }

    /**
     * @dev Sends a supply collateral message to Base via CCIP.
     * @param market The Morpho market parameters.
     * @param amount The amount of collateral to supply.
     * @param user The user address for whom the supply is performed.
     */

   /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function bridgeAndSupply(
        MarketParams calldata market,
        uint256 amount,
        address user
    ) external payable {
        bytes memory data = abi.encode(uint8(0), market, amount, user, address(0));
        _sendMessage(data, 0, market, amount, user, address(0));
    }

    /**
     * @dev Sends a borrow message to Base via CCIP.
     * @param market The Morpho market parameters.
     * @param amount The amount to borrow.
     * @param user The user address for whom the borrow is performed.
     * @param receiver The address to receive the borrowed assets on Base.
     */
    function bridgeAndBorrow(
        MarketParams calldata market,
        uint256 amount,
        address user,
        address receiver
    ) external payable {
        bytes memory data = abi.encode(uint8(1), market, amount, user, receiver);
        _sendMessage(data, 1, market, amount, user, receiver);
    }

    /**
     * @dev Sends a repay message to Base via CCIP.
     * @param market The Morpho market parameters.
     * @param amount The amount to repay.
     * @param user The user address for whom the repay is performed.
     */
    function bridgeAndRepay(
        MarketParams calldata market,
        uint256 amount,
        address user
    ) external payable {
        bytes memory data = abi.encode(uint8(2), market, amount, user, address(0));
        _sendMessage(data, 2, market, amount, user, address(0));
    }

    /**
     * @dev Sends a withdraw collateral message to Base via CCIP.
     * @param market The Morpho market parameters.
     * @param amount The amount of collateral to withdraw.
     * @param user The user address for whom the withdrawal is performed.
     * @param receiver The address to receive the withdrawn collateral on Base.
     */
    function bridgeAndWithdraw(
        MarketParams calldata market,
        uint256 amount,
        address user,
        address receiver
    ) external payable {
        bytes memory data = abi.encode(uint8(3), market, amount, user, receiver);
        _sendMessage(data, 3, market, amount, user, receiver);
    }

    /**
     * @dev Internal helper to build and send a CCIP message to Base.
     * @param data The encoded action and parameters.
     * @param action The action type (0=supply, 1=borrow, 2=repay, 3=withdraw).
     * @param market The Morpho market parameters.
     * @param amount The amount for the operation.
     * @param user The user address for whom the operation is performed.
     * @param receiver The receiver address for borrow/withdraw actions.
     */

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTION
    //////////////////////////////////////////////////////////////*/
    function _sendMessage(
        bytes memory data,
        uint8 action,
        MarketParams calldata market,
        uint256 amount,
        address user,
        address receiver
    ) internal {
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(baseReceiver),
            data: data,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            feeToken: address(0), //
            extraArgs: "" // Default extraArgs (200k gas limit)
        });
        uint256 fee = ccipRouter.getFee(baseChainSelector, message);
        require(msg.value >= fee, "Insufficient fee"); 
        ccipRouter.ccipSend{value: fee}(baseChainSelector, message);
        emit MessageSent(action, market, amount, user, receiver);
    }
} 