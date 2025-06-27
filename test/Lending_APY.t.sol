// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {LendingAPYAggregator} from "src/LendingAPYAggregator.sol";

// Import the APYComparison struct for use in tests
import {APYComparison} from "src/LendingAPYAggregator.sol";

// Import the main contract (assuming it's in src/ directory)
// import "../src/LendingAPYAggregator.sol";

// For testing purposes, we'll include the interfaces and contract here
// In real implementation, you'd import from separate files

interface IPool {
    struct ReserveData {
        uint256 configuration;
        uint128 liquidityIndex;
        uint128 currentLiquidityRate;
        uint128 variableBorrowIndex;
        uint128 currentVariableBorrowRate;
        uint128 currentStableBorrowRate;
        uint40 lastUpdateTimestamp;
        uint16 id;
        address aTokenAddress;
        address stableDebtTokenAddress;
        address variableDebtTokenAddress;
        address interestRateStrategyAddress;
        uint128 accruedToTreasury;
        uint128 unbacked;
        uint128 isolationModeTotalDebt;
    }

    function getReserveData(address asset) external view returns (ReserveData memory);
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf)
        external;
    function repay(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf)
        external
        returns (uint256);
    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );
}

interface IMorphoCrossChainBridge {
    function getSupplyAPY(address asset) external view returns (uint256);
    function getBorrowAPY(address asset) external view returns (uint256);
    function bridgeAndSupply(address asset, uint256 amount, address onBehalfOf, bytes calldata bridgeData) external;
    function bridgeAndBorrow(address asset, uint256 amount, address onBehalfOf, bytes calldata bridgeData) external;
    function withdrawAndBridge(address asset, uint256 amount, address to, bytes calldata bridgeData) external;
    function repayAndBridge(address asset, uint256 amount, address onBehalfOf, bytes calldata bridgeData) external;
    function estimateBridgeFee(address asset, uint256 amount) external view returns (uint256);
}

// Mock ERC20 Token for testing
contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10 ** 18); // Mint 1M tokens
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

// Mock Aave Pool
contract MockAavePool is IPool {
    mapping(address => ReserveData) private reserveData;
    mapping(address => mapping(address => uint256)) private userSupplied;
    mapping(address => mapping(address => uint256)) private userBorrowed;

    // Mock APY rates (in RAY format - 1e27)
    uint128 public constant MOCK_SUPPLY_RATE = 5e25; // 5% APY
    uint128 public constant MOCK_BORROW_RATE = 8e25; // 8% APY

    function setReserveData(address asset) external {
        reserveData[asset] = ReserveData({
            configuration: 0,
            liquidityIndex: 1e27,
            currentLiquidityRate: MOCK_SUPPLY_RATE,
            variableBorrowIndex: 1e27,
            currentVariableBorrowRate: MOCK_BORROW_RATE,
            currentStableBorrowRate: MOCK_BORROW_RATE + 1e25,
            lastUpdateTimestamp: uint40(block.timestamp),
            id: 1,
            aTokenAddress: address(0),
            stableDebtTokenAddress: address(0),
            variableDebtTokenAddress: address(0),
            interestRateStrategyAddress: address(0),
            accruedToTreasury: 0,
            unbacked: 0,
            isolationModeTotalDebt: 0
        });
    }

    function getReserveData(address asset) external view override returns (ReserveData memory) {
        return reserveData[asset];
    }

    function supply(address asset, uint256 amount, address onBehalfOf, uint16) external override {
        MockToken(asset).transferFrom(msg.sender, address(this), amount);
        userSupplied[onBehalfOf][asset] += amount;
    }

    function withdraw(address asset, uint256 amount, address to) external override returns (uint256) {
        require(userSupplied[msg.sender][asset] >= amount, "Insufficient balance");
        userSupplied[msg.sender][asset] -= amount;
        MockToken(asset).transfer(to, amount);
        return amount;
    }

    function borrow(address asset, uint256 amount, uint256, uint16, address onBehalfOf) external override {
        userBorrowed[onBehalfOf][asset] += amount;
        MockToken(asset).transfer(onBehalfOf, amount);
    }

    function repay(address asset, uint256 amount, uint256, address onBehalfOf) external override returns (uint256) {
        MockToken(asset).transferFrom(msg.sender, address(this), amount);
        if (userBorrowed[onBehalfOf][asset] >= amount) {
            userBorrowed[onBehalfOf][asset] -= amount;
            return amount;
        } else {
            uint256 repayAmount = userBorrowed[onBehalfOf][asset];
            userBorrowed[onBehalfOf][asset] = 0;
            return repayAmount;
        }
    }

    function getUserAccountData(address user)
        external
        view
        override
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        )
    {
        // Mock data
        totalCollateralBase = 1000e18;
        totalDebtBase = 500e18;
        availableBorrowsBase = 400e18;
        currentLiquidationThreshold = 8000; // 80%
        ltv = 7500; // 75%
        healthFactor = 2e18; // 2.0
    }
}

