// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BToken} from "./BToken.sol";
import {UToken} from "./UToken.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

contract UTokenFactory {
    using SafeERC20 for IERC20Metadata;

    address public immutable bTokenImplementation;
    address public immutable uTokenImplementation;
    mapping(IERC20Metadata => mapping(IERC20Metadata => address[]))
        internal uTokens;
    mapping(IERC20Metadata => mapping(IERC20Metadata => address[]))
        internal bTokens;

    error InvalidRange();
    error OutOfBounds();

    constructor(address _bTokenImplementation, address _uTokenImplementation) {
        bTokenImplementation = _bTokenImplementation;
        uTokenImplementation = _uTokenImplementation;
    }

    function tokenizeUnderlying(
        IERC20Metadata _underlyingToken,
        IERC20Metadata _settlementToken,
        uint256 _strike,
        uint256 _expiry
    ) external returns (address, address) {
        address _bTokenImplementation = bTokenImplementation;
        address _uTokenImplementation = uTokenImplementation;

        address newBToken = Clones.cloneDeterministic(
            _bTokenImplementation,
            keccak256(
                abi.encode(
                    _bTokenImplementation,
                    _underlyingToken,
                    _settlementToken,
                    _strike,
                    _expiry
                )
            )
        );

        address newUToken = Clones.cloneDeterministic(
            uTokenImplementation,
            keccak256(
                abi.encode(
                    _uTokenImplementation,
                    _underlyingToken,
                    _settlementToken,
                    _strike,
                    _expiry
                )
            )
        );
        uTokens[_underlyingToken][_settlementToken].push(newUToken);
        bTokens[_underlyingToken][_settlementToken].push(newBToken);

        UToken(newUToken).initialize(
            _underlyingToken,
            _settlementToken,
            newBToken,
            _strike,
            _expiry
        );
        BToken(newBToken).initialize(newBToken);

        return (newBToken, newUToken);
    }

    function getBTokens(
        IERC20Metadata underlying,
        IERC20Metadata settlement,
        uint256 from,
        uint256 numElements
    ) external view returns (address[] memory) {
        address[] memory allBTokens = bTokens[underlying][settlement];
        return _getTokens(allBTokens, from, numElements);
    }

    function getUTokens(
        IERC20Metadata underlying,
        IERC20Metadata settlement,
        uint256 from,
        uint256 numElements
    ) external view returns (address[] memory) {
        address[] memory allUTokens = uTokens[underlying][settlement];
        return _getTokens(allUTokens, from, numElements);
    }

    function _getTokens(
        address[] memory allTokens,
        uint256 from,
        uint256 numElements
    ) internal pure returns (address[] memory) {
        if (numElements == 0) {
            revert InvalidRange();
        }
        uint256 length = allTokens.length;
        if (from + numElements > length + 1) {
            revert OutOfBounds();
        }
        address[] memory selectedTokens = new address[](numElements);
        for (uint256 i = 0; i < numElements; i++) {
            selectedTokens[i] = allTokens[from + i];
        }
        return selectedTokens;
    }
}
