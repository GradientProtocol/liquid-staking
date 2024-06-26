// SPDX-License-Identifier: MIT

import "../interfaces/IwTAO.sol";

pragma solidity ^0.8.26;

contract wTAO {
    string public symbol;
    string public name;
    uint256 public decimals;
    uint256 public totalSupply;

    // this was a real fee from the live contract
    // it's a 0.125% fee and has the same number of decimals as wTAO (9)
    uint256 public BITTENSOR_FEE = 125000145;

    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) allowed;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _decimals,
        uint256 _totalSupply
    )
        
    {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        totalSupply = _totalSupply;
        balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    function bridgeBack(uint256 _amount, string memory) external returns(bool) {
        _burn(msg.sender, _amount);
        return true;
    }

    
    function balanceOf(address _owner) public view returns (uint256) {
        return balances[_owner];
    }

    
    function allowance(
        address _owner,
        address _spender
    )
        public
        view
        returns (uint256)
    {
        return allowed[_owner][_spender];
    }

    
    function approve(address _spender, uint256 _value) public returns (bool) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    
    function _transfer(address _from, address _to, uint256 _value) internal {
        require(balances[_from] >= _value, "Insufficient balance");
        balances[_from] = balances[_from] - (_value);
        balances[_to] = balances[_to] + (_value);
        emit Transfer(_from, _to, _value);
    }

    function _burn(address _from, uint256 _value) internal {
        require(balances[_from] >= _value, "Insufficient balance");
        balances[_from] -= _value;
    }

    
    function transfer(address _to, uint256 _value) public returns (bool) {
        _transfer(msg.sender, _to, _value);
        return true;
    }


    
    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    )
        public
        returns (bool)
    {
        require(allowed[_from][msg.sender] >= _value, "Insufficient allowance");
        allowed[_from][msg.sender] = allowed[_from][msg.sender] - (_value);
        _transfer(_from, _to, _value);
        return true;
    }

}