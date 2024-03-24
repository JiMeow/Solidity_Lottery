// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;
import "./CommitReveal.sol";

contract Lottery is CommitReveal {
    address public owner;
    uint public t1;
    uint public t2;
    uint public t3;

    uint public num_player;
    uint public max_player;

    uint private startTime = 0;
    uint public reward = 0;

    mapping(address => bytes32) private player_commit;
    mapping(uint => address) private player_address;
    mapping(address => uint) private player_value;

    bool is_game_finish = false;

    constructor(uint _T1, uint _T2, uint _T3, uint _max_player) {
        t1 = _T1;
        t2 = _T2;
        t3 = _T3;
        max_player = _max_player;
        owner = msg.sender;
    }

    function hashInp(uint value, uint salt) public view returns (bytes32) {
        return getSaltedHash(bytes32(value), bytes32(salt));
    }

    function view_game_state() external view returns (string memory) {
        string memory ret = "stage1(add_player)";

        if (
            (block.timestamp >= startTime &&
                block.timestamp <= startTime + t1) || startTime == 0
        ) {
            ret = "stage1(add_player)";
        } else if (
            block.timestamp > startTime + t1 &&
            block.timestamp <= startTime + t1 + t2
        ) {
            ret = "stage2(reveal)";
        } else if (
            block.timestamp > startTime + t1 + t2 &&
            block.timestamp <= startTime + t1 + t2 + t3
        ) {
            ret = "stage3(find_winner)";
        } else {
            ret = "stage4(withdraw)";
        }

        return ret;
    }

    function add_player(bytes32 commit_val) public payable {
        require(
            (block.timestamp >= startTime &&
                block.timestamp <= startTime + t1) || startTime == 0,
            "This game is not in stage1(add_player)."
        );

        require(msg.value == 0.001 ether, "Please input 0.001 ether.");
        require(player_commit[msg.sender] == bytes32(0));
        require(num_player < max_player, "This room is full.");

        if (startTime == 0) {
            startTime = block.timestamp;
        }

        player_commit[msg.sender] = commit_val;
        reward += msg.value;
        player_address[num_player] = msg.sender;
        player_value[msg.sender] = 1000;
        num_player += 1;
    }

    function reveal_data(uint value, uint salt) public {
        require(
            block.timestamp > startTime + t1 &&
                block.timestamp <= startTime + t1 + t2,
            "This game is not in stage2(reveal)."
        );

        bytes32 new_hashed = hashInp(value, salt);
        bytes32 hashed = player_commit[msg.sender];
        require(new_hashed == hashed, "This is not your real value.");

        player_value[msg.sender] = value;
    }

    function find_winner() public payable {
        require(
            block.timestamp > startTime + t1 + t2 &&
                block.timestamp <= startTime + t1 + t2 + t3,
            "This game is not in stage3(find winner)."
        );
        require(msg.sender == owner, "You are not contract owner.");
        require(!is_game_finish, "Game already complete");

        is_game_finish = true;

        uint valid_player = 0;
        uint winner = 0;
        address winnerAddr = owner;

        for (uint i = 0; i < num_player; i++) {
            address addr = player_address[i];
            if (player_value[addr] >= 0 && player_value[addr] <= 999) {
                valid_player += 1;
                winner ^= player_value[addr];
            }
        }

        if (valid_player != 0) {
            winner %= valid_player;
            for (uint i = 0; i < num_player; i++) {
                address addr = player_address[i];
                if (player_value[addr] >= 0 && player_value[addr] <= 999) {
                    if (winner == 0) {
                        winnerAddr = addr;
                        break;
                    } else {
                        winner -= 1;
                    }
                }
            }
        }

        address payable ownerAddress = payable(owner);
        address payable winnerAddress = payable(winnerAddr);

        ownerAddress.transfer((reward * 2) / 100);
        winnerAddress.transfer((reward * 98) / 100);

        resetGame();
    }

    function withdraw() public {
        require(
            block.timestamp > startTime + t1 + t2 + t3,
            "This game is not in stage4(player withdraw)."
        );

        require(player_commit[msg.sender] != 0);
        player_commit[msg.sender] = 0;

        assert(reward > 0);

        reward -= 0.001 ether;
        address payable payAddress = payable(msg.sender);
        payAddress.transfer(0.001 ether);

        if (reward == 0) {
            resetGame();
        }
    }

    function resetGame() private {
        for (uint i = 0; i < num_player; i++) {
            address playerAddr = player_address[i];
            player_address[i] = address(0);
            player_commit[playerAddr] = 0;
            player_value[playerAddr] = 0;
        }

        is_game_finish = false;
        num_player = 0;
        reward = 0;
        startTime = 0;
    }
}
