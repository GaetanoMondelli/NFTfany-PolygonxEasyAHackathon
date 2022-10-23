const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");
const { use, expect } = require("chai");
const { solidity } = require("ethereum-waffle");

use(solidity);

describe("NFTFanyRingFoundry", () => {
  describe("deploy", () => {
    it("should deploy a NFTFanyRingFoundry contract", async () => {
      const NFTFanyRingFoundryFactory = await ethers.getContractFactory(
        "NFTFanyRingFoundry"
      );
      const NFTFanyRingFoundry = await NFTFanyRingFoundryFactory.deploy();
      // eslint-disable-next-line no-unused-expressions
      expect(NFTFanyRingFoundry.address).to.exist;
    });

    it("should forge a ring", async () => {
      const [foundryOwner, erc20Owner, ringOwner] = await ethers.getSigners();
      const ERC20GemFactory = await ethers.getContractFactory(
        "GEM_ERC20",
        erc20Owner
      );
      const ERC20Gem = await ERC20GemFactory.deploy();

      const NFTFanyRingFoundryFactory = await ethers.getContractFactory(
        "NFTFanyRingFoundry",
        foundryOwner
      );
      const NFTFanyRingFoundry = await NFTFanyRingFoundryFactory.deploy();

      await ERC20Gem.connect(erc20Owner).transfer(ringOwner.address, 30);
      console.log(
        "logg",
        NFTFanyRingFoundry.address,
        await NFTFanyRingFoundry.getAllowanceAddress()
      );
      await ERC20Gem.connect(ringOwner).approve(
        await NFTFanyRingFoundry.getAllowanceAddress(),
        20
      );

      expect(
        await ERC20Gem.connect(ringOwner).allowance(
          ringOwner.address,
          await NFTFanyRingFoundry.getAllowanceAddress()
        )
      ).to.equal(20);

      expect(await NFTFanyRingFoundry.getTokenCounterId()).to.equal(0);
      expect(await NFTFanyRingFoundry.getAlloyLeft()).to.equal(
        await NFTFanyRingFoundry.getMaxAlloy()
      );

      await NFTFanyRingFoundry.connect(ringOwner).forge(
        ringOwner.address,
        ERC20Gem.address,
        10,
        "One ring to rule them all",
        { value: ethers.utils.parseEther("100") }
      );
      expect(await NFTFanyRingFoundry.getTokenCounterId()).to.equal(1);

      const maxAlloy = BigNumber.from(await NFTFanyRingFoundry.getMaxAlloy());
      const exp = BigNumber.from("10").pow(18);
      const alloyUsed = BigNumber.from("100").mul(exp);
      const left = maxAlloy.sub(alloyUsed); // 49900000000000000000000
      console.log(maxAlloy, alloyUsed, left);
      expect(BigNumber.from(await NFTFanyRingFoundry.getAlloyLeft())).to.equal(
        left
      );
    });
  });
});
