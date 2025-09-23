// scripts/deploy-all.js
const { ethers } = require("hardhat");
const fs = require("fs");

// Color logging for better visibility
const colors = {
  reset: "\x1b[0m",
  bright: "\x1b[1m",
  green: "\x1b[32m",
  yellow: "\x1b[33m",
  blue: "\x1b[34m",
  cyan: "\x1b[36m"
};

const log = {
  info: (msg) => console.log(`${colors.cyan}ℹ ${msg}${colors.reset}`),
  success: (msg) => console.log(`${colors.green}✓ ${msg}${colors.reset}`),
  address: (name, addr) => console.log(`${colors.yellow}📍 ${name}: ${colors.bright}${addr}${colors.reset}`),
  section: (msg) => console.log(`\n${colors.blue}${colors.bright}═══ ${msg} ═══${colors.reset}\n`)
};

async function main() {
  const [deployer] = await ethers.getSigners();
  const network = await ethers.provider.getNetwork();
  
  log.section("CapturGO DePIN Deployment");
  log.info(`Network: ${network.name} (Chain ID: ${network.chainId})`);
  log.info(`Deployer: ${deployer.address}`);
  
  const balance = await ethers.provider.getBalance(deployer.address);
  log.info(`Balance: ${ethers.utils.formatEther(balance)} ETH\n`);

  // Track deployment addresses
  const deployments = {};
  
  // 1. Deploy BaseToken (CAP)
  log.section("Token Deployment");
  log.info("Deploying BaseToken (CAP)...");
  const BaseToken = await ethers.getContractFactory("BaseToken");
  const baseToken = await BaseToken.deploy(deployer.address);
  await baseToken.deployed();
  deployments.baseToken = baseToken.address;
  log.success("BaseToken deployed");
  log.address("CAP Token", baseToken.address);

  // 2. Deploy DataContribution
  log.section("Core Infrastructure");
  log.info("Deploying DataContribution...");
  const DataContribution = await ethers.getContractFactory("DataContribution");
  const dataContribution = await DataContribution.deploy(
    baseToken.address,
    deployer.address
  );
  await dataContribution.deployed();
  deployments.dataContribution = dataContribution.address;
  log.success("DataContribution deployed");
  log.address("DataContribution", dataContribution.address);

  // 3. Deploy DeviceRegistry
  log.info("Deploying DeviceRegistry...");
  const DeviceRegistry = await ethers.getContractFactory("DeviceRegistry");
  const deviceRegistry = await DeviceRegistry.deploy(deployer.address);
  await deviceRegistry.deployed();
  deployments.deviceRegistry = deviceRegistry.address;
  log.success("DeviceRegistry deployed");
  log.address("DeviceRegistry", deviceRegistry.address);

  // 4. Deploy DataMarketplace
  log.section("Marketplace & Staking");
  log.info("Deploying DataMarketplace...");
  const DataMarketplace = await ethers.getContractFactory("DataMarketplace");
  const dataMarketplace = await DataMarketplace.deploy(baseToken.address);
  await dataMarketplace.deployed();
  deployments.dataMarketplace = dataMarketplace.address;
  log.success("DataMarketplace deployed");
  log.address("DataMarketplace", dataMarketplace.address);

  // 5. Deploy StakingRewards
  log.info("Deploying StakingRewards...");
  const StakingRewards = await ethers.getContractFactory("StakingRewards");
  const stakingRewards = await StakingRewards.deploy(
    baseToken.address,
    baseToken.address, // Using CAP for both staking and rewards
    deployer.address
  );
  await stakingRewards.deployed();
  deployments.stakingRewards = stakingRewards.address;
  log.success("StakingRewards deployed");
  log.address("StakingRewards", stakingRewards.address);

  // Configuration Phase
  log.section("Contract Configuration");
  
  // Grant minting rights to DataContribution
  log.info("Configuring minting permissions...");
  const MINTER_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("MINTER_ROLE"));
  await baseToken.grantRole(MINTER_ROLE, dataContribution.address);
  log.success("DataContribution can now mint CAP tokens");

  // Grant data provider role to deployer
  log.info("Setting up marketplace roles...");
  const DATA_PROVIDER_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("DATA_PROVIDER_ROLE"));
  await dataMarketplace.grantRole(DATA_PROVIDER_ROLE, deployer.address);
  log.success("Deployer registered as data provider");

  // Initial token minting for liquidity
  log.info("Minting initial token supply...");
  const initialSupply = ethers.utils.parseEther("1000000"); // 1M CAP
  await baseToken.mint(deployer.address, initialSupply);
  log.success(`Minted ${ethers.utils.formatEther(initialSupply)} CAP to deployer`);

  // Allocate tokens for staking rewards pool
  log.info("Funding staking rewards pool...");
  const rewardsAllocation = ethers.utils.parseEther("100000"); // 100k CAP
  await baseToken.transfer(stakingRewards.address, rewardsAllocation);
  log.success(`Allocated ${ethers.utils.formatEther(rewardsAllocation)} CAP for staking rewards`);

  // Save deployment addresses
  log.section("Saving Deployment Info");
  const chainId = network.chainId.toString();
  const deploymentsPath = `./deployments/${chainId}.json`;
  
  const deploymentInfo = {
    network: network.name,
    chainId: chainId,
    timestamp: new Date().toISOString(),
    deployer: deployer.address,
    contracts: {
      BaseToken: deployments.baseToken,
      DataContribution: deployments.dataContribution,
      DeviceRegistry: deployments.deviceRegistry,
      DataMarketplace: deployments.dataMarketplace,
      StakingRewards: deployments.stakingRewards
    },
    configuration: {
      initialSupply: ethers.utils.formatEther(initialSupply),
      rewardsPool: ethers.utils.formatEther(rewardsAllocation),
      platformFeePercent: "10",
      minQualityThreshold: "60",
      rewardPerPoint: "10 CAP"
    }
  };

  // Create deployments directory if it doesn't exist
  if (!fs.existsSync("./deployments")) {
    fs.mkdirSync("./deployments");
  }

  fs.writeFileSync(deploymentsPath, JSON.stringify(deploymentInfo, null, 2));
  log.success(`Deployment info saved to ${deploymentsPath}`);

  // Summary
  log.section("Deployment Complete!");
  console.log(`
${colors.bright}Contract Addresses:${colors.reset}
═══════════════════════════════════════════
📜 BaseToken (CAP):     ${deployments.baseToken}
📊 DataContribution:    ${deployments.dataContribution}
📱 DeviceRegistry:      ${deployments.deviceRegistry}
💹 DataMarketplace:     ${deployments.dataMarketplace}
💎 StakingRewards:      ${deployments.stakingRewards}

${colors.green}✨ CapturGO DePIN infrastructure is ready!${colors.reset}
${colors.cyan}📡 Start collecting location intelligence on IoTeX${colors.reset}
  `);

  // Verification helper
  if (network.name !== "localhost" && network.name !== "hardhat") {
    console.log(`
${colors.yellow}To verify contracts on IoTeX explorer:${colors.reset}
npx hardhat verify --network ${network.name} ${deployments.baseToken} ${deployer.address}
npx hardhat verify --network ${network.name} ${deployments.dataContribution} ${deployments.baseToken} ${deployer.address}
npx hardhat verify --network ${network.name} ${deployments.deviceRegistry} ${deployer.address}
npx hardhat verify --network ${network.name} ${deployments.dataMarketplace} ${deployments.baseToken}
npx hardhat verify --network ${network.name} ${deployments.stakingRewards} ${deployments.baseToken} ${deployments.baseToken} ${deployer.address}
    `);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
