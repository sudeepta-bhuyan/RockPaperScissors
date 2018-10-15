pragma solidity ^0.4.20;

import './Pausable.sol';

contract RockPaperScissors is Pausable {
    
    enum Move {
        None, Rock, Paper, Scissors
    }
    
    enum GameState {
        ChallengeIssued,
        ChallengeAccepted,
        WinnerDecided,
        NoWinner,
        GameOver
    }
    
    struct Game {
        
        GameState state;
        uint256 challengeIssuedTime; //using block number instead of timestamp
        uint256 ChallengeAcceptedTime; //using block number instead of timestamp
        address winner;
        
        address challenger;
        uint256 challengerAmount;
        bytes32 challengerSecretMove;
        
        address acceptor;
        uint256 acceptorAmount;
        Move acceptorMove;
    }
    
    uint256 constant public minWager = 200;
    uint256 timeout = 100;
    mapping(uint256=>Game) games;
    uint256 numOfGames;
    mapping(bytes32 => bool) public usedSecrets;
    
    event LogChallengeIssued(uint256 indexed gameID, address indexed challenger, uint256 amountWagered);
    event LogChallengeAccepted(uint256 indexed gameID, address indexed acceptor, uint256 amountWagered);
    event LogWinnerDecided(uint256 indexed gameID, address indexed winner, uint256 amountWon);
    event LogClaimedWinningAmount(uint256 indexed gameID, address indexed who, uint256 amountWithdrawn);
    event LogWithdrawnByChallenger(uint256 indexed gameID, address indexed who, uint256 amountWithdrawn);
    event LogWithdrawnByAcceptor(uint256 indexed gameID, address indexed who, uint256 amountWithdrawn);
    event LogReclaimedWageredAmount(uint256 indexed gameID, address indexed who, uint256 amountReclaimed);
    
    modifier validAmountOnly {
        require(msg.value >= 200);
        _;
    }
    
    function issueChallenge(bytes32 secretMove) public payable validAmountOnly returns (uint256 gameID) {
        require(!usedSecrets[secretMove]);
        usedSecrets[secretMove] = true;
        
        gameID = numOfGames++;
        games[gameID] = Game(GameState.ChallengeIssued, block.number, 0, 0, msg.sender, msg.value, secretMove, 0, 0, Move.None);
        emit LogChallengeIssued(gameID, msg.sender, msg.value);
    }
    
    function acceptChallenge(uint256 gameID, Move move) public payable validAmountOnly {
        require(games[gameID].state == GameState.ChallengeIssued);
        require(move > Move.None && move <= Move.Scissors);
        require(block.number - games[gameID].challengeIssuedTime < timeout);
        
        games[gameID].acceptor = msg.sender;
        games[gameID].acceptorAmount = msg.value;
        games[gameID].acceptorMove = move;
        games[gameID].state = GameState.ChallengeAccepted;
        games[gameID].ChallengeAcceptedTime = block.number;
        emit LogChallengeAccepted(gameID, msg.sender, msg.value);
    }
    
    function decideWinner(uint256 gameID, Move challengerMove, uint256 random) public returns (bool status){
        require(games[gameID].state == GameState.ChallengeAccepted);
        require(msg.sender == games[gameID].challenger);
        require(games[gameID].challengerSecretMove == keccak256(abi.encode(random, challengerMove)));
        
        if (games[gameID].acceptorMove == Move.Rock) {
            if ( challengerMove == Move.Paper) {
                games[gameID].winner = games[gameID].challenger;
            } else if (challengerMove == Move.Scissors) {
                games[gameID].winner = games[gameID].acceptor;
            }
        } else if (games[gameID].acceptorMove == Move.Paper) {
            if ( challengerMove == Move.Rock) {
                games[gameID].winner = games[gameID].acceptor;
            } else if (challengerMove == Move.Scissors) {
                games[gameID].winner = games[gameID].challenger;
            }
        } else if (games[gameID].acceptorMove == Move.Scissors) {
            if ( challengerMove == Move.Rock) {
                games[gameID].winner = games[gameID].challenger;
            } else if (challengerMove == Move.Paper) {
                games[gameID].winner = games[gameID].acceptor;
            }
        }
        
        if (games[gameID].winner != 0) {
            games[gameID].state = GameState.WinnerDecided;
            status = true;
        } else {
            games[gameID].state = GameState.NoWinner;
            status = false;
        }
    }
    
    function claimWinningAmount(uint256 gameID) public {
        require(games[gameID].state == GameState.WinnerDecided);
        require(msg.sender == games[gameID].winner);
        
        uint256 amount = games[gameID].challengerAmount + games[gameID].acceptorAmount;
        games[gameID].challengerAmount = 0;
        games[gameID].acceptorAmount = 0;
        games[gameID].state = GameState.GameOver;
        emit LogClaimedWinningAmount(gameID, msg.sender, amount);
        msg.sender.transfer(amount);
    }
    
    //Challenger should be able to withdraw his wagered amount if no one responded to
    //his challenge within the timeout period (100 blocks from the creation of the challenge).
    function withdrawIfChallengeUnanswered(uint256 gameID) public {
        require(games[gameID].state == GameState.ChallengeIssued);
        require(msg.sender == games[gameID].challenger);
        require(block.number - games[gameID].challengeIssuedTime >= timeout);
        
        games[gameID].state = GameState.GameOver;
        uint256 amount = games[gameID].challengerAmount;
        games[gameID].challengerAmount = 0;
        emit LogWithdrawnByChallenger(gameID, msg.sender, amount);
        msg.sender.transfer(amount);
    }
    
    //If challenger does not reveal his move within the timeout period after his challenge
    //accepted, the acceptor can collect all the money as penalty.
    function withdrawIfChallengerForfeited(uint256 gameID) public {
        require(games[gameID].state == GameState.ChallengeAccepted);
        require(msg.sender == games[gameID].acceptor);
        require(block.number - games[gameID].ChallengeAcceptedTime >= timeout);
        
        uint256 amount = games[gameID].challengerAmount + games[gameID].acceptorAmount;
        games[gameID].challengerAmount = 0;
        games[gameID].acceptorAmount = 0;
        games[gameID].state = GameState.GameOver;
        emit LogWithdrawnByAcceptor(gameID, msg.sender, amount);
        msg.sender.transfer(amount);
    }
    
    //if the game ended in a draw
    function reclaimWageredAmount(uint256 gameID) public {
        require(games[gameID].state == GameState.NoWinner);
        require(msg.sender == games[gameID].challenger || msg.sender == games[gameID].acceptor);
        
        uint256 amount = 0;
        if (msg.sender == games[gameID].challenger) {
            amount = games[gameID].challengerAmount;
            games[gameID].challengerAmount = 0;
        } else {
            amount = games[gameID].acceptorAmount;
            games[gameID].acceptorAmount = 0;
        }
        games[gameID].state = GameState.GameOver;
        emit LogReclaimedWageredAmount(gameID, msg.sender, amount);
        msg.sender.transfer(amount);
    }
}
