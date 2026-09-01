// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import "forge-std/Test.sol";
import "../src/DAOTreasury.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./mocks/MockERC20.sol";
import "./mocks/FalseReturnERC20.sol";
import "./mocks/RejectEther.sol";

contract DAOTreasuryTest is Test {
    DAOTreasury treasury;
    MockERC20 mockToken;

    address owner = address(this);
    address daoStub = makeAddr("daoStub"); // acts as the "DAO" caller (msg.sender == dao)
    address alice = makeAddr("alice");
    address recipient = makeAddr("recipient");

    event ProposalApproved(uint256 indexed proposalId);
    event FundsSpend(uint256 indexed proposalId, address indexed recipient, uint256 amount, address token);
    event TreasuryFunded(address indexed sender, uint256 amount);
    event DAOSet(address indexed dao);

    function setUp() public {
        treasury = new DAOTreasury(daoStub);
        mockToken = new MockERC20("Mock", "MCK");
    }

    // ---------------------------------------------------------------------
    // constructor
    // ---------------------------------------------------------------------

    function test_constructor_setsDaoAndOwner() public view {
        assertEq(address(treasury.dao()), daoStub);
        assertEq(treasury.owner(), owner);
    }

    // ---------------------------------------------------------------------
    // setDAO
    // ---------------------------------------------------------------------

    function test_setDAO_revertsForNonOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        treasury.setDAO(alice);
    }

    function test_setDAO_revertsOnZeroAddress() public {
        vm.expectRevert(bytes("DAO address cannot be zero"));
        treasury.setDAO(address(0));
    }

    function test_setDAO_success() public {
        address newDao = makeAddr("newDao");
        vm.expectEmit(true, false, false, true);
        emit DAOSet(newDao);
        treasury.setDAO(newDao);
        assertEq(address(treasury.dao()), newDao);
    }

    // ---------------------------------------------------------------------
    // approvedProposal
    // ---------------------------------------------------------------------

    function test_approvedProposal_revertsWhenCallerIsNotDAO() public {
        vm.prank(alice);
        vm.expectRevert(bytes("Only DAO can approve proposals"));
        treasury.approvedProposal(1);
    }

    function test_approvedProposal_success() public {
        vm.prank(daoStub);
        vm.expectEmit(true, false, false, false);
        emit ProposalApproved(1);
        treasury.approvedProposal(1);
        assertTrue(treasury.approvedProposals(1));
    }

    function test_approvedProposal_revertsWhenAlreadyApproved() public {
        vm.startPrank(daoStub);
        treasury.approvedProposal(1);
        vm.expectRevert(bytes("Proposal already approved"));
        treasury.approvedProposal(1);
        vm.stopPrank();
    }

    // ---------------------------------------------------------------------
    // sendFunds
    // ---------------------------------------------------------------------

    function test_sendFunds_revertsWhenCallerIsNotDAO() public {
        vm.prank(alice);
        vm.expectRevert(bytes("Only DAO can spend funds"));
        treasury.sendFunds(1, recipient, 1 ether, address(0));
    }

    function test_sendFunds_revertsWhenProposalNotApproved() public {
        vm.prank(daoStub);
        vm.expectRevert(bytes("Proposal not approved"));
        treasury.sendFunds(1, recipient, 1 ether, address(0));
    }

    function test_sendFunds_revertsWhenAlreadyExecuted() public {
        vm.deal(address(treasury), 10 ether);
        vm.startPrank(daoStub);
        treasury.approvedProposal(1);
        treasury.sendFunds(1, recipient, 1 ether, address(0));

        vm.expectRevert(bytes("Proposal already executed"));
        treasury.sendFunds(1, recipient, 1 ether, address(0));
        vm.stopPrank();
    }

    function test_sendFunds_revertsOnZeroRecipient() public {
        vm.startPrank(daoStub);
        treasury.approvedProposal(1);
        vm.expectRevert(bytes("Invalid recipient"));
        treasury.sendFunds(1, address(0), 1 ether, address(0));
        vm.stopPrank();
    }

    function test_sendFunds_revertsOnZeroAmount() public {
        vm.startPrank(daoStub);
        treasury.approvedProposal(1);
        vm.expectRevert(bytes("Amount must be greater than 0"));
        treasury.sendFunds(1, recipient, 0, address(0));
        vm.stopPrank();
    }

    function test_sendFunds_ETH_revertsOnInsufficientBalance() public {
        vm.startPrank(daoStub);
        treasury.approvedProposal(1);
        vm.expectRevert(bytes("Insufficient ETH balance"));
        treasury.sendFunds(1, recipient, 1 ether, address(0));
        vm.stopPrank();
    }

    function test_sendFunds_ETH_success() public {
        vm.deal(address(treasury), 5 ether);
        vm.startPrank(daoStub);
        treasury.approvedProposal(1);

        vm.expectEmit(true, true, false, true);
        emit FundsSpend(1, recipient, 2 ether, address(0));
        treasury.sendFunds(1, recipient, 2 ether, address(0));
        vm.stopPrank();

        assertEq(recipient.balance, 2 ether);
        assertEq(address(treasury).balance, 3 ether);
        assertTrue(treasury.executedProposals(1));
    }

    function test_sendFunds_ETH_revertsWhenTransferFails() public {
        RejectEther badRecipient = new RejectEther();
        vm.deal(address(treasury), 5 ether);
        vm.startPrank(daoStub);
        treasury.approvedProposal(1);
        vm.expectRevert(bytes("ETH transfer failed"));
        treasury.sendFunds(1, address(badRecipient), 1 ether, address(0));
        vm.stopPrank();
    }

    function test_sendFunds_ERC20_revertsOnInsufficientBalance() public {
        vm.startPrank(daoStub);
        treasury.approvedProposal(1);
        vm.expectRevert(bytes("Insufficient token balance"));
        treasury.sendFunds(1, recipient, 100 ether, address(mockToken));
        vm.stopPrank();
    }

    function test_sendFunds_ERC20_success() public {
        mockToken.mint(address(treasury), 100 ether);
        vm.startPrank(daoStub);
        treasury.approvedProposal(1);

        vm.expectEmit(true, true, false, true);
        emit FundsSpend(1, recipient, 30 ether, address(mockToken));
        treasury.sendFunds(1, recipient, 30 ether, address(mockToken));
        vm.stopPrank();

        assertEq(mockToken.balanceOf(recipient), 30 ether);
        assertEq(mockToken.balanceOf(address(treasury)), 70 ether);
    }

    function test_sendFunds_ERC20_revertsWhenTransferFails() public {
        FalseReturnERC20 badToken = new FalseReturnERC20();
        badToken.setBalance(address(treasury), 100 ether);

        vm.startPrank(daoStub);
        treasury.approvedProposal(1);
        vm.expectRevert(bytes("Token transfer failed"));
        treasury.sendFunds(1, recipient, 10 ether, address(badToken));
        vm.stopPrank();
    }

    // ---------------------------------------------------------------------
    // fundTreasury
    // ---------------------------------------------------------------------

    function test_fundTreasury_revertsOnZeroValue() public {
        vm.expectRevert(bytes("Must send ETH"));
        treasury.fundTreasury{value: 0}();
    }

    function test_fundTreasury_success() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit TreasuryFunded(alice, 1 ether);
        treasury.fundTreasury{value: 1 ether}();
        assertEq(address(treasury).balance, 1 ether);
    }

    // ---------------------------------------------------------------------
    // fundTreasuryWithToken
    // ---------------------------------------------------------------------

    function test_fundTreasuryWithToken_revertsOnZeroTokenAddress() public {
        vm.expectRevert(bytes("Invalid token address"));
        treasury.fundTreasuryWithToken(address(0), 1 ether);
    }

    function test_fundTreasuryWithToken_revertsOnZeroAmount() public {
        vm.expectRevert(bytes("Amount must be greater than 0"));
        treasury.fundTreasuryWithToken(address(mockToken), 0);
    }

    function test_fundTreasuryWithToken_success() public {
        mockToken.mint(alice, 50 ether);
        vm.startPrank(alice);
        mockToken.approve(address(treasury), 50 ether);
        vm.expectEmit(true, false, false, true);
        emit TreasuryFunded(alice, 20 ether);
        treasury.fundTreasuryWithToken(address(mockToken), 20 ether);
        vm.stopPrank();

        assertEq(mockToken.balanceOf(address(treasury)), 20 ether);
    }

    function test_fundTreasuryWithToken_revertsWhenTransferFromFails() public {
        FalseReturnERC20 badToken = new FalseReturnERC20();
        vm.expectRevert(bytes("Failed to transfer tokens"));
        treasury.fundTreasuryWithToken(address(badToken), 1 ether);
    }

    // ---------------------------------------------------------------------
    // receive()
    // ---------------------------------------------------------------------

    function test_receive_acceptsPlainETHTransfers() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit TreasuryFunded(alice, 1 ether);
        (bool success, ) = address(treasury).call{value: 1 ether}("");
        assertTrue(success);
        assertEq(address(treasury).balance, 1 ether);
    }

    // ---------------------------------------------------------------------
    // emergencyWithdraw
    // ---------------------------------------------------------------------

    function test_emergencyWithdraw_revertsForNonOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        treasury.emergencyWithdraw(address(0), 1 ether, recipient);
    }

    function test_emergencyWithdraw_revertsOnZeroRecipient() public {
        vm.expectRevert(bytes("Invalid recipient address"));
        treasury.emergencyWithdraw(address(0), 1 ether, address(0));
    }

    function test_emergencyWithdraw_revertsOnZeroAmount() public {
        vm.expectRevert(bytes("Amount must be greater than 0"));
        treasury.emergencyWithdraw(address(0), 0, recipient);
    }

    function test_emergencyWithdraw_ETH_revertsOnInsufficientBalance() public {
        vm.expectRevert(bytes("Insufficient ETH balance"));
        treasury.emergencyWithdraw(address(0), 1 ether, recipient);
    }

    function test_emergencyWithdraw_ETH_success() public {
        vm.deal(address(treasury), 5 ether);
        treasury.emergencyWithdraw(address(0), 3 ether, recipient);
        assertEq(recipient.balance, 3 ether);
        assertEq(address(treasury).balance, 2 ether);
    }

    function test_emergencyWithdraw_ETH_revertsWhenTransferFails() public {
        RejectEther badRecipient = new RejectEther();
        vm.deal(address(treasury), 5 ether);
        vm.expectRevert(bytes("ETH transfer failed"));
        treasury.emergencyWithdraw(address(0), 1 ether, address(badRecipient));
    }

    function test_emergencyWithdraw_ERC20_revertsOnInsufficientBalance() public {
        vm.expectRevert(bytes("Insufficient token balance"));
        treasury.emergencyWithdraw(address(mockToken), 1 ether, recipient);
    }

    function test_emergencyWithdraw_ERC20_success() public {
        mockToken.mint(address(treasury), 10 ether);
        treasury.emergencyWithdraw(address(mockToken), 4 ether, recipient);
        assertEq(mockToken.balanceOf(recipient), 4 ether);
    }

    function test_emergencyWithdraw_ERC20_revertsWhenTransferFails() public {
        FalseReturnERC20 badToken = new FalseReturnERC20();
        badToken.setBalance(address(treasury), 10 ether);
        vm.expectRevert(bytes("Token transfer failed"));
        treasury.emergencyWithdraw(address(badToken), 1 ether, recipient);
    }
}
