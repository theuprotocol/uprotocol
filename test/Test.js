const { expect } = require("chai");
const { ethers } = require("hardhat");

let tokenFactory;
let capTokenImplementation;
let upTokenImplementation;
let underlyingToken;
let settlementToken;

let owner
let user
let lp
let swapper

describe("Tests", function () {

  beforeEach(async function () {
    [owner, user, lp, swapper] = await ethers.getSigners();

    CapToken = await ethers.getContractFactory("CapToken");
    capTokenImplementation = await CapToken.deploy();

    UpToken = await ethers.getContractFactory("UpToken");
    upTokenImplementation = await UpToken.deploy();

    const TokenFactory = await ethers.getContractFactory("TokenFactory");
    tokenFactory = await TokenFactory.deploy(capTokenImplementation, upTokenImplementation);

    const MockERC20 = await ethers.getContractFactory("MockERC20");
    underlyingToken = await MockERC20.deploy("XYZ", "XYZ", "18", "111")
    settlementToken = await MockERC20.deploy("USDC", "USDC", "6", "222")
  });

  describe("CapToken and UpToken Creation", function () {
    it("should create and tokenize underlying into CapToken and UpToken correctly", async function () {
        const strike = 100
        const expiry = (await ethers.provider.getBlock("latest")).timestamp + (180 * 24 * 60 * 60);
        
        await tokenFactory.connect(user).create(
            underlyingToken.target,
            settlementToken.target,
            strike,
            expiry
        );

        const [upTokenAddrs, capTokenAddrs] = await tokenFactory.tokens(underlyingToken.target, settlementToken.target, 0, 1)
        const upToken = await ethers.getContractAt("UpToken", upTokenAddrs[0]);
        const capToken = await ethers.getContractAt("CapToken", capTokenAddrs[0]);
        expect(await upToken.name()).to.be.equal("U-XYZ")
        expect(await upToken.symbol()).to.be.equal("uXYZ")
        expect(await capToken.name()).to.be.equal("C-XYZ")
        expect(await capToken.symbol()).to.be.equal("cXYZ")

        const mintAmount = "1000000000000000000"
        await underlyingToken.mint(user.address, mintAmount)
        await underlyingToken.connect(user).approve(upToken.target, mintAmount)
        const undBalPre = await underlyingToken.balanceOf(user.address)
        await upToken.connect(user).tokenize(user.address, mintAmount)

        const undBalPost1 = await underlyingToken.balanceOf(user.address)
        const mintBal1 = await upToken.balanceOf(user.address) 
        const mintBal2 = await capToken.balanceOf(user.address)
        expect(undBalPre - undBalPost1).to.be.equal(mintBal1)
        expect(mintBal1).to.be.equal(mintAmount)
        expect(mintBal1).to.be.equal(mintBal2)

        // test untokenize
        await upToken.connect(user).untokenize(user.address, mintAmount)
        const undBalPost2 = await underlyingToken.balanceOf(user.address) 
        const mintBalPost1 = await upToken.balanceOf(user.address)
        const mintBalPost2 = await capToken.balanceOf(user.address)
        expect(undBalPost2 - undBalPost1).to.be.equal(mintBal1)
        expect(mintBalPost1).to.be.equal(mintBalPost2)
        expect(mintBalPost1).to.be.equal(0)
    });

    it("should initialize the UpToken with correct parameters", async function () {
        const strike = 100
        const expiry = (await ethers.provider.getBlock("latest")).timestamp + (180 * 24 * 60 * 60);

        await tokenFactory.connect(user).create(
          underlyingToken.target,
          settlementToken.target,
          strike,
          expiry
        );

        const [upTokenAddrs, capTokenAddrs] = await tokenFactory.tokens(underlyingToken.target, settlementToken.target, 0, 1)
        const upToken = await ethers.getContractAt("UpToken", upTokenAddrs[0]);
        const capToken = await ethers.getContractAt("CapToken", capTokenAddrs[0]);

        const mintAmount = "1000000000000000000"
        await underlyingToken.mint(user.address, mintAmount)
        await underlyingToken.connect(user).approve(upToken.target, mintAmount)
        await upToken.connect(user).tokenize(user.address, mintAmount)

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

  })

  describe("Pool math", function () {
    it("should calculate x max, y and x correctly (1/2)", async function () {
      const Pool = await ethers.getContractFactory("Pool");
      pool = await Pool.deploy();

      const a = BigInt(10) ** BigInt(18);
      const k = BigInt(10) * BigInt(10) ** BigInt(18);
      const t = BigInt(31536000);

      // Get xMax
      const xMax = await pool.calcXMax(a, k, t);
      expect(xMax).to.be.equal("10916079781560898380")

      // Calculate x, y, starting from 0.1 x
      let x = BigInt(10) ** BigInt(18)  / BigInt(10);
      const xStep = BigInt(10) ** BigInt(18) / BigInt(10);

      while (x <= xMax) {
          const y = await pool.calcY(x, a, k, t);
          const x_rev = await pool.calcX(y, a, k, t);
          expect(x).to.be.equal(x_rev)
          
          x += xStep;
      }
    })

    it("should calculate x max, y and x correctly (2/2)", async function () {
      const Pool = await ethers.getContractFactory("Pool");
      pool = await Pool.deploy();

      const a = BigInt(10) ** BigInt(18);
      const k = BigInt(10) * BigInt(10) ** BigInt(18);
      // 2/100 of a year, ~7.3 days to expiry
      const t = BigInt(31536000) / BigInt(100) * BigInt(2);

      // Get xMax
      const xMax = await pool.calcXMax(a, k, t);
      expect(xMax).to.be.equal("10139461979840581630")

      // Calculate x, y, starting from 0.1 x
      let x = BigInt(10) ** BigInt(18)  / BigInt(10);
      const xStep = BigInt(10) ** BigInt(18) / BigInt(10);

      while (x <= xMax) {
          const y = await pool.calcY(x, a, k, t);
          const x_rev = await pool.calcX(y, a, k, t);
          expect(x).to.be.equal(x_rev)
          
          x += xStep;
      }
    })

    it("should calculate k correctly", async function () {
      const Pool = await ethers.getContractFactory("Pool");
      pool = await Pool.deploy();

      const a = BigInt(10) ** BigInt(18);
      const t = BigInt(31536000);
      const k0 = BigInt(10) * BigInt(10) ** BigInt(18);

      const xMax = await pool.calcXMax(a, k0, t);

      let x0 = BigInt(10) ** BigInt(18) / BigInt(10);

      while (x0 <= xMax) {
          let y0 = await pool.calcY(x0, a, k0, t);
      
          let k = await pool.calcK(x0, y0, a, t);

          const diff = BigInt(k) > BigInt(k0) ? BigInt(k) - BigInt(k0) : BigInt(k0) - BigInt(k);

          expect(diff).to.be.below(BigInt(2));

          x0 += BigInt(10) ** BigInt(18) / BigInt(10);
      }
    })

    it("should calculate y out given x in correctly", async function () {
      const Pool = await ethers.getContractFactory("Pool");
      pool = await Pool.deploy();

      const a = BigInt(10) ** BigInt(18);
      const k = BigInt(10) * BigInt(10) ** BigInt(18);
      const t = BigInt(31536000);

      // Get xMax
      const xMax = await pool.calcXMax(a, k, t);

      const x0 = BigInt(10) ** BigInt(18)

      let xIn = BigInt(0)
      const xStep = BigInt(10) ** BigInt(18) / BigInt(10)
      
      while (xIn <= xMax - x0) {
          const yOut = await pool.calcYOutGivenXIn(x0, xIn, a, k, t);
          xIn += xStep;
      }

      await expect(pool.calcYOutGivenXIn(xMax - x0, xIn, a, k, t)).to.be.revertedWithCustomError(pool, "XInTooLarge")
    })

    it("should calculate x out given y in correctly", async function () {
      const Pool = await ethers.getContractFactory("Pool");
      pool = await Pool.deploy();

      const a = BigInt(10) ** BigInt(18);
      const k = BigInt(10) * BigInt(10) ** BigInt(18);
      const t = BigInt(31536000);

      const yEnd = BigInt(10) ** BigInt(18) * BigInt(30)

      const y0 = BigInt(10) ** BigInt(18)

      let yIn = BigInt(0)
      const yStep = BigInt(10) ** BigInt(18) / BigInt(10)
      
      while (yIn <= yEnd - y0) {
          const xOut = await pool.calcXOutGivenYIn(y0, yIn, a, k, t);
          yIn += yStep;
      }
    })

    it("should calculate equilibrium point correctly", async function () {
      const Pool = await ethers.getContractFactory("Pool");
      pool = await Pool.deploy();

      const a = BigInt(10) ** BigInt(18);
      const k = BigInt(10) * BigInt(10) ** BigInt(18);
      const t = BigInt(31536000);

      const eqPoint = await pool.calcEquilibriumPoint(a, k, t)
      expect(eqPoint).to.be.equal("5854101965976788105")
    })

    it("should calculate yNew correctly", async function () {
      const Pool = await ethers.getContractFactory("Pool");
      pool = await Pool.deploy();

      const a = BigInt(10) ** BigInt(18);
      const k = BigInt(10) * BigInt(10) ** BigInt(18);
      const t = BigInt(31536000);

      const eqPoint = await pool.calcEquilibriumPoint(a, k, t)
      const xAdd = eqPoint

      const yNew = await pool.calcInvariantYNew(true, xAdd, eqPoint, a, k, t)
      expect(yNew).to.be.equal("31708203933204422184")
    })

    it("should calculate derivative correctly", async function () {
      const Pool = await ethers.getContractFactory("Pool");
      pool = await Pool.deploy();

      const a = BigInt(10) ** BigInt(18);
      const k = BigInt(10) * BigInt(10) ** BigInt(18);
      const t = BigInt(31536000);

      const eqPoint = await pool.calcEquilibriumPoint(a, k, t)
      expect(eqPoint).to.be.equal("5854101965976788105")
      let x = eqPoint

      let xPrice = await pool.calcXPriceInY(x, a, k, t)
      expect(xPrice).to.be.equal("1291796067527835803")

      x = BigInt(2) * BigInt(10) ** BigInt(18);
      xPrice = await pool.calcXPriceInY(x, a, k, t)
      expect(xPrice).to.be.equal("3500000000000000000")

      const xAdd = BigInt(10) ** BigInt(18)
      const x0 = BigInt(10) ** BigInt(18) * BigInt(2);
      const y0 = BigInt(10) ** BigInt(18) * BigInt(13);
      const yNewTmp = await pool.calcInvariantYNew(true, xAdd, x0, a, k, t)
      expect(yNewTmp).to.be.equal("27000000000000000000")
      const totalSupply = BigInt(10) ** BigInt(18);

      let kOld = await pool.calcK(eqPoint, eqPoint, a, t)
      let pOld = await pool.calcXPriceInY(eqPoint, a, kOld, t)
      expect(pOld).to.be.equal("1291796067512248786")

      const [lpTokenAmount2, yAdd2, xPrice2] = await pool.calcLpTokenAmount(true, xAdd, eqPoint, eqPoint, a, t, totalSupply)
      expect(lpTokenAmount2).to.be.equal("319891591764079352")
      expect(yAdd2).to.be.equal("2999999999999999997")
      expect(xPrice2).to.be.equal("1291796067512248786")
      // Check price invariance
      let xNew = eqPoint + BigInt(xAdd)
      let yNew = eqPoint + BigInt(yAdd2)
      let kNew = await pool.calcK(xNew, yNew, a, t)
      let pNew = await pool.calcXPriceInY(xNew, a, kNew, t)
      expect(pNew).to.be.equal("1291796067512248786")

      const [lpTokenAmount3, yRemove3, xPrice3] = await pool.calcLpTokenAmount(false, xAdd, eqPoint, eqPoint, a, t, totalSupply)
      expect(lpTokenAmount3).to.be.equal("276393202260638378")
      expect(yRemove3).to.be.equal("2416407864975502428")
      expect(xPrice3).to.be.equal("1291796067512248786")
      // Check price invariance
      xNew = eqPoint - BigInt(xAdd)
      yNew = eqPoint - BigInt(yRemove3)
      kNew = await pool.calcK(xNew, yNew, a, t)
      pNew = await pool.calcXPriceInY(xNew, a, kNew, t)
      expect(pNew).to.be.equal("1291796067512248786")
    })

    it("should allow swapping x for y", async function () {

      // strike price 1.5 USDC
      const strike = BigInt(10) ** BigInt(6) * BigInt(15) / BigInt(10)
      // expiry in 1y from now
      const expiry = (await ethers.provider.getBlock("latest")).timestamp + (365 * 24 * 60 * 60);

      // mint underlying tokens
      const mintAmount = BigInt(10) ** BigInt(18) * BigInt(2000)
      await underlyingToken.mint(lp.address, mintAmount)
      
      let userBalUnderlying = await underlyingToken.balanceOf(lp.address)
      expect(userBalUnderlying).to.be.equal(mintAmount)

      await tokenFactory.connect(user).create(
        underlyingToken.target,
        settlementToken.target,
        strike,
        expiry
      );

      const [upTokenAddrs, capTokenAddrs] = await tokenFactory.tokens(underlyingToken.target, settlementToken.target, 0, 1)
      const upToken = await ethers.getContractAt("UpToken", upTokenAddrs[0]);
      const capToken = await ethers.getContractAt("CapToken", capTokenAddrs[0]);

      await underlyingToken.mint(user.address, mintAmount)
      await underlyingToken.connect(user).approve(upToken.target, mintAmount)
      await upToken.connect(user).tokenize(lp.address, mintAmount)

      contractBalUnderlying = await underlyingToken.balanceOf(upToken.target)
      userBalUnderlying = await underlyingToken.balanceOf(lp.address)
      userBalUpToken = await upToken.balanceOf(lp.address)
      userBalCapToken = await capToken.balanceOf(lp.address)

      const PoolImpl = await ethers.getContractFactory("Pool");
      poolImpl = await PoolImpl.deploy();

      const PoolFactory = await ethers.getContractFactory("PoolFactory");
      poolFactory = await PoolFactory.deploy(poolImpl.target);

      // define pool parameters
      const a = BigInt(10) ** BigInt(18);
      const k = BigInt(10) * BigInt(10) ** BigInt(18);

      // LP creates and seeds pool
      const t = BigInt(31536000) - BigInt(24*60*60);
      const x0y0 = await poolImpl.calcEquilibriumPoint(a, k, t)
      await underlyingToken.connect(lp).approve(poolFactory.target, x0y0)
      await capToken.connect(lp).approve(poolFactory.target, x0y0)
      await poolFactory.connect(lp).createPool(upToken.target, a, k, t, lp.address)

      const poolAddrs = await poolFactory.pools(0, 1)
      console.log(poolAddrs)
      const pool = await ethers.getContractAt("Pool", poolAddrs[0]);
      lpTokenBal = await pool.balanceOf(lp.address)
      expect(lpTokenBal).to.be.equal(x0y0)

      // other user mints underlying and swaps against pool
      await underlyingToken.mint(swapper.address, mintAmount)
      await underlyingToken.connect(swapper).approve(upToken.target, mintAmount)
      await upToken.connect(swapper).tokenize(swapper.address, mintAmount / BigInt(2));
      
      const to = swapper.address
      const xIn = BigInt(10) ** BigInt(18)
      const minYOut = 0
      let deadline = (await ethers.provider.getBlock("latest")).timestamp + (600)
      await underlyingToken.connect(swapper).approve(pool, BigInt(2) ** BigInt(200))
      let [yOut, _x0, _y0, _a, _k, _t] = await pool.getYOutGivenXIn(xIn)

      let preUndBalSwapper = await underlyingToken.balanceOf(swapper.address)
      let preCapBalSwapper = await capToken.balanceOf(swapper.address)
      let preUndBalPool = await underlyingToken.balanceOf(pool.target)
      let preCapBalPool = await capToken.balanceOf(pool.target)
      await pool.connect(swapper).swapGetYGivenXIn(to, xIn, minYOut, deadline)
      let postUndBalSwapper = await underlyingToken.balanceOf(swapper.address)
      let postCapBalSwapper = await capToken.balanceOf(swapper.address)
      let postUndBalPool = await underlyingToken.balanceOf(pool.target)
      let postCapBalPool = await capToken.balanceOf(pool.target)

      let postUndBalPoolState = await pool.x()
      let postCapBalPoolState = await pool.y()

      expect(postUndBalPool).to.be.equal(postUndBalPoolState)
      expect(postCapBalPool).to.be.equal(postCapBalPoolState)

      expect(postCapBalSwapper - preCapBalSwapper).to.be.equal(yOut)
      expect(preUndBalSwapper - postUndBalSwapper).to.be.equal(xIn)

      // now user swaps caps for underlying
      const yIn = BigInt(10) ** BigInt(18) * BigInt(20)
      deadline = (await ethers.provider.getBlock("latest")).timestamp + (600)
      let xOut
      [xOut, _x0, _y0, _a, _k, _t] = await pool.getXOutGivenYIn(yIn)
      expect(xOut).to.be.equal("6198602258013584099")

      preUndBalSwapper = await underlyingToken.balanceOf(swapper.address)
      preCapBalSwapper = await capToken.balanceOf(swapper.address)
      preUndBalPool = await underlyingToken.balanceOf(pool.target)
      preCapBalPool = await capToken.balanceOf(pool.target)
      const minXOut = 0
      await capToken.connect(swapper).approve(pool, BigInt(2) ** BigInt(200))
      await pool.connect(swapper).swapGetXGivenYIn(to, yIn, minXOut, deadline)
      postUndBalSwapper = await underlyingToken.balanceOf(swapper.address)
      postCapBalSwapper = await capToken.balanceOf(swapper.address)
      postUndBalPool = await underlyingToken.balanceOf(pool.target)
      postCapBalPool = await capToken.balanceOf(pool.target)

      postUndBalPoolState = await pool.x()
      postCapBalPoolState = await pool.y()
      
      expect(postUndBalPool).to.be.equal(postUndBalPoolState)
      expect(postCapBalPool).to.be.equal(postCapBalPoolState)

      expect(preCapBalSwapper - postCapBalSwapper).to.be.equal(yIn)
      expect(postUndBalSwapper - preUndBalSwapper).to.be.equal(xOut)

      // move past pool expiry
      const timeInSeconds = t.toString();
      await ethers.provider.send("evm_increaseTime", [Number(timeInSeconds)]);
      await ethers.provider.send("evm_mine");

      deadline = (await ethers.provider.getBlock("latest")).timestamp + (600)
      await expect(pool.connect(swapper).swapGetXGivenYIn(to, yIn, minXOut, deadline)).to.be.revertedWithCustomError(pool, "PoolExpired")
      await expect(pool.connect(swapper).swapGetYGivenXIn(to, xIn, minYOut, deadline)).to.be.revertedWithCustomError(pool, "PoolExpired")

      preUndBalPool = await underlyingToken.balanceOf(pool.target)
      preCapBalPool = await capToken.balanceOf(pool.target)
      await pool.connect(lp).redeem(lp.address)
      postUndBalPool = await underlyingToken.balanceOf(pool.target)
      postCapBalPool = await capToken.balanceOf(pool.target)

      expect(postUndBalPool).to.be.equal(0)
      expect(postCapBalPool).to.be.equal(0)

      const bal = await upToken.balanceOf(lp.address)
      await settlementToken.mint(lp.address, BigInt(1000000) * BigInt(10) ** BigInt(6))
      await settlementToken.connect(lp).approve(upToken.target, BigInt(2) ** BigInt(200))
      await upToken.connect(lp).exercise(lp.address, bal / BigInt(2))

      // move past upToken expiry
      const upTokenExpiry = await upToken.expiry()
      const currentTimestamp = BigInt((await ethers.provider.getBlock("latest")).timestamp)
      const timeUntilExpiry = upTokenExpiry - currentTimestamp
      await ethers.provider.send("evm_increaseTime", [Number(timeUntilExpiry.toString())]);
      await ethers.provider.send("evm_mine");
      await expect(upToken.connect(lp).exercise(lp.address, bal / BigInt(2))).to.be.revertedWithCustomError(upToken, "Expired")

      let underlyingBalPre = await underlyingToken.balanceOf(upToken.target)

      // let users convert
      let convertableLpPre = await capToken.convertable(lp.address)
      let lpBalPre = await settlementToken.balanceOf(lp.address)
      await capToken.connect(lp).convert(lp.address)
      let convertableLpPost = await capToken.convertable(lp.address)
      let lpBalPost = await settlementToken.balanceOf(lp.address)
      expect(lpBalPost - lpBalPre).to.be.greaterThan(0)
      expect(convertableLpPre[0] - convertableLpPost[0]).to.be.equal(lpBalPost - lpBalPre)

      let convertableSwapperPre = await capToken.convertable(swapper.address)
      let swapperBalPre = await settlementToken.balanceOf(swapper.address)
      await capToken.connect(swapper).convert(swapper.address)
      let convertableSwapperPost = await capToken.convertable(swapper.address)
      let swapperBalPost = await settlementToken.balanceOf(swapper.address)
      expect(swapperBalPost - swapperBalPre).to.be.greaterThan(0)
      expect(convertableSwapperPre[0] - convertableSwapperPost[0]).to.be.equal(swapperBalPost - swapperBalPre)

      let underlyingBalPost = await underlyingToken.balanceOf(upToken.target)
      expect(underlyingBalPost).to.be.equal(0)
      
    })
  })
})
