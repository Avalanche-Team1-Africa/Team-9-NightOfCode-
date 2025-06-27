// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
//import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";

/**
 * @title LendingAPYAggregator
 * @dev Aggregates lending/borrowing APYs from Aave V3 (Avalanche) and Morpho (Base via bridge)
 * @notice This contract helps users find the best lending rates across protocols
 */

// Aave V3 Pool interface (simplified);
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
        function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) external;
        function repay(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf) external returns (uint256);
        function getUserAccountData(address user) external view returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );
    }

//Cross-chain bridge interface for Morpho on Base
interface IMorphoCrossChainBridge {
    function getSupplyAPY(address asset) external view returns (uint256);
    function getBorrowAPY(address asset) external view returns (uint256);
    function bridgeAndSupply(address asset, uint256 amount, address onBehalfOf, bytes calldata bridgeData) external;
    function bridgeAndBorrow(address asset, uint256 amount, address onBehalfOf, bytes calldata bridgeData) external;
    function withdrawAndBridge(address asset, uint256 amount, address to, bytes calldata bridgeData) external;
    function repayAndBridge(address asset, uint256 amount, address onBehalfOf, bytes calldata bridgeData) external;
    function estimateBridgeFee(address asset, uint256 amount) external view returns (uint256);
}

// Position tracking for users
struct UserPosition {
    uint256 aaveSupplied;
    uint256 aaveBorrowed;
    uint256 morphoSupplied;
    uint256 morphoBorrowed;
    uint256 lastUpdate;
}

// APY comparison struct
struct APYComparison {
    uint256 aaveSupplyAPY;
    uint256 aaveBorrowAPY;
    uint256 morphoSupplyAPY;
    uint256 morphoBorrowAPY;
    bool aaveBetterForSupply;
    bool aaveBetterForBorrow;
    uint256 bridgeFee;
}

