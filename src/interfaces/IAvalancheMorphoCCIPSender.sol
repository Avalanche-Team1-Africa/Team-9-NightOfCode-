// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MarketParams} from "lib/morpho-blue/src/interfaces/IMorpho.sol";

interface IAvalancheMorphoCCIPSender {
    function bridgeAndSupply(MarketParams calldata market, uint256 amount, address user) external payable;
    function bridgeAndBorrow(MarketParams calldata market, uint256 amount, address user, address receiver) external payable;
    function bridgeAndRepay(MarketParams calldata market, uint256 amount, address user) external payable;
    function bridgeAndWithdraw(MarketParams calldata market, uint256 amount, address user, address receiver) external payable;
    // ... any other view functions you want to expose
}
