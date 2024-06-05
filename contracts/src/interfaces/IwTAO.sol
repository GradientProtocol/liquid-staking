// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IwTAO {
    // Constants
    function BRIDGE_ROLE() external view returns (bytes32);

    // Read-only functions
    function decimals() external view returns (uint8);
    function deployer() external view returns (address);
    function BITTENSOR_FEE() external view returns (uint256);

    // State-changing functions
    function burn(address from, uint256 amount) external returns (bool);
    function setBridge(address _bridge) external returns(bool);
    function bridgedTo(string[] memory _froms, address[] memory _tos, uint256[] memory _amounts) external returns(bool);
    function bridgeBack(uint256 _amount, string memory _to) external returns(bool);
    function reclaimToken(address _token) external;

    // Events
    event Mint(address indexed to, uint256 amount);
    event BridgedTo(string from, address indexed to, uint256 amount, uint256 nonce);
    event BridgedBack(address indexed from, uint256 amount, string to, uint256 nonce);
    event BridgeSet(address indexed bridge);
}
