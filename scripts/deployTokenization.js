const { ethers, upgrades } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  /*
  // Deploy cap token
  const CapToken = await ethers.getContractFactory("CapToken");
  const capToken = await CapToken.deploy();
  console.log(`npx hardhat verify --network scrollSepolia ${capToken.target}`);
  // 0x66be1a245184d010f2aa4c733d90eef422b164bc 
  */

  /*
  // Deploy cap token
  const UpToken = await ethers.getContractFactory("UpToken");
  const upToken = await UpToken.deploy();
  console.log(`npx hardhat verify --network scrollSepolia ${upToken.target}`);
  // 0x2DF9dCC2Bfb67fB7F0F04e8a4359643ad31EAF5c
  */

  // Deploy factory
  const TokenFactory = await ethers.getContractFactory("TokenFactory");
  const capTokenImpl = "0x66be1a245184d010f2aa4c733d90eef422b164bc"
  const upTokenImpl = "0x2DF9dCC2Bfb67fB7F0F04e8a4359643ad31EAF5c"
  const tokenFactory = await TokenFactory.deploy(capTokenImpl, upTokenImpl);
  console.log(`npx hardhat verify --network scrollSepolia ${tokenFactory.target} ${capTokenImpl} ${upTokenImpl}`);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });