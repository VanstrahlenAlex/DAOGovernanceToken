// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "./DAOGovernanceToken.sol";


/**
 * @title IDAOTreasury
 * @author Alexander Van strahlen
 * @notice Interface for the treasury contract
 */
interface IDAOTreasury {
    function approveProposal(uint256 proposalId) external;
	function spendFunds(uint256 proposalId, address recipient, uint256 amount, address token) external; 
}

/**
 * @title DAO
 * @author Alexander Van strahlen
 * @dev Decentralized autonomous organization contract handles proposal creation, voting and execution
 */
contract DAO is Ownable {

	DAOGovernanceToken public governanceToken; 

	IDAOTreasury public treasury; 

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
		address recipient;
		uint256 amount; 
		address token;
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
	event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description, address recipient, uint256 amount, address token, uint256 startTime, uint256 endTime);
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
	
	constructor(address _governanceToken, address _treasury,  uint256 _proposalThreshold, uint256 _votingPeriod, uint256 quorumVotes) Ownable(msg.sender) {
		governanceToken = DAOGovernanceToken(_governanceToken); 
		treasury = IDAOTreasury(_treasury);
		proposalThreshold = _proposalThreshold;
		votingPeriod = _votingPeriod;
		quorumVotes = quorumVotes;
	}


	/**
	 * @author Alexander Van strahlen
	 * @notice Creates a new proposal with the given parameters
	 * @param description Description of the proposal
	 * @param recipient Address to receive the funds
	 * @param amount Amount of tokens to transfer
	 * @param token Address of the token to transfer
	 * @return proposal The proposal ID
	 */
	function createProposal(string memory description, address recipient, uint256 amount, address token) external returns (uint256 proposal) {
		require(governanceToken.getVotingPower(msg.sender) >= proposalThreshold, "Insufficient voting power to create proposal");
		require(bytes(description).length > 0, "Description can not be empty");
		require(recipient != address(0), "Invalid recipient address");
		require(amount > 0, "Amount must be greater than 0");

		proposalId = proposalCount++;
		Proposal storage proposal = proposals[proposalId];

		proposal.id = proposalId;
		proposal.proposer = msg.sender;
		proposal.description = description;
		proposal.recipient = recipient;
		proposal.amount = amount;
		proposal.token = token;
		proposal.startTime = block.timestamp;
		proposal.endTime = block.timestamp + votingPeriod;
		proposal.executed = false;
		proposal.canceled = false;
		
		emit ProposalCreated(proposalId, msg.sender, description, recipient, amount, token, proposal.startTime, proposal.endTime);
		return proposalId;
	}
}