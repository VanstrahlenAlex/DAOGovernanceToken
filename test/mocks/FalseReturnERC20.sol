// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

/// @dev Minimal ERC20-shaped token whose transfer()/transferFrom() always report
/// "insufficient" through a normal `false` return instead of reverting, and whose
/// balanceOf() is controllable. Used to exercise the "Token transfer failed" require()
/// branches in DAOTreasury, which OpenZeppelin's ERC20 can never trigger (it reverts
/// instead of returning false).
contract FalseReturnERC20 {
    mapping(address => uint256) private _balances;

    function setBalance(address account, uint256 amount) external {
        _balances[account] = amount;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function transfer(address, uint256) external pure returns (bool) {
        return false;
    }

    function transferFrom(address, address, uint256) external pure returns (bool) {
        return false;
    }
}
