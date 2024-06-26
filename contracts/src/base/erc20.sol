// SPDX-License-Identifier: MIT

import "../interfaces/IwTAO.sol";
import "../lib/OwnableImplement.sol";


pragma solidity ^0.8.26;

abstract contract ERC20 {

    string public symbol;
    string public name;
    uint8 public decimals;
    uint256 public totalSupply;

    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) allowed;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function initializeERC(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) public virtual
        
    {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
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
        unchecked {
            balances[_from] = balances[_from] - (_value);
            balances[_to] = balances[_to] + (_value);
        }
        emit Transfer(_from, _to, _value);
    }

    function _burn(address _from, uint256 _value) internal {
        require(balances[_from] >= _value, "Insufficient balance");
        balances[_from] -= _value;
        totalSupply -= _value;
        emit Transfer(_from, address(0), _value);
    }

    function _mint(address account, uint256 value) internal {
        balances[account] += value;
        totalSupply += value;
        emit Transfer(address(0), account, value);
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
        allowed[_from][msg.sender] -= _value;
        _transfer(_from, _to, _value);
        return true;
    }

}