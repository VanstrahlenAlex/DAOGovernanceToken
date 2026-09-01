// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./DAOGovernanceToken.sol";


/**
 * @title IDAOTreasury
 * @author Alexander Van strahlen
 * @notice Interface for the treasury contract
 */
interface IDAOTreasury {
    function approvedProposal(uint256 proposalId) external;
	function sendFunds(uint256 proposalId, address recipient, uint256 amount, address token) external;
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
	 * @param _quorumVotes Minimum votes required for proposal to pass
	 */

	constructor(address _governanceToken, address _treasury,  uint256 _proposalThreshold, uint256 _votingPeriod, uint256 _quorumVotes) Ownable(msg.sender) {
		governanceToken = DAOGovernanceToken(_governanceToken);
		treasury = IDAOTreasury(_treasury);
		proposalThreshold = _proposalThreshold;
		votingPeriod = _votingPeriod;
		quorumVotes = _quorumVotes;
	}


	/**
	 * @notice Creates a new proposal with the given parameters
	 * @param description Description of the proposal
	 * @param recipient Address to receive the funds
	 * @param amount Amount of tokens to transfer
	 * @param token Address of the token to transfer
	 * @return proposalId The proposal ID
	 */
	function createProposal(string memory description, address recipient, uint256 amount, address token) external returns (uint256 proposalId) {
		require(governanceToken.getVotingPower(msg.sender) >= proposalThreshold, "Insufficient voting power to create proposal");
		require(bytes(description).length > 0, "Description can not be empty");
		require(recipient != address(0), "Invalid recipient address");
		require(amount > 0, "Amount must be greater than 0");

		proposalId = proposalCount++;
		Proposal storage newProposal = proposals[proposalId];

		newProposal.id = proposalId;
		newProposal.proposer = msg.sender;
		newProposal.description = description;
		newProposal.recipient = recipient;
		newProposal.amount = amount;
		newProposal.token = token;
		newProposal.startTime = block.timestamp;
		newProposal.endTime = block.timestamp + votingPeriod;
		newProposal.executed = false;
		newProposal.canceled = false;

		emit ProposalCreated(proposalId, msg.sender, description, recipient, amount, token, newProposal.startTime, newProposal.endTime);
	}

	function vote(uint256 proposalId, bool support) external {
		Proposal storage proposal = proposals[proposalId];

		require(proposal.proposer != address(0), "Proposal does not exist");
		require(block.timestamp >= proposal.startTime, "Voting not started");
		require(block.timestamp < proposal.endTime, "Voting has ended");
		require(!proposal.hasVoted[msg.sender], "You have already voted on this proposal");
		require(!proposal.canceled, "Proposal is canceled");
		require(!proposal.executed, "Proposal is already executed");
		
		uint256 votes = governanceToken.getVotingPower(msg.sender);
		require(votes > 0, "No voting power");
	
		proposal.hasVoted[msg.sender] = true;
		proposal.votedFor[msg.sender] = support;

		if(support){
			proposal.forVotes += votes;
		} else {
			proposal.againstVotes += votes;
		}

		emit Voted(proposalId, msg.sender, support, votes);
	}

	/**
	 * @dev Cancel a proposal
	 * @param proposalId  ID of the proposal to cancel 
	 */
	function cancelProposal(uint256 proposalId) external {
		Proposal storage proposal = proposals[proposalId];
		require(proposal.proposer != address(0), "Proposal does not exist");
		require(!proposal.executed, "Proposal already executed");
		require(!proposal.canceled, "Proposal already canceled");
		require(msg.sender == proposal.proposer || msg.sender == owner(), "Not authorized to cancel");

		proposal.canceled = true;
		emit ProposalCanceled(proposalId);
	}

	function executeProposal(uint256 proposalId) external {
		Proposal storage proposal = proposals[proposalId];

		require(proposal.proposer != address(0), "Proposal does not exist");
		require(block.timestamp >= proposal.endTime, "Voting period is not over");
		require(!proposal.canceled, "Proposal is canceled");
		require(!proposal.executed, "Proposal is already executed");
		
		require(proposal.forVotes >= quorumVotes, "Quorum not reached");
		require(proposal.forVotes > proposal.againstVotes, "Proposal not passed");

		proposal.executed = true;

		treasury.approvedProposal(proposalId);

		treasury.sendFunds(proposalId, proposal.recipient, proposal.amount, proposal.token);

		emit ProposalExecuted(proposalId);
		
	}
}