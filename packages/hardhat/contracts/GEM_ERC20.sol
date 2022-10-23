// SPDX-License-Identifier: Unlicense
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GEM_ERC20 is ERC20 {
    constructor() ERC20("ExampleERC20", "GEM") {
        _mint(msg.sender, 1000);
    }
}
