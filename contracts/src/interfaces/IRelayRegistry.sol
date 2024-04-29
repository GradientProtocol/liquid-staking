// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IRelayRegistry {
    function enrollRelayer() external;
    function haltRelayer() external;
    function isRelayer(address relay) external view returns (bool);
}
