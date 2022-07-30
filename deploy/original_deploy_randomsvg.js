let { networkConfig } = require("../helper-hardhat-config");

module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
  const { deploy, get, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();

  // Initialising these variables
  let linkTokenAddress, vrfCoordinatorAddress;

  // If on the local network, deploy a mock
  if (chainId == 31337) {
    let linkToken = await get("LinkToken");
    linkTokenAddress = linkToken.address;
    let vrfCoordinatorMock = await get("VRFCoordinatorMock");
    vrfCoordinatorAddress = vrfCoordinatorMock.address;
  } else {
    linkTokenAddress = networkConfig[chainId]["linkToken"];
    vrfCoordinatorAddress = networkConfig[chainId]["vrfCoordinator"];
  }
  const keyHash = networkConfig[chainId]["keyHash"];
  const fee = networkConfig[chainId]["fee"];
  let args = [vrfCoordinatorAddress, linkTokenAddress, keyHash, fee];
  log("------------------------------------");
  const RandomSVG = await deploy("RandomSVG", {
    from: deployer,
    args: args,
    log: true,
  });
  log("Random NFT contract deployed!");
  const networkName = networkConfig[chainId]["name"];
  log(
    `Verify with: \n npx hardhat verify --network ${networkName} ${
      RandomSVG.address
    } ${args.toString().replace(/,/g, " ")}` // Replace all the commas with spaces
  );

  // fund with LINK
  const linkTokenContract = await ethers.getContractFactory("LinkToken");
  const accounts = await hre.ethers.getSigners();
  const signer = accounts[0];
  const linkToken = new ethers.Contract(
    linkTokenAddress,
    linkTokenContract.interface,
    signer
  );
  let fund_tx = await linkToken.transfer(RandomSVG.address, fee);
  await fund_tx.wait(1);

  // Create an NFT! By calling a random number
  const RandomSVGContract = await ethers.getContractFactory("RandomSVG");
  // Note the lowercase
  const randomSVG = new ethers.Contract(
    RandomSVG.address,
    RandomSVGContract.interface,
    signer
  );
  let creation_tx = await randomSVG.create({ gasLimit: 300000 });
  // Receipt will have the create() Topics (indexed events)
  let receipt = await creation_tx.wait(1);
  // 4th event (will need to keep track of this)
  // topic 1: requestId, topic 2: tokenId
  let tokenId = receipt.events[3].topics[2];
  log(`NFT made, this is token number ${tokenId.toString()}`);
  log("Waiting for the chainlink node to respond...");

  if (chainId != 31337) {
    // I think the updated github script is necessary for this deployment here
    await new Promise((r) => setTimeout(r, 60000));
    log("Now finishing the mint...");
    let finish_tx = await randomSVG.finishMint(tokenId, { gasLimit: 2000000 });
    await finish_tx.wait(1);
    log(`You can view the tokenURI here ${await randomSVG.tokenURI(tokenId)}`);
  } else {
    const VRFCoordinatorMock = await deployments.get("VRFCoordinatorMock");
    vrfCoordinator = await ethers.getContractAt(
      "VRFCoordinatorMock",
      VRFCoordinatorMock.address,
      signer
    );
    let vrf_tx = await vrfCoordinator.callBackWithRandomness(
      receipt.logs[3].topics[1], // logs is the same as event
      497494, // Fake random number
      randomSVG.address
    );
    await vrf_tx.wait(1);
    log("Now let's finish the mint!");
    let finish_tx = await randomSVG.finishMint(tokenId, { gasLimit: 2000000 });
    await finish_tx.wait(1);
    log(`TokenURI can be viewed here: ${await randomSVG.tokenURI(tokenId)}`);
  }
};
// module.exports.tags = ["all", "rsvg"];
