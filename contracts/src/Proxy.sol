// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.0 <0.9.0;

import "./lib//OwnableImplement.sol";

/**
 * @title Proxy
 * @author naomsa <https://twitter.com/naomsa666>
 * @notice An upgradable proxy util for function delegation following EIP-897.
 * @dev The implementaion MUST reserve the first two storage slots to the
 * `_owner` address and the `_implementation` address.
 */
contract Proxy is OwnableImplement {

    /// @notice Emitted when a new implementation is set.
    event Upgraded(address indexed from, address indexed to);

    constructor() {}

    function implementation() public view returns (address) {
        return _implementation;
    }

    /// @notice Set the new implementation.
    function setImplementation(address newImplementation) public onlyOwner {
        require(
            newImplementation != address(0),
            "Proxy: upgrading to the zero address"
        );
        require(
            newImplementation != _implementation,
            "Proxy: upgrading to the current implementation"
        );

        address oldImplementation = _implementation;
        _implementation = newImplementation;

        emit Upgraded(oldImplementation, newImplementation);
    }

    function setImplementation(
        address newImplementation,
        bytes memory data
    ) public onlyOwner {
        require(
            newImplementation != address(0),
            "Proxy: upgrading to the zero address"
        );
        require(
            newImplementation != _implementation,
            "Proxy: upgrading to the current implementation"
        );

        address oldImplementation = _implementation;
        _implementation = newImplementation;

        (bool success, bytes memory returndata) = newImplementation
            .delegatecall(data);
        verifyCallResult(success, returndata, "Implementation call failed");

        emit Upgraded(oldImplementation, newImplementation);
    }

    /// @notice See {EIP897-proxyType}.
    function proxyType() external pure returns (uint256) {
        return 2;
    }

    /**
     * @notice Fallback function that delegates calls to the address returned by `_implementation()`. Will run if no other
     * function in the contract matches the call data.
     */
    fallback() external payable {
        _delegate(_implementation);
    }

    /**
     * @notice Fallback function that delegates calls to the address returned by `_implementation()`. Will run if no other
     * function in the contract matches the call data.
     */
    receive() external payable {
        _delegate(_implementation);
    }

    /// @notice Delegate the current call to `newImplementation`.
    function _delegate(address newImplementation) internal {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(
                gas(),
                newImplementation,
                0,
                calldatasize(),
                0,
                0
            )

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }

    function _checkOwner() internal view {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
    }
}
