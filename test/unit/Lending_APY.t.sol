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
        return amount; // Simulate successful withdrawal of the requested amount
    }
    function repay(
        address /*asset*/,
        uint256 amount,
        uint256 /*interestRateMode*/,
        address /*onBehalfOf*/
    ) external pure returns (uint256) {
        // Simulate successful repay by returning the amount
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

contract LendingAPYAggregatorTest is Test {
    LendingAPYAggregator aggregator;
    address owner = 0x5FbDB2315678afecb367f032d93F642f64180aa3; //Anvil address
    TestERC20 token;
    MockAavePool mockAavePool;
    MockMorphoSender mockMorphoSender;

    modifier withInitializedToken() {
        token = new TestERC20();
        token.initialize("Test Token", "TST", 18);
        _;
    }

    function setUp() public {
        mockAavePool = new MockAavePool();
        mockMorphoSender = new MockMorphoSender();
        vm.prank(owner);
        aggregator = new LendingAPYAggregator(
            address(mockAavePool),
            address(mockMorphoSender),
            owner
        );
    }

    function testAddSupportedAsset() public withInitializedToken {
        // Act: add the new token as a supported asset
        vm.prank(owner);
        aggregator.addSupportedAsset(address(token));

        // Assert: supportedAssets mapping is updated
        assertTrue(aggregator.supportedAssets(address(token)));

        // Assert: assetList contains the new token
        address[] memory assets = aggregator.getSupportedAssets();
        bool found = false;
        for (uint i = 0; i < assets.length; i++) {
            if (assets[i] == address(token)) {
                found = true;
                break;
            }
        }
        assertTrue(found, "New token should be in assetList");
    }

    function testRemoveSupportedAsset() public withInitializedToken {
        // Add the token as a supported asset
        vm.prank(owner);
        aggregator.addSupportedAsset(address(token));

        // Act: remove the token
        vm.prank(owner);
        aggregator.removeSupportedAsset(address(token));

        // Assert: supportedAssets mapping is updated
        assertFalse(aggregator.supportedAssets(address(token)));

        // Assert: assetList does not contain the token
        address[] memory assets = aggregator.getSupportedAssets();
        bool found = false;
        for (uint i = 0; i < assets.length; i++) {
            if (assets[i] == address(token)) {
                found = true;
                break;
            }
        }
        assertFalse(found, "Token should not be in assetList after removal");
    }

    function testSupplyToAave() public withInitializedToken {
        address user = address(0x2);
        uint256 amount = 1000 ether;

        // Add the token as a supported asset
        vm.prank(owner);
        aggregator.addSupportedAsset(address(token));

        // Mint tokens to the user and approve aggregator
        token.mint(user, amount);
        vm.prank(user);
        token.approve(address(aggregator), amount);

        // Call supplyToAave from the user
        vm.prank(user);
        vm.expectEmit(true, true, false, true);
        emit LendingAPYAggregator.SupplyExecuted(user, address(token), amount, true);
        aggregator.supplyToAave(address(token), amount);

        // Assert: user's position is updated
        (uint256 aaveSupplied,, uint256 morphoSupplied,, uint256 lastUpdate) = aggregator.userPositions(user, address(token));
        assertEq(aaveSupplied, amount);
        assertEq(morphoSupplied, 0);
        assertTrue(lastUpdate > 0);
    }

    function testSupplyToMorpho() public withInitializedToken {
        address user = address(0x3);
        uint256 amount = 500 ether;
        vm.prank(owner);
        aggregator.addSupportedAsset(address(token));
        // Set dummy MarketParams for the token
        MarketParams memory params = MarketParams(address(1), address(2), address(3), address(4), 5);
        vm.prank(owner);
        aggregator.setMorphoMarketParams(address(token), params);
        token.mint(user, amount);
        vm.prank(user);
        token.approve(address(aggregator), amount);
        vm.prank(user);
        vm.expectEmit(true, true, false, true);
        emit LendingAPYAggregator.SupplyExecuted(user, address(token), amount, false);
        aggregator.supplyToMorpho{value: 0}(address(token), amount);
        (uint256 aaveSupplied,, uint256 morphoSupplied,, uint256 lastUpdate) = aggregator.userPositions(user, address(token));
        assertEq(aaveSupplied, 0);
        assertEq(morphoSupplied, amount);
        assertTrue(lastUpdate > 0);
    }

    function testBorrowFromAave() public withInitializedToken {
        address user = address(0x4);
        uint256 amount = 200 ether;
        
        vm.prank(owner);
        aggregator.addSupportedAsset(address(token));
        vm.prank(user);
        vm.expectEmit(true, true, false, true);
        emit LendingAPYAggregator.BorrowExecuted(user, address(token), amount, true);
        aggregator.borrowFromAave(address(token), amount);
        (, uint256 aaveBorrowed, , uint256 morphoBorrowed, uint256 lastUpdate) = aggregator.userPositions(user, address(token));
        assertEq(aaveBorrowed, amount);
        assertEq(morphoBorrowed, 0);
        assertTrue(lastUpdate > 0);
    }

    function testBorrowFromMorpho() public withInitializedToken {
        address user = address(0x6);
        uint256 amount = 300 ether;
        address receiver = address(0x7);
        vm.prank(owner);
        aggregator.addSupportedAsset(address(token));
        MarketParams memory params = MarketParams(address(1), address(2), address(3), address(4), 5);
        vm.prank(owner);
        aggregator.setMorphoMarketParams(address(token), params);
        vm.prank(user);
        vm.expectEmit(true, true, false, true);
        emit LendingAPYAggregator.BorrowExecuted(user, address(token), amount, false);
        aggregator.borrowFromMorpho{value: 0}(address(token), amount, receiver);
        (, uint256 aaveBorrowed, , uint256 morphoBorrowed, uint256 lastUpdate) = aggregator.userPositions(user, address(token));
        assertEq(aaveBorrowed, 0);
        assertEq(morphoBorrowed, amount);
        assertTrue(lastUpdate > 0);
    }

    function testGetAggregatorUserPosition() public withInitializedToken {
        address user = address(0x8);
        uint256 supplyAave = 100 ether;
        uint256 supplyMorpho = 200 ether;
        uint256 borrowAave = 50 ether;
        uint256 borrowMorpho = 75 ether;
        address receiver = address(0x9);

        vm.prank(owner);
        aggregator.addSupportedAsset(address(token));
        MarketParams memory params = MarketParams(address(1), address(2), address(3), address(4), 5);
        vm.prank(owner);
        aggregator.setMorphoMarketParams(address(token), params);

        // Mint and approve for user
        token.mint(user, supplyAave + supplyMorpho);
        vm.prank(user);
        token.approve(address(aggregator), type(uint256).max);

        // Supply to Aave
        vm.prank(user);
        aggregator.supplyToAave(address(token), supplyAave);
        // Supply to Morpho
        vm.prank(user);
        aggregator.supplyToMorpho{value: 0}(address(token), supplyMorpho);
        // Borrow from Aave
        vm.prank(user);
        aggregator.borrowFromAave(address(token), borrowAave);
        // Borrow from Morpho
        vm.prank(user);
        aggregator.borrowFromMorpho{value: 0}(address(token), borrowMorpho, receiver);

        (
            uint256 aaveSupplied,
            uint256 aaveBorrowed,
            uint256 morphoSupplied,
            uint256 morphoBorrowed,
            uint256 lastUpdate
        ) = aggregator.getAggregatorUserPosition(user, address(token));

        assertEq(aaveSupplied, supplyAave);
        assertEq(aaveBorrowed, borrowAave);
        assertEq(morphoSupplied, supplyMorpho);
        assertEq(morphoBorrowed, borrowMorpho);
        assertTrue(lastUpdate > 0);
    }

    function testGetSupportedAssets() public withInitializedToken {
        // Arrange: deploy and initialize a second token
        TestERC20 token2 = new TestERC20();
        token2.initialize("Second Token", "TKN2", 18);

        // Add both tokens as supported assets
        vm.prank(owner);
        aggregator.addSupportedAsset(address(token));
        vm.prank(owner);
        aggregator.addSupportedAsset(address(token2));

        // Act: get supported assets
        address[] memory assets = aggregator.getSupportedAssets();

        // Assert: both tokens are present
        bool found1 = false;
        bool found2 = false;
        for (uint i = 0; i < assets.length; i++) {
            if (assets[i] == address(token)) found1 = true;
            if (assets[i] == address(token2)) found2 = true;
        }
        assertTrue(found1, "First token should be in supported assets");
        assertTrue(found2, "Second token should be in supported assets");
    }

    function testEmergencyWithdraw() public withInitializedToken {
        uint256 amount = 1000 ether;
        // Mint tokens to the aggregator contract
        token.mint(address(aggregator), amount);
        uint256 ownerBalanceBefore = token.balanceOf(owner);
        uint256 aggregatorBalanceBefore = token.balanceOf(address(aggregator));

        // Call emergencyWithdraw as the owner
        vm.prank(owner);
        aggregator.emergencyWithdraw(address(token), amount);

        uint256 ownerBalanceAfter = token.balanceOf(owner);
        uint256 aggregatorBalanceAfter = token.balanceOf(address(aggregator));

        assertEq(ownerBalanceAfter, ownerBalanceBefore + amount, "Owner should receive withdrawn tokens");
        assertEq(aggregatorBalanceAfter, aggregatorBalanceBefore - amount, "Aggregator balance should decrease");
    }

    function testOnlyOwnerCanCallOwnerFunctions() public withInitializedToken {
        address notOwner = address(0xDEAD);
        MarketParams memory params = MarketParams(address(1), address(2), address(3), address(4), 5);
        uint256 amount = 100 ether;
        // Try addSupportedAsset
        vm.prank(notOwner);
        vm.expectRevert();
        aggregator.addSupportedAsset(address(token));
        // Try removeSupportedAsset
        vm.prank(owner);
        aggregator.addSupportedAsset(address(token));
        vm.prank(notOwner);
        vm.expectRevert();
        aggregator.removeSupportedAsset(address(token));
        // Try setMorphoMarketParams
        vm.prank(notOwner);
        vm.expectRevert();
        aggregator.setMorphoMarketParams(address(token), params);
        // Try emergencyWithdraw
        token.mint(address(aggregator), amount);
        vm.prank(notOwner);
        vm.expectRevert();
        aggregator.emergencyWithdraw(address(token), amount);
    }

    function testSupplyToAaveUnsupportedAssetReverts() public withInitializedToken {
        address user = address(0x10);
        uint256 amount = 100 ether;
        vm.prank(user);
        vm.expectRevert();
        aggregator.supplyToAave(address(token), amount);
    }

    function testSupplyToAaveZeroAmountReverts() public withInitializedToken {
        address user = address(0x11);
        vm.prank(owner);
        aggregator.addSupportedAsset(address(token));
        vm.prank(user);
        vm.expectRevert();
        aggregator.supplyToAave(address(token), 0);
    }

    function testSupplyToAaveInsufficientBalanceReverts() public withInitializedToken {
        address user = address(0x12);
        uint256 amount = 100 ether;
        vm.prank(owner);
        aggregator.addSupportedAsset(address(token));
        // No minting to user, so balance is zero
        vm.prank(user);
        token.approve(address(aggregator), amount);
        vm.prank(user);
        vm.expectRevert();
        aggregator.supplyToAave(address(token), amount);
    }

    function testBorrowFromAaveZeroAmountReverts() public withInitializedToken {
        address user = address(0x13);
        vm.prank(owner);
        aggregator.addSupportedAsset(address(token));
        vm.prank(user);
        vm.expectRevert();
        aggregator.borrowFromAave(address(token), 0);
    }

    function testBorrowFromAaveUnsupportedAssetReverts() public withInitializedToken {
        address user = address(0x14);
        uint256 amount = 100 ether;
        vm.prank(user);
        vm.expectRevert();
        aggregator.borrowFromAave(address(token), amount);
    }

    function testUserPositionTracking() public withInitializedToken {
        address user = address(0x20);
        uint256 supplyAave = 100 ether;
        uint256 supplyMorpho = 50 ether;
        uint256 borrowAave = 30 ether;
        uint256 borrowMorpho = 20 ether;
        address receiver = address(0x21);

        vm.prank(owner);
        aggregator.addSupportedAsset(address(token));
        MarketParams memory params = MarketParams(address(1), address(2), address(3), address(4), 5);
        vm.prank(owner);
        aggregator.setMorphoMarketParams(address(token), params);

        // Mint and approve for user
        token.mint(user, supplyAave + supplyMorpho);
        vm.prank(user);
        token.approve(address(aggregator), type(uint256).max);

        // Supply to Aave
        vm.prank(user);
        aggregator.supplyToAave(address(token), supplyAave);
        // Supply to Morpho
        vm.prank(user);
        aggregator.supplyToMorpho{value: 0}(address(token), supplyMorpho);
        // Borrow from Aave
        vm.prank(user);
        aggregator.borrowFromAave(address(token), borrowAave);
        // Borrow from Morpho
        vm.prank(user);
        aggregator.borrowFromMorpho{value: 0}(address(token), borrowMorpho, receiver);

        (
            uint256 aaveSupplied,
            uint256 aaveBorrowed,
            uint256 morphoSupplied,
            uint256 morphoBorrowed,
            uint256 lastUpdate
        ) = aggregator.getAggregatorUserPosition(user, address(token));

        assertEq(aaveSupplied, supplyAave);
        assertEq(aaveBorrowed, borrowAave);
        assertEq(morphoSupplied, supplyMorpho);
        assertEq(morphoBorrowed, borrowMorpho);
        assertTrue(lastUpdate > 0);
    }

    function testSupplyAndBorrowEvents() public withInitializedToken {
        address user = address(0x22);
        uint256 supplyAmount = 123 ether;
        uint256 borrowAmount = 45 ether;
        address receiver = address(0x23);

        vm.prank(owner);
        aggregator.addSupportedAsset(address(token));
        MarketParams memory params = MarketParams(address(1), address(2), address(3), address(4), 5);
        vm.prank(owner);
        aggregator.setMorphoMarketParams(address(token), params);

        token.mint(user, supplyAmount);
        vm.prank(user);
        token.approve(address(aggregator), type(uint256).max);

        // Supply to Aave event
        vm.prank(user);
        vm.expectEmit(true, true, false, true);
        emit LendingAPYAggregator.SupplyExecuted(user, address(token), supplyAmount, true);
        aggregator.supplyToAave(address(token), supplyAmount);

        // Borrow from Morpho event
        vm.prank(user);
        vm.expectEmit(true, true, false, true);
        emit LendingAPYAggregator.BorrowExecuted(user, address(token), borrowAmount, false);
        aggregator.borrowFromMorpho{value: 0}(address(token), borrowAmount, receiver);
    }

    function testWithdrawFromAave() public withInitializedToken {
        address user = address(0x30);
        uint256 supplyAmount = 100 ether;
        uint256 withdrawAmount = 60 ether;

        vm.prank(owner);
        aggregator.addSupportedAsset(address(token));
        token.mint(user, supplyAmount);
        vm.prank(user);
        token.approve(address(aggregator), supplyAmount);
        vm.prank(user);
        aggregator.supplyToAave(address(token), supplyAmount);

        // Withdraw from Aave
        vm.prank(user);
        vm.expectEmit(true, true, false, true);
        emit LendingAPYAggregator.WithdrawExecuted(user, address(token), withdrawAmount, true);
        aggregator.withdrawFromAave(address(token), withdrawAmount);

        // Check aggregator position
        (uint256 aaveSupplied,,,,) = aggregator.getAggregatorUserPosition(user, address(token));
        assertEq(aaveSupplied, supplyAmount - withdrawAmount);
    }

    function testWithdrawFromMorpho() public withInitializedToken {
        address user = address(0x31);
        uint256 supplyAmount = 100 ether;
        uint256 withdrawAmount = 60 ether;
        address receiver = address(0x32);

        vm.prank(owner);
        aggregator.addSupportedAsset(address(token));
        MarketParams memory params = MarketParams(address(1), address(2), address(3), address(4), 5);
        vm.prank(owner);
        aggregator.setMorphoMarketParams(address(token), params);
        token.mint(user, supplyAmount);
        vm.prank(user);
        token.approve(address(aggregator), supplyAmount);
        vm.prank(user);
        aggregator.supplyToMorpho{value: 0}(address(token), supplyAmount);

        // Withdraw from Morpho
        vm.prank(user);
        vm.expectEmit(true, true, false, true);
        emit LendingAPYAggregator.WithdrawExecuted(user, address(token), withdrawAmount, false);
        aggregator.withdrawFromMorpho{value: 0}(address(token), withdrawAmount, receiver);

        // Check aggregator position
        ( , , uint256 morphoSupplied, , ) = aggregator.getAggregatorUserPosition(user, address(token));
        assertEq(morphoSupplied, supplyAmount - withdrawAmount);
    }

    function testRepayToAave() public withInitializedToken {
        address user = address(0x40);
        uint256 borrowAmount = 100 ether;
        uint256 repayAmount = 60 ether;

        // Add the token as a supported asset
        vm.prank(owner);
        aggregator.addSupportedAsset(address(token));

        // Simulate a borrow to set aaveBorrowed
        vm.prank(user);
        aggregator.borrowFromAave(address(token), borrowAmount);

        // Mint tokens to the user and approve aggregator for repayment
        token.mint(user, repayAmount);
        vm.prank(user);
        token.approve(address(aggregator), repayAmount);

        // Repay to Aave
        vm.prank(user);
        vm.expectEmit(true, true, false, true);
        emit LendingAPYAggregator.RepayExecuted(user, address(token), repayAmount, true);
        uint256 repaid = aggregator.repayToAave(address(token), repayAmount);

        // Check aggregator position
        (, uint256 aaveBorrowed, , , ) = aggregator.getAggregatorUserPosition(user, address(token));
        assertEq(aaveBorrowed, borrowAmount - repayAmount);
        assertEq(repaid, repayAmount);
    }

    function testRepayToMorpho() public withInitializedToken {
        address user = address(0x50);
        uint256 borrowAmount = 100 ether;
        uint256 repayAmount = 60 ether;

        // Add the token as a supported asset and set MarketParams
        vm.prank(owner);
        aggregator.addSupportedAsset(address(token));
        MarketParams memory params = MarketParams(address(1), address(2), address(3), address(4), 5);
        vm.prank(owner);
        aggregator.setMorphoMarketParams(address(token), params);

        // Simulate a borrow to set morphoBorrowed
        vm.prank(user);
        aggregator.borrowFromMorpho{value: 0}(address(token), borrowAmount, user);

        // Mint tokens to the user and approve aggregator for repayment
        token.mint(user, repayAmount);
        vm.prank(user);
        token.approve(address(aggregator), repayAmount);

        // Repay to Morpho
        vm.prank(user);
        vm.expectEmit(true, true, false, true);
        emit LendingAPYAggregator.RepayExecuted(user, address(token), repayAmount, false);
        uint256 repaid = aggregator.repayToMorpho{value: 0}(address(token), repayAmount);

        // Check aggregator position
        ( , , , uint256 morphoBorrowed, ) = aggregator.getAggregatorUserPosition(user, address(token));
        assertEq(morphoBorrowed, borrowAmount - repayAmount);
        assertEq(repaid, repayAmount);
    }
}
