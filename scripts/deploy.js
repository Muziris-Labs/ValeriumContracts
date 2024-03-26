// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  const counter = await hre.ethers.deployContract(
    "ValeriumProxyFactoryExternal",
    [
      "0x0560f6B73E570b4eCD2018E4AC450E773E60bED5",
      "0x3558a0038F42C2d9bcb8D16583c11eCEC88AbC13",
      "0x1018d42fbf6e24010d82c55b9bc035083ace81eac84048154dd46bb37019d1ac",
    ]
  );

  console.log("Contract address:", await counter.getAddress());
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
