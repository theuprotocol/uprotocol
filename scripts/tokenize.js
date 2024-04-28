const { ethers, upgrades } = require("hardhat");

const underlyingTokenAddr = "0xB238A96A10A517423a91795F543956dcCeBb8ac3"
const settlementTokenAddr = "0x00b8557652cace2e446a0133e7ad5a311c4fe9ae"
const tokenFactoryAddr = "0x7B015Ed8AecE877293A5F20B757ee8e707c650a5"

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Running script with the account:", deployer.address);

  const tokenFactory = await ethers.getContractAt("TokenFactory", tokenFactoryAddr);
  const underlyingToken = underlyingTokenAddr
  const settlementToken = settlementTokenAddr
  const strike = BigInt(10) ** BigInt(6)
  const expiry = "1715148488"
  await tokenFactory.create(underlyingToken, settlementToken, strike, expiry)

  const [upTokenAddrs, capTokenAddrs] = await tokenFactory.tokens(underlyingTokenAddr, settlementTokenAddr, 0, 1)
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });