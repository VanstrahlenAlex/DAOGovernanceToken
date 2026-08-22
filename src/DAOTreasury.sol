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

	}

    
}
