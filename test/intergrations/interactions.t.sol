// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {LendingAPYAggregator} from "src/LendingAPYAggregator.sol";
import {MockERC20} from "lib/chainlink/contracts/src/v0.8/vendor/forge-std/src/mocks/MockERC20.sol";
import {MarketParams} from "lib/morpho-blue/src/interfaces/IMorpho.sol";

// Minimal mock Aave pool for testing
contract MockAavePool {
    event Supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode);
    event Borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf);
    event Withdraw(address asset, uint256 amount, address to);
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external {
        emit Supply(asset, amount, onBehalfOf, referralCode);
    }
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) external {
        emit Borrow(asset, amount, interestRateMode, referralCode, onBehalfOf);
    }
    function withdraw(address asset, uint256 amount, address to) external returns (uint256) {
        emit Withdraw(asset, amount, to);
        return amount;
    }
    function repay(
        address /*asset*/,
        uint256 amount,
        uint256 /*interestRateMode*/,
        address /*onBehalfOf*/
    ) external pure returns (uint256) {
        return amount;
    }
}

// Extend MockERC20 to add a public mint function for testing
contract TestERC20 is MockERC20 {
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

// Minimal mock Morpho sender for testing
contract MockMorphoSender {
    event BridgeAndSupply(bytes32 marketHash, uint256 amount, address user);
    event BridgeAndBorrow(bytes32 marketHash, uint256 amount, address user, address receiver);
    event BridgeAndWithdraw(bytes32 marketHash, uint256 amount, address user, address receiver);
    event BridgeAndRepay(bytes32 marketHash, uint256 amount, address user);
    function bridgeAndSupply(MarketParams memory market, uint256 amount, address user) external payable {
        emit BridgeAndSupply(keccak256(abi.encode(market)), amount, user);
    }
    function bridgeAndBorrow(MarketParams memory market, uint256 amount, address user, address receiver) external payable {
        emit BridgeAndBorrow(keccak256(abi.encode(market)), amount, user, receiver);
    }
    function bridgeAndWithdraw(MarketParams memory market, uint256 amount, address user, address receiver) external payable {
        emit BridgeAndWithdraw(keccak256(abi.encode(market)), amount, user, receiver);
    }
    function bridgeAndRepay(MarketParams memory market, uint256 amount, address user) external payable {
        emit BridgeAndRepay(keccak256(abi.encode(market)), amount, user);
    }
}

contract IntegrationTest is Test {
    LendingAPYAggregator aggregator;
    TestERC20 token;
    address owner = address(0x1);
    address user = address(0x2);
    MockAavePool mockAavePool;
    MockMorphoSender mockMorphoSender;

    function setUp() public {
        mockAavePool = new MockAavePool();
        mockMorphoSender = new MockMorphoSender();
        aggregator = new LendingAPYAggregator(address(mockAavePool), address(mockMorphoSender), owner);

        // Deploy and initialize token
        token = new TestERC20();
        token.initialize("Test Token", "TST", 18);

        // Add supported asset and set MarketParams for Morpho
        vm.prank(owner);
        aggregator.addSupportedAsset(address(token));
        MarketParams memory params = MarketParams(address(1), address(2), address(3), address(4), 5);
        vm.prank(owner);
        aggregator.setMorphoMarketParams(address(token), params);

        // Mint tokens to user and approve aggregator
        token.mint(user, 1000 ether);
        vm.prank(user);
        token.approve(address(aggregator), type(uint256).max);
    }

    function testFullAaveFlow() public {
        uint256 supplyAmount = 100 ether;
        uint256 borrowAmount = 50 ether;
        uint256 repayAmount = 30 ether;
        uint256 withdrawAmount = 20 ether;

        // Supply to Aave
        vm.prank(user);
        aggregator.supplyToAave(address(token), supplyAmount);

        // Borrow from Aave
        vm.prank(user);
        aggregator.borrowFromAave(address(token), borrowAmount);

        // Repay to Aave
        token.mint(user, repayAmount);
        vm.prank(user);
        aggregator.repayToAave(address(token), repayAmount);

        // Withdraw from Aave
        vm.prank(user);
        aggregator.withdrawFromAave(address(token), withdrawAmount);

        // Assert final position
        (uint256 aaveSupplied, uint256 aaveBorrowed, , , ) = aggregator.getAggregatorUserPosition(user, address(token));
        assertEq(aaveSupplied, supplyAmount - withdrawAmount);
        assertEq(aaveBorrowed, borrowAmount - repayAmount);
    }

    function testFullMorphoFlow() public {
        uint256 supplyAmount = 200 ether;
        uint256 borrowAmount = 80 ether;
        uint256 repayAmount = 50 ether;
        uint256 withdrawAmount = 40 ether;

        // Supply to Morpho
        vm.prank(user);
        aggregator.supplyToMorpho{value: 0}(address(token), supplyAmount);

        // Borrow from Morpho
        vm.prank(user);
        aggregator.borrowFromMorpho{value: 0}(address(token), borrowAmount, user);

        // Repay to Morpho
        token.mint(user, repayAmount);
        vm.prank(user);
        aggregator.repayToMorpho{value: 0}(address(token), repayAmount);

        // Withdraw from Morpho
        vm.prank(user);
        aggregator.withdrawFromMorpho{value: 0}(address(token), withdrawAmount, user);

        // Assert final position
        (, , uint256 morphoSupplied, uint256 morphoBorrowed, ) = aggregator.getAggregatorUserPosition(user, address(token));
        assertEq(morphoSupplied, supplyAmount - withdrawAmount);
        assertEq(morphoBorrowed, borrowAmount - repayAmount);
    }
}
