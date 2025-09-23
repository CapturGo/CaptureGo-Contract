// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract DeviceRegistry is Ownable {
    struct Device {
        bytes32 deviceId;       // Unique device identifier
        address owner;          // Device owner address
        uint256 registeredAt;
        uint256 lastActive;
        uint256 dataPoints;     // Total data points submitted
        uint256 reputation;     // Device reputation score (0-1000)
        bool isActive;
        bool isVerified;        // Verified by platform
    }
    
    mapping(bytes32 => Device) public devices;
    mapping(address => bytes32[]) public userDevices;
    mapping(bytes32 => bool) public bannedDevices;
    
    uint256 public constant MIN_REPUTATION = 100;
    uint256 public constant MAX_DEVICES_PER_USER = 5;
    uint256 public verificationReward = 100; // Initial reputation bonus
    
    event DeviceRegistered(bytes32 indexed deviceId, address indexed owner);
    event DeviceVerified(bytes32 indexed deviceId);
    event DeviceBanned(bytes32 indexed deviceId, string reason);
    event DeviceActivityRecorded(bytes32 indexed deviceId, uint256 dataPoints);
    event ReputationUpdated(bytes32 indexed deviceId, uint256 newReputation);
    
    constructor(address initialOwner) Ownable(initialOwner) {}
    
    function registerDevice(bytes32 _deviceId) external {
        require(!bannedDevices[_deviceId], "Device is banned");
        require(devices[_deviceId].owner == address(0), "Device already registered");
        require(userDevices[msg.sender].length < MAX_DEVICES_PER_USER, "Max devices reached");
        
        devices[_deviceId] = Device({
            deviceId: _deviceId,
            owner: msg.sender,
            registeredAt: block.timestamp,
            lastActive: block.timestamp,
            dataPoints: 0,
            reputation: MIN_REPUTATION,
            isActive: true,
            isVerified: false
        });
        
        userDevices[msg.sender].push(_deviceId);
        emit DeviceRegistered(_deviceId, msg.sender);
    }
    
    function verifyDevice(bytes32 _deviceId) external onlyOwner {
        require(devices[_deviceId].owner != address(0), "Device not found");
        require(!devices[_deviceId].isVerified, "Already verified");
        
        devices[_deviceId].isVerified = true;
        devices[_deviceId].reputation += verificationReward;
        
        emit DeviceVerified(_deviceId);
        emit ReputationUpdated(_deviceId, devices[_deviceId].reputation);
    }
    
    function recordActivity(
        bytes32 _deviceId,
        uint256 _dataPoints,
        uint256 _qualityScore
    ) external onlyOwner {
        require(devices[_deviceId].isActive, "Device not active");
        require(!bannedDevices[_deviceId], "Device is banned");
        
        Device storage device = devices[_deviceId];
        device.lastActive = block.timestamp;
        device.dataPoints += _dataPoints;
        
        // Update reputation based on quality (0-100 quality maps to ±10 reputation)
        if (_qualityScore >= 80) {
            device.reputation = min(device.reputation + 10, 1000);
        } else if (_qualityScore < 50 && device.reputation > 10) {
            device.reputation -= 10;
        }
        
        emit DeviceActivityRecorded(_deviceId, _dataPoints);
        emit ReputationUpdated(_deviceId, device.reputation);
        
        // Auto-ban if reputation too low
        if (device.reputation < MIN_REPUTATION) {
            banDevice(_deviceId, "Low reputation");
        }
    }
    
    function banDevice(bytes32 _deviceId, string memory _reason) public onlyOwner {
        bannedDevices[_deviceId] = true;
        devices[_deviceId].isActive = false;
        emit DeviceBanned(_deviceId, _reason);
    }
    
    function unbanDevice(bytes32 _deviceId) external onlyOwner {
        bannedDevices[_deviceId] = false;
        devices[_deviceId].isActive = true;
        devices[_deviceId].reputation = MIN_REPUTATION;
    }
    
    function getUserDeviceCount(address _user) external view returns (uint256) {
        return userDevices[_user].length;
    }
    
    function isDeviceEligible(bytes32 _deviceId) external view returns (bool) {
        Device memory device = devices[_deviceId];
        return device.isActive && 
               !bannedDevices[_deviceId] && 
               device.reputation >= MIN_REPUTATION;
    }
    
    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }
}