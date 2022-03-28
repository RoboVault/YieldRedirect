import pytest
from brownie import interface
from brownie import reverts

def test_migrate(StrategyLiquidDriver, Strategy0xDAO, vault, strategy, distributor, chain, accounts, gov, token, user1, user2, strategist, amount, conf):

    targetToken = interface.IERC20Extended(distributor.tokenOut())
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
    chain.sleep(distributor.timePerEpoch())
    chain.mine(1)


    vault.harvest({"from": gov})

    pendingRewards = distributor.getUserRewards(user1)
    print("Pending Rewards")
    print(pendingRewards)
    distributor.harvest({"from": user1})

    assert distributor.getUserRewards(user1) == 0 
    assert (targetToken.balanceOf(user1) - target_token_before) == pendingRewards

    # ensure all earned tokens were paid out
    assert distributor.targetBalance() == 0 

    with reverts() : 
        distributor.harvest({"from": user1})

    if conf['farmAddress'] == '0XDAO' :
        newStrat = Strategy0xDAO.deploy(vault, token.address, {"from": gov})
    else : 
        newStrat = StrategyLiquidDriver.deploy(vault, token.address, pid, {"from": gov})


    vault.proposeStrat(newStrat, {"from": gov})
    chain.sleep(1)
    chain.mine(1)
    vault.upgradeStrat({"from": gov})

    chain.sleep(distributor.timePerEpoch())
    chain.mine(1)
    vault.harvest({"from": gov})
    pendingRewards = distributor.getUserRewards(user1)
    print("Pending Rewards")
    print(pendingRewards)
    target_token_before = targetToken.balanceOf(user1)

    distributor.harvest({"from": user1})

    assert distributor.getUserRewards(user1) == 0 
    assert (targetToken.balanceOf(user1) - target_token_before) == pendingRewards

    # ensure all earned tokens were paid out
    assert distributor.targetBalance() == 0 

    vault.withdraw(amount, {"from": user1})
    assert token.balanceOf(user1) == user_balance_before
