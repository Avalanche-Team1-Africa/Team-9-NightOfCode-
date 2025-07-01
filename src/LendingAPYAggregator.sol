// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {MarketParams} from "lib/morpho-blue/src/interfaces/IMorpho.sol";
import {DataTypes} from "aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";
import {IAvalancheMorphoCCIPSender} from "./interfaces/IAvalancheMorphoCCIPSender.sol";

/**
 * @title LendingAPYAggregator
 * @dev Aggregates lending/borrowing APYs from Aave V3 (Avalanche) and Morpho (Base via bridge)
 * @notice This contract helps users find the best lending rates across protocols
 */

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
    IAvalancheMorphoCCIPSender public immutable morphoSender;
    
    // Supported assets
    mapping(address => bool) public supportedAssets;
    address[] public assetList;
    
    // User positions
    mapping(address => mapping(address => UserPosition)) public userPositions;
    
    // Map asset => MarketParams for Morpho
    mapping(address => MarketParams) public morphoMarketParams;
    
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
    
    // Modifier must be declared after state variables and errors
    modifier onlySupportedAssetAndNonZeroAmount(address asset, uint256 amount) {
        if (!supportedAssets[asset]) revert UnsupportedAsset();
        if (amount == 0) revert InvalidAmount();
        _;
    }
    
    constructor(
        address _aavePool,
        address _morphoSender,
        address _owner

    ) Ownable(_owner) {
        aavePool = IPool(_aavePool);
        morphoSender = IAvalancheMorphoCCIPSender(_morphoSender);

    }
    
    /**
     * @dev Add supported asset
     * @param asset Address of the asset to support
     */
    function addSupportedAsset(address asset) external onlyOwner {
        if (supportedAssets[asset]) revert("Asset already supported");
        supportedAssets[asset] = true;
        assetList.push(asset);
        emit AssetAdded(asset);
    }
    
    /**
     * @dev Remove supported asset
     * @param asset Address of the asset to remove
     */
    function removeSupportedAsset(address asset) external onlyOwner {
        if (!supportedAssets[asset]) revert("Asset not supported");
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
    
    // /**
    //  * @dev Get comprehensive APY comparison for an asset
    //  * @notice APY data is now fetched off-chain; this function is deprecated and returns empty values.
    //  */
    // function getAPYComparison(address asset) external pure returns (APYComparison memory comparison) {
    //     // All APY data is fetched off-chain in the frontend.
    //     // This function is deprecated and returns empty/default values.
    //     return comparison;
    // }
    
    // /**
    //  * @dev Get best protocol for supply
    //  * @notice Protocol selection is now handled off-chain by the frontend; this function is deprecated and returns default values.
    //  */
    // function getBestSupplyProtocol(address asset, uint256 amount) 
    //     external 
    //     pure 
    //     returns (bool useAave, uint256 netAPY) 
    // {
    //     // Protocol selection is now handled off-chain by the frontend.
    //     // This function is deprecated and returns default values.
    //     return (true, 0);
    // }
    
    // /**
    //  * @dev Get best protocol for borrowing
    //  * @notice Protocol selection is now handled off-chain by the frontend; this function is deprecated and returns default values.
    //  */
    // function getBestBorrowProtocol(address asset, uint256 amount) 
    //     external 
    //     pure 
    //     returns (bool useAave, uint256 netAPY) 
    // {
    //     // Protocol selection is now handled off-chain by the frontend.
    //     // This function is deprecated and returns default values.
    //     return (true, 0);
    // }
    
    /**
     * @dev Supply to Aave
     * @param asset The asset to supply
     * @param amount The amount to supply
     */
    function supplyToAave(address asset, uint256 amount) external nonReentrant {
        if (!supportedAssets[asset]) revert UnsupportedAsset();
        if (amount == 0) revert InvalidAmount();

        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(asset).approve(address(aavePool), amount);
        aavePool.supply(asset, amount, msg.sender, 0);
        userPositions[msg.sender][asset].aaveSupplied += amount;
        userPositions[msg.sender][asset].lastUpdate = block.timestamp;
        emit SupplyExecuted(msg.sender, asset, amount, true);
    }
    
    /**
     * @dev Supply to Morpho (via bridge)
     * @param asset The asset to supply
     * @param amount The amount to supply
     */
    function supplyToMorpho(address asset, uint256 amount) external payable nonReentrant {
        if (!supportedAssets[asset]) revert UnsupportedAsset();
        if (amount == 0) revert InvalidAmount();

        MarketParams memory market = morphoMarketParams[asset];
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(asset).approve(address(morphoSender), amount);
        morphoSender.bridgeAndSupply{value: msg.value}(market, amount, msg.sender);
        userPositions[msg.sender][asset].morphoSupplied += amount;
        userPositions[msg.sender][asset].lastUpdate = block.timestamp;
        emit SupplyExecuted(msg.sender, asset, amount, false);
    }
    
    /**
     * @dev Borrow from Aave
     * @param asset The asset to borrow
     * @param amount The amount to borrow
     */
    function borrowFromAave(address asset, uint256 amount) external nonReentrant {
        if (!supportedAssets[asset]) revert UnsupportedAsset();
        if (amount == 0) revert InvalidAmount();

        aavePool.borrow(asset, amount, 2, 0, msg.sender); // 2 = variable rate, 0 = referral
        userPositions[msg.sender][asset].aaveBorrowed += amount;
        userPositions[msg.sender][asset].lastUpdate = block.timestamp;
        emit BorrowExecuted(msg.sender, asset, amount, true);
    }
    
    /**
     * @dev Borrow from Morpho (via bridge)
     * @param asset The asset to borrow
     * @param amount The amount to borrow
     * @param receiver The address to receive the borrowed funds
     */
    function borrowFromMorpho(address asset, uint256 amount, address receiver) external payable nonReentrant {
        if (!supportedAssets[asset]) revert UnsupportedAsset();
        if (amount == 0) revert InvalidAmount();

        MarketParams memory market = morphoMarketParams[asset];
        morphoSender.bridgeAndBorrow{value: msg.value}(market, amount, msg.sender, receiver);
        userPositions[msg.sender][asset].morphoBorrowed += amount;
        userPositions[msg.sender][asset].lastUpdate = block.timestamp;
        emit BorrowExecuted(msg.sender, asset, amount, false);
    }
    
    /**
     * @dev Get user's position for an asset as tracked by the aggregator.
     * @param user The user address
     * @param asset The asset address
     * @return aaveSupplied Amount supplied to Aave
     * @return aaveBorrowed Amount borrowed from Aave
     * @return morphoSupplied Amount supplied to Morpho
     * @return morphoBorrowed Amount borrowed from Morpho
     * @return lastUpdate Last update timestamp
     */
    function getAggregatorUserPosition(address user, address asset)
        external
        view
        returns (
            uint256 aaveSupplied,
            uint256 aaveBorrowed,
            uint256 morphoSupplied,
            uint256 morphoBorrowed,
            uint256 lastUpdate
        )
    {
        UserPosition memory pos = userPositions[user][asset];
        return (pos.aaveSupplied, pos.aaveBorrowed, pos.morphoSupplied, pos.morphoBorrowed, pos.lastUpdate);
    }
    
    /**
     * @dev Get all supported assets
     */
    function getSupportedAssets() external view returns (address[] memory) {
        return assetList;
    }
    
    
    /**
     * @dev Emergency withdraw function from this contract
     * @param asset The asset to withdraw
     * @param amount The amount to withdraw
     */
    function emergencyWithdraw(address asset, uint256 amount) external onlyOwner {
        IERC20(asset).safeTransfer(owner(), amount);
    }

    // Add admin function to set MarketParams for each asset
    function setMorphoMarketParams(address asset, MarketParams calldata params) external onlyOwner {
        morphoMarketParams[asset] = params;
    }

    /**
     * @dev Withdraw from Aave
     * @param asset The asset to withdraw
     * @param amount The amount to withdraw
     */
    function withdrawFromAave(address asset, uint256 amount) external nonReentrant onlySupportedAssetAndNonZeroAmount(asset, amount) returns (uint256) {
        uint256 withdrawn = aavePool.withdraw(asset, amount, msg.sender);
        userPositions[msg.sender][asset].aaveSupplied -= withdrawn;
        emit WithdrawExecuted(msg.sender, asset, withdrawn, true);
        return withdrawn;
    }

    /**
     * @dev Withdraw from Morpho (via bridge)
     * @param asset The asset to withdraw
     * @param amount The amount to withdraw
     * @param receiver The address to receive the withdrawn funds
     */
    function withdrawFromMorpho(address asset, uint256 amount, address receiver) external payable nonReentrant onlySupportedAssetAndNonZeroAmount(asset, amount) {
        MarketParams memory market = morphoMarketParams[asset];
        morphoSender.bridgeAndWithdraw{value: msg.value}(market, amount, msg.sender, receiver);
        userPositions[msg.sender][asset].morphoSupplied -= amount;
        emit WithdrawExecuted(msg.sender, asset, amount, false);
    }

    /**
     * @dev Repay Aave debt
     * @param asset The asset to repay
     * @param amount The amount to repay
     * @return repaid The actual amount repaid
     */
    function repayToAave(address asset, uint256 amount) external nonReentrant onlySupportedAssetAndNonZeroAmount(asset, amount) returns (uint256 repaid) {
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(asset).approve(address(aavePool), amount);
        repaid = aavePool.repay(asset, amount, 2, msg.sender); // 2 = variable rate
        userPositions[msg.sender][asset].aaveBorrowed -= repaid;
        userPositions[msg.sender][asset].lastUpdate = block.timestamp;
        emit RepayExecuted(msg.sender, asset, repaid, true);
        return repaid;
    }

    /**
     * @dev Repay Morpho debt (via bridge)
     * @param asset The asset to repay
     * @param amount The amount to repay
     * @return repaid The amount repaid
     */
    function repayToMorpho(address asset, uint256 amount) external payable nonReentrant onlySupportedAssetAndNonZeroAmount(asset, amount) returns (uint256 repaid) {
        MarketParams memory market = morphoMarketParams[asset];
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(asset).approve(address(morphoSender), amount);
        morphoSender.bridgeAndRepay{value: msg.value}(market, amount, msg.sender);
        userPositions[msg.sender][asset].morphoBorrowed -= amount;
        userPositions[msg.sender][asset].lastUpdate = block.timestamp;
        emit RepayExecuted(msg.sender, asset, amount, false);
        return amount;
    }
}