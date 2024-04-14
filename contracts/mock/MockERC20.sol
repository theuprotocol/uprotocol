// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    uint8 private _decimals;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 __decimals,
        uint256 amount
    ) ERC20(_name, _symbol) {
        _decimals = __decimals;
        _mint(msg.sender, amount);
    }

    function mint(address account, uint256 value) external {
        _mint(account, value);
    }
}