// Mock Morpho Bridge
contract MockMorphoBridge is IMorphoCrossChainBridge {
    uint256 public constant MOCK_SUPPLY_APY = 6e18; // 6% APY (in 1e18 format)
    uint256 public constant MOCK_BORROW_APY = 7e18; // 7% APY (in 1e18 format)
    uint256 public constant MOCK_BRIDGE_FEE = 5e6; // $5 equivalent in 1e6 format

    mapping(address => mapping(address => uint256)) private userSupplied;
    mapping(address => mapping(address => uint256)) private userBorrowed;

    function getSupplyAPY(address) external pure override returns (uint256) {
        return MOCK_SUPPLY_APY;
    }

    function getBorrowAPY(address) external pure override returns (uint256) {
        return MOCK_BORROW_APY;
    }

    function bridgeAndSupply(address asset, uint256 amount, address onBehalfOf, bytes calldata) external override {
        MockToken(asset).transferFrom(msg.sender, address(this), amount);
        userSupplied[onBehalfOf][asset] += amount;
    }

    function bridgeAndBorrow(address asset, uint256 amount, address onBehalfOf, bytes calldata) external override {
        userBorrowed[onBehalfOf][asset] += amount;
        MockToken(asset).transfer(onBehalfOf, amount);
    }

    function withdrawAndBridge(address asset, uint256 amount, address to, bytes calldata) external override {
        require(userSupplied[msg.sender][asset] >= amount, "Insufficient balance");
        userSupplied[msg.sender][asset] -= amount;
        MockToken(asset).transfer(to, amount);
    }

    function repayAndBridge(address asset, uint256 amount, address onBehalfOf, bytes calldata) external override {
        MockToken(asset).transferFrom(msg.sender, address(this), amount);
        if (userBorrowed[onBehalfOf][asset] >= amount) {
            userBorrowed[onBehalfOf][asset] -= amount;
        } else {
            userBorrowed[onBehalfOf][asset] = 0;
        }
    }

    function estimateBridgeFee(address, uint256) external pure override returns (uint256) {
        return MOCK_BRIDGE_FEE;
    }
}

// Include the main contract here (copy from your provided code)
// [The LendingAPYAggregator contract code would go here]
// For brevity, I'll assume it's imported or included

