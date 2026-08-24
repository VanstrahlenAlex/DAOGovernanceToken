// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "./DAOGovernanceToken.sol";


/**
 * @title DAO
 * @author Alexander Van strahlen
 * @dev Decentralized autonomous organization contract handles proposal creation, voting and execution
 */
contract DAO is Ownable {

	DAOGovernanceToken public governanceToken; 

	//Proposal struct
	struct Proposal {
		uint256 id; 
		address proposer; 
		string description;
		uint256 forVotes;
		uint256 againstVotes;
		uint256 startTime;
		uint256 endTime;
		bool executed;
		bool canceled; 
		mapping(address => bool) hasVoted;
		mapping(address => bool) votedFor;

	}


	//DAO configuration
	uint256 proposalThreshold;
	uint256 votingPeriod;
	uint256 quorumVotes;

	//Proposal tracking
	uint256 public proposalCount; 
	mapping(uint256 => Proposal) public proposals;

	//Events 
	event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description, uint256 startTime, uint256 endTime);
	event Voted(uint256 indexed proposalId, address indexed voter, bool support, uint256 votes);
	event ProposalExecuted(uint256 indexed proposalId);
	event ProposalCanceled(uint256 indexed proposalId);
	event configurationUpdated(uint256 proposalThreshold, uint256 votingPeriod, uint256 quorumVotes);

	/**
	 * 
	 * @param _governanceToken Address of the governance token contract
	 * @param _proposalThreshold Minum tokens required to create a proposal
	 * @param _votingPeriod Duration of the voting period in seconds
	 * @param quorumVotes Minimum votes required for proposal to pass
	 */
	
	constructor(address _governanceToken, uint256 _proposalThreshold, uint256 _votingPeriod, uint256 quorumVotes) Ownable(msg.sender) {
		governanceToken = DAOGovernanceToken(_governanceToken); 
		proposalThreshold = _proposalThreshold;
		votingPeriod = _votingPeriod;
		quorumVotes = quorumVotes;
	}
}