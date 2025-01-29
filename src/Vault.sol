// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IRebaseToken } from "./interfaces/IRebaseToken.sol";

contract Vault {

    // we need to pass the token address to th constructor
    // create a deposit function tha mints tokens to the user equal to the amount of ETH the user
    // create a redeem function that burns tokens from the user and sends the user ETH
    // Create way to add rewards to the vault
    ////////////////////
    //* Errors       //
    ///////////////////
    error Vault__MustBeMoreThanZero();
    error Vault__RedeemFailed();

    ///////////////////////
    //* State Variables  //
    //////////////////////
    IRebaseToken private immutable i_rebaseToken;
    

    ///////////////////////
    //*    Events       //
    //////////////////////
    // agregar "indexed" a los argumentos de los eventos quiere decir que te permite indexar u 
    // ordenar los eventos por esa variable
    event NewDepositAndMint(address indexed accountAddress, uint256 value); 
    event NewRedeemAndBurn(address indexed accountAddress, uint256 value); 

    ///////////////////
    //* Modifiers    //
    ///////////////////
    modifier moreThanZero(uint256 amount) {
        if (amount <= 0) revert Vault__MustBeMoreThanZero();
        _;
    }

    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    // en el mundo real estas seran recompensas que se desbloquearan linealmente en funcion de algunos
    // mecanismos como staking o lending and borrowing, pero lo hacemos de forma discreta.
    // o un mecanismo que solamente obtiene ganancias para usuarios basados en el monto de 
    // recompensas que se depositen en la vault
    receive() external payable {

    }

    /** 
    * @notice Allow users to deposit ETH into the vault and mint tokens equal to the amount of ETH the user
    * @dev The amount of ETH must be greater than 0
    */
    function deposit() external payable {
        // utilizar la cantidad de ETH recibida para acuñar tokens
        i_rebaseToken.mint(msg.sender, msg.value);
        emit NewDepositAndMint(msg.sender, msg.value);
    }

    /** 
    * @notice Allow users to redeem rebase tokens and send ETH to the user
    * @dev The amount of tokens must be greater than 0
    */
    function redeem(uint256 _amount) external {
        // 1. burn tokens from the user
        i_rebaseToken.burn(msg.sender, _amount);
        // 2. send ETH to the user
        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault__RedeemFailed();
        }
        emit NewRedeemAndBurn(msg.sender, _amount);
    }

    /** 
    * @notice Get the address of the rebase token
    * @return The address of the rebase token
    */
    function getRebaseTokenAddress() external view returns (address) {
        return address(i_rebaseToken);
    }
}