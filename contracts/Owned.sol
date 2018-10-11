pragma solidity ^0.4.20;

contract Owned {
    address private owner;
    event LogOwnerChanged(address indexed by, address indexed who);
    
    constructor() public {
        owner = msg.sender;    
    }
    
    modifier ownerOnly {
        require(msg.sender == owner);
        _;
    }
    
    function getOwner() public view returns (address) {
        return owner;
    }
    
    function changeOwner(address newOwner) public ownerOnly returns(bool success) {
        emit LogOwnerChanged(msg.sender, newOwner);
        owner = newOwner;
        return true;
    }
}
