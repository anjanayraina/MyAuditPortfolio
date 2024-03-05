// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/**
 * @title Staking (Interface)
 *
 * @notice Facilitates the staking process for a specified ERC20 Token while deployment.
 *
 * @notice It also introduces a unlock time. Users will only be able to withdraw after that unlock time.
 *
 * @notice Doesn't introduce any rewards, just tracks the stake/withdraw amount of users. Data will be used later to process rewards
 */
interface StakingV2 {
	// Views

	/**
	 * @notice Returns amount of token staked by user account
	 *
	 * @param account The address of user account
	 *
	 * @return amount of token staked by user
	 */
	function balanceOf(address account) external view returns (uint256);

	/**
	 * @notice Returns unlock time after which unstake/withdraw is allowed
	 *
	 * @return Unlock Time in unix timestamp
	 */
	function getUnlockTime() external view returns (uint256);

	// Mutative

	/**
	 * @notice Allows users to stake tokens. Tokens are transferred from its owner to the staking contract
	 *      User will not be able to withdraw them util unlock time reaches.
	 *
	 * @param amount The amount of tokens user want to stake.
	 */
	function stake(uint256 amount) external;

	/**
	 * @notice Allows users to withdraw staked tokens. Tokens are transferred from staking contract back to its previous owner.
	 *      Can be called only after unlock time.
	 *
	 * @param amount The amount of tokens user want to withdraw.
	 */
	function withdraw(uint256 amount) external;
}