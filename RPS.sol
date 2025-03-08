// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./TimeUnit.sol";
import "./CommitReveal.sol";

contract RPS {
    uint public numPlayer = 0;
    uint public reward = 0;
    mapping (address => uint) public player_choice; // 0 - Rock, 1 - Paper, 2 - Scissors, 3 - Spock, 4 - Lizard
    mapping(address => bool) public hasCommitted;
    mapping(address => bool) public hasRevealed;
    mapping(address => bytes32) public commitments;
    mapping(address => uint256) public startTime;
    address[] public players;
    uint public numInput = 0;
    TimeUnit private time = new TimeUnit();
    uint256 public constant TIMEOUT = 3 minutes;
    CommitReveal private commitReveal;

    constructor() {
        commitReveal = new CommitReveal();
    }

    function addPlayer() public payable {
        require(numPlayer < 2);
        require(msg.value == 1 ether);
        require(!isPlayer(msg.sender));
        
        reward += msg.value;
        players.push(msg.sender);
        numPlayer++;
        startTime[msg.sender] = block.timestamp;
    }

    function getChoiceHash(uint choice, string memory secret) public pure returns (bytes32) {
    require(choice <= 4, "Invalid choice");
    return keccak256(abi.encodePacked(keccak256(abi.encodePacked(choice, secret))));
    }

    function commitChoice(bytes32 commitHash) public {
        require(isPlayer(msg.sender));
        require(!hasCommitted[msg.sender]);
        
        commitments[msg.sender] = commitHash;
        hasCommitted[msg.sender] = true;
    }

    function revealChoice(uint choice, string memory secret) public {
        require(isPlayer(msg.sender));
        require(hasCommitted[msg.sender]);
        require(!hasRevealed[msg.sender]);

        bytes32 calculatedHash = getChoiceHash(choice, secret);
        require(commitments[msg.sender] == calculatedHash);
        require(choice <= 4);

        player_choice[msg.sender] = choice;
        hasRevealed[msg.sender] = true;
        numInput++;

        if (numInput == 2) {
           _checkWinnerAndPay();
        }
    }


    function SingleplayTimeOut() public {
        require(numPlayer == 1);
        if (block.timestamp - startTime[players[0]] > TIMEOUT) {
            payable(players[0]).transfer(reward);
            DeleteGame();
        }
    }

    function MultiPlayTimeOut() public {
        require(numPlayer == 2);
        require(numInput < 2);
        if (block.timestamp - startTime[players[0]] > TIMEOUT) {
            for (uint i = 0; i < players.length; i++) {
                if (!hasRevealed[players[i]]) {
                    payable(players[i]).transfer(reward / 2);
                }
            }
            DeleteGame();
        }
    }

    function _checkWinnerAndPay() private {
        uint p0Choice = player_choice[players[0]];
        uint p1Choice = player_choice[players[1]];
        address payable account0 = payable(players[0]);
        address payable account1 = payable(players[1]);

        if ((p0Choice + 1) % 5 == p1Choice) {
            account1.transfer(reward);
        } else if ((p1Choice + 1) % 5 == p0Choice) {
            account0.transfer(reward);
        } else {
            account0.transfer(reward / 2);
            account1.transfer(reward / 2);
        }
        DeleteGame();
    }

    function DeleteGame() internal {
        delete player_choice[players[0]];
        delete player_choice[players[1]];
        numPlayer = 0;
        numInput = 0;
        reward = 0;
    }

    function isPlayer(address player) internal view returns (bool) {
        for (uint i = 0; i < players.length; i++) {
            if (players[i] == player) return true;
        }
        return false;
    }
}
