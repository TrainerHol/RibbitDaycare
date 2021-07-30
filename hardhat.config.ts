import {task} from "hardhat/config";
import ("@nomiclabs/hardhat-waffle");
import {ethers} from "ethers";
require('dotenv').config();



// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (args, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  defaultNetwork: "hardhat",
  solidity: "0.8.4",
  networks : {
    hardhat: {
      forking: {
        url: process.env.ALCHEMY_MAINNET_RPC_URL,
      },
      gasPrice: 30,
      chainId: 1337,
    }
  },
  kovan: {
    url: process.env.TESTNET_RPC_URL,
    accounts: [process.env.PRIVATE_KEY],
    saveDeployments: true,
  }
};

