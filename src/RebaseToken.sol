// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/*
* @title RebaseToken
* @author Victor Mosquera
* @notice This is a cross-chain rebase token that incentivizes users to deposit into a vault and
* interest in rewards.
* @notice the interest rate in the smart contract can only decrease
* @ Each user will have their own interest rate that is the global interest rate at the time of depositing
*/
contract RebaseToken is ERC20 {
    constructor() ERC20("Rebase Token", "RBST") {}
}