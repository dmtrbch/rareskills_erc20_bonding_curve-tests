const { expect } = require("chai");
const { ethers } = require("hardhat");
const { utils } = ethers;
const { BigNumber } = ethers;

function revertReason(reason) {
  return `VM Exception while processing transaction: reverted with reason string '${reason}'`;
}

function calculatePurchaseReturn(totalSupply, reserveBalance, depositAmount) {
  // return totalSupply * (Math.sqrt(1 + depositAmount / reserveBalance) - 1);

  totalSupply.mul(2);
}

function calculateSaleReturn(totalSupply, reserveBalance, sellAmount) {
  const one = new BigNumber.from(1);
  const two = new BigNumber.from(2);
  const amountDivSupply = 
  // return reserveBalance * (1 - Math.pow(1 - sellAmount / totalSupply, 2));
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
      const tx = await bondingCurveTokenContract.mint({
        value: ethers.utils.parseEther("1"),
      });
      await tx.wait();

      const totalSupply = await bondingCurveTokenContract.totalSupply();
      const reserveBalance = await bondingCurveTokenContract.reserveBalance();

      console.log(totalSupply);
      console.log(reserveBalance);
      console.log(ethers.utils.parseEther("1"));

      expect(
        await bondingCurveTokenContract.balanceOf(accounts[0].address)
      ).to.be.above(new BigNumber.from(0));
    });

    it("should revert if trying to mint/buy tokens withoud sending ETH", async function () {
      await expect(bondingCurveTokenContract.mint()).to.be.revertedWith(
        revertReason("ERC20: Must send ether to buy tokens.")
      );
    });
  });
});