contract LendingAPYAggregator is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // Constants
    uint256 private constant RAY = 1e27;
    uint256 private constant PERCENTAGE_FACTOR = 1e18;
    uint256 private constant SECONDS_PER_YEAR = 365 days;
    
    // Contract addresses
    IPool public immutable aavePool;
    IMorphoCrossChainBridge public immutable morphoBridge;
    
    // Supported assets
    mapping(address => bool) public supportedAssets;
    address[] public assetList;
    
    // User positions
    mapping(address => mapping(address => UserPosition)) public userPositions;
    
    // Events
    event AssetAdded(address indexed asset);
    event AssetRemoved(address indexed asset);
    event SupplyExecuted(address indexed user, address indexed asset, uint256 amount, bool useAave);
    event BorrowExecuted(address indexed user, address indexed asset, uint256 amount, bool useAave);
    event WithdrawExecuted(address indexed user, address indexed asset, uint256 amount, bool useAave);
    event RepayExecuted(address indexed user, address indexed asset, uint256 amount, bool useAave);
    
    // Custom errors
    error UnsupportedAsset();
    error InvalidAmount();
    error InsufficientBalance();
    error BridgeError();
    
    constructor(
        address _aavePool,
        address _morphoBridge,
        address _owner

    ) Ownable(_owner) {
        aavePool = IPool(_aavePool);
        morphoBridge = IMorphoCrossChainBridge(_morphoBridge);

    }
    
    /**
     * @dev Add supported asset
     * @param asset Address of the asset to support
     */
    function addSupportedAsset(address asset) external onlyOwner {
        require(!supportedAssets[asset], "Asset already supported");
        supportedAssets[asset] = true;
        assetList.push(asset);
        emit AssetAdded(asset);
    }
    
    /**
     * @dev Remove supported asset
     * @param asset Address of the asset to remove
     */
    function removeSupportedAsset(address asset) external onlyOwner {
        require(supportedAssets[asset], "Asset not supported");
        supportedAssets[asset] = false;
        
        // Remove from array
        for (uint256 i = 0; i < assetList.length; i++) {
            if (assetList[i] == asset) {
                assetList[i] = assetList[assetList.length - 1];
                assetList.pop();
                break;
            }
        }
        emit AssetRemoved(asset);
    }
    
    /**
     * @dev Get comprehensive APY comparison for an asset
     * @param asset The asset to compare
     * @return comparison APY comparison data
     */
    function getAPYComparison(address asset) external view returns (APYComparison memory comparison) {
        if (!supportedAssets[asset]) revert UnsupportedAsset();
        
        // Get Aave APYs
        IPool.ReserveData memory reserveData = aavePool.getReserveData(asset);
        comparison.aaveSupplyAPY = _rayToPercentage(reserveData.currentLiquidityRate);
        comparison.aaveBorrowAPY = _rayToPercentage(reserveData.currentVariableBorrowRate);
        
        // Get Morpho APYs
        comparison.morphoSupplyAPY = morphoBridge.getSupplyAPY(asset);
        comparison.morphoBorrowAPY = morphoBridge.getBorrowAPY(asset);
        
        // Determine better protocol
        comparison.aaveBetterForSupply = comparison.aaveSupplyAPY > comparison.morphoSupplyAPY;
        comparison.aaveBetterForBorrow = comparison.aaveBorrowAPY < comparison.morphoBorrowAPY;
        
        // Get bridge fee estimate (for 1000 USDC equivalent)
        comparison.bridgeFee = morphoBridge.estimateBridgeFee(asset, 1000 * 1e6);
    }
    
    /**
     * @dev Get best protocol for supply
     * @param asset The asset to supply
     * @param amount The amount to supply
     * @return useAave True if Aave is better, false if Morpho is better
     * @return netAPY Net APY after considering bridge costs
     */
    function getBestSupplyProtocol(address asset, uint256 amount) 
        external 
        view 
        returns (bool useAave, uint256 netAPY) 
    {
        APYComparison memory comparison = this.getAPYComparison(asset);
        
        if (comparison.aaveBetterForSupply) {
            useAave = true;
            netAPY = comparison.aaveSupplyAPY;
        } else {
            // Calculate net APY for Morpho considering bridge costs
            uint256 bridgeFee = morphoBridge.estimateBridgeFee(asset, amount);
            uint256 bridgeCostPercentage = (bridgeFee * PERCENTAGE_FACTOR) / amount;
            
            if (comparison.morphoSupplyAPY > bridgeCostPercentage) {
                useAave = false;
                netAPY = comparison.morphoSupplyAPY - bridgeCostPercentage;
            } else {
                useAave = true;
                netAPY = comparison.aaveSupplyAPY;
            }
        }
    }
    
    /**
     * @dev Get best protocol for borrowing
     * @param asset The asset to borrow
     * @param amount The amount to borrow
     * @return useAave True if Aave is better, false if Morpho is better
     * @return netAPY Net APY after considering bridge costs
     */
    function getBestBorrowProtocol(address asset, uint256 amount) 
        external 
        view 
        returns (bool useAave, uint256 netAPY) 
    {
        APYComparison memory comparison = this.getAPYComparison(asset);
        
        if (comparison.aaveBetterForBorrow) {
            useAave = true;
            netAPY = comparison.aaveBorrowAPY;
        } else {
            // Calculate net APY for Morpho considering bridge costs
            uint256 bridgeFee = morphoBridge.estimateBridgeFee(asset, amount);
            uint256 bridgeCostPercentage = (bridgeFee * PERCENTAGE_FACTOR) / amount;
            
            uint256 morphoTotalCost = comparison.morphoBorrowAPY + bridgeCostPercentage;
            
            if (morphoTotalCost < comparison.aaveBorrowAPY) {
                useAave = false;
                netAPY = morphoTotalCost;
            } else {
                useAave = true;
                netAPY = comparison.aaveBorrowAPY;
            }
        }
    }
    
    /**
     * @dev Supply to the best protocol automatically
     * @param asset The asset to supply
     * @param amount The amount to supply
     * @param bridgeData Bridge-specific data (if using Morpho)
     */
    function supplyToBest(
        address asset, 
        uint256 amount, 
        bytes calldata bridgeData
    ) external nonReentrant {
        if (!supportedAssets[asset]) revert UnsupportedAsset();
        if (amount == 0) revert InvalidAmount();
        
        (bool useAave,) = this.getBestSupplyProtocol(asset, amount);
        
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        
        if (useAave) {
            IERC20(asset).approve(address(aavePool), amount);
            aavePool.supply(asset, amount, msg.sender, 0);
            userPositions[msg.sender][asset].aaveSupplied += amount;
        } else {
            IERC20(asset).approve(address(morphoBridge), amount);
            morphoBridge.bridgeAndSupply(asset, amount, msg.sender, bridgeData);
            userPositions[msg.sender][asset].morphoSupplied += amount;
        }
        
        userPositions[msg.sender][asset].lastUpdate = block.timestamp;
        emit SupplyExecuted(msg.sender, asset, amount, useAave);
    }
    
    /**
     * @dev Borrow from the best protocol automatically
     * @param asset The asset to borrow
     * @param amount The amount to borrow
     * @param bridgeData Bridge-specific data (if using Morpho)
     */
    function borrowFromBest(
        address asset, 
        uint256 amount, 
        bytes calldata bridgeData
    ) external nonReentrant {
        if (!supportedAssets[asset]) revert UnsupportedAsset();
        if (amount == 0) revert InvalidAmount();
        
        (bool useAave,) = this.getBestBorrowProtocol(asset, amount);
        
        if (useAave) {
            aavePool.borrow(asset, amount, 2, 0, msg.sender); // Variable rate
            userPositions[msg.sender][asset].aaveBorrowed += amount;
        } else {
            morphoBridge.bridgeAndBorrow(asset, amount, msg.sender, bridgeData);
            userPositions[msg.sender][asset].morphoBorrowed += amount;
        }
        
        userPositions[msg.sender][asset].lastUpdate = block.timestamp;
        emit BorrowExecuted(msg.sender, asset, amount, useAave);
    }
    
    // /**
    //  * @dev Manual supply to specific protocol
    //  * @param asset The asset to supply
    //  * @param amount The amount to supply
    //  * @param useAave True for Aave, false for Morpho
    //  * @param bridgeData Bridge-specific data (if using Morpho)
    //  */
    // function supply(
    //     address asset, 
    //     uint256 amount, 
    //     bool useAave, 
    //     bytes calldata bridgeData
    // ) external nonReentrant {
    //     if (!supportedAssets[asset]) revert UnsupportedAsset();
    //     if (amount == 0) revert InvalidAmount();
        
    //     IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        
    //     if (useAave) {
    //         IERC20(asset).approve(address(aavePool), amount);
    //         aavePool.supply(asset, amount, msg.sender, 0);
    //         userPositions[msg.sender][asset].aaveSupplied += amount;
    //     } else {
    //         IERC20(asset).approve(address(morphoBridge), amount);
    //         morphoBridge.bridgeAndSupply(asset, amount, msg.sender, bridgeData);
    //         userPositions[msg.sender][asset].morphoSupplied += amount;
    //     }
        
    //     userPositions[msg.sender][asset].lastUpdate = block.timestamp;
    //     emit SupplyExecuted(msg.sender, asset, amount, useAave);
    // }
    
    // /**
    //  * @dev Manual borrow from specific protocol
    //  * @param asset The asset to borrow
    //  * @param amount The amount to borrow
    //  * @param useAave True for Aave, false for Morpho
    //  * @param bridgeData Bridge-specific data (if using Morpho)
    //  */
    // function borrow(
    //     address asset, 
    //     uint256 amount, 
    //     bool useAave, 
    //     bytes calldata bridgeData
    // ) external nonReentrant {
    //     if (!supportedAssets[asset]) revert UnsupportedAsset();
    //     if (amount == 0) revert InvalidAmount();
        
    //     if (useAave) {
    //         aavePool.borrow(asset, amount, 2, 0, msg.sender);
    //         userPositions[msg.sender][asset].aaveBorrowed += amount;
    //     } else {
    //         morphoBridge.bridgeAndBorrow(asset, amount, msg.sender, bridgeData);
    //         userPositions[msg.sender][asset].morphoBorrowed += amount;
    //     }
        
    //     userPositions[msg.sender][asset].lastUpdate = block.timestamp;
    //     emit BorrowExecuted(msg.sender, asset, amount, useAave);
    // }
    
    /**
     * @dev Get user's account data from Aave
     * @param user The user address
     */
    function getUserAccountData(address user) external view returns (
        uint256 totalCollateralBase,
        uint256 totalDebtBase,
        uint256 availableBorrowsBase,
        uint256 currentLiquidationThreshold,
        uint256 ltv,
        uint256 healthFactor
    ) {
        return aavePool.getUserAccountData(user);
    }
    
    /**
     * @dev Get all supported assets
     */
    function getSupportedAssets() external view returns (address[] memory) {
        return assetList;
    }
    
    /** 
     * @dev Convert ray (1e27) to percentage (1e18)
     * @param ray The ray value to convert
     */
    function _rayToPercentage(uint256 ray) private pure returns (uint256) {
        return ray / 1e9;
    }
    
    /**
     * @dev Emergency withdraw function
     * @param asset The asset to withdraw
     * @param amount The amount to withdraw
     */
    function emergencyWithdraw(address asset, uint256 amount) external onlyOwner {
        IERC20(asset).safeTransfer(owner(), amount);
    }
}