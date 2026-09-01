// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import "forge-std/Test.sol";
import "../src/DAO.sol";
import "../src/DAOTreasury.sol";
import "../src/DAOGovernanceToken.sol";
import "./mocks/MockERC20.sol";

contract DAOTest is Test {
    DAOGovernanceToken token;
    DAOTreasury treasury;
    DAO dao;
    MockERC20 mockToken;

    address owner = address(this);
    address alice = makeAddr("alice"); // proposer / voter, 1000 tokens
    address bob = makeAddr("bob"); // voter, 1000 tokens
    address carol = makeAddr("carol"); // voter, 1000 tokens
    address dave = makeAddr("dave"); // below proposal threshold, 10 tokens
    address eve = makeAddr("eve"); // no tokens, not involved in DAO
    address recipient = makeAddr("recipient");

    uint256 constant INITIAL_SUPPLY = 1_000_000 ether;
    uint256 constant PROPOSAL_THRESHOLD = 100 ether;
    uint256 constant VOTING_PERIOD = 7 days;
    uint256 constant QUORUM_VOTES = 1500 ether;

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string description,
        address recipient,
        uint256 amount,
        address token,
        uint256 startTime,
        uint256 endTime
    );
    event Voted(uint256 indexed proposalId, address indexed voter, bool support, uint256 votes);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);

    function setUp() public {
        token = new DAOGovernanceToken("DAO Governance Token", "DAOG", INITIAL_SUPPLY);
        treasury = new DAOTreasury(address(0xdead));
        dao = new DAO(address(token), address(treasury), PROPOSAL_THRESHOLD, VOTING_PERIOD, QUORUM_VOTES);
        treasury.setDAO(address(dao));

        mockToken = new MockERC20("Mock", "MCK");

        token.transfer(alice, 1000 ether);
        token.transfer(bob, 1000 ether);
        token.transfer(carol, 1000 ether);
        token.transfer(dave, 10 ether);
    }

    function _getProposal(uint256 id)
        internal
        view
        returns (
            uint256 pid,
            address proposer,
            string memory description,
            uint256 forVotes,
            uint256 againstVotes,
            uint256 startTime,
            uint256 endTime,
            bool executed,
            bool canceled,
            address recip,
            uint256 amount,
            address tok
        )
    {
        return dao.proposals(id);
    }

    function _createDefaultProposal() internal returns (uint256 id) {
        vm.prank(alice);
        id = dao.createProposal("Fund grant", recipient, 1 ether, address(0));
    }

    // ---------------------------------------------------------------------
    // constructor
    // ---------------------------------------------------------------------

    function test_constructor_wiresGovernanceTokenAndTreasury() public view {
        assertEq(address(dao.governanceToken()), address(token));
        assertEq(address(dao.treasury()), address(treasury));
        assertEq(dao.owner(), owner);
        assertEq(dao.proposalCount(), 0);
    }

    // ---------------------------------------------------------------------
    // createProposal
    // ---------------------------------------------------------------------

    function test_createProposal_revertsOnInsufficientVotingPower() public {
        vm.prank(dave);
        vm.expectRevert(bytes("Insufficient voting power to create proposal"));
        dao.createProposal("desc", recipient, 1 ether, address(0));
    }

    function test_createProposal_revertsOnEmptyDescription() public {
        vm.prank(alice);
        vm.expectRevert(bytes("Description can not be empty"));
        dao.createProposal("", recipient, 1 ether, address(0));
    }

    function test_createProposal_revertsOnZeroRecipient() public {
        vm.prank(alice);
        vm.expectRevert(bytes("Invalid recipient address"));
        dao.createProposal("desc", address(0), 1 ether, address(0));
    }

    function test_createProposal_revertsOnZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(bytes("Amount must be greater than 0"));
        dao.createProposal("desc", recipient, 0, address(0));
    }

    function test_createProposal_success() public {
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + VOTING_PERIOD;

        vm.expectEmit(true, true, false, true);
        emit ProposalCreated(0, alice, "Fund grant", recipient, 1 ether, address(0), startTime, endTime);

        uint256 id = _createDefaultProposal();

        assertEq(id, 0);
        assertEq(dao.proposalCount(), 1);

        _assertProposalCore(id, alice, "Fund grant", startTime, endTime);
        _assertProposalSpend(id, recipient, 1 ether, address(0));
    }

    function _assertProposalCore(
        uint256 id,
        address expectedProposer,
        string memory expectedDescription,
        uint256 expectedStartTime,
        uint256 expectedEndTime
    ) internal view {
        (uint256 pid, address proposer, string memory description, uint256 forVotes, uint256 againstVotes,,,,,,,) =
            _getProposal(id);
        assertEq(pid, id);
        assertEq(proposer, expectedProposer);
        assertEq(description, expectedDescription);
        assertEq(forVotes, 0);
        assertEq(againstVotes, 0);

        (,,,,, uint256 sTime, uint256 eTime,,,,,) = _getProposal(id);
        assertEq(sTime, expectedStartTime);
        assertEq(eTime, expectedEndTime);
    }

    function _assertProposalSpend(uint256 id, address expectedRecipient, uint256 expectedAmount, address expectedToken)
        internal
        view
    {
        (,,,,,,, bool executed, bool canceled, address recip, uint256 amount, address tok) = _getProposal(id);
        assertFalse(executed);
        assertFalse(canceled);
        assertEq(recip, expectedRecipient);
        assertEq(amount, expectedAmount);
        assertEq(tok, expectedToken);
    }

    function test_createProposal_incrementsIdAcrossCalls() public {
        vm.startPrank(alice);
        uint256 id0 = dao.createProposal("first", recipient, 1 ether, address(0));
        uint256 id1 = dao.createProposal("second", recipient, 1 ether, address(0));
        vm.stopPrank();

        assertEq(id0, 0);
        assertEq(id1, 1);
        assertEq(dao.proposalCount(), 2);
    }

    // ---------------------------------------------------------------------
    // vote
    // ---------------------------------------------------------------------

    function test_vote_revertsWhenProposalDoesNotExist() public {
        vm.expectRevert(bytes("Proposal does not exist"));
        dao.vote(999, true);
    }

    function test_vote_revertsWhenVotingNotStarted() public {
        vm.warp(10 days);
        uint256 id = _createDefaultProposal();
        (, , , , , uint256 startTime, , , , , , ) = _getProposal(id);

        vm.warp(startTime - 1);
        vm.prank(bob);
        vm.expectRevert(bytes("Voting not started"));
        dao.vote(id, true);
    }

    function test_vote_revertsWhenVotingHasEnded() public {
        uint256 id = _createDefaultProposal();
        (, , , , , , uint256 endTime, , , , , ) = _getProposal(id);

        vm.warp(endTime);
        vm.prank(bob);
        vm.expectRevert(bytes("Voting has ended"));
        dao.vote(id, true);
    }

    function test_vote_revertsWhenAlreadyVoted() public {
        uint256 id = _createDefaultProposal();
        vm.startPrank(bob);
        dao.vote(id, true);
        vm.expectRevert(bytes("You have already voted on this proposal"));
        dao.vote(id, true);
        vm.stopPrank();
    }

    function test_vote_revertsWhenCanceled() public {
        uint256 id = _createDefaultProposal();
        vm.prank(alice);
        dao.cancelProposal(id);

        vm.prank(bob);
        vm.expectRevert(bytes("Proposal is canceled"));
        dao.vote(id, true);
    }

    function test_vote_revertsWhenAlreadyExecuted() public {
        uint256 id = _createDefaultProposal();
        vm.deal(address(treasury), 10 ether);

        vm.prank(alice);
        dao.vote(id, true);
        vm.prank(bob);
        dao.vote(id, true);

        (, , , , , uint256 startTime, uint256 endTime, , , , , ) = _getProposal(id);
        vm.warp(endTime);
        dao.executeProposal(id);

        // Jump back inside the original voting window (only possible via cheatcode-forced
        // time travel; on-chain this branch is unreachable because execution requires
        // block.timestamp >= endTime, which always fails the earlier "Voting has ended"
        // check first). Exercised here purely for coverage of the defensive check.
        vm.warp(startTime + 1);
        vm.prank(carol);
        vm.expectRevert(bytes("Proposal is already executed"));
        dao.vote(id, true);
    }

    function test_vote_revertsOnNoVotingPower() public {
        uint256 id = _createDefaultProposal();
        vm.prank(eve);
        vm.expectRevert(bytes("No voting power"));
        dao.vote(id, true);
    }

    function test_vote_support_recordsForVotes() public {
        uint256 id = _createDefaultProposal();

        vm.prank(bob);
        vm.expectEmit(true, true, false, true);
        emit Voted(id, bob, true, 1000 ether);
        dao.vote(id, true);

        (, , , uint256 forVotes, uint256 againstVotes, , , , , , , ) = _getProposal(id);
        assertEq(forVotes, 1000 ether);
        assertEq(againstVotes, 0);
    }

    function test_vote_against_recordsAgainstVotes() public {
        uint256 id = _createDefaultProposal();

        vm.prank(carol);
        vm.expectEmit(true, true, false, true);
        emit Voted(id, carol, false, 1000 ether);
        dao.vote(id, false);

        (, , , uint256 forVotes, uint256 againstVotes, , , , , , , ) = _getProposal(id);
        assertEq(forVotes, 0);
        assertEq(againstVotes, 1000 ether);
    }

    // ---------------------------------------------------------------------
    // cancelProposal
    // ---------------------------------------------------------------------

    function test_cancelProposal_revertsWhenProposalDoesNotExist() public {
        vm.expectRevert(bytes("Proposal does not exist"));
        dao.cancelProposal(999);
    }

    function test_cancelProposal_revertsWhenAlreadyExecuted() public {
        uint256 id = _createDefaultProposal();
        vm.deal(address(treasury), 10 ether);
        vm.prank(alice);
        dao.vote(id, true);
        vm.prank(bob);
        dao.vote(id, true);

        (, , , , , , uint256 endTime, , , , , ) = _getProposal(id);
        vm.warp(endTime);
        dao.executeProposal(id);

        vm.expectRevert(bytes("Proposal already executed"));
        dao.cancelProposal(id);
    }

    function test_cancelProposal_revertsWhenAlreadyCanceled() public {
        uint256 id = _createDefaultProposal();
        vm.prank(alice);
        dao.cancelProposal(id);

        vm.prank(alice);
        vm.expectRevert(bytes("Proposal already canceled"));
        dao.cancelProposal(id);
    }

    function test_cancelProposal_revertsWhenNotAuthorized() public {
        uint256 id = _createDefaultProposal();
        vm.prank(eve);
        vm.expectRevert(bytes("Not authorized to cancel"));
        dao.cancelProposal(id);
    }

    function test_cancelProposal_successByProposer() public {
        uint256 id = _createDefaultProposal();

        vm.prank(alice);
        vm.expectEmit(true, false, false, false);
        emit ProposalCanceled(id);
        dao.cancelProposal(id);

        (, , , , , , , , bool canceled, , , ) = _getProposal(id);
        assertTrue(canceled);
    }

    function test_cancelProposal_successByOwner() public {
        uint256 id = _createDefaultProposal();

        // owner (this test contract) is not the proposer (alice)
        vm.expectEmit(true, false, false, false);
        emit ProposalCanceled(id);
        dao.cancelProposal(id);

        (, , , , , , , , bool canceled, , , ) = _getProposal(id);
        assertTrue(canceled);
    }

    // ---------------------------------------------------------------------
    // executeProposal
    // ---------------------------------------------------------------------

    function test_executeProposal_revertsWhenProposalDoesNotExist() public {
        vm.expectRevert(bytes("Proposal does not exist"));
        dao.executeProposal(999);
    }

    function test_executeProposal_revertsWhenVotingPeriodNotOver() public {
        uint256 id = _createDefaultProposal();
        vm.prank(alice);
        dao.vote(id, true);

        vm.expectRevert(bytes("Voting period is not over"));
        dao.executeProposal(id);
    }

    function test_executeProposal_revertsWhenCanceled() public {
        uint256 id = _createDefaultProposal();
        vm.prank(alice);
        dao.cancelProposal(id);

        (, , , , , , uint256 endTime, , , , , ) = _getProposal(id);
        vm.warp(endTime);

        vm.expectRevert(bytes("Proposal is canceled"));
        dao.executeProposal(id);
    }

    function test_executeProposal_revertsWhenAlreadyExecuted() public {
        uint256 id = _createDefaultProposal();
        vm.deal(address(treasury), 10 ether);
        vm.prank(alice);
        dao.vote(id, true);
        vm.prank(bob);
        dao.vote(id, true);

        (, , , , , , uint256 endTime, , , , , ) = _getProposal(id);
        vm.warp(endTime);
        dao.executeProposal(id);

        vm.expectRevert(bytes("Proposal is already executed"));
        dao.executeProposal(id);
    }

    function test_executeProposal_revertsWhenQuorumNotReached() public {
        uint256 id = _createDefaultProposal();
        // only alice votes for: 1000 ether for-votes < 1500 ether quorum
        vm.prank(alice);
        dao.vote(id, true);

        (, , , , , , uint256 endTime, , , , , ) = _getProposal(id);
        vm.warp(endTime);

        vm.expectRevert(bytes("Quorum not reached"));
        dao.executeProposal(id);
    }

    function test_executeProposal_revertsWhenNotPassed() public {
        // dedicated DAO with a lower quorum so we can reach quorum while still losing the vote
        DAOTreasury lowQuorumTreasury = new DAOTreasury(address(0xdead));
        DAO lowQuorumDao = new DAO(address(token), address(lowQuorumTreasury), PROPOSAL_THRESHOLD, VOTING_PERIOD, 500 ether);
        lowQuorumTreasury.setDAO(address(lowQuorumDao));

        vm.prank(alice);
        uint256 id = lowQuorumDao.createProposal("desc", recipient, 1 ether, address(0));

        vm.prank(alice);
        lowQuorumDao.vote(id, true); // 1000 for (>= 500 quorum)
        vm.prank(bob);
        lowQuorumDao.vote(id, false); // 1000 against
        vm.prank(carol);
        lowQuorumDao.vote(id, false); // 1000 against -> againstVotes 2000 > forVotes 1000

        (, , , , , , uint256 endTime, , , , , ) = lowQuorumDao.proposals(id);
        vm.warp(endTime);

        vm.expectRevert(bytes("Proposal not passed"));
        lowQuorumDao.executeProposal(id);
    }

    function test_executeProposal_success_ETH() public {
        vm.deal(address(treasury), 10 ether);
        uint256 id = _createDefaultProposal(); // recipient, 1 ether, ETH

        vm.prank(alice);
        dao.vote(id, true);
        vm.prank(bob);
        dao.vote(id, true);
        vm.prank(carol);
        dao.vote(id, false);

        (, , , , , , uint256 endTime, , , , , ) = _getProposal(id);
        vm.warp(endTime);

        vm.expectEmit(true, false, false, false);
        emit ProposalExecuted(id);
        dao.executeProposal(id);

        (, , , , , , , bool executed, , , , ) = _getProposal(id);
        assertTrue(executed);
        assertEq(recipient.balance, 1 ether);
        assertEq(address(treasury).balance, 9 ether);
        assertTrue(treasury.approvedProposals(id));
        assertTrue(treasury.executedProposals(id));
    }

    function test_executeProposal_success_ERC20() public {
        mockToken.mint(address(treasury), 500 ether);

        vm.prank(alice);
        uint256 id = dao.createProposal("Pay grant in tokens", recipient, 200 ether, address(mockToken));

        vm.prank(alice);
        dao.vote(id, true);
        vm.prank(bob);
        dao.vote(id, true);

        (, , , , , , uint256 endTime, , , , , ) = _getProposal(id);
        vm.warp(endTime);

        dao.executeProposal(id);

        assertEq(mockToken.balanceOf(recipient), 200 ether);
        assertEq(mockToken.balanceOf(address(treasury)), 300 ether);
    }
}
