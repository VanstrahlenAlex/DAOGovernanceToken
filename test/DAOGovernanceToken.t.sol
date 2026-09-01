// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import "forge-std/Test.sol";
import "../src/DAOGovernanceToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract DAOGovernanceTokenTest is Test {
    DAOGovernanceToken token;

    address owner = address(this);
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address carol = makeAddr("carol");

    uint256 constant INITIAL_SUPPLY = 1_000_000 ether;

    event VotingPowerDelegated(address indexed delegator, address indexed delegate, uint256 amount);
    event VotingPowerUndelegated(address indexed delegator, address indexed delegate, uint256 amount);

    function setUp() public {
        token = new DAOGovernanceToken("DAO Governance Token", "DAOG", INITIAL_SUPPLY);
    }

    // ---------------------------------------------------------------------
    // constructor
    // ---------------------------------------------------------------------

    function test_constructor_mintsInitialSupplyToDeployer() public view {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
    }

    function test_constructor_setsNameAndSymbol() public view {
        assertEq(token.name(), "DAO Governance Token");
        assertEq(token.symbol(), "DAOG");
    }

    function test_constructor_setsOwner() public view {
        assertEq(token.owner(), owner);
    }

    // ---------------------------------------------------------------------
    // delegateVotingPower
    // ---------------------------------------------------------------------

    function test_delegate_revertsOnZeroAddress() public {
        vm.expectRevert(bytes("Cannot delegate to zero address"));
        token.delegateVotingPower(address(0), 1 ether);
    }

    function test_delegate_revertsOnSelfDelegate() public {
        vm.expectRevert(bytes("Cannot delegate to self"));
        token.delegateVotingPower(owner, 1 ether);
    }

    function test_delegate_revertsOnZeroAmount() public {
        vm.expectRevert(bytes("Amount must be greater than 0"));
        token.delegateVotingPower(alice, 0);
    }

    function test_delegate_revertsOnInsufficientBalance() public {
        // alice has 0 balance, trying to delegate reverts on the custom balance check
        vm.prank(alice);
        vm.expectRevert(bytes("Insufficeint balance"));
        token.delegateVotingPower(bob, 1 ether);
    }

    function test_delegate_revertsWhenAmountEqualsBalance() public {
        // contract uses a strict `>` check, so delegating the *entire* balance reverts too
        token.transfer(alice, 100 ether);
        vm.prank(alice);
        vm.expectRevert(bytes("Insufficeint balance"));
        token.delegateVotingPower(bob, 100 ether);
    }

    function test_delegate_success() public {
        token.transfer(alice, 100 ether);

        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit VotingPowerDelegated(alice, bob, 40 ether);
        token.delegateVotingPower(bob, 40 ether);

        assertEq(token.balanceOf(alice), 60 ether);
        assertEq(token.balanceOf(bob), 40 ether);
        assertEq(token.delegates(alice), bob);
        assertEq(token.delegatedVotes(bob), 40 ether);
        assertTrue(token.hasDelegated(alice));
    }

    function test_delegate_accumulatesAcrossMultipleCalls() public {
        token.transfer(alice, 100 ether);

        vm.startPrank(alice);
        token.delegateVotingPower(bob, 10 ether);
        token.delegateVotingPower(bob, 20 ether);
        vm.stopPrank();

        assertEq(token.delegatedVotes(bob), 30 ether);
        assertEq(token.balanceOf(bob), 30 ether);
    }

    // ---------------------------------------------------------------------
    // undelegateVotingPower
    // ---------------------------------------------------------------------

    function test_undelegate_revertsWhenNoDelegationFound() public {
        vm.prank(alice);
        vm.expectRevert(bytes("No delegation found"));
        token.undelegateVotingPower(1 ether);
    }

    function test_undelegate_revertsOnZeroAmount() public {
        token.transfer(alice, 100 ether);
        vm.startPrank(alice);
        token.delegateVotingPower(bob, 40 ether);
        vm.expectRevert(bytes("amount must be greater than 0"));
        token.undelegateVotingPower(0);
        vm.stopPrank();
    }

    function test_undelegate_revertsOnInsufficientDelegatedAmount() public {
        token.transfer(alice, 100 ether);
        vm.startPrank(alice);
        token.delegateVotingPower(bob, 40 ether);
        vm.expectRevert(bytes("Insufficient delegated amount"));
        token.undelegateVotingPower(41 ether);
        vm.stopPrank();
    }

    function test_undelegate_partial_keepsDelegationActive() public {
        token.transfer(alice, 100 ether);
        vm.startPrank(alice);
        token.delegateVotingPower(bob, 40 ether);

        vm.expectEmit(true, true, false, true);
        emit VotingPowerUndelegated(alice, bob, 15 ether);
        token.undelegateVotingPower(15 ether);
        vm.stopPrank();

        assertEq(token.delegatedVotes(bob), 25 ether);
        assertEq(token.balanceOf(alice), 75 ether);
        assertTrue(token.hasDelegated(alice));
        assertEq(token.delegates(alice), bob);
    }

    function test_undelegate_full_clearsDelegationState() public {
        token.transfer(alice, 100 ether);
        vm.startPrank(alice);
        token.delegateVotingPower(bob, 40 ether);
        token.undelegateVotingPower(40 ether);
        vm.stopPrank();

        assertEq(token.delegatedVotes(bob), 0);
        assertFalse(token.hasDelegated(alice));
        assertEq(token.delegates(alice), address(0));
        assertEq(token.balanceOf(alice), 100 ether);
    }

    function test_undelegate_afterFullUndelegate_requiresNewDelegation() public {
        token.transfer(alice, 100 ether);
        vm.startPrank(alice);
        token.delegateVotingPower(bob, 40 ether);
        token.undelegateVotingPower(40 ether);

        vm.expectRevert(bytes("No delegation found"));
        token.undelegateVotingPower(1);
        vm.stopPrank();
    }

    // ---------------------------------------------------------------------
    // getVotingPower
    // ---------------------------------------------------------------------

    function test_getVotingPower_matchesBalance() public {
        token.transfer(alice, 55 ether);
        assertEq(token.getVotingPower(alice), 55 ether);
        assertEq(token.getVotingPower(bob), 0);
    }

    // ---------------------------------------------------------------------
    // mint
    // ---------------------------------------------------------------------

    function test_mint_onlyOwner() public {
        token.mint(alice, 10 ether);
        assertEq(token.balanceOf(alice), 10 ether);
        assertEq(token.totalSupply(), INITIAL_SUPPLY + 10 ether);
    }

    function test_mint_revertsForNonOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        token.mint(bob, 1 ether);
    }

    // ---------------------------------------------------------------------
    // burn
    // ---------------------------------------------------------------------

    function test_burn_success() public {
        token.transfer(alice, 10 ether);
        vm.prank(alice);
        token.burn(4 ether);
        assertEq(token.balanceOf(alice), 6 ether);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - 4 ether);
    }

    function test_burn_revertsOnInsufficientBalance() public {
        vm.prank(carol);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, carol, 0, 1 ether)
        );
        token.burn(1 ether);
    }
}
