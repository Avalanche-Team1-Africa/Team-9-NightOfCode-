// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IMorpho, MarketParams} from "@morpho-blue/interfaces/IMorpho.sol";
import {CCIPReceiver} from "@chainlink/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/ccip/libraries/Client.sol";

/**
 * @dev Receives and processes cross-chain messages from Avalanche via Chainlink CCIP for Morpho protocol operations on Base.
 *      Decodes the message and calls the appropriate Morpho function based on the action type.
 */
contract BaseMorphoCCIPReceiver is CCIPReceiver {
     /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    IMorpho public immutable morpho;
    address public immutable trustedSender;

    /**
     * @dev Emitted when a message is received and processed.
     * @param action The action type (0=supply, 1=borrow, 2=repay, 3=withdraw).
     * @param market The Morpho market parameters.
     * @param amount The amount for the operation.
     * @param user The user address for whom the operation is performed.
     * @param receiver The receiver address for borrow/withdraw actions.
     */
    event MessageReceived(uint8 action, MarketParams market, uint256 amount, address user, address receiver);

    /**
     * @dev Reverts if the message sender is not the trusted sender contract on Avalanche.
     * @param sender The address of the unauthorized sender.
     */
    error UnauthorizedSender(address sender);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Initializes the receiver with the CCIP router, Morpho contract, and trusted sender address.
     * @param _router The address of the Chainlink CCIP router on Base.
     * @param _morpho The address of the Morpho protocol contract on Base.
     * @param _trustedSender The address of the trusted sender contract on Avalanche.
     */
    constructor(
        address _router,
        address _morpho,
        address _trustedSender
    ) CCIPReceiver(_router) {
        morpho = IMorpho(_morpho);
        trustedSender = _trustedSender;
    }

    /**
     * @dev Handles incoming CCIP messages, decodes the action and parameters, and calls the appropriate Morpho function.
     * @param message The CCIP message containing the encoded action and parameters.
     */

    /*//////////////////////////////////////////////////////////////
                                FUNCTION
    //////////////////////////////////////////////////////////////*/
    function _ccipReceive(
        Client.Any2EVMMessage memory message
    ) internal override {
        if (abi.decode(message.sender, (address)) != trustedSender) {
            revert UnauthorizedSender(abi.decode(message.sender, (address)));
        }

        // Decode: (uint8 action, MarketParams market, uint256 amount, address user, address receiver)
        (uint8 action, MarketParams memory market, uint256 amount, address user, address receiver) = abi.decode(
            message.data, (uint8, MarketParams, uint256, address, address)
        );

        emit MessageReceived(action, market, amount, user, receiver);

        if (action == 0) {
            // Supply collateral
            morpho.supplyCollateral(market, amount, user, "");
        } else if (action == 1) {
            // Borrow
            morpho.borrow(market, amount, 0, user, receiver);
        } else if (action == 2) {
            // Repay
            morpho.repay(market, amount, 0, user, "");
        } else if (action == 3) {
            // Withdraw collateral
            morpho.withdrawCollateral(market, amount, user, receiver);
        } else {
            revert("Unknown action");
        }
    }
}