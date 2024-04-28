const { ethers, upgrades } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  // Deploy factory
  const TokenFactory = await ethers.getContractFactory("TokenFactory");
  const capTokenImpl = "0x6F590eec1E1BfF5ACd0390324aDB635AB224B486"
  const upTokenImpl = "0x2D01192B89DCBD9313d16d784afB536448c1100E"
  const tokenFactory = await TokenFactory.deploy(capTokenImpl, upTokenImpl);
  console.log(`npx hardhat verify --network scrollSepolia ${tokenFactory.target} ${capTokenImpl} ${upTokenImpl}`);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });