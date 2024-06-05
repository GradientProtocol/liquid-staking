import * as dotenv from "dotenv";
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-tracer";

dotenv.config();


const config: HardhatUserConfig = {
  paths: {
    sources: "./contracts/src",
  },
  solidity: {
    // Only use Solidity default versions `>=0.8.20` for EVM networks that support the opcode `PUSH0`
    // Otherwise, use the versions `<=0.8.19`
    version: "0.8.26",
    settings: {
      optimizer: {
        enabled: true,
        runs: 2,
      },
      // evmVersion: "paris", // Prevent using the `PUSH0` opcode
    },
  },


  typechain: {
    outDir: "web3types",
    target: "web3-v1",
  },
  
  networks: {
    hardhat: {
      initialBaseFeePerGas: 0,
      chainId: 31337,
      hardfork: "cancun",
      forking: {
        url: "https://eth.llamarpc.com",
        // The Hardhat network will by default fork from the latest mainnet block
        // To pin the block number, specify it below
        // You will need access to a node with archival data for this to work!
        // blockNumber: 14743877,
        // If you want to do some forking, set `enabled` to true
        enabled: true,
      },
    },
    localhost: {
      url: "http://127.0.0.1:8545",
    },
    eth: {
      url: process.env.ETH_URL || "",
      // accounts: [process.env.GSWTAO_DEPLOYER_KEY || '', process.env.DEPLOYER_CONTRACT_WALLET || ''],
    },

  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};

export default config;
