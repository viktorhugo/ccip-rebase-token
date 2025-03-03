// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

import { Test, console } from "forge-std/Test.sol";

import { RebaseToken } from "../src/RebaseToken.sol";
import { Vault } from "../src/Vault.sol";
import { IRebaseToken } from "../src/interfaces/IRebaseToken.sol";

contract RebaseTokenTest is Test {

    RebaseToken private rebaseToken;
    Vault private vault;

    address private owner = makeAddr('owner');
    address private user = makeAddr('user');

    function setUp() public {
        
        console.log('===========  Init setUp   =================');
        console.log('owner', address(owner));
        console.log('user', address(user));
        console.log('msg.sender', address(msg.sender));
        console.log('===========================================');

        vm.startPrank(owner); //cambia el address del owner a el address del msg.sender
        console.log('prank owner', address(msg.sender));
        rebaseToken = new RebaseToken();
        console.log('rebaseToken', address(rebaseToken));
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        console.log('vault', address(vault));
        rebaseToken.grantMintAndBurnRole(address(vault)); // ahora concedemos a la vault el rol de MintAndBurn
        vm.stopPrank();
        
        console.log('===========  Finish setUp   ===============');
        console.log('===========================================');
    }
    
    function addRewardsToVault(uint256 rewardAmount) public { 
        // this function no exec because don't have previous "test" in the name function
        (bool success, )= payable(address(vault)).call{value: rewardAmount}("");
        console.log('payable', success);
    }

    function testDepositLinear(uint256 amount) public {
        // - asegurarnos de que la cantidad del amount sea suficiente para poder ver algun interes lineal
        // en una cierta cantidad de tiempo para que podamos usar el limite para restringir la cantidad
        amount = bound(amount, 1e5, type(uint96).max);
        console.log('New Amount for bound', amount);
        // 1. deposit
        vm.startPrank(user); // este es el user que va a llamara
        vm.deal(user, amount); // - Asegurarnos de que este usuario tenga algo de ETH para poder usarlo
        vault.deposit{value: amount}();
        // 2. check our rebase token balance(que sea el mismo que el amount del deposit)
        uint256 startingBalance = rebaseToken.balanceOf(user);
        console.log('startingBalance', startingBalance);
        // assertEq(startingBalance, amount);
        // 3. warp the time and check the balance again (aumenta el tiempo y verifica el balance)
        vm.warp(block.timestamp + 2 hours); // cheap para avanzar el tiempo
        uint256 middleBalance = rebaseToken.balanceOf(user);
        console.log('middleBalance', middleBalance);
        assertGt(middleBalance, startingBalance); // el middleBalance va ser mayor que el amount
        // 4. warp the time again by same amount and check the balance again
        vm.warp(block.timestamp + 2 hours); // cheap para avanzar el tiempo
        uint256 finalBalance = rebaseToken.balanceOf(user);
        console.log('finalBalance', finalBalance);
        assertGt(finalBalance, middleBalance);
        // 5. diff between finalBalance and middleBalance
        uint256 middleDiff = middleBalance - startingBalance;
        uint256 finalDiff = finalBalance - middleBalance;
        console.log('middleDiff', middleDiff);
        console.log('finalDiff', finalDiff);
        assertApproxEqAbs(middleDiff, finalDiff, 1);
        
        vm.stopPrank();
    }

    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        // 1. deposit
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        uint256 startingBalance = rebaseToken.balanceOf(user);
        console.log('startingBalance', startingBalance);
        // assertEq(startingBalance, amount);
        // 2. redeem
        vault.redeem(type(uint256).max); // redeem todo el balance
        assertEq(rebaseToken.balanceOf(user), 0);
        assertEq(address(user).balance, amount);
        vm.stopPrank();
    }

    function testRedeemAfterTimePassed(uint256 depositAmount, uint256 time) public {
        time = bound(time, 1000, type(uint96).max); // limitemos el tiempo de 1000 seg al maximo posible
        depositAmount = bound(depositAmount, 1e5, type(uint96).max);
        console.log('depositAmount', depositAmount);
        // 1. deposit
        vm.deal(user, depositAmount);
        vm.prank(user);
        vault.deposit{value: depositAmount}(); // depositamos el monto del depositAmount en la vault
        // 2. warp the time and check the balance again
        vm.warp(block.timestamp + time); // recorremos el tiempo
        uint256 balanceAfterSomeTime = rebaseToken.balanceOf(user);
        // 3. add rewards to the vault
        vm.deal(owner, balanceAfterSomeTime - depositAmount);
        vm.prank(owner);
        addRewardsToVault(balanceAfterSomeTime - depositAmount); //el amount Rewards sera el monto del deposit 
        // 4. redeem
        vm.prank(user);
        vault.redeem(type(uint256).max); // redeem todo el balance
        uint256 ethBalance = address(user).balance;
        console.log('ethBalance', ethBalance);
        // la cantidad de tokens es igual a la cantidad que tenia de rebase tokens antes de que
        // se retiraron despues del tiempo transcurrido
        assertEq(ethBalance, balanceAfterSomeTime);
        // comprobar que su saldo eth es mayor que el monto del deposit
        assertGt(ethBalance, depositAmount);

        vm.stopPrank();
    }


    function testTransfer(uint256 amount, uint256 amountToTransfer) public {
        amount = bound(amount, 1e5 + 1e5, type(uint96).max);
        amountToTransfer = bound(amountToTransfer, 1e5, amount - 1e5);
        // 1. deposit
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}(); // depositamos el monto del depositAmount en la vault
        
        address user2 = makeAddr('user2');
        uint256 startingBalanceUser = rebaseToken.balanceOf(user);
        uint256 startingBalanceUser2 = rebaseToken.balanceOf(user2);
        console.log('startingBalanceUser', startingBalanceUser);
        console.log('startingBalanceUser2', startingBalanceUser2);
        assertEq(startingBalanceUser, amount);
        assertEq(startingBalanceUser2, 0);
        
        // vamos asegurarnos de que si la tasa de interest esta fijada por el propietario 
        // entonces cuando alguien envia sus tokens a otro user, no pueden obtener el interes en el contract
        // encambio obtiene la tasa de interes heredada de la persona que envio los tokens
        // owner reduce the interest rate
        vm.prank(owner); // la persona que puede llamar establece la tasa de interes y luego podemos hacer la transfer
        rebaseToken.setInterestRate(4e10);
        
        // 2. transfers the tokens
        vm.prank(user);
        rebaseToken.transfer(address(user2), amountToTransfer);
        // obtenemos los saldos de los users
        uint256 userBalanceAfterTransfer = rebaseToken.balanceOf(user);
        uint256 user2BalanceAfterTransfer = rebaseToken.balanceOf(user2);
        console.log('userBalanceAfterTransfer', userBalanceAfterTransfer);
        console.log('user2BalanceAfterTransfer', user2BalanceAfterTransfer);
        assertEq(userBalanceAfterTransfer, startingBalanceUser - amountToTransfer);
        assertEq(user2BalanceAfterTransfer, startingBalanceUser2 + amountToTransfer);

        //3. check the interest rate has been inherited ( que ha sido heredada) (5e10 not 4e10)
        assertEq(rebaseToken.getUserInterestRate(user), 5e10);
        assertEq(rebaseToken.getUserInterestRate(user2), 5e10);
    }
}