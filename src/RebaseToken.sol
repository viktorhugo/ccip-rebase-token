// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { console } from "forge-std/Test.sol";

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

/**
* @title RebaseToken
* @author Victor Mosquera
* @notice This is a cross-chain rebase token that incentivizes users to deposit into a vault and
* interest in rewards.
* @notice the interest rate in the smart contract can only decrease
* @ Each user will have their own interest rate that is the global interest rate at the time of depositing
*/
contract RebaseToken is ERC20, Ownable, AccessControl {

    ////////////////////
    //* Errors       //
    ///////////////////
    error RebaseToken__MustBeMoreThanZero();
    error RebaseToken__TokensToMintMustBeMoreThanZero();
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 newInterestRate, uint256 oldInterestRate);

    ////////////////////
    //* Types       //
    ///////////////////

    ///////////////////////
    //* State Variables  //
    //////////////////////
    uint256 private constant PRECISION_FACTOR = 1e18;
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");

    uint256 private s_interestRate = 5e10; // 10^-8 == 1/10^8

    mapping(address => uint256) private s_usersInterestRate;
    mapping(address => uint256) private s_usersLastUpdateTimestamp;

    ///////////////////////
    //*    Events       //
    //////////////////////
    event InterestRateSet(uint256 newInterestRate, uint256 oldInterestRate);

    ///////////////////
    //* Modifiers    //
    ///////////////////
    modifier moreThanZero(uint256 amount) {
        if (amount <= 0) revert RebaseToken__MustBeMoreThanZero();
        _;
    }

    constructor() ERC20("Rebase Token", "CAPY") Ownable(msg.sender) {} // (Ownable) Transfers ownership of the contract to a new account

    /** 
    * @notice Grant the mint and burn role to the account. only called by the owner
    * @param _address The address to grant the role
    */
    function grantMintAndBurnRole(address _address) external onlyOwner {
        console.log('set BurnAndMintRole', _address);
        _grantRole(MINT_AND_BURN_ROLE, _address);
    }

    // poder fijar el tipo de interes
    /**
    * @notice Set the interest rate in the smart contract
    * @param _newInterestRate The new interest rate
    * @dev The interest rate can only decrease
    */    
    function setInterestRate(uint256 _newInterestRate) external onlyOwner { // solo la puede modificar el propietario
        // Set the interest rate
        if (_newInterestRate >= s_interestRate) revert RebaseToken__InterestRateCanOnlyDecrease(_newInterestRate, s_interestRate);
        s_interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate, s_interestRate);
    }

    /**
    * @notice Mint the user tokens when they deposit into the vault
    * @notice only user whit role mint can execute this function 
    * @param _to The address of the user
    * @param _amount The amount of tokens to mint
    */
    function mint(address _to, uint256 _amount) external moreThanZero(_amount) onlyRole(MINT_AND_BURN_ROLE) {
        // acreditar el interes acumulado al user
        _mintAccruedInterest(_to);
        // Set the interest rate
        s_usersInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);  
    }

    /**
    * @notice Burn the user tokens when they withdraw from the vault
    * @notice only user whit role burn can execute this function 
    * @param _from The address of the user
    * @param _amount The amount of tokens to burn
    */
    // esta se llamara cuando transiramos tokens entre si
    function burn(address _from, uint256 _amount) external moreThanZero(_amount) onlyRole(MINT_AND_BURN_ROLE) {
        // acreditar el interes acumulado al user
        _mintAccruedInterest(_from);
        // burn the tokens
        _burn(_from, _amount);
    }

    /**
    * @notice Calculate the balance of the user including the interest that has accumulated since the last update
    * (principle balance + interest that has accrued)
    * @param _user The address of the user
    * @return The balance of the user including the interest that has accumulated since the last update
    */
    function balanceOf(address _user) public  view override returns (uint256) {
        // get the current principal balance of the user (# tokens that have been minted user)
        // multiply the principal balance by the interest that has accumulated since the last update of the user
        uint256 userBalance = super.balanceOf(_user);
        if ( userBalance == 0) {
            return 0;
        }
        uint256 linearInterestAmount = _calculateUserAccumulatedInterestSinceLastUpdate(_user);
        console.log('linearInterestAmount', linearInterestAmount);
        return ( userBalance * linearInterestAmount ) / PRECISION_FACTOR;
    }


    /**
    * @notice Transfer tokens from one user to another
    * @param _recipient The address of the recipient
    * @param _amount The amount of tokens to transfer
    * @return success True if the transfer was successful
    */
    function transfer(address _recipient, uint256 _amount) public override moreThanZero(_amount) returns (bool success) {
        // acreditar el interes acumulado al sender user
        _mintAccruedInterest(msg.sender);
        // acreditar el interes acumulado al receiver user
        _mintAccruedInterest(_recipient);
        // check if amount is max
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        // verificar si el destinatario (_recipient) tiene ya una tasa de interes, 
        // si no tiene o no ha depositado en el protocolo aun, fijarle con la tasa del remitente (msg.sender)
        if (s_usersInterestRate[_recipient] == 0) {
            s_usersInterestRate[_recipient] = s_usersInterestRate[msg.sender];
        }
        return super.transfer(_recipient, _amount);
    }

    /**
    * @notice Transfer tokens from one user to another
    * @param _sender The address of the sender
    * @param _recipient The address of the recipient
    * @param _amount The amount of tokens to transfer
    * @return success True if the transfer was successful
    */ 
    function transferFrom(address _sender, address _recipient, uint256 _amount) public override moreThanZero(_amount) returns (bool success) {
        // acreditar el interes acumulado al sender user
        _mintAccruedInterest(_sender);
        // acreditar el interes acumulado al receiver user
        _mintAccruedInterest(_recipient);
        // check if amount is max
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }
        // verificar si el destinatario (_recipient) tiene ya una tasa de interes, 
        // si no tiene o no ha depositado en el protocolo aun, fijarle con la tasa del remitente (_sender)
        if (s_usersInterestRate[_recipient] == 0) {
            s_usersInterestRate[_recipient] = s_usersInterestRate[_sender];
        }
        return super.transferFrom(_sender, _recipient, _amount);
    }


    
    /**
    * @notice Mint the accrued interest to the user since the last time they interacted with the protocol (burn, transfer, etc)
    * @param _user The user address to mint the accrued interest
    */
    // esto recuperara cualquier interes que se haya acumulado desde el
    // momento que haya realizadp alguna otra acción (mint, burn transfer, etc);
    function _mintAccruedInterest(address _user) internal {
        // (1) find their current balance of rebase tokens that have been minted -> principal balance
        uint256 userBalance = super.balanceOf(_user);
        // (2) calculate their current balance including any interest -> BalanceOf
        uint256 currentBalance = balanceOf(_user);
        // calculate de number tokens that need to be minted to the user, cantidad de token a los que tiene derecho
        // (2) - (1) cantidad de tokens que se necesitan acuñar
        uint256 tokensToMint = currentBalance - userBalance;
        // check that the number of tokens to mint is more than 0
        if ( tokensToMint == 0 ) return;
        // (3) mint those tokens to the user (_mint)
        _mint(_user, tokensToMint);
        // (4) set the users last updated timestamp
        s_usersLastUpdateTimestamp[_user] = block.timestamp;
    }

    /**
    * @notice Calculate the interest that has accumulated since the last update
    * @param _user The address of the user
    * @return linearInterestAmount The interest that has accumulated since the last update
    */
    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user) internal view returns (uint256 linearInterestAmount) {
        // nesecitamos calcular el interes que se ha acumulado desde el ultimo update:
        // este sera un crecimiento lineal con el tiempo
        // 1. calcular el tiempo transcurrido desde el ultimo update
        // 2. calcualr la cantidad de crecimiento lineal:
        // (balance principal) + (balance principal * user interest rate * tiempo transcurrido)
        // explicacion:
        // deposit: 10 tokens
        // user interest rate: 0.5 tokens per second
        // time elapsed: 2 
        // 10 + (10 * 0.5 * 2) = 22 tokens
        uint256 timeElapsed = block.timestamp - s_usersLastUpdateTimestamp[_user];
        return linearInterestAmount =  (s_usersInterestRate[_user] * timeElapsed) + PRECISION_FACTOR;
    }

    /**
    * @notice Get the interest rate for a specific user
    * @param _userAddress The address of the user
    * @return The interest rate for the user
    */
    function getUserInterestRate(address _userAddress) external view returns (uint256) {
        return s_usersInterestRate[_userAddress];
    }

    /**
    * @notice Get the principle balance of a user (no including any interest)
    * @param _userAddress The address of the user
    * @return The principle balance of the user
    */
    function getPrincipleBalanceOfUser(address _userAddress) external view returns (uint256) {
        return super.balanceOf(_userAddress);
    }
    
    /**
    * @notice Get the interest rate currently set for the contract, any future deposits will receive this interest rate
    * @return The accumulated interest of the user
    */
    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }
}