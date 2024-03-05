// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

import "./StakingSpecV2.sol";

/**
 * @title Staking (Implementation)
 *
 * @notice see StakingV2
 */
// Inheritance
contract StakingImplV2 is StakingV2, UUPSUpgradeable, OwnableUpgradeable, PausableUpgradeable {
	using SafeMathUpgradeable for uint256;
	using SafeERC20Upgradeable for IERC20Upgradeable;

	/* ========== STATE VARIABLES ========== */
	// Time until which stakes are locked
	uint256 public unlockTime;
	// Total supply of staked tokens
	uint256 public totalSupply;

	// Total number of users staked
	uint256 public totalNoOfStakers;

	// Token being staked
	IERC20Upgradeable public token;

	// Mapping to track user balances
	mapping(address => uint256) private _balances;

	/* ========== EVENTS ========== */

	// Event emitted when a user stakes token
	event Staked(address indexed user, uint256 amount, uint256 time);
	// Event emitted when a user withdraws tokens
	event Withdrawn(address indexed user, uint256 amount, uint256 time);
	// Event emitted when tokens are recovered
	event Recovered(address indexed sender, address token, uint256 amount);
	// Event emitted when the unlock time is updated
	event UnlockTimeUpdated(address indexed sender, uint256 unlockTime);

	/* ========== CONSTRUCTOR ========== */

	/**
	 * @dev Constructor function to initialize the contract
	 * @param _token Address of the token to be staked
	 * @param _lockupDays Number of days users' stakes will be locked up
	 */
	function postConstruct(IERC20Upgradeable _token, uint256 _lockupDays) public virtual initializer {
		// stake token should be valid address
		require(address(_token) != address(0x0), "staking token is invalid");
		// validate supplied unlock time
		require(_lockupDays != 0 && _lockupDays <= 252 days, "invalid lockupDays");

		// initialize state variable
		token = _token;
		unlockTime = block.timestamp + _lockupDays;

		// init dependent contracts
		__Ownable_init();
		__Pausable_init_unchained();
	}

	/* ========== VIEWS ========== */

	/**
	 * @inheritdoc StakingV2
	 */
	function balanceOf(address account) external view override returns (uint256) {
		return _balances[account];
	}

	/**
	 * @inheritdoc StakingV2
	 */
	function getUnlockTime() external view override returns (uint256) {
		return unlockTime;
	}

	/* ========== MUTATIVE FUNCTIONS ========== */

	/**
	 * @inheritdoc StakingV2
	 */
	function stake(uint256 amount) external override whenNotPaused {
		// verify input argument
		require(amount > 0, "cannot stake 0");

		// transfer token from user wallet
		token.safeTransferFrom(msg.sender, address(this), amount);

		// if new user update no of stakers
		if(_balances[msg.sender] == 0) {
			totalNoOfStakers++;
		}
		// update user stake amount
		_balances[msg.sender] = _balances[msg.sender].add(amount);
		// update total stake amount
		totalSupply = totalSupply.add(amount);

		// emit an event
		emit Staked(msg.sender, amount, block.timestamp);
	}

	/**
	 * @inheritdoc StakingV2
	 */
	function withdraw(uint256 amount) public override {
		// verify input argument
		require(amount > 0, "cannot withdraw 0");
		// verify withdrawal balance
		require(_balances[msg.sender] >= amount, "bad withdraw");
		// make sure withdraw is allowed now
		require(block.timestamp >= unlockTime, "withdraw is locked");

		// update user stake balance
		_balances[msg.sender] = _balances[msg.sender].sub(amount);
		// update total staked amount
		totalSupply = totalSupply.sub(amount);
		// if all amount withdrawn update no of stakers
		if(_balances[msg.sender] == 0) {
			totalNoOfStakers--;
		}
		// transfer token to user account
		token.safeTransfer(msg.sender, amount);

		// emit an event
		emit Withdrawn(msg.sender, amount, block.timestamp);
	}

	/* ========== RESTRICTED FUNCTIONS ========== */
	/**
	 * @dev Updates the unlock time for staked tokens
	 * @param _unlockTime The new unlock time
	 */
	function updateUnlockTime(uint256 _unlockTime) external onlyOwner {
		// make sure supplied unlock time is within bound terms
		require(_unlockTime > block.timestamp && _unlockTime < block.timestamp + 252 days, "invalid unlockTime");

		// update unlock time
		unlockTime = _unlockTime;

		// emit an event
		emit UnlockTimeUpdated(msg.sender, _unlockTime);
	}

	/**
	 * @dev Recovers ERC20 tokens accidentally sent to the contract
	 * @param _token Address of the ERC20 token to recover
	 * @param tokenAmount Amount of tokens to recover
	 */
	function recoverERC20(IERC20Upgradeable _token, uint256 tokenAmount) external onlyOwner {
		// make sure admin won't withdraw stake token
		require(address(_token) != address(token), "cannot withdraw the staking token");

		// transfer token to owner account
		_token.safeTransfer(owner(), tokenAmount);

		// emit an event
		emit Recovered(msg.sender, address(_token), tokenAmount);
	}

	/**
	 * @inheritdoc UUPSUpgradeable
	 */
	function _authorizeUpgrade(address) internal virtual override onlyOwner {}
}