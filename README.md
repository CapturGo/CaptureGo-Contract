# CapturGO - DePIN Location Intelligence Protocol

Decentralized location data network rewarding users for sharing anonymized movement insights.

## Quick Start

```bash
# Install dependencies
npm install

# Deploy entire infrastructure
npx hardhat run scripts/deploy-all.js --network base

# Local testing
npx hardhat node
npx hardhat run scripts/deploy-all.js --network localhost
```

## Smart Contracts

- **BaseToken.sol** - CAP token (ERC20) with minting capabilities
- **DataContribution.sol** - Location data submission with quality validation and rewards
- **DeviceRegistry.sol** - Device management with reputation scoring and fraud prevention
- **DataMarketplace.sol** - Enterprise data subscription marketplace with revenue sharing
- **StakingRewards.sol** - Token staking with tiered rewards system

## Architecture Flow

1. Users submit anonymized location data through mobile app
2. Device registry validates and tracks device reputation
3. Quality data gets validated and rewarded with CAP tokens
4. Enterprises purchase data subscriptions using CAP
5. Community members stake tokens for additional rewards

## Configuration

Update `hardhat.config.js` with your network settings:

```javascript
networks: {
  base: {
    url: "https://sepolia.base.org",
    accounts: ["YOUR_PRIVATE_KEY"]
  }
}
```

## Deployment

The `deploy-all.js` script handles:
- Sequential contract deployment
- Permission and role configuration
- Initial token minting (1M CAP)
- Staking pool funding (100K CAP)
- Deployment address tracking in JSON

## Development

```bash
# Compile
npx hardhat compile

# Test
npx hardhat test

# Verify contracts
npx hardhat verify --network base CONTRACT_ADDRESS
```

## Token Economics

- Symbol: CAP
- Initial Supply: 1,000,000
- Staking Rewards Pool: 100,000
- Data Validation Reward: 10 CAP per point
- Marketplace Fee: 10%

## Project Structure

```
contracts/
  ├── BaseToken.sol
  ├── DataContribution.sol
  ├── DeviceRegistry.sol
  ├── DataMarketplace.sol
  └── StakingRewards.sol
scripts/
  ├── deploy.js
  └── deploy-all.js
deployments/
  └── [chainId].json
```