// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "./base/erc20.sol";
import "./interfaces/IRelayRegistry.sol";
import "./interfaces/IwTAO.sol";
import "./lib//OwnableImplement.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract gswTAO is OwnableImplement, ERC20 {
    using SafeERC20 for IERC20;

    bool public initComplete;

    enum Status {
        UNKNOWN,
        INIT,
        READY,
        COMPLETE
    }

    struct UnwrapRequest {
        Status reqStatus;
        uint256 amount;
        uint256 finalAmount;
        uint256 timestamp;
        uint256 nonce;
    }

    bool public relaysLimited;

    uint256 public stakeFee;

    address public wTAO;
    address public relayRegistry;
    address public feeCollector;

    uint256 public latestTAOBalance;
    uint256 public unwrapNonce;
    uint256 public processedNonce;

    uint256 public constant DIVISOR = 1e32;

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 _status = _NOT_ENTERED;

    // bittensor cold_key address
    string public taoReceiver;

    mapping(address => UnwrapRequest) public unwrapRequests;
    mapping(address => bool) public relayerWhitelist;

    uint256 public decDiff;
    
    uint256 public ethGasFee;
    uint256 public bttGasFee;
    uint256 public bttFeePercent;
    uint256 public bttDivisor;

    modifier entryGuard() {
        require(_status != _ENTERED, "!reentrancy");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    modifier onlyRelayers() {
        _checkRelayer();
        _;
    }

    event StakeWTAO(address user, uint256 amount);
    event UnwrapRequested(address user, uint256 amount, uint256 nonce);
    event Claim(address user, uint256 amount, uint256 nonce);
    event Rebase(uint256 newBalance);

    constructor() {}

    function initialize(
        address _feeCollector,
        address _wTAO,
        address _relayRegistry,
        string memory _taoReceiver
    ) public {
        require(msg.sender == _owner, "!owner");
        require(decDiff == 0 || !initComplete, "!!initialized");
        
        initComplete = true;

        ERC20.initializeERC("Gradient Staked TAO", "gswTAO", 18);

        relaysLimited = true;
        feeCollector = _feeCollector;
        taoReceiver = _taoReceiver;
        wTAO = _wTAO;
        relayRegistry = _relayRegistry;

        decDiff = this.decimals() - IwTAO(wTAO).decimals();
    }

    function initializeERC(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) public override onlyOwner {
        require(decDiff == 0 || !initComplete, "!!initialized");
        ERC20.initializeERC(_name, _symbol, _decimals);

    }

    function wrap(uint256 amount) external {
        require(amount > 0, "!greater_than_zero");
        require(amount > minStakeAmt(), "!min_stake_amt");

        uint256 bal = IERC20(wTAO).balanceOf(address(this));
        _transferTokens(wTAO, msg.sender, address(this), amount);
        uint256 deposit = IERC20(wTAO).balanceOf(address(this)) - bal;

        require(
            IwTAO(wTAO).bridgeBack(deposit, taoReceiver),
            "bridging_failed"
        );

        uint256 bitFee = IwTAO(wTAO).BITTENSOR_FEE();

        deposit -= (bitFee + stakeFee);

        uint256 rate = mintRate();
        uint256 mintAmount = ((deposit * 10**decDiff) * rate) / DIVISOR;

        _mint(msg.sender, mintAmount);
        latestTAOBalance += deposit;

        emit StakeWTAO(msg.sender, mintAmount);
    }

    // ONLY ONE UNWRAP REQUEST PER ADDRESS AT A TIME
    // This is done in order to save on gas and reduce complexity/attack surface

    function unwrap(uint256 amount) external {
        require(amount > 0, "!greater_than_zero");
        require(amount > minStakeAmt(), "!min_stake_amt");

        UnwrapRequest storage unwrapRequest = unwrapRequests[msg.sender];

        if (unwrapRequest.reqStatus == Status.COMPLETE)
            unwrapRequest.reqStatus = Status.UNKNOWN;
        else
            require(
                unwrapRequest.reqStatus == Status.UNKNOWN,
                "request_pending"
            );

        uint256 rate = burnRate();
        uint256 bridgeAmount = (amount * rate) / DIVISOR / 10**decDiff;

        _burn(msg.sender, amount);
        latestTAOBalance -= bridgeAmount;

        // adding this to handle precision limitations
        if (latestTAOBalance == 1) latestTAOBalance = 0;

        unwrapRequests[msg.sender] = (
            UnwrapRequest({
                reqStatus: Status.INIT,
                amount: bridgeAmount,
                finalAmount: 0,
                timestamp: block.timestamp,
                nonce: unwrapNonce
            })
        );

        emit UnwrapRequested(msg.sender, bridgeAmount, unwrapNonce);
        unwrapNonce++;
    }

    function claim() external {
        UnwrapRequest storage unwrapRequest = unwrapRequests[msg.sender];
        require(unwrapRequest.reqStatus == Status.READY, "!claim");

        uint256 pendingOut = unwrapRequest.finalAmount;

        unwrapRequest.amount = 0;
        unwrapRequest.finalAmount = 0;
        unwrapRequest.reqStatus = Status.COMPLETE;

        require(
            IERC20(wTAO).balanceOf(address(this)) >= pendingOut,
            "!balance"
        );

        _transferTokens(wTAO, address(this), msg.sender, pendingOut);

        emit Claim(msg.sender, pendingOut, unwrapRequest.nonce);
    }

    // View functions

    function mintRate() public view returns (uint256 rate) {
        rate =
            totalSupply == 0 || latestTAOBalance == 0
                ? 1 * DIVISOR
                : (totalSupply * DIVISOR) / (latestTAOBalance * 10**decDiff);

        return rate;
    }

    function burnRate() public view returns (uint256 rate) {
        rate =
            totalSupply == 0 || latestTAOBalance == 0
                ? 1 * DIVISOR
                : ((latestTAOBalance * 10**decDiff) * DIVISOR) / totalSupply;

        return rate;
    }

    function minStakeAmt() public view returns (uint256) {
        return IwTAO(wTAO).BITTENSOR_FEE() * 4;
    }

    function bridgeToEthFee(uint256 amount) public view returns (uint256 actualFee) {
        uint256 percentFee = (amount * bttFeePercent) / bttDivisor;
        actualFee = percentFee > bttGasFee ? percentFee : bttGasFee;
        actualFee += ethGasFee;
    }

    // defaults based off taobridge.xyz values:
    // eth gas fee: 2000 => 0.002 eth
    // btt gas fee: 500000 => 0.005 tao
    // % fee: 5 => 0.5% fee
    // calc divisor: 1000 => allows calc values down to 0.1%
    function setBttValues(uint256 _ethGasFee, uint256 _bttGasFee, uint256 _bttFeePercent, uint256 _bttDivisor) external onlyOwner {
        ethGasFee = _ethGasFee;
        bttGasFee = _bttGasFee;
        bttFeePercent = _bttFeePercent;
        bttDivisor = _bttDivisor;
    }

    // OWNERS ONLY DOT COM / RELAYERS ONLY DOT COM

    function setRelayerWhitelist(address relayer, bool status) external onlyOwner {
        relayerWhitelist[relayer] = status;
    }

    function setRegistry(address _registry) external onlyOwner {
        require(_registry != address(0), "invalid_address");
        relayRegistry = _registry;
    }

    function setRelayLimited(bool _set) external onlyOwner {
        relaysLimited = _set;
    }

    function setStakeFee(uint256 _stakeFee) external onlyOwner {
        require(_stakeFee < 1e9, "invalid_stake_fee");
        stakeFee = _stakeFee;
    }

    function setTaoReceiver(string memory _taoReceiver) external onlyOwner {
        require(bytes(_taoReceiver).length > 0, "invalid_tao_receiver");
        taoReceiver = _taoReceiver;
    }

    function setTaoAddress(address _wTAO) external onlyOwner {
        require(_wTAO != address(0), "invalid_address");
        wTAO = _wTAO;
    }

    function setFeeCollector(address _feeCollector) external onlyOwner {
        require(_feeCollector != address(0), "invalid_address");
        feeCollector = _feeCollector;
    }

    function setBalance(uint256 _latestTAOBalance) external onlyRelayers {
        require(_latestTAOBalance >= totalSupply / 10**decDiff, "invalid_balance");
        require(totalSupply > 0, "invalid_total_supply");

        latestTAOBalance = _latestTAOBalance;
        emit Rebase(_latestTAOBalance);
    }

    function fulfillRequest(address user) external onlyRelayers {
        UnwrapRequest storage unwrapRequest = unwrapRequests[user];
        require(unwrapRequest.reqStatus == Status.INIT, "!pending");
        require(unwrapRequest.nonce == processedNonce, "invalid_nonce");
        processedNonce++;

        unwrapRequest.finalAmount = (unwrapRequest.amount - bridgeToEthFee(unwrapRequest.amount));
        require(
            IERC20(wTAO).balanceOf(address(this)) >=
                unwrapRequest.finalAmount, // / 10**decDiff - ethGasFee,
            "insufficient_balance"
        );

        unwrapRequest.reqStatus = Status.READY;
    }

    function fulfillBatchRequest(address[] calldata users) external onlyRelayers {
        uint256 runningTotal;
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];

            UnwrapRequest storage unwrapRequest = unwrapRequests[user];
            if(unwrapRequest.reqStatus != Status.INIT) continue;
            if(unwrapRequest.nonce != processedNonce) continue;
            processedNonce++;

            runningTotal += unwrapRequest.amount - bridgeToEthFee(unwrapRequest.amount);
            unwrapRequest.finalAmount = (unwrapRequest.amount - bridgeToEthFee(unwrapRequest.amount));

            unwrapRequest.reqStatus = Status.READY;
        }

        uint256 bal = IERC20(wTAO).balanceOf(address(this));
        require(bal >= runningTotal, "insufficient_balance");
    }

    function setDecDiff() external onlyOwner {
        decDiff = this.decimals() - IwTAO(wTAO).decimals();
    }

    function rescueTokens(
        address recipient,
        address token,
        uint256 amount
    ) external onlyOwner {
        IERC20(token).safeTransfer(recipient, amount);
    }

    function rescueNative(uint256 amount, address payable recipient) external onlyOwner {
        recipient.transfer(amount);
    }

    // internal functions

    function _checkRelayer() internal view {
        if(relaysLimited) {
            require(relayerWhitelist[msg.sender], "!whitelisted");
        } else {
            bool isRelayer = IRelayRegistry(relayRegistry).isRelayer(msg.sender);
            require(isRelayer, "!relayer");
        }
    }

    function _transferTokens(
        address token,
        address from,
        address to,
        uint256 amount
    ) internal entryGuard {
        if (from == address(this)) IERC20(token).safeTransfer(to, amount);
        else IERC20(token).safeTransferFrom(from, to, amount);
    }

}
