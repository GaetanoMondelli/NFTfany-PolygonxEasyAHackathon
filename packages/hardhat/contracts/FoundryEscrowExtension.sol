import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@openzeppelin/contracts/utils/Counters.sol";

import "hardhat/console.sol";

contract FoundryEscrowExtension is Ownable {
    using Address for address payable;
    using SafeMath for uint256;

    event Deposited(uint256 indexed tokenId, uint256 weiAmount);
    event Withdrawn(uint256 indexed tokenId, uint256 weiAmount);

    event DepositedERC20(
        uint256 indexed tokenId,
        address indexed tokenAddress,
        uint256 amount
    );
    event WithdrawnERC20(
        uint256 indexed tokenId,
        address indexed tokenAddress,
        uint256 amount
    );

    address foundryAddress;

    mapping(uint256 => uint256) private _deposits;

    // tokenId -> GemAddress(ERC20) -> Token quantity
    mapping(uint256 => mapping(address => uint256)) _tokenBalances;

    mapping(address => uint256) _totalSupplies;

    constructor(address _foundryAddress) {
        foundryAddress = _foundryAddress;
    }

    function totalSupplies(address tokenAddress) public view returns (uint256) {
        return _totalSupplies[tokenAddress];
    }

    function depositsOf(uint256 tokenId) public view returns (uint256) {
        return _deposits[tokenId];
    }

    function balanceOf(uint256 tokenId, address tokenAddress)
        public
        view
        returns (uint256)
    {
        return _tokenBalances[tokenId][tokenAddress];
    }

    /**
     * @dev Stores the sent amount as credit to be withdrawn.
     * @param tokenId the TokenId whose owner is the destination address of the funds.
     *
     * Emits a {Deposited} event.
     */
    function deposit(uint256 tokenId) public payable virtual onlyOwner {
        uint256 amount = msg.value;
        _deposits[tokenId] += amount;
        emit Deposited(tokenId, amount);
    }

    /**
     * @dev Withdraw accumulated balance for a payee, forwarding all gas to the
     * recipient.
     *
     * WARNING: Forwarding all gas opens the door to reentrancy vulnerabilities.
     * Make sure you trust the recipient, or are either following the
     * checks-effects-interactions pattern or using {ReentrancyGuard}.
     *
     * @param tokenId The token id whose funds will be withdrawn and transferred to its owner.
     *
     * Emits a {Withdrawn} event.
     */
    function withdraw(uint256 tokenId) public virtual onlyOwner {
        uint256 payment = _deposits[tokenId];

        _deposits[tokenId] = 0;

        address payable owner = payable(
            IERC721(foundryAddress).ownerOf(tokenId)
        );

        owner.sendValue(payment);

        console.log("with", owner, tokenId, payment);

        emit Withdrawn(tokenId, payment);
    }

    function depositERC20(
        uint256 tokenId,
        address tokenAddress,
        address tokenOwner,
        uint256 amount
    ) external onlyOwner {
        require(amount > 0, "Cannot deposit zero tokens");
        _totalSupplies[tokenAddress] = _totalSupplies[tokenAddress].add(amount);
        _tokenBalances[tokenId][tokenAddress] = _tokenBalances[tokenId][
            tokenAddress
        ].add(amount);
        // Before this you should have approved the amount
        // This will transfer the amount of  _token from caller to contract
        console.log("amount", _tokenBalances[tokenId][tokenAddress]);
        IERC20(tokenAddress).transferFrom(tokenOwner, address(this), amount);
        emit DepositedERC20(tokenId, tokenAddress, amount);
    }

    function withdrawERC20(uint256 tokenId, address tokenAddress)
        external
        onlyOwner
    {
        uint256 amount = _tokenBalances[tokenId][tokenAddress];

        _totalSupplies[tokenAddress] = _totalSupplies[tokenAddress].sub(amount);
        _tokenBalances[tokenId][tokenAddress].sub(amount);
        address owner = IERC721(foundryAddress).ownerOf(tokenId);
        // This will transfer the amount of  _token from contract to owner of tokenId
        console.log("sender", _msgSender(), foundryAddress);
        IERC20(tokenAddress).transfer(owner, amount);
        emit DepositedERC20(tokenId, tokenAddress, amount);
    }

    function getInterfaceIdForFoundry() public pure returns (bytes4) {
        return type(IERC721).interfaceId;
    }
}
