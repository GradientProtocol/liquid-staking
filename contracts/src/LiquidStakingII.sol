// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "./interfaces/IRelayRegistry.sol";
import "./interfaces/IwTAO.sol";
import { SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


// TODO: Add the fucking ACCESS CONTROL vars
contract gswTAO is ERC20, AccessControl {
    using SafeERC20 for ERC20;

    address public owner;

    enum Status {
        UNKNOWN,
        INIT,
        READY,
        COMPLETE
    }
    
    struct UnwrapRequest {
        Status reqStatus;
        uint256 amount;
        uint256 timestamp;
    }

    mapping(address => UnwrapRequest) public unwrapRequests;

    uint256 public yieldAvailable;

    address public wTAO;
    address public relayRegistry;

    uint256 public totalDeposits;
    uint256 public latestTAOBalance;

    // validator cold_key/administrative wallet on bittensor
    string public taoReceiver;

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 _status = _NOT_ENTERED;

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

    modifier onlyRelayers() {
        bool isRelayer = IRelayRegistry(relayRegistry).isRelayer(msg.sender);
        require(isRelayer, "Only relayers");
        _;
    }

    event Rebase(uint256 newBalance);

    constructor() ERC20("gswTAO", "gswTAO") {
        owner = msg.sender;
    }

    function wrap(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");

        uint256 bal = ERC20(wTAO).balanceOf(address(this));
        _transferTokens(wTAO, msg.sender, address(this), amount);
        uint256 deposit = ERC20(wTAO).balanceOf(address(this)) - bal;

        // this is prolly not needed
        // ERC20(wTAO).approve(wTAO, deposit);

        require(IwTAO(wTAO).bridgeBack(deposit, taoReceiver), "TAO bridging failed");

        uint256 rate = mintRate();
        uint256 mintAmount = deposit * rate;

        _mint(msg.sender, mintAmount);
        totalDeposits += deposit;
    }

    // ONLY ONE UNWRAP REQUEST PER ADDRESS
    // in order to save gas, reduce complexity/attack surface

    function unwrap(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");

        UnwrapRequest storage unwrapRequest = unwrapRequests[msg.sender];

        if(unwrapRequest.reqStatus == Status.COMPLETE)
            unwrapRequest.reqStatus = Status.UNKNOWN;
        else
            require(unwrapRequest.reqStatus == Status.UNKNOWN, "Previous request pending");
 
        uint256 rate = burnRate();
        uint256 bridgeAmount = amount * rate;

        _burn(msg.sender, amount);
        totalDeposits -= amount;

        unwrapRequests[msg.sender] = (UnwrapRequest({
            reqStatus: Status.INIT,
            amount: bridgeAmount,
            timestamp: block.timestamp
        }));
    }

    function claim() external {
        UnwrapRequest storage unwrapRequest = unwrapRequests[msg.sender];
        require(unwrapRequest.reqStatus == Status.READY, "No pending claim");

        uint256 pendingOut = unwrapRequest.amount;

        unwrapRequest.amount = 0;
        unwrapRequest.reqStatus = Status.COMPLETE;

        _transferTokens(wTAO, address(this), msg.sender, pendingOut);
    }


// View functions

    // TODO: revise on finish
    function mintRate() public view returns (uint256) {
        return totalDeposits == 0 || totalSupply() < totalDeposits ? 0 
            : totalSupply() * 1e32 / totalDeposits / 1e32;
    }
    // TODO: revise on finish
    function burnRate() public view returns (uint256) {
        return totalDeposits == 0 || totalSupply() < totalDeposits ? 0 
            : totalDeposits * 1e32 / totalSupply() / 1e32;
    }

    function meanYield() external view returns (uint256){
        uint256 surplus = latestTAOBalance -  totalDeposits;
        return surplus / totalDeposits;
    }

    function getCurrentRate() external view returns (uint256) {
        return mintRate();
    }

// RELAYERS ONLY DOT COM
         
    function updateBalances(uint256 newBalance) external onlyRelayers() {
        latestTAOBalance = newBalance;
        emit Rebase(newBalance);
    }

    function fulfillRequest(address user) external onlyRelayers() {
        UnwrapRequest storage unwrapRequest = unwrapRequests[user];
        require(unwrapRequest.reqStatus == Status.INIT, "No pending request");

        unwrapRequest.reqStatus = Status.READY;
    }


// internal functions
    function _transferTokens(address token, address from, address to, uint256 amount) internal entryGuard {
        if(from == address(this))
            ERC20(token).safeTransfer(to, amount);
        else
            ERC20(token).safeTransferFrom(from, to, amount);
    }
}