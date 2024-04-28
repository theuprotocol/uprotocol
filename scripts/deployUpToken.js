const { ethers, upgrades } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  // Deploy cap token
  const UpToken = await ethers.getContractFactory("UpToken");
  const upToken = await UpToken.deploy();
  console.log(`npx hardhat verify --network scrollSepolia ${upToken.target}`);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });