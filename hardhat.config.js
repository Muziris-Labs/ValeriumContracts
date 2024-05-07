require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

const PRIVATE_KEY = process.env.PRIVATE_KEY;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 800,
        details: {
          yulDetails: {
            optimizerSteps: "u",
          },
        },
      },
      evmVersion: "paris",
      viaIR: true,
    },
  },
  networks: {
    pegasus: {
      url: `https://replicator.pegasus.lightlink.io/rpc/v1`,
      accounts: [PRIVATE_KEY],
    },
    opSepolia: {
      url: `https://sepolia.optimism.io/`,
      accounts: [PRIVATE_KEY],
    },
    optimism: {
      url: `https://optimism-rpc.publicnode.com`,
      accounts: [PRIVATE_KEY],
    },
    base: {
      url: `https://base-rpc.publicnode.com`,
      accounts: [PRIVATE_KEY],
    },
    mode: {
      url: `https://1rpc.io/mode`,
      accounts: [PRIVATE_KEY],
    },
    baseSepolia: {
      url: `https://base-sepolia-rpc.publicnode.com`,
      accounts: [PRIVATE_KEY],
    },
    modeSepolia: {
      url: `https://sepolia.mode.network`,
      accounts: [PRIVATE_KEY],
    },
  },
  etherscan: {
    apiKey: {
      pegasus: "your API key",
      opSepolia: "89K6NC1QZIUZSA6A6S5SY1N3DVIBCJCD3A",
      optimism: "89K6NC1QZIUZSA6A6S5SY1N3DVIBCJCD3A",
      Base: "BZP99H9U5SEDZTTP3BIBUYE5X2TMM9PX5Q",
      mode: "your API key",
    },
    customChains: [
      {
        network: "pegasus",
        chainId: 1891,
        urls: {
          apiURL: "https://pegasus.lightlink.io/api",
          browserURL: "https://pegasus.lightlink.io/",
        },
      },
      {
        network: "opSepolia",
        chainId: 11155420,
        urls: {
          apiURL: "https://api-sepolia-optimistic.etherscan.io/api",
          browserURL: "https://sepolia-optimism.etherscan.io/",
        },
      },
      {
        network: "optimism",
        chainId: 10,
        urls: {
          apiURL: "https://api-optimistic.etherscan.io/api",
          browserURL: "https://optimistic.etherscan.io/",
        },
      },
      {
        network: "Base",
        chainId: 8453,
        urls: {
          apiURL: "https://api.basescan.org/api",
          browserURL: "https://basescan.org/",
        },
      },
      {
        network: "mode",
        chainId: 34443,
        urls: {
          apiURL: "https://explorer.mode.network/api/",
          browserURL: "https://explorer.mode.network/",
        },
      },
    ],
  },
};
