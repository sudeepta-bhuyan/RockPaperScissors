pragma solidity ^0.4.20;

import './Pausable.sol';

contract RockPaperScissors is Pausable {

    enum Move {
        None, Rock, Paper, Scissor
    }
    
    enum GameState {
        Enrollment,
        LockMove,
        RevealMove,
        WinnerDecided
    }
    
    struct Player {
        address addr;
        bytes32 hashedMove;
        Move actualMove;
        uint256 moneyWagered;
        bool enrolled;
        bool locked;
        bool revealed;
    }
    
    uint256 constant public minWager = 200; //wei
    GameState public state = GameState.Enrollment;
    address[2] public playerAddresses;
    mapping(address => Player) public playerDetails;
    
    address public winner;
    uint8 public enrolledCount;
    uint8 public lockedCount;
    uint8 public revealedCount;
    mapping(bytes32 => bool) usedSecrets;
    uint256 public amountWon;
    
    event LogPlayerEnrolled(address indexed who, uint256 amountWagered);
    event LogSecretMoveLocked(address indexed whose, bytes32 secretMove);
    event LogMoveRevealed(address indexed whose, Move move);
    event LogWinner(address indexed who, uint256 amountWon);
    event LogNewRoundRequired(address indexed player1, address indexed player2);
    event LogAmountWithdrawn(address indexed who, uint256 amount);
    
    modifier winnerOnly {
        require(msg.sender == winner);
        _;
    }
    
    function ChangeState() private {
        if (state == GameState.WinnerDecided) {
            state = GameState.Enrollment;
        } else {
            state = GameState(uint8(state) + 1);
        }
    }
    
    function NewRound() private {
        state = GameState.LockMove;
        
        for (uint8 i = 0; i < 2; i++) {
            address player = playerAddresses[i];
            playerDetails[player].hashedMove = bytes32(0); //do we need to explicitly delete the previous value??
            playerDetails[player].actualMove = Move.None;
            playerDetails[player].locked = false;
            playerDetails[player].revealed = false;
        }
    }
    
    function cleanup() private {
        for (uint8 i = 0; i < 2; i++) {
            address player = playerAddresses[i];
            delete playerDetails[player];
            playerAddresses[i] = 0;
        }
        enrolledCount = 0;
        lockedCount = 0;
        revealedCount = 0;
    }
    
    function checkWinner() private {
        address player1 = playerAddresses[0];
        address player2 = playerAddresses[1];
        
        //Maybe we can have some kind of lookup table instead of this
        if (playerDetails[player1].actualMove == Move.Rock) {
            if (playerDetails[player2].actualMove == Move.Paper) {
                winner = player2;
            } else if (playerDetails[player2].actualMove == Move.Scissor){
                winner = player1;
            }
        } else if (playerDetails[player1].actualMove == Move.Paper) {
            if (playerDetails[player2].actualMove == Move.Rock) {
                winner = player1;
            } else if (playerDetails[player2].actualMove == Move.Scissor) {
                winner = player2;
            }
        } else {
            if (playerDetails[player2].actualMove == Move.Rock) {
                winner = player2;
            } else if (playerDetails[player2].actualMove == Move.Paper) {
                winner = player1;
            }
        }
        
        if (winner != 0) {
            ChangeState();
            amountWon = playerDetails[player1].moneyWagered + playerDetails[player2].moneyWagered;
            cleanup();    
            emit LogWinner(winner, amountWon);
        } else {
            NewRound();
            emit LogNewRoundRequired(player1, player2);
        }
    }
    
    function enroll() public payable {
        require(state == GameState.Enrollment);
        require(!playerDetails[msg.sender].enrolled);
        require(msg.value >= minWager);
        
        playerAddresses[enrolledCount++] = msg.sender;
        playerDetails[msg.sender] = Player(msg.sender, bytes32(0), Move.None ,msg.value, true, false, false);
        if (enrolledCount == 2) {
            ChangeState();
        }
        emit LogPlayerEnrolled(msg.sender, msg.value);
    }
    
    function sendSecretMove(bytes32 secretMove) public {
        require(state == GameState.LockMove);
        require(playerDetails[msg.sender].enrolled);
        require(!playerDetails[msg.sender].locked);
        require(!usedSecrets[secretMove]);
        
        playerDetails[msg.sender].hashedMove = secretMove;
        playerDetails[msg.sender].locked = true;
        usedSecrets[secretMove] = true;
        lockedCount++;
        if (lockedCount == 2) {
            ChangeState();
        }
        emit LogSecretMoveLocked(msg.sender, secretMove);
    }
    
    function revealMove(uint256 random, uint8 move) public {
        require(state == GameState.RevealMove);
        require(playerDetails[msg.sender].locked);
        require(!playerDetails[msg.sender].revealed);
        require(move > 0 && move < 4);
        require(playerDetails[msg.sender].hashedMove == keccak256(abi.encode(random,move)));

        
        playerDetails[msg.sender].actualMove = Move(move);
        playerDetails[msg.sender].revealed = true;
        revealedCount++;
        emit LogMoveRevealed(msg.sender, Move(move));
        
        if(revealedCount == 2) {
            checkWinner();    
        }
    }
    
    function withdrawIfWinner() public winnerOnly {
        require(state == GameState.WinnerDecided);
        
        ChangeState();
        uint256 amount = amountWon;
        amountWon = 0;
        winner = 0;
        emit LogAmountWithdrawn(msg.sender, amount);

        msg.sender.transfer(amount);        
    }

}
