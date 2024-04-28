const { ethers, upgrades } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  // Deploy MockERC20 contract
  const MockERC20 = await ethers.getContractFactory("CapToken");
  const tokenName = "USDC"
  const tokenSymbol = "USDC"
  const decimals = 6
  const mintAmount = ethers.parseEther("123456789")
  const mockERC20 = await MockERC20.deploy(tokenName, tokenSymbol, decimals, mintAmount);

  console.log(`npx hardhat verify --network scrollSepolia ${mockERC20.target}`);

  // npx hardhat verify --network scrollSepolia 0xb238a96a10a517423a91795f543956dccebb8ac3 "XYZ Token" "XYZ" 18 123456789000000000000000000
  // npx hardhat verify --network scrollSepolia 0x00b8557652cace2e446a0133e7ad5a311c4fe9ae "USDC" "USDC" 6 123456789000000000000000000
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });