pragma solidity ^0.8.0;
//SPDX-License-Identifier: MIT

//import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import "./FoundryEscrowExtension.sol";

import "hardhat/console.sol";

// import "@openzeppelin/contracts/utils/escrow/Escrow.sol";
//learn more: https://docs.openzeppelin.com/contracts/3.x/erc721

// GET LISTED ON OPENSEA: https://testnets.opensea.io/get-listed/step-two

contract NFTFanyRingFoundry is ERC721, Ownable {
    using ERC165Checker for address;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    mapping(uint256 => string) private _engravings;
    mapping(address => Counters.Counter) private _gemAllocation;
    mapping(uint256 => address) private _gemMap;

    mapping(address => bool) private _forged;

    uint256 constant FOUNDRY_MATIC_ALLOY_CAP = 50000 ether; // 1 MATIC $0.87
    uint256 constant MIN_MATIC_ALLOY_RING = 100 ether;
    uint256 constant MAX_MATIC_ALLOY_RING = 1000 ether;
    uint256 constant MAX_GEM_TYPE_RINGS = 3;
    uint256 foundryAlloyCapacity = FOUNDRY_MATIC_ALLOY_CAP;

    FoundryEscrowExtension private foundryEscrow;

    constructor() ERC721("NFTFanyRing", "TFN") {
        foundryEscrow = new FoundryEscrowExtension(address(this));
    }

    function getAllowanceAddress() public view returns (address) {
        return address(foundryEscrow);
    }

    function getInterfaceIdForGems() public pure returns (bytes4) {
        return type(IERC20).interfaceId;
    }

    function getTokenCounterId() public view returns (uint256) {
        return _tokenIds.current();
    }

    function getTokenEngraving(uint256 tokenId)
        public
        view
        returns (string memory)
    {
        return _engravings[tokenId];
    }

    function getMaxAlloy() public pure returns (uint256) {
        return FOUNDRY_MATIC_ALLOY_CAP;
    }

    function getAlloyLeft() public view returns (uint256) {
        return foundryAlloyCapacity;
    }

    function getTokenIdAlloy(uint256 tokenId) public view returns (uint256) {
        return foundryEscrow.depositsOf(tokenId);
    }

    function getGemAddress(uint256 tokenId) public view returns (address) {
        return _gemMap[tokenId];
    }

    function getGemAddressQuantity(uint256 tokenId)
        public
        view
        returns (uint256)
    {
        return foundryEscrow.balanceOf(tokenId, _gemMap[tokenId]);
    }

    function getGemForged(address tokenAddress) public view returns (uint256) {
        return foundryEscrow.totalSupplies(tokenAddress);
    }

    function getGemAllocated(address tokenAddress)
        public
        view
        returns (uint256)
    {
        return _gemAllocation[tokenAddress].current();
    }

    function forge(
        address to,
        address gemAddress,
        uint256 gemQuantity,
        string memory engraving
    ) public payable returns (uint256) {
        require(
            msg.value < MAX_MATIC_ALLOY_RING,
            "Matic alloy exceeds MAX_MATIC_ALLOY_RING"
        );
        require(
            msg.value >= MIN_MATIC_ALLOY_RING,
            "Matic alloy is below MIN_MATIC_ALLOY_RING"
        );
        require(
            msg.value < foundryAlloyCapacity,
            "Foundry has not enough alloy capacity"
        );
        // Need to whitelist gem tokens
        // require(
        //     gemAddress.supportsInterface(getInterfaceIdForGems()),
        //     "Foundry v1 only supports ERC20 as gem"
        // );
        require(
            _gemAllocation[gemAddress].current() < MAX_GEM_TYPE_RINGS,
            "Foundry has already forged MAX_GEM_TYPE_RINGS rings for gemAddress"
        );

        _tokenIds.increment();
        uint256 id = _tokenIds.current();
        foundryEscrow.deposit{value: msg.value}(id);
        foundryAlloyCapacity -= msg.value;
        _gemAllocation[gemAddress].increment();
        _gemMap[id] = gemAddress;

        foundryEscrow.depositERC20(id, gemAddress, msg.sender, gemQuantity);

        _engravings[id] = engraving;
        _mint(to, id);
        return id;
    }

    function melt(uint256 tokenId) public {
        require(ownerOf(tokenId) == msg.sender, "Only the ring owner can melt");

        uint256 ringAlloy = foundryEscrow.depositsOf(tokenId);
        foundryEscrow.withdraw(tokenId);
        foundryAlloyCapacity += ringAlloy;

        _gemAllocation[_gemMap[tokenId]].decrement();
        foundryEscrow.withdrawERC20(tokenId, _gemMap[tokenId]);

        _burn(tokenId);
    }
}
