const { expect } = require("chai");
const { ethers } = require("hardhat");
const { utils } = ethers;
const { BigNumber } = ethers;

// const ONE = new BigNumber.from(1);
// const TWO = new BigNumber.from(2);

/* function sqrt(value) {
  let z = value.add(ONE).div(TWO);
  let y = value;
  while (z.sub(y).isNegative()) {
    y = z;
    z = value.div(z).add(z).div(TWO);
  }

  return y;
} */

function revertReason(reason) {
  return `VM Exception while processing transaction: reverted with reason string '${reason}'`;
}

function calculatePurchaseReturn(totalSupply, reserveBalance, depositAmount) {
  return totalSupply * (Math.sqrt(1 + depositAmount / reserveBalance) - 1);
  /* console.log(totalSupply);
  console.log(reserveBalance);
  console.log(depositAmount);
  const depostiDivReserve = depositAmount.div(reserveBalance);
  console.log(depostiDivReserve);
  const onePlustDepostiDivReserve = ONE.add(depostiDivReserve);
  const sqrtOnePlustDepostiDivReserve = sqrt(onePlustDepostiDivReserve);
  const sqrtOnePlustDepostiDivReserveMinusOne =
    sqrtOnePlustDepostiDivReserve.sub(ONE);

  return totalSupply.mul(sqrtOnePlustDepostiDivReserveMinusOne); */
}

function calculateSaleReturn(totalSupply, reserveBalance, sellAmount) {
  return reserveBalance * (1 - Math.pow(1 - sellAmount / totalSupply, 2));
  /* const amountDivSupply = sellAmount.div(totalSupply);
  const oneMinusAmountDivSupply = ONE.sub(amountDivSupply);
  const powerOneMinusAmountDivSupply = oneMinusAmountDivSupply.pow(TWO);
  const substractOnePowerOneMinusAmountDivSupply = ONE.sub(
    powerOneMinusAmountDivSupply
  );

  return reserveBalance.mul(substractOnePowerOneMinusAmountDivSupply); */
}

describe("BondingCurveToken", function () {
  let bondingCurveTokenContract = null;
  let accounts = null;
  // const RESERVE_RATIO = 0.5;
  // const WITHDRAWAL_FEE_PERCENTAGE = 10;
  // const INITIAL_TOKEN_SUPPLY = 100000;

  beforeEach(async function () {
    accounts = await ethers.getSigners();

    const BondingCurveTokenContractFactory = await ethers.getContractFactory(
      "BctToken"
    );
    bondingCurveTokenContract = await BondingCurveTokenContractFactory.deploy();
    await bondingCurveTokenContract.deployed();
  });

  describe("BondingCurveToken: mint - buyTokens", async function () {
    it("should allow minting/buying new tokens with ETH", async function () {
      const depositAmount = 1;
      const tx = await bondingCurveTokenContract.connect(accounts[1]).mint({
        value: ethers.utils.parseEther(depositAmount.toString()),
      });
      await tx.wait();

      const totalSupply = await bondingCurveTokenContract.totalSupply();
      const reserveBalance = await bondingCurveTokenContract.reserveBalance();

      const purchaseReturn = calculatePurchaseReturn(
        utils.formatUnits(totalSupply),
        utils.formatUnits(reserveBalance),
        depositAmount
      );

      expect(
        await bondingCurveTokenContract.balanceOf(accounts[1].address)
      ).to.be.closeTo(
        new BigNumber.from(ethers.utils.parseEther(purchaseReturn.toString())),
        new BigNumber.from(ethers.utils.parseEther(depositAmount.toString()))
      );
    });

    it("should revert if trying to mint/buy tokens withoud sending ETH", async function () {
      await expect(bondingCurveTokenContract.mint()).to.be.revertedWith(
        revertReason("ERC20: Must send ether to buy tokens.")
      );
    });
  });
});
