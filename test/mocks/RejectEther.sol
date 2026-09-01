// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

/// @dev Contract with no receive()/fallback(), used as a recipient that always rejects
/// plain ETH transfers so the "ETH transfer failed" require() branches can be exercised.
contract RejectEther {}
