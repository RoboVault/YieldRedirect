import pytest
from brownie import interface
from brownie import reverts

def test_migrate(StrategyLiquidDriver, Strategy0xDAO, StrategyBeethoven, vault, strategy, distributor, chain, accounts, gov, token, user1, user2, strategist, amount, conf):

    targetToken = interface.IERC20Extended(distributor.tokenOut())
    tokenRec = interface.IERC20Extended(distributor.targetToken())

    target_token_before = targetToken.balanceOf(user1)
    user_balance_before = token.balanceOf(user1)
    token.approve(vault.address, amount, {"from": user1})
    vault.deposit(amount, {"from": user1})
    assert token.balanceOf(user1) == user_balance_before - amount 
    assert vault.balance() ==  amount

    chain.sleep(10)
    chain.mine(1)

    vault.harvest({"from": gov})

    # chain.sleep(10000)
    chain.sleep(distributor.timePerEpoch() + 10)
    chain.mine(5)


    vault.harvest({"from": gov})

    pendingRewards = distributor.getUserRewardsTarget(user1)
    print("Pending Rewards")
    print(pendingRewards)
    distributor.harvest({"from": user1})

    assert distributor.getUserRewardsTarget(user1) == 0 
    assert pytest.approx((tokenRec.balanceOf(user1) - target_token_before), rel = 1e-3) == pendingRewards

    # ensure all earned tokens were paid out
    assert distributor.targetBalance() == 0 

    with reverts() : 
        distributor.harvest({"from": user1})

    lqdrMasterChef = '0x6e2ad6527901c9664f016466b8DA1357a004db0f'
    beetsMasterChef = '0x8166994d9ebBe5829EC86Bd81258149B87faCfd3'


    if conf['farmAddress'] == '0XDAO' :
        newStrat = Strategy0xDAO.deploy(vault, token.address, {"from": gov})
    if conf['farmAddress'] == lqdrMasterChef:
        newStrat = StrategyLiquidDriver.deploy(vault, token.address, conf['pid'], {"from": gov})
    if conf['farmAddress'] == beetsMasterChef:
        newStrat = StrategyBeethoven.deploy(vault, token.address, conf['pid'], {"from": gov})


    vault.proposeStrat(newStrat, {"from": gov})
    chain.sleep(1)
    chain.mine(1)
    vault.upgradeStrat({"from": gov})

    chain.sleep(distributor.timePerEpoch())
    chain.mine(1)
    vault.harvest({"from": gov})
    pendingRewards = distributor.getUserRewardsTarget(user1)
    print("Pending Rewards")
    print(pendingRewards)
    target_token_before = tokenRec.balanceOf(user1)

    distributor.harvest({"from": user1})

    assert distributor.getUserRewardsTarget(user1) == 0 
    assert pytest.approx((tokenRec.balanceOf(user1) - target_token_before), rel = 1e-3) == pendingRewards

    # ensure all earned tokens were paid out
    assert distributor.targetBalance() == 0 

    vault.withdraw(amount, {"from": user1})
    assert token.balanceOf(user1) == user_balance_before
