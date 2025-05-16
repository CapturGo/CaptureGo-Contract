require("@nomiclabs/hardhat-ethers");

module.exports = {
  solidity: "0.8.20",
  networks: {
    base: {
      url: "https://sepolia.base.org", // Base Sepolia RPC
      accounts: ["YOUR_PRIVATE_KEY"], // Replace with your private key
    }
  }
};