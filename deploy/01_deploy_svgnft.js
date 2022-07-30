// yarn add fs
const fs = require("fs");
let { networkConfig } = require("../helper-hardhat-config");

module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
  // log is basically console.log, it logs data
  const { deploy, log } = deployments;
  // Parsed from the hardhat config file (hardhat deploy)
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();

  // Personal border Patrick uses
  log("-----------------------------------");
  const SVGNFT = await deploy("SVGNFT", { from: deployer, log: true });
  log(`SVGNFT contract deployed at ${SVGNFT.address}`);
  // Patrick recommends the svg is on one line
  let filepath = "./img/hexagon.svg";
  // Reading the file in sequence (synchronous)
  let svg = fs.readFileSync(filepath, { encoding: "utf8" });

  const svgNFTContract = await ethers.getContractFactory("SVGNFT");
  // hre = Hardhat runtime environment
  const accounts = await hre.ethers.getSigners();
  const signer = accounts[0];
  const svgNFT = new ethers.Contract(
    SVGNFT.address,
    svgNFTContract.interface,
    signer
  );
  const networkName = networkConfig[chainId]["name"];
  // No constructor arguments here.
  log(
    `Verify with: \n npx hardhat verify --network ${networkName} ${SVGNFT.address}`
  );

  // Sometimes shown as tx (transactionReceipt may also be displayed as tx)
  let transactionResponse = await svgNFT.create(svg);
  let receipt = await transactionResponse.wait(1);
  log(`You've made an NFT`);
  log(`You can view the tokenURI here ${await svgNFT.tokenURI(0)}`);
};
module.exports.tags = ["all", "svg"];