contract LendingAPYAggregatorTest is Test {
    LendingAPYAggregator aggregator;
    MockToken usdc;
    MockToken usdt;
    MockAavePool aavePool;
    MockMorphoBridge morphoBridge;

    address owner = address(0x1);
    address user1 = address(0x2);
    address user2 = address(0x3);

    uint256 constant INITIAL_BALANCE = 10000e6; // 10,000 USDC
    bytes constant EMPTY_BRIDGE_DATA = "";

    function setUp() public {
        // Deploy mock tokens
        usdc = new MockToken("USD Coin", "USDC");
        usdt = new MockToken("Tether USD", "USDT");

        // Deploy mock protocols
        aavePool = new MockAavePool();
        morphoBridge = new MockMorphoBridge();

        // Set up reserve data for tokens
        aavePool.setReserveData(address(usdc));
        aavePool.setReserveData(address(usdt));

        // Deploy main contract
        vm.prank(owner);
        aggregator = new LendingAPYAggregator(address(aavePool), address(morphoBridge), owner);

        // Add supported assets
        vm.startPrank(owner);
        aggregator.addSupportedAsset(address(usdc));
        aggregator.addSupportedAsset(address(usdt));
        vm.stopPrank();

        // Fund users
        usdc.mint(user1, INITIAL_BALANCE);
        usdc.mint(user2, INITIAL_BALANCE);
        usdt.mint(user1, INITIAL_BALANCE);
        usdt.mint(user2, INITIAL_BALANCE);

        // Fund mock pools for borrowing
        usdc.mint(address(aavePool), INITIAL_BALANCE * 10);
        usdc.mint(address(morphoBridge), INITIAL_BALANCE * 10);
        usdt.mint(address(aavePool), INITIAL_BALANCE * 10);
        usdt.mint(address(morphoBridge), INITIAL_BALANCE * 10);

        // Approve tokens for users
        vm.prank(user1);
        usdc.approve(address(aggregator), type(uint256).max);
        vm.prank(user1);
        usdt.approve(address(aggregator), type(uint256).max);
        vm.prank(user2);
        usdc.approve(address(aggregator), type(uint256).max);
        vm.prank(user2);
        usdt.approve(address(aggregator), type(uint256).max);
    }

    // Test basic setup and initialization
    function testInitialization() public {
        assertEq(address(aggregator.aavePool()), address(aavePool));
        assertEq(address(aggregator.morphoBridge()), address(morphoBridge));
        assertTrue(aggregator.supportedAssets(address(usdc)));
        assertTrue(aggregator.supportedAssets(address(usdt)));
    }

    // Test asset management
    function testAddSupportedAsset() public {
        MockToken newToken = new MockToken("DAI", "DAI");

        vm.prank(owner);
        aggregator.addSupportedAsset(address(newToken));

        assertTrue(aggregator.supportedAssets(address(newToken)));

        address[] memory assets = aggregator.getSupportedAssets();
        bool found = false;
        for (uint256 i = 0; i < assets.length; i++) {
            if (assets[i] == address(newToken)) {
                found = true;
                break;
            }
        }
        assertTrue(found);
    }

    function testRemoveSupportedAsset() public {
        vm.prank(owner);
        aggregator.removeSupportedAsset(address(usdt));

        assertFalse(aggregator.supportedAssets(address(usdt)));

        address[] memory assets = aggregator.getSupportedAssets();
        for (uint256 i = 0; i < assets.length; i++) {
            assertNotEq(assets[i], address(usdt));
        }
    }

    function testOnlyOwnerCanManageAssets() public {
        MockToken newToken = new MockToken("DAI", "DAI");

        vm.prank(user1);
        vm.expectRevert();
        aggregator.addSupportedAsset(address(newToken));

        vm.prank(user1);
        vm.expectRevert();
        aggregator.removeSupportedAsset(address(usdc));
    }
    // Test APY comparison functionality
    function testGetAPYComparison() public {
        APYComparison memory comparison = aggregator.getAPYComparison(address(usdc));

        // Aave: 5% supply, 8% borrow
        // Morpho: 6% supply, 7% borrow
        assertEq(comparison.aaveSupplyAPY, 5e16); // 5% in 1e18 format
        assertEq(comparison.aaveBorrowAPY, 8e16); // 8% in 1e18 format
        assertEq(comparison.morphoSupplyAPY, 6e18); // 6% in 1e18 format
        assertEq(comparison.morphoBorrowAPY, 7e18); // 7% in 1e18 format

        // Morpho should be better for supply (6% > 5%)
        assertFalse(comparison.aaveBetterForSupply);
        // Morpho should be better for borrow (7% < 8%)
        assertFalse(comparison.aaveBetterForBorrow);

        assertEq(comparison.bridgeFee, 5e6); // $5 bridge fee
    }

    function testGetAPYComparisonUnsupportedAsset() public {
        MockToken unsupportedToken = new MockToken("WETH", "WETH");

        vm.expectRevert();
        aggregator.getAPYComparison(address(unsupportedToken));
    }

    // Test best protocol selection
    function testGetBestSupplyProtocol() public {
        uint256 amount = 1000e6; // 1000 USDC
        (bool useAave, uint256 netAPY) = aggregator.getBestSupplyProtocol(address(usdc), amount);

        // Morpho has better supply APY (6% vs 5%), and bridge cost is minimal
        assertFalse(useAave);
        // Net APY should be Morpho APY minus bridge cost percentage
        uint256 expectedBridgeCostPercentage = (5e6 * 1e18) / amount; // Bridge fee as percentage
        uint256 expectedNetAPY = 6e18 - expectedBridgeCostPercentage;
        assertEq(netAPY, expectedNetAPY);
    }

    function testGetBestBorrowProtocol() public {
        uint256 amount = 1000e6; // 1000 USDC
        (bool useAave, uint256 netAPY) = aggregator.getBestBorrowProtocol(address(usdc), amount);

        // Morpho has better borrow APY (7% vs 8%)
        assertFalse(useAave);
        // Net APY should be Morpho APY plus bridge cost percentage
        uint256 expectedBridgeCostPercentage = (5e6 * 1e18) / amount;
        uint256 expectedNetAPY = 7e18 + expectedBridgeCostPercentage;
        assertEq(netAPY, expectedNetAPY);
    }

    // Test supply functionality
    function testSupplyToBest() public {
        uint256 amount = 1000e6;
        uint256 initialBalance = usdc.balanceOf(user1);

        vm.prank(user1);
        aggregator.supplyToBest(address(usdc), amount, EMPTY_BRIDGE_DATA);

        // Check user balance decreased
        assertEq(usdc.balanceOf(user1), initialBalance - amount);

        // Check position was recorded (should use Morpho based on our mock data)
        (uint256 aaveSupplied,, uint256 morphoSupplied,, uint256 lastUpdate) =
            aggregator.userPositions(user1, address(usdc));

        assertEq(aaveSupplied, 0);
        assertEq(morphoSupplied, amount);
        assertEq(lastUpdate, block.timestamp);
    }

    // function testManualSupplyToAave() public {
    //     uint256 amount = 1000e6;

    //     vm.prank(user1);
    //     aggregator.supply(address(usdc), amount, true, EMPTY_BRIDGE_DATA);

    //     (uint256 aaveSupplied,, uint256 morphoSupplied,,) = aggregator.userPositions(user1, address(usdc));

    //     assertEq(aaveSupplied, amount);
    //     assertEq(morphoSupplied, 0);
    // }

    // function testManualSupplyToMorpho() public {
    //     uint256 amount = 1000e6;

    //     vm.prank(user1);
    //     aggregator.supply(address(usdc), amount, false, EMPTY_BRIDGE_DATA);

    //     (uint256 aaveSupplied,, uint256 morphoSupplied,,) = aggregator.userPositions(user1, address(usdc));

    //     assertEq(aaveSupplied, 0);
    //     assertEq(morphoSupplied, amount);
    // }

    // Test borrow functionality
    function testBorrowFromBest() public {
        uint256 amount = 500e6;
        uint256 initialBalance = usdc.balanceOf(user1);

        vm.prank(user1);
        aggregator.borrowFromBest(address(usdc), amount, EMPTY_BRIDGE_DATA);

        // Check user balance increased
        assertEq(usdc.balanceOf(user1), initialBalance + amount);

        // Check position was recorded (should use Morpho based on our mock data)
        (, uint256 aaveBorrowed,, uint256 morphoBorrowed,) = aggregator.userPositions(user1, address(usdc));

        assertEq(aaveBorrowed, 0);
        assertEq(morphoBorrowed, amount);
    }

    //function testManualBorrowFromAave() public {
    //     uint256 amount = 500e6;

    //     vm.prank(user1);
    //     aggregator.borrow(address(usdc), amount, true, EMPTY_BRIDGE_DATA);

    //     (, uint256 aaveBorrowed,, uint256 morphoBorrowed,) = aggregator.userPositions(user1, address(usdc));

    //     assertEq(aaveBorrowed, amount);
    //     assertEq(morphoBorrowed, 0);
    // }

    // Test error conditions
    function testSupplyUnsupportedAsset() public {
        MockToken unsupportedToken = new MockToken("WETH", "WETH");

        vm.prank(user1);
        vm.expectRevert();
        aggregator.supplyToBest(address(unsupportedToken), 1000e18, EMPTY_BRIDGE_DATA);
    }

    function testSupplyZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert();
        aggregator.supplyToBest(address(usdc), 0, EMPTY_BRIDGE_DATA);
    }

    function testBorrowZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert();
        aggregator.borrowFromBest(address(usdc), 0, EMPTY_BRIDGE_DATA);
    }

    function testInsufficientBalance() public {
        uint256 amount = INITIAL_BALANCE + 1; // More than user has

        vm.prank(user1);
        vm.expectRevert();
        aggregator.supplyToBest(address(usdc), amount, EMPTY_BRIDGE_DATA);
    }

    // Test user account data
    function testGetUserAccountData() public {
        (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        ) = aggregator.getUserAccountData(user1);

        // Check mock values
        assertEq(totalCollateralBase, 1000e18);
        assertEq(totalDebtBase, 500e18);
        assertEq(availableBorrowsBase, 400e18);
        assertEq(currentLiquidationThreshold, 8000);
        assertEq(ltv, 7500);
        assertEq(healthFactor, 2e18);
    }

    // Test emergency functions
    function testEmergencyWithdraw() public {
        uint256 amount = 100e6;
        usdc.mint(address(aggregator), amount);

        vm.prank(owner);
        aggregator.emergencyWithdraw(address(usdc), amount);

        assertEq(usdc.balanceOf(owner), amount);
    }

    function testEmergencyWithdrawOnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        aggregator.emergencyWithdraw(address(usdc), 100e6);
    }

    // Test events
    function testSupplyEmitsEvent() public {
        uint256 amount = 1000e6;

        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit SupplyExecuted(user1, address(usdc), amount, false); // Should use Morpho
        aggregator.supplyToBest(address(usdc), amount, EMPTY_BRIDGE_DATA);
    }

    function testBorrowEmitsEvent() public {
        uint256 amount = 500e6;

        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit BorrowExecuted(user1, address(usdc), amount, false); // Should use Morpho
        aggregator.borrowFromBest(address(usdc), amount, EMPTY_BRIDGE_DATA);
    }

    // Test multiple operations
    function testMultipleOperations() public {
        uint256 supplyAmount = 1000e6;
        uint256 borrowAmount = 500e6;

        // Supply to best protocol
        vm.prank(user1);
        aggregator.supplyToBest(address(usdc), supplyAmount, EMPTY_BRIDGE_DATA);

        // Borrow from best protocol
        vm.prank(user1);
        aggregator.borrowFromBest(address(usdc), borrowAmount, EMPTY_BRIDGE_DATA);

        // Check final positions
        (uint256 aaveSupplied, uint256 aaveBorrowed, uint256 morphoSupplied, uint256 morphoBorrowed,) =
            aggregator.userPositions(user1, address(usdc));

        // Both should use Morpho based on our mock rates
        assertEq(aaveSupplied, 0);
        assertEq(aaveBorrowed, 0);
        assertEq(morphoSupplied, supplyAmount);
        assertEq(morphoBorrowed, borrowAmount);
    }

    // Events for testing
    event SupplyExecuted(address indexed user, address indexed asset, uint256 amount, bool useAave);
    event BorrowExecuted(address indexed user, address indexed asset, uint256 amount, bool useAave);
}

// Additional test contract for edge cases and complex scenarios
contract LendingAPYAggregatorAdvancedTest is Test {
// Additional advanced tests can be added here
// Such as:
// - Fuzzing tests
// - Integration tests with real protocol behaviors
// - Gas optimization tests
// - Complex multi-user scenarios
// - Bridge failure scenarios
}
