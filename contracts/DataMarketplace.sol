// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract DataMarketplace is AccessControl, ReentrancyGuard {
    bytes32 public constant DATA_PROVIDER_ROLE = keccak256("DATA_PROVIDER_ROLE");
    
    struct DataPackage {
        string metadataURI;      // IPFS URI for data description
        uint256 pricePerMonth;   // Price in CAP tokens
        uint256 minSubscription; // Minimum subscription period (months)
        bool isActive;
        address provider;
    }
    
    struct Subscription {
        uint256 packageId;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
    }
    
    IERC20 public paymentToken;
    uint256 public platformFeePercent = 10; // 10% platform fee
    uint256 public totalRevenue;
    
    mapping(uint256 => DataPackage) public dataPackages;
    mapping(address => mapping(uint256 => Subscription)) public subscriptions;
    mapping(address => uint256) public providerBalances;
    
    uint256 private packageCounter;
    
    event PackageCreated(uint256 indexed packageId, address provider, uint256 price);
    event SubscriptionPurchased(address indexed subscriber, uint256 packageId, uint256 duration);
    event RevenueWithdrawn(address indexed provider, uint256 amount);
    
    constructor(address _paymentToken) {
        paymentToken = IERC20(_paymentToken);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    function createDataPackage(
        string calldata _metadataURI,
        uint256 _pricePerMonth,
        uint256 _minSubscription
    ) external onlyRole(DATA_PROVIDER_ROLE) returns (uint256) {
        require(_pricePerMonth > 0, "Invalid price");
        require(_minSubscription > 0, "Invalid minimum subscription");
        
        uint256 packageId = packageCounter++;
        dataPackages[packageId] = DataPackage({
            metadataURI: _metadataURI,
            pricePerMonth: _pricePerMonth,
            minSubscription: _minSubscription,
            isActive: true,
            provider: msg.sender
        });
        
        emit PackageCreated(packageId, msg.sender, _pricePerMonth);
        return packageId;
    }
    
    function purchaseSubscription(
        uint256 _packageId,
        uint256 _months
    ) external nonReentrant {
        DataPackage memory package = dataPackages[_packageId];
        require(package.isActive, "Package not active");
        require(_months >= package.minSubscription, "Below minimum subscription");
        
        uint256 totalCost = package.pricePerMonth * _months;
        uint256 platformFee = (totalCost * platformFeePercent) / 100;
        uint256 providerRevenue = totalCost - platformFee;
        
        require(
            paymentToken.transferFrom(msg.sender, address(this), totalCost),
            "Payment failed"
        );
        
        subscriptions[msg.sender][_packageId] = Subscription({
            packageId: _packageId,
            startTime: block.timestamp,
            endTime: block.timestamp + (_months * 30 days),
            isActive: true
        });
        
        providerBalances[package.provider] += providerRevenue;
        totalRevenue += platformFee;
        
        emit SubscriptionPurchased(msg.sender, _packageId, _months);
    }
    
    function hasActiveSubscription(
        address _user,
        uint256 _packageId
    ) external view returns (bool) {
        Subscription memory sub = subscriptions[_user][_packageId];
        return sub.isActive && block.timestamp < sub.endTime;
    }
    
    function withdrawRevenue() external nonReentrant {
        uint256 balance = providerBalances[msg.sender];
        require(balance > 0, "No revenue to withdraw");
        
        providerBalances[msg.sender] = 0;
        require(paymentToken.transfer(msg.sender, balance), "Transfer failed");
        
        emit RevenueWithdrawn(msg.sender, balance);
    }
    
    function withdrawPlatformFees() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 fees = totalRevenue;
        require(fees > 0, "No fees to withdraw");
        
        totalRevenue = 0;
        require(paymentToken.transfer(msg.sender, fees), "Transfer failed");
    }
    
    function updatePackageStatus(uint256 _packageId, bool _isActive) external {
        require(dataPackages[_packageId].provider == msg.sender, "Not package owner");
        dataPackages[_packageId].isActive = _isActive;
    }
}