# YieldRedirect

![Yield Redirect Diagram](https://github.com/RoboVault/YieldRedirect/blob/smooth_refactor/YieldRedirect.png)

YieldRedirect is a new kind of vault. Rather than farming rewards being auto-compound back into the vault, the rewards are swapped into the vaults target token. For example, users can farm LQDR on OATH-FTM and all LQDR rewards could be swapped into USDC. The target farm and target token are configurable in the contracts constructor. 
The vault supports LP farming and single-asset farming.
in essence, users can DCA the target token while LP farming. 

## Terminology

- `RedirectVault`: A fork of Reapers Vaults, this is the vault interface for users to deposit and withdraw their lp tokens.
- `Strategy`: A fork of Reapers farming strategies. This strategy farms LP and rather than autocompounding, when claim() is called by the vault, it sends the reward tokens to the RewardDistributor
- `RewardDistributor`: All rewards are sent to the reward distributor which tracks rewards per-user. Rewards are recored in target token and tracked on an epoch basis, much like validator nodes. The reward accounting is separated from the vault and strategy to mitigate risk. If there's an issue in the RewardsDistributor, it cannot impact the funds deposited into the vault & strategy. 

## Roles
- `goveranance`: Most trusted role. Either goveranance contract or multisig. They can rug with upgradeStrat() however it is timelocked. 
- `strategist`: developer role granted the permission to pause the strategy. Users can always withdraw from a paused strategy
- `management`: another developer role granted the permission to modify the TVL cap and permit new reward tokens for the reward distributor to swap. Both low-risk functions.
- `keeper`: the keeper role can harvest the RedirectVault once an epoch is complete. 


## Getting Started

Run tests
`yarn test`
