# Cross-chain Rebase Token

1. Create protocol that allows users to deposit into a vault and return, receiver rebase
tokens that represent their underlying balance.
2. Rebase token -> balance of function is dynamic to show the changing increasing balance with time.
    - Balance increase linearly  with the time
    - Mint tokens to our users every time they perform an action (minting, burning,
    transferring, or... bridging)
3. Interest rate
    - Individually set an interest rate or each user based on some global interest rate of
    the protocol at the time the user deposits into the vault.
    - This global interest rate can only decrease to incentive/reward early adopters.
    - Increase token adoption.
