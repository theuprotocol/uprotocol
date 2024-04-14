const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time, loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");

describe("UpTokenFactory", function () {
  let upTokenFactory;
  let bTokenImplementation;
  let uTokenImplementation;
  let underlyingToken;
  let settlementToken;

  beforeEach(async function () {
    [owner, user] = await ethers.getSigners();

    CapToken = await ethers.getContractFactory("CapToken");
    bTokenImplementation = await CapToken.deploy();

    UpToken = await ethers.getContractFactory("UpToken");
    uTokenImplementation = await UpToken.deploy();

    const UpTokenFactory = await ethers.getContractFactory("UpTokenFactory");
    upTokenFactory = await UpTokenFactory.deploy(bTokenImplementation, uTokenImplementation);

    const MockERC20 = await ethers.getContractFactory("MockERC20");
    underlyingToken = await MockERC20.deploy("XYZ", "XYZ", "18", "123")
    settlementToken = await MockERC20.deploy("USDC", "USDC", "6", "123")
  });

  describe("CapToken and UpToken Creation", function () {
    it("should create a new CapToken and UpToken", async function () {
        const strike = 100
        const expiry = (await ethers.provider.getBlock("latest")).timestamp + (180 * 24 * 60 * 60);
        
        await upTokenFactory.create(
            underlyingToken.target,
            settlementToken.target,
            strike,
            expiry,
            owner.address,
            0
        );

        const upTokenAddrs = await upTokenFactory.getUpTokens(underlyingToken.target, settlementToken.target, 0, 1)
        const capTokenAddrs = await upTokenFactory.getCapTokens(underlyingToken.target, settlementToken.target, 0, 1)
        console.log(upTokenAddrs)
    });

    it("should initialize the UpToken with correct parameters", async function () {
        const strike = 100
        const expiry = (await ethers.provider.getBlock("latest")).timestamp + (180 * 24 * 60 * 60);

        await upTokenFactory.create(
            underlyingToken.target,
            settlementToken.target,
            strike,
            expiry,
            owner.address,
            0
        );

        const upTokenAddrs = await upTokenFactory.getUpTokens(underlyingToken.target, settlementToken.target, 0, 1)
        const capTokenAddrs = await upTokenFactory.getCapTokens(underlyingToken.target, settlementToken.target, 0, 1)
        
        const upToken = await ethers.getContractAt("UpToken", upTokenAddrs[0]);

        expect(await upToken.underlyingToken()).to.equal(underlyingToken.target);
        expect(await upToken.settlementToken()).to.equal(settlementToken.target);
        expect(await upToken.capToken()).to.equal(capTokenAddrs[0]);
        expect(await upToken.strike()).to.equal(strike);
        expect(await upToken.expiry()).to.equal(expiry);
    });
  });
});
