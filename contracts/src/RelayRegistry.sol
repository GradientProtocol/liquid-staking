// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RelayRegistry is Ownable {
    using SafeERC20 for IERC20;
    using Address for address;

    address public entryToken;
    uint256 public entryThreshold;

    mapping(address => uint256) public relayerBalances;

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

    event RelayerEnrolled(address indexed relayer, uint256 amount);
    event RelayerHalted(address indexed relayer, uint256 amount);

    constructor(address _entryToken, uint256 _entryThreshold) {
        entryToken = _entryToken;
        entryThreshold = _entryThreshold;
    }

    function enrollRelayer(uint256 amount) public {
        require(relayerBalances[msg.sender] == 0, "Relay already registered");
        require(amount >= entryThreshold, "Insufficient amount");

        uint256 bal0 = IERC20(entryToken).balanceOf(address(this));
        _transfer(msg.sender, address(this), amount);
        uint256 deposit = IERC20(entryToken).balanceOf(address(this)) - bal0;

        require(deposit >= entryThreshold, "Insufficient deposit");

        relayerBalances[msg.sender] = deposit;
        
        emit RelayerEnrolled(msg.sender, deposit);
    }

    function haltRelayer() public {
        require(relayerBalances[msg.sender] > 0, "Relay not registered");

        uint256 amt = relayerBalances[msg.sender];
        relayerBalances[msg.sender] = 0;
        _transfer(address(this), msg.sender, amt);

        emit RelayerHalted(msg.sender, amt);
    }

    function setEntryThreshold(uint256 _entryThreshold) public onlyOwner {
        entryThreshold = _entryThreshold;
    }

    function setEntryToken(address _entryToken) public onlyOwner {
        entryToken = _entryToken;
    }

    function isRelayer(address relay) external view returns (bool) {
        return relayerBalances[relay] >= entryThreshold;
    }

    function _transfer(address from, address to, uint256 amount) internal entryGuard {
        IERC20 token = IERC20(entryToken);
        if(from == address(this))
            token.safeTransfer(to, amount);
        else
            token.safeTransferFrom(from, to, amount);
    }
}