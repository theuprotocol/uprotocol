// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Pool} from "./Pool.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PoolFactory {
    using SafeERC20 for IERC20Metadata;

    address public immutable poolImplementation;
    address[] internal _pools;

    error Invalid();
    error InvalidRange();
    error OutOfBounds();

    constructor(address _poolImplementation) {
        poolImplementation = _poolImplementation;
    }

    function createPool(
        address _upToken,
        uint256 _a,
        uint256 _k,
        uint256 _t,
        address to
    ) external returns (address) {
        if (_a == 0 || _k == 0 || _t == 0) {
            revert Invalid();
        }
        address newPool = Clones.cloneDeterministic(
            poolImplementation,
            keccak256(abi.encode(_upToken, _a))
        );

        _pools.push(newPool);
        (address _xToken, address _yToken, uint256 x0y0) = Pool(newPool)
            .initialize(_upToken, _a, _k, _t, to);
        IERC20Metadata(_xToken).transferFrom(msg.sender, newPool, x0y0);
        IERC20Metadata(_yToken).transferFrom(msg.sender, newPool, x0y0);
        return newPool;
    }

    function pools(
        uint256 from,
        uint256 numElements
    ) external view returns (address[] memory) {
        uint256 length = _pools.length;
        if (numElements == 0) {
            revert InvalidRange();
        }
        if (from + numElements > length + 1) {
            revert OutOfBounds();
        }
        address[] memory _poolSelection = new address[](numElements);
        for (uint256 i = 0; i < numElements; i++) {
            _poolSelection[i] = _pools[from + i];
        }
        return _poolSelection;
    }
}
