// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;


interface IRebaseToken {
    error RebaseToken__MustBeMoreThanZero();
    error RebaseToken__TokensToMintMustBeMoreThanZero();
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 newInterestRate, uint256 oldInterestRate);
    function mint(address _to, uint256 _amount) external;
    function burn(address _from, uint256 _amount) external;
    function balanceOf(address _account) external view returns (uint256);
}