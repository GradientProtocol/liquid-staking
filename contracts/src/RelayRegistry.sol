// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract RelayRegistr {
    using SafeERC20 for IERC20;
    using Address for address;

    address public owner;
    address public entryToken;

    bytes32 public constant AUX_ADMIN = keccak256("AUX_ADMIN");
    uint256 constant DIVISOR = 10_000;

    mapping(address => uint256) public relayerBalances;

    uint256 public entryThreshold;

    // entryguard vars
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 _status =        _NOT_ENTERED;


    modifier entryGuard() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor(address _entryToken) {
        owner = msg.sender;
        entryToken = _entryToken;
    }

    function enrollRelayer(uint256 amount) public {
        require(relayerBalances[msg.sender] == 0, "Relay already registered");
        require(amount >= entryThreshold, "Insufficient amount");

        uint256 bal0 = IERC20(entryToken).balanceOf(address(this));
        _transfer(msg.sender, address(this), amount);
        uint256 deposit = IERC20(entryToken).balanceOf(address(this)) - bal0;

        relayerBalances[msg.sender] = deposit;
    }

    function haltRelayer() public {
        require(relayerBalances[msg.sender] >= entryThreshold, "Relay not registered");

        uint256 amt = relayerBalances[msg.sender];
        relayerBalances[msg.sender] = 0;
        _transfer(address(this), msg.sender, amt);
    }

    function isRelayer(address relay) external view returns (bool) {
        return relayerBalances[relay] == entryThreshold;
    }

    function _transfer(address from, address to, uint256 amount) internal entryGuard {
        IERC20 token = IERC20(entryToken);
        if(from == address(this))
            token.safeTransfer(to, amount);
        else
            token.safeTransferFrom(from, to, amount);
    }
}