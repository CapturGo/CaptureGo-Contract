# BaseToken Hardhat Project

This project contains a simple ERC20 token contract (`BaseToken`) using OpenZeppelin and Hardhat.

## Prerequisites

- Node.js (v16+ recommended)
- npm

## Setup

1. **Install dependencies:**

   ```sh
   npm install
   ```

2. **Configure network (optional):**

   - Edit `hardhat.config.js` to add your private key for testnet/mainnet deployment.

## Compile the Contract

```sh
npx hardhat compile
```

## Deploy the Contract (Local Network)

1. Start a local Hardhat node (in a separate terminal):

   ```sh
   npx hardhat node
   ```

2. Deploy the contract:

   ```sh
   npx hardhat run scripts/deploy.js --network localhost
   ```

## Deploy to Testnet (e.g., Base Sepolia)

1. Set your private key in `hardhat.config.js` under `networks.base.accounts`.
2. Deploy:

   ```sh
   npx hardhat run scripts/deploy.js --network base
   ```

## Contract Details

- **Contract:** `BaseToken`
- **Symbol:** `CAP`
- **Minting:** Only the owner (deployer) can mint new tokens.
