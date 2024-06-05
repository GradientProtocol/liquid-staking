// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Deployer {
    event Deployed(address indexed addr);

    function deployContract(
        string calldata salt_,
        bytes calldata bytecode_
    ) public returns (address) {
        require(bytecode_.length > 0, "Empty bytecode");
        bytes memory bytecode = bytecode_;
        address addr;

        bytes32 salt = keccak256(abi.encode(salt_));

        assembly {
            addr := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }

        require(addr != address(0), "Failed to deploy contract");

        emit Deployed(addr);
        return addr;
    }
}
