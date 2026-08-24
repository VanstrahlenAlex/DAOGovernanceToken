// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "./DAO.sol";


/**
 * @title DAOTreasury
 * @author Alexander Van strahlen
 * @dev Treasury contract for storing and managing DAO funds
 * @notice This contract is only accessible by the DAO
 */
contract DAOTreasury is Ownable {

	DAO public dao;

	//Mapping to track approved spending proposals
	mapping(address => bool) public approvedProposals;

	//Mapping to track executed spending proposals
	mapping(address => bool) public executedProposals;

	//Event
	event ProposalApproved(uint256 indexed proposalId);
	event FundsSpend(uint256 indexed proposalId, address indexed recipient, uint256 amount, address token);
	event TreasuryFunded(address indexed sender, uint256 amount); 
	event DAOSet(address indexed dao);


	/**
	 * 
	 * @param _dao Address of the DAO contract
	 */
    
    constructor(address _dao) Ownable(msg.sender){
		dao = DAO(_dao);
	}

	function setDAO(address _dao) external onlyOwner {
		require(_dao != address(0), "DAO address cannot be zero");
		dao = DAO(_dao);
		emit DAOSet(_dao);
	}


	/**
	 * @dev Fund the Trasuery with ETH 
	 */
	function fundTreasury() external payable {
		require(msg.value > 0, "Must send ETH");
		emit TreasuryFunded(msg.sender, msg.value);
	}

	/**
	 * @dev Fund the treasury with ERC20 tokens
	 * @param token Token address
	 * @param amount Amount to fund 
	 */

	function fundTreasuryWithToken(address token, uint256 amount) external {
		require(token != address(0), "Invalid token address");
		require(amount > 0, "Amount must be greater than 0");

		IERC20 tokenContract = IERC20(token);
		require(tokenContract.transferFrom(msg.sender, address(this), amount), "Failed to transfer tokens");
		
		emit TreasuryFunded(msg.sender, amount);
	}

	//Allow contract to receive ETH 
	receive() external payable {
		emit TreasuryFunded(msg.sender, msg.value);
	}

	function emergencyWithdraw(address token, uint256 amount, address receipient) external onlyOwner() {
		require(receipient != address(0), "Invalid recipient address");
		require(amount > 0, "Amount must be greater than 0");

		if(token == address(0)) {
			require(address(this).balance >= amount, "Insufficient ETH balance");
			(bool success,) = receipient.call{value: amount}("");
			require(success, "ETH transfer failed");
		} else {
			IERC20 tokenContract = IERC20(token);
			require(tokenContract.balanceOf(address(this)) >= amount, "Insufficient token balance");
			require(tokenContract.transfer(receipient, amount), "Token transfer failed");
		}
		
	}

	
    
}
