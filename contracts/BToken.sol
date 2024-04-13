// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {InitializableERC20} from "./InitializableERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract BToken is InitializableERC20 {
    using SafeERC20 for IERC20Metadata;
}
