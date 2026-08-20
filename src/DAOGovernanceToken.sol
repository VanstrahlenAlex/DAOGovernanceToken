// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


/**
 * @title DAOGovernanceToken
 * @author Alexander Van strahlen
 * @dev ERC20 token used for DAO governance voting
 * @notice This is a simple ERC20 token for governance purposes
 */
contract DAOGovernanceToken is ERC20, Ownable {

	mapping(address => bool) public hasDelegated;
	mapping(address => address) public delegates;
	mapping(address => uint256) public delegatedVotes;

	//Event
	event VotingPowerDelegated(address indexed delegator, address indexed delegate, uint256 amount);
	event VotingPowerUndelegated(address indexed delegator, address indexed delegate, uint256 amount);
    
	/**
	 * @dev Constrcutor that gives msg.sender all of initial tokens
	 * @param name Token name
	 * @param symbol Token Symbol
	 * @param initialSupply Initial Token supply
	 */
	constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) Ownable(msg.sender){
		_mint(msg.sender, initialSupply);
	}

	function delegateVotingPower(address delegate, uint256 amount) external {
		require(delegate != address(0), "Cannot delegate to zero address");
		require(delegate != msg.sender, "Cannot delegate to self");
		require(amount > 0, "Amount must be greater than 0");
		require(balanceOf(msg.sender) > amount, "Insufficeint balance");

		_transfer(msg.sender, delegate, amount);

		delegates[msg.sender] = delegate; 
		delegatedVotes[delegate] += amount;
		hasDelegated[msg.sender] = true;

		emit VotingPowerDelegated(msg.sender, delegate, amount);
	}

	function undelegateVotingPower(uint256 amount) external {
		require(hasDelegated[msg.sender], "No delegation found");
		require(amount > 0, "amount must be greater than 0");
		require(delegatedVotes[delegates[msg.sender]] >= amount, "Insufficient delegated amount"); 

		address delegate = delegates[msg.sender];
		
		_transfer(delegate, msg.sender, amount);

		delegatedVotes[delegate] -= amount;

		if(delegatedVotes[delegate] == 0) {
			hasDelegated[msg.sender] = false;
			delete delegates[msg.sender];
		}

		emit VotingPowerUndelegated(msg.sender, delegate, amount);
	}

	/**
	 * @dev Get voting power of a specific account
	 * @param account Address to check voting power for
	 * @return Total Voting power of the account
	 */
	function getVotingPower(address account) external view returns(uint256) {
		return balanceOf(account);
	}

	function mint (address to, uint256 amount) external onlyOwner {
		_mint(to, amount);
	}

	function burn(uint256 amount) external {
		_burn(msg.sender, amount);
	}

	
}