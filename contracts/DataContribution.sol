// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

interface IBaseToken {
    function mint(address to, uint256 amount) external;
}

contract DataContribution is Ownable, Pausable {
    IBaseToken public rewardToken;
    
    struct DataPoint {
        bytes32 dataHash;      // Hash of location data (privacy-preserved)
        uint256 timestamp;
        uint256 quality;        // Quality score (0-100)
        bool validated;
    }
    
    struct Contributor {
        uint256 totalPoints;
        uint256 pendingRewards;
        uint256 lastContribution;
        bool isActive;
    }
    
    mapping(address => Contributor) public contributors;
    mapping(address => DataPoint[]) public userDataPoints;
    
    uint256 public rewardPerPoint = 10 * 10**18; // 10 CAP tokens per validated point
    uint256 public minQualityThreshold = 60;
    uint256 public contributionCooldown = 300; // 5 minutes between contributions
    
    event DataSubmitted(address indexed user, bytes32 dataHash, uint256 quality);
    event DataValidated(address indexed user, uint256 points);
    event RewardsClaimed(address indexed user, uint256 amount);
    
    constructor(address _rewardToken, address initialOwner) Ownable(initialOwner) {
        rewardToken = IBaseToken(_rewardToken);
    }
    
    function submitLocationData(
        bytes32 _dataHash,
        uint256 _quality
    ) external whenNotPaused {
        require(
            block.timestamp >= contributors[msg.sender].lastContribution + contributionCooldown,
            "Cooldown period not met"
        );
        require(_quality >= minQualityThreshold, "Data quality too low");
        
        DataPoint memory newPoint = DataPoint({
            dataHash: _dataHash,
            timestamp: block.timestamp,
            quality: _quality,
            validated: false
        });
        
        userDataPoints[msg.sender].push(newPoint);
        contributors[msg.sender].lastContribution = block.timestamp;
        contributors[msg.sender].isActive = true;
        
        emit DataSubmitted(msg.sender, _dataHash, _quality);
    }
    
    function validateDataBatch(
        address[] calldata users,
        uint256[] calldata pointIndices
    ) external onlyOwner {
        require(users.length == pointIndices.length, "Array length mismatch");
        
        for (uint i = 0; i < users.length; i++) {
            address user = users[i];
            uint256 index = pointIndices[i];
            
            require(index < userDataPoints[user].length, "Invalid index");
            require(!userDataPoints[user][index].validated, "Already validated");
            
            userDataPoints[user][index].validated = true;
            contributors[user].totalPoints++;
            contributors[user].pendingRewards += rewardPerPoint;
            
            emit DataValidated(user, 1);
        }
    }
    
    function claimRewards() external {
        uint256 rewards = contributors[msg.sender].pendingRewards;
        require(rewards > 0, "No rewards to claim");
        
        contributors[msg.sender].pendingRewards = 0;
        rewardToken.mint(msg.sender, rewards);
        
        emit RewardsClaimed(msg.sender, rewards);
    }
    
    function updateRewardRate(uint256 _newRate) external onlyOwner {
        rewardPerPoint = _newRate;
    }
    
    function updateQualityThreshold(uint256 _newThreshold) external onlyOwner {
        require(_newThreshold <= 100, "Invalid threshold");
        minQualityThreshold = _newThreshold;
    }
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
}