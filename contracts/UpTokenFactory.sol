// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {CapToken} from "./CapToken.sol";
import {UpToken} from "./UpToken.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

contract UpTokenFactory {
    using SafeERC20 for IERC20Metadata;

    address public immutable capTokenImplementation;
    address public immutable upTokenImplementation;
    mapping(IERC20Metadata => mapping(IERC20Metadata => address[]))
        internal upTokens;
    mapping(IERC20Metadata => mapping(IERC20Metadata => address[]))
        internal capTokens;

    error InvalidRange();
    error OutOfBounds();

    constructor(
        address _capTokenImplementation,
        address _upTokenImplementation
    ) {
        capTokenImplementation = _capTokenImplementation;
        upTokenImplementation = _upTokenImplementation;
    }

    function create(
        IERC20Metadata _underlyingToken,
        IERC20Metadata _settlementToken,
        uint256 _strike,
        uint256 _expiry,
        address to,
        uint256 amount
    ) external returns (address, address) {
        address _capTokenImplementation = capTokenImplementation;
        address _upTokenImplementation = upTokenImplementation;

        address newCapToken = Clones.cloneDeterministic(
            _capTokenImplementation,
            keccak256(
                abi.encode(
                    _capTokenImplementation,
                    _underlyingToken,
                    _settlementToken,
                    _strike,
                    _expiry
                )
            )
        );

        address newUpToken = Clones.cloneDeterministic(
            upTokenImplementation,
            keccak256(
                abi.encode(
                    _upTokenImplementation,
                    _underlyingToken,
                    _settlementToken,
                    _strike,
                    _expiry
                )
            )
        );
        upTokens[_underlyingToken][_settlementToken].push(newUpToken);
        capTokens[_underlyingToken][_settlementToken].push(newCapToken);

        CapToken(newCapToken).initialize(newUpToken);
        UpToken(newUpToken).initialize(
            _underlyingToken,
            _settlementToken,
            newCapToken,
            _strike,
            _expiry,
            to,
            amount
        );

        _underlyingToken.safeTransferFrom(msg.sender, newUpToken, amount);

        return (newCapToken, newUpToken);
    }

    function tokens(
        IERC20Metadata underlying,
        IERC20Metadata settlement,
        uint256 from,
        uint256 numElements
    ) external view returns (address[] memory, address[] memory) {
        uint256 length = capTokens[underlying][settlement].length;
        if (numElements == 0) {
            revert InvalidRange();
        }
        if (from + numElements > length + 1) {
            revert OutOfBounds();
        }
        address[] memory _upTokens = new address[](numElements);
        address[] memory _capTokens = new address[](numElements);
        for (uint256 i = 0; i < numElements; i++) {
            _upTokens[i] = upTokens[underlying][settlement][from + i];
            _capTokens[i] = capTokens[underlying][settlement][from + i];
        }
        return (_upTokens, _capTokens);
    }
}
