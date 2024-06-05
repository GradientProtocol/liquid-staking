// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.0;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract OwnableImplement is Context {
    address internal _owner;
    address internal _implementation;
    address public ownerNominee;

    event OwnerNominated(address indexed potentialOwner);
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        _owner = msg.sender;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() external virtual onlyOwner {
        _owner = address(0);
    }

    function transferOwnership(address nominee) external onlyOwner {
        require(nominee != address(0), "!zero_address");
        ownerNominee = nominee;
        emit OwnerNominated(nominee);
    }

    function acceptOwnership() external {
        require(msg.sender == ownerNominee, "!nominated");
        _acceptOwnership();
    }

    function _acceptOwnership() internal virtual {
        address oldOwner = _owner;
        _owner = ownerNominee;
        ownerNominee = address(0);
        emit OwnershipTransferred(oldOwner, _owner);
    }
}
