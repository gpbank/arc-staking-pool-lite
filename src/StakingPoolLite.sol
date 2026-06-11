// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

contract StakingPoolLite {
    IERC20 public immutable usdc;
    address public owner;
    uint256 public lockPeriod; // seconds
    uint256 public rewardBps; // basis points reward per lock cycle

    struct Stake {
        uint256 amount;
        uint256 stakedAt;
        bool withdrawn;
    }
    mapping(address => Stake[]) public stakes;
    uint256 public totalStaked;

    event Staked(address indexed user, uint256 amount, uint256 index);
    event Withdrawn(address indexed user, uint256 principal, uint256 reward);

    constructor(address _usdc) {
        require(_usdc != address(0), "BAD_USDC");
        usdc = IERC20(_usdc);
        owner = msg.sender;
        lockPeriod = 7 days;
        rewardBps = 100; // 1%
    }

    modifier onlyOwner() { require(msg.sender == owner, "NOT_OWNER"); _; }

    function setParams(uint256 _lockPeriod, uint256 _rewardBps) external onlyOwner {
        lockPeriod = _lockPeriod;
        rewardBps = _rewardBps;
    }

    function stake(uint256 amount) external {
        require(amount > 0, "ZERO");
        require(usdc.transferFrom(msg.sender, address(this), amount), "TRANSFER_FAILED");
        stakes[msg.sender].push(Stake(amount, block.timestamp, false));
        totalStaked += amount;
        emit Staked(msg.sender, amount, stakes[msg.sender].length - 1);
    }

    function withdraw(uint256 index) external {
        Stake storage s = stakes[msg.sender][index];
        require(!s.withdrawn, "ALREADY");
        require(block.timestamp >= s.stakedAt + lockPeriod, "LOCKED");
        s.withdrawn = true;
        uint256 reward = (s.amount * rewardBps) / 10000;
        totalStaked -= s.amount;
        require(usdc.transfer(msg.sender, s.amount + reward), "TRANSFER_FAILED");
        emit Withdrawn(msg.sender, s.amount, reward);
    }
}
