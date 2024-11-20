// SPDX-License-Identifier: MIT
/**
 * Gotta Beyt (GBETY) Token Smart Contract on Solana
 * Features: Self-contained ERC20, Transaction Fees, Staking, Burning Mechanism
 */

pragma solidity ^0.8.0;

contract GottaBeytToken {
    string public name = "Gotta Beyt";
    string public symbol = "GBETY";
    uint8 public decimals = 6;
    uint256 public totalSupply;

    address public Contractowner;
    address public liquidityPool;
    address public authorityWallet;

    uint256 public constant LP_FEE = 200; // 2.00%
    uint256 public constant AUTHORITY_FEE = 215; // 2.15%
    uint256 public constant BURN_FEE = 35; // 0.35%
    uint256 public constant FEE_DENOMINATOR = 10000;

    uint256 public constant REWARD_FIRST_MONTH = 115; // 1.15%
    uint256 public constant REWARD_THIRD_MONTH = 225; // 2.25%
    uint256 public constant REWARD_SIXTH_MONTH = 335; // 3.35%
    uint256 public constant REWARD_ONE_YEAR = 425; // 4.25%
    uint256 public constant REWARD_DENOMINATOR = 10000;

    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowances;
    mapping(address => uint256) public stakingBalances;
    mapping(address => uint256) public lastClaimedTime;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event FeesDistributed(uint256 lpFee, uint256 authorityFee, uint256 burnAmount);
    event RewardsClaimed(address indexed user, uint256 rewardAmount);

    constructor(uint256 _totalSupply, address _liquidityPool, address _authorityWallet) {
        require(_liquidityPool != address(0), "Invalid liquidity pool address");
        require(_authorityWallet != address(0), "Invalid authority wallet address");

        Contractowner = msg.sender;
        liquidityPool = _liquidityPool;
        authorityWallet = _authorityWallet;
        totalSupply = _totalSupply;

        balances[msg.sender] = _totalSupply; // Assign total supply to the deployer
    }

    modifier onlyOwner() {
        require(msg.sender == Contractowner, "Not the contract owner");
        _;
    }

    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return allowances[owner][spender];
    }

    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        require(allowances[sender][msg.sender] >= amount, "Allowance exceeded");
        allowances[sender][msg.sender] -= amount;
        _transfer(sender, recipient, amount);
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(balances[sender] >= amount, "Insufficient balance");

        uint256 lpFee = (amount * LP_FEE) / FEE_DENOMINATOR;
        uint256 authorityFee = (amount * AUTHORITY_FEE) / FEE_DENOMINATOR;
        uint256 burnAmount = (amount * BURN_FEE) / FEE_DENOMINATOR;

        uint256 transferAmount = amount - lpFee - authorityFee - burnAmount;

        balances[sender] -= amount;
        balances[liquidityPool] += lpFee;
        balances[authorityWallet] += authorityFee;
        totalSupply -= burnAmount;
        balances[recipient] += transferAmount;

        emit Transfer(sender, liquidityPool, lpFee);
        emit Transfer(sender, authorityWallet, authorityFee);
        emit Transfer(sender, recipient, transferAmount);
        emit FeesDistributed(lpFee, authorityFee, burnAmount);
    }

    function calculateReward(address user) public view returns (uint256) {
        uint256 stakingDuration = block.timestamp - lastClaimedTime[user];
        uint256 balance = stakingBalances[user];

        if (stakingDuration >= 365 days) {
            return (balance * REWARD_ONE_YEAR) / REWARD_DENOMINATOR;
        } else if (stakingDuration >= 180 days) {
            return (balance * REWARD_SIXTH_MONTH) / REWARD_DENOMINATOR;
        } else if (stakingDuration >= 90 days) {
            return (balance * REWARD_THIRD_MONTH) / REWARD_DENOMINATOR;
        } else if (stakingDuration >= 30 days) {
            return (balance * REWARD_FIRST_MONTH) / REWARD_DENOMINATOR;
        }
        return 0;
    }

    function claimRewards() public {
        uint256 reward = calculateReward(msg.sender);
        require(reward > 0, "No rewards available");

        balances[msg.sender] += reward;
        totalSupply += reward;
        lastClaimedTime[msg.sender] = block.timestamp;

        emit RewardsClaimed(msg.sender, reward);
    }

    function stakeTokens(uint256 amount) public {
        require(amount > 0, "Cannot stake 0 tokens");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        balances[msg.sender] -= amount;
        stakingBalances[msg.sender] += amount;

        if (lastClaimedTime[msg.sender] == 0) {
            lastClaimedTime[msg.sender] = block.timestamp;
        }
    }

    function unstakeTokens(uint256 amount) public {
        require(amount > 0, "Cannot unstake 0 tokens");
        require(stakingBalances[msg.sender] >= amount, "Not enough staked balance");

        stakingBalances[msg.sender] -= amount;
        balances[msg.sender] += amount;
    }
}
