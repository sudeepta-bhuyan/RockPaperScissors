pragma solidity ^0.4.20;
import "./Owned.sol"; 

contract Pausable is Owned {
    
    bool public isRunning;
    event LogPausedContract(address indexed sender);
    event LogResumedContract(address indexed sender);
    
    modifier onlyIfRunning {
        require(isRunning == true);
        _;
    }
    
    constructor() public {
        isRunning = true;
    }
    
    function pauseContract() public ownerOnly onlyIfRunning returns (bool success) {
        isRunning = false;
        emit LogPausedContract(msg.sender);
        return true;
    }
    
    function resumeContract() public ownerOnly returns (bool success) {
        require(!isRunning);
        isRunning = true;
        emit LogResumedContract(msg.sender);
        return true;
    }
}
