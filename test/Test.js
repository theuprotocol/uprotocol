const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time, loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");

describe("UpTokenFactory", function () {
  let upTokenFactory;
  let capTokenImplementation;
  let upTokenImplementation;
  let underlyingToken;
  let settlementToken;

  beforeEach(async function () {
    [owner, user] = await ethers.getSigners();

    CapToken = await ethers.getContractFactory("CapToken");
    capTokenImplementation = await CapToken.deploy();

    UpToken = await ethers.getContractFactory("UpToken");
    upTokenImplementation = await UpToken.deploy();

    const UpTokenFactory = await ethers.getContractFactory("UpTokenFactory");
    upTokenFactory = await UpTokenFactory.deploy(capTokenImplementation, upTokenImplementation);

    const MockERC20 = await ethers.getContractFactory("MockERC20");
    underlyingToken = await MockERC20.deploy("XYZ", "XYZ", "18", "123")
    settlementToken = await MockERC20.deploy("USDC", "USDC", "6", "123")
  });

  describe("CapToken and UpToken Creation", function () {
    it("should create a new CapToken and UpToken", async function () {
        const strike = 100
        const expiry = (await ethers.provider.getBlock("latest")).timestamp + (180 * 24 * 60 * 60);
        
        const mintAmount = "1000000000000000000"
        await underlyingToken.mint(user.address, mintAmount)
        await underlyingToken.connect(user).approve(upTokenFactory.target, mintAmount)
        await upTokenFactory.connect(user).create(
            underlyingToken.target,
            settlementToken.target,
            strike,
            expiry,
            owner.address,
            mintAmount
        );

        const [upTokenAddrs, capTokenAddrs] = await upTokenFactory.tokens(underlyingToken.target, settlementToken.target, 0, 1)
        console.log(upTokenAddrs)
    });

    it("should initialize the UpToken with correct parameters", async function () {
        const strike = 100
        const expiry = (await ethers.provider.getBlock("latest")).timestamp + (180 * 24 * 60 * 60);

        const mintAmount = "1000000000000000000"
        await underlyingToken.mint(user.address, mintAmount)
        await underlyingToken.connect(user).approve(upTokenFactory.target, mintAmount)
        await upTokenFactory.connect(user).create(
            underlyingToken.target,
            settlementToken.target,
            strike,
            expiry,
            user.address,
            mintAmount
        );

        const [upTokenAddrs, capTokenAddrs] = await upTokenFactory.tokens(underlyingToken.target, settlementToken.target, 0, 1)
        
        const upToken = await ethers.getContractAt("UpToken", upTokenAddrs[0]);
        const capToken = await ethers.getContractAt("CapToken", capTokenAddrs[0]);

        const contractBalUnderlying = await underlyingToken.balanceOf(upToken.target)
        const userBalUnderlying = await underlyingToken.balanceOf(user.address)
        const userBalUpToken = await upToken.balanceOf(user.address)
        const userBalCapToken = await capToken.balanceOf(user.address)

        expect(contractBalUnderlying).to.be.equal(mintAmount)
        expect(userBalUnderlying).to.be.equal(0)
        expect(userBalUpToken).to.be.equal(mintAmount)
        expect(userBalCapToken).to.be.equal(mintAmount)

        expect(await upToken.underlyingToken()).to.equal(underlyingToken.target);
        expect(await upToken.settlementToken()).to.equal(settlementToken.target);
        expect(await upToken.capToken()).to.equal(capTokenAddrs[0]);
        expect(await upToken.strike()).to.equal(strike);
        expect(await upToken.expiry()).to.equal(expiry);
    });
  });
});
