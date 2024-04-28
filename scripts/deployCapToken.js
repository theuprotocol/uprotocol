const { ethers, upgrades } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  // Deploy cap token
  const CapToken = await ethers.getContractFactory("CapToken");
  const capToken = await CapToken.deploy();
  console.log(`npx hardhat verify --network scrollSepolia ${capToken.target}`);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });