import { ethers } from "ethers";

const hre = require("hardhat");
async function main() {
  const provider = new ethers.providers.JsonRpcProvider("http://localhost:8545");
  // Increase the time by one year
  console.log("Starting time: " + provider.blockNumber);
  await provider.send("evm_increaseTime", [31536000]);
  await provider.send("evm_mine", []);
  console.log("Starting time: " + provider.blockNumber);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
