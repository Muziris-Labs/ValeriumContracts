require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

const PRIVATE_KEY = process.env.PRIVATE_KEY;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.24",
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
  },
  etherscan: {
    apiKey: {
      pegasus: "your API key",
      opSepolia: "89K6NC1QZIUZSA6A6S5SY1N3DVIBCJCD3A",
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
    ],
  },
};
