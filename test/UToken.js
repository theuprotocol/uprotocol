const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time, loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");

describe("UTokenFactory", function () {
  let uTokenFactory;
  let bTokenImplementation;
  let uTokenImplementation;
  let underlyingToken;
  let settlementToken;

  beforeEach(async function () {
    [owner] = await ethers.getSigners();

    BToken = await ethers.getContractFactory("BToken");
    bTokenImplementation = await BToken.deploy();

    UToken = await ethers.getContractFactory("UToken");
    uTokenImplementation = await UToken.deploy();

    const UTokenFactory = await ethers.getContractFactory("UTokenFactory");
    uTokenFactory = await UTokenFactory.deploy(bTokenImplementation, uTokenImplementation);

    const MockERC20 = await ethers.getContractFactory("MockERC20");
    underlyingToken = await MockERC20.deploy("XYZ", "XYZ", "18", "123")
    settlementToken = await MockERC20.deploy("USDC", "USDC", "6", "123")
  });

  describe("createBAndUToken", function () {
    it("should create a new BToken and UToken", async function () {
        const strike = 100
        const expiry = (await ethers.provider.getBlock("latest")).timestamp + (180 * 24 * 60 * 60);

        await uTokenFactory.tokenizeUnderlying(
            underlyingToken.target,
            settlementToken.target,
            strike,
            expiry
        );
        console.log("TEST")

        const uTokenAddrs = await uTokenFactory.getUTokens(underlyingToken.target, settlementToken.target, 0, 1)
        const bTokenAddrs = await uTokenFactory.getBTokens(underlyingToken.target, settlementToken.target, 0, 1)
        console.log(uTokenAddrs)
    });

    it("should initialize the UToken with correct parameters", async function () {
        const strike = 100
        const expiry = (await ethers.provider.getBlock("latest")).timestamp + (180 * 24 * 60 * 60);

        await uTokenFactory.tokenizeUnderlying(
            underlyingToken.target,
            settlementToken.target,
            strike,
            expiry
        );

        const uTokenAddrs = await uTokenFactory.getUTokens(underlyingToken.target, settlementToken.target, 0, 1)
        const bTokenAddrs = await uTokenFactory.getBTokens(underlyingToken.target, settlementToken.target, 0, 1)
        
        const uToken = await ethers.getContractAt("UToken", uTokenAddrs[0]);

        expect(await uToken.underlyingToken()).to.equal(underlyingToken.target);
        expect(await uToken.settlementToken()).to.equal(settlementToken.target);
        expect(await uToken.bToken()).to.equal(bTokenAddrs[0]);
        expect(await uToken.strike()).to.equal(strike);
        expect(await uToken.expiry()).to.equal(expiry);
    });
  });
});
