// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract StakingRewards is ReentrancyGuard, Ownable, Pausable {
    IERC20 public stakingToken;
    IERC20 public rewardsToken;
    
    struct StakeInfo {
        uint256 amount;
        uint256 stakedAt;
        uint256 rewardDebt;
        uint256 tier;  // 0: Bronze, 1: Silver, 2: Gold
    }
    
    mapping(address => StakeInfo) public stakes;
    
    uint256 public totalStaked;
    uint256 public rewardRate = 100; // Reward tokens per day per 1000 staked tokens
    uint256 public minStakeAmount = 100 * 10**18; // Minimum 100 tokens
    
    uint256[] public tierThresholds = [1000 * 10**18, 5000 * 10**18, 10000 * 10**18];
    uint256[] public tierMultipliers = [10, 15, 25]; // 1x, 1.5x, 2.5x rewards
    
    uint256 public constant REWARD_PRECISION = 10000;
    uint256 public accRewardPerShare;
    uint256 public lastRewardTime;
    
    event Staked(address indexed user, uint256 amount, uint256 tier);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event TierUpgraded(address indexed user, uint256 newTier);
    
    constructor(
        address _stakingToken,
        address _rewardsToken,
        address initialOwner
    ) Ownable(initialOwner) {
        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardsToken);
        lastRewardTime = block.timestamp;
    }
    
    function stake(uint256 _amount) external nonReentrant whenNotPaused {
        require(_amount >= minStakeAmount, "Below minimum stake");
        updateRewardPool();
        
        if (stakes[msg.sender].amount > 0) {
            uint256 pending = calculatePendingRewards(msg.sender);
            if (pending > 0) {
                rewardsToken.transfer(msg.sender, pending);
                emit RewardsClaimed(msg.sender, pending);
            }
        }
        
        stakingToken.transferFrom(msg.sender, address(this), _amount);
        
        stakes[msg.sender].amount += _amount;
        stakes[msg.sender].stakedAt = block.timestamp;
        
        // Update tier based on new total stake
        uint256 newTier = calculateTier(stakes[msg.sender].amount);
        if (newTier > stakes[msg.sender].tier) {
            stakes[msg.sender].tier = newTier;
            emit TierUpgraded(msg.sender, newTier);
        }
        
        stakes[msg.sender].rewardDebt = (stakes[msg.sender].amount * accRewardPerShare) / REWARD_PRECISION;
        totalStaked += _amount;
        
        emit Staked(msg.sender, _amount, stakes[msg.sender].tier);
    }
    
    function withdraw(uint256 _amount) external nonReentrant {
        StakeInfo storage userStake = stakes[msg.sender];
        require(userStake.amount >= _amount, "Insufficient staked amount");
        
        updateRewardPool();
        
        uint256 pending = calculatePendingRewards(msg.sender);
        if (pending > 0) {
            rewardsToken.transfer(msg.sender, pending);
            emit RewardsClaimed(msg.sender, pending);
        }
        
        userStake.amount -= _amount;
        totalStaked -= _amount;
        
        // Downgrade tier if necessary
        uint256 newTier = calculateTier(userStake.amount);
        userStake.tier = newTier;
        
        userStake.rewardDebt = (userStake.amount * accRewardPerShare) / REWARD_PRECISION;
        
        stakingToken.transfer(msg.sender, _amount);
        emit Withdrawn(msg.sender, _amount);
    }
    
    function claimRewards() external nonReentrant {
        updateRewardPool();
        
        uint256 pending = calculatePendingRewards(msg.sender);
        require(pending > 0, "No rewards to claim");
        
        stakes[msg.sender].rewardDebt = (stakes[msg.sender].amount * accRewardPerShare) / REWARD_PRECISION;
        rewardsToken.transfer(msg.sender, pending);
        
        emit RewardsClaimed(msg.sender, pending);
    }
    
    function calculatePendingRewards(address _user) public view returns (uint256) {
        StakeInfo memory userStake = stakes[_user];
        if (userStake.amount == 0) return 0;
        
        uint256 currentAccRewardPerShare = accRewardPerShare;
        if (totalStaked > 0) {
            uint256 timePassed = block.timestamp - lastRewardTime;
            uint256 rewards = (timePassed * rewardRate * REWARD_PRECISION) / 86400; // Daily rate
            currentAccRewardPerShare += (rewards / totalStaked);
        }
        
        uint256 baseReward = (userStake.amount * currentAccRewardPerShare) / REWARD_PRECISION - userStake.rewardDebt;
        uint256 tierBonus = (baseReward * tierMultipliers[userStake.tier]) / 10;
        
        return baseReward + tierBonus;
    }
    
    function calculateTier(uint256 _amount) public view returns (uint256) {
        if (_amount >= tierThresholds[2]) return 2; // Gold
        if (_amount >= tierThresholds[1]) return 1; // Silver
        if (_amount >= tierThresholds[0]) return 0; // Bronze
        return 0;
    }
    
    function updateRewardPool() private {
        if (totalStaked == 0) {
            lastRewardTime = block.timestamp;
            return;
        }
        
        uint256 timePassed = block.timestamp - lastRewardTime;
        uint256 rewards = (timePassed * rewardRate * REWARD_PRECISION) / 86400;
        accRewardPerShare += (rewards / totalStaked);
        lastRewardTime = block.timestamp;
    }
    
    function updateRewardRate(uint256 _newRate) external onlyOwner {
        updateRewardPool();
        rewardRate = _newRate;
    }
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
}