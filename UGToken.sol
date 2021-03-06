/*
This Token Contract implements the standard token functionality (https://github.com/ethereum/EIPs/issues/20) as well as the following OPTIONAL extras intended for use by humans.

In other words. This is intended for deployment in something like a Token Factory or Mist wallet, and then used by humans.
Imagine coins, currencies, shares, voting weight, etc.
Machine-based, rapid creation of many tokens would not necessarily need these extra features or will be minted in other manners.

1) Initial Finite Supply (upon creation one specifies how much is minted).
2) In the absence of a token registry: Optional Decimal, Symbol & Name.
3) Optional approveAndCall() functionality to notify a contract if an approval() has occurred.

.*/

import "./StandardToken.sol";

pragma solidity ^0.4.8;

contract UGToken is StandardToken {

    function () {
        //if ether is sent to this address, send it back.
        throw;
    }

    string public name = "UG Token";                   //fancy name: eg Simon Bucks
    uint8 public decimals = 18;                //How many decimals to show. ie. There could 1000 base units with 3 decimals. Meaning 0.980 SBX = 980 base units. It's like comparing 1 wei to 1 ether.
    string public symbol = "UGT";                 //An identifier: eg SBX
    string public version = 'v0.1';       //ug 0.1 standard. Just an arbitrary versioning scheme.

    address public founder; // The address of the founder
    uint256 public allocateStartBlock; // The start block number that starts to allocate token to users.
    uint256 public allocateEndBlock; // The end block nubmer that allocate token to users, lasted for a week.

    // The nonce for avoid transfer replay attacks
    mapping(address => uint256) nonces;

    function UGToken() {
        founder = msg.sender;
        allocateStartBlock = block.number;
        allocateEndBlock = allocateStartBlock + 5082; // about one day
    }

    /*
     * Proxy transfer ug token. When some users of the ethereum account has no ether,
     * he or she can authorize the agent for broadcast transactions, and agents may charge agency fees
     * @param _from
     * @param _to
     * @param _value
     * @param feeUgt
     * @param _v
     * @param _r
     * @param _s
     */
    function transferProxy(address _from, address _to, uint256 _value, uint256 _feeUgt,
        uint8 _v,bytes32 _r, bytes32 _s) returns (bool){

        if(balances[_from] < _feeUgt + _value) throw;

        uint256 nonce = nonces[_from];
        bytes32 h = sha3(_from,_to,_value,_feeUgt,nonce);
        if(_from != ecrecover(h,_v,_r,_s)) throw;

        if(balances[_to] + _value < balances[_to]
            || balances[msg.sender] + _feeUgt < balances[msg.sender]) throw;
        balances[_to] += _value;
        Transfer(_from, _to, _value);

        balances[msg.sender] += _feeUgt;
        Transfer(_from, msg.sender, _feeUgt);

        balances[_from] -= _value + _feeUgt;
        nonces[_from] = nonce + 1;
        return true;
    }

    /*
     * Proxy approve that some one can authorize the agent for broadcast transaction
     * which call approve method, and agents may charge agency fees
     * @param _from The  address which should tranfer ugt to others
     * @param _spender The spender who allowed by _from
     * @param _value The value that should be tranfered.
     * @param _v
     * @param _r
     * @param _s
     */
    function approveProxy(address _from, address _spender, uint256 _value,
        uint8 _v,bytes32 _r, bytes32 _s) returns (bool success) {

        uint256 nonce = nonces[_from];
        bytes32 hash = sha3(_from,_spender,_value,nonce);
        if(_from != ecrecover(hash,_v,_r,_s)) throw;
        allowed[_from][_spender] = _value;
        Approval(_from, _spender, _value);
        nonces[_from] = nonce + 1;
        return true;
    }


    /*
     * Get the nonce
     * @param _addr
     */
    function getNonce(address _addr) constant returns (uint256){
        return nonces[_addr];
    }

    /* Approves and then calls the receiving contract */
    function approveAndCall(address _spender, uint256 _value, bytes _extraData) returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);

        //call the receiveApproval function on the contract you want to be notified. This crafts the function signature manually so one doesn't have to include a contract in here just for this.
        //receiveApproval(address _from, uint256 _value, address _tokenContract, bytes _extraData)
        //it is assumed that when does this that the call *should* succeed, otherwise one would use vanilla approve instead.
        if(!_spender.call(bytes4(bytes32(sha3("receiveApproval(address,uint256,address,bytes)"))), msg.sender, _value, this, _extraData)) { throw; }
        return true;
    }

    /* Approves and then calls the contract code*/
    function approveAndCallcode(address _spender, uint256 _value, bytes _extraData) returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);

        //Call the contract code
        if(!_spender.call(_extraData)) { throw; }
        return true;
    }

    // Allocate tokens to the users
    // @param _owners The owners list of the token
    // @param _values The value list of the token
    function allocateTokens(address[] _owners, uint256[] _values) {

        if(msg.sender != founder) throw;
        if(block.number < allocateStartBlock || block.number > allocateEndBlock) throw;
        if(_owners.length != _values.length) throw;

        for(uint256 i = 0; i < _owners.length ; i++){
            address owner = _owners[i];
            uint256 value = _values[i];
            if(totalSupply + value <= totalSupply || balances[owner] + value <= balances[owner]) throw;
            totalSupply += value;
            balances[owner] += value;
        }
    }
}
