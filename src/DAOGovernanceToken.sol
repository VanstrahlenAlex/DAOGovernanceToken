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
    
	/**
	 * @dev Constrcutor that gives msg.sender all of initial tokens
	 * @param name Token name
	 * @param symbol Token Symbol
	 * @param initialSupply Initial Token supply
	 */
	constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) Ownable(msg.sender){
		_mint(msg.sender, initialSupply);
	}
}