require("@nomicfoundation/hardhat-toolbox");
require("hardhat-deploy");
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");

const RINKEBY_RPC_URL = process.env.RINKEBY_RPC_URL;
const KOVAN_RPC_URL = process.env.KOVAN_RPC_URL;
const GOERLI_RPC_URL = process.env.GOERLI_RPC_URL;
const PK = process.env.PK;
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {},
    rinkeby: {
      url: RINKEBY_RPC_URL,
      accounts: [PK],
      saveDeployments: true,
    },
    kovan: {
      url: KOVAN_RPC_URL,
      accounts: [PK],
      saveDeployments: true,
    },
    goerli: {
      url: GOERLI_RPC_URL,
      accounts: [PK],
      saveDeployments: true,
    },
  },

  etherscan: {
    apiKey: ETHERSCAN_API_KEY,
  },

  solidity: {
    compilers: [
      { version: "0.8.0" },
      { version: "0.4.24" },
      { version: "0.6.6" },
      { version: "0.7.0" },
      { version: "0.8.1" },
    ],
  },

  namedAccounts: {
    deployer: {
      // 0th account
      default: 0,
    },
  },
};
