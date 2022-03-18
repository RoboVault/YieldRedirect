import pytest
from brownie import interface
from brownie import reverts

def test_deposit_withdraw(vault, strategy, token, amount, user1, user2):

    user_balance_before = token.balanceOf(user1)
    token.approve(vault.address, amount, {"from": user1})
    vault.deposit(amount, {"from": user1})

    assert token.balanceOf(user1) == user_balance_before - amount 
    assert vault.balance() ==  amount

    with reverts() : 
        vault.withdraw(amount, {"from": user2})

    vault.withdraw(amount, {"from": user1})

    assert token.balanceOf(user1) == user_balance_before

    with reverts() : 
        vault.withdraw(amount, {"from": user1})


def test_operation_harvest(vault, strategy, distributor, chain, accounts, gov, token, user1, user2, strategist, amount, conf):

    rewardToken = interface.IERC20Extended(conf['targetToken'])
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
    assert rewardToken.balanceOf(user1) == pendingRewards
    with reverts() : 
        distributor.harvest({"from": user1})

    vault.withdraw(amount, {"from": user1})

    assert token.balanceOf(user1) == user_balance_before

def test_operation_withdraw(chain, strategy, distributor, gov, token, vault, user1, user2 ,strategist, amount, conf):

    user_balance_before = token.balanceOf(user1)
    token.approve(vault.address, amount, {"from": user1})
    vault.deposit(amount, {"from": user1})

    assert token.balanceOf(user1) == user_balance_before - amount 
    assert vault.balance() ==  amount

    chain.sleep(10)
    chain.mine(1)

    vault.harvest({"from": gov})

    chain.sleep(distributor.timePerEpoch())
    chain.mine(1)


    vault.harvest({"from": gov})

    pendingRewards = distributor.getUserRewards(user1)
    print("Pending Rewards")
    print(pendingRewards)

def test_multiple_deposits(chain, strategy, distributor, gov, token, vault, user1, user2 ,strategist, amount, conf):

    rewardToken = interface.IERC20Extended(conf['targetToken'])
    user_balance_before = token.balanceOf(user1)
    depositAmt = int(amount / 3)
    token.approve(vault.address, amount, {"from": user1})
    token.approve(vault.address, amount, {"from": user2})

    vault.deposit(depositAmt, {"from": user1})
    vault.deposit(depositAmt, {"from": user2})

    chain.sleep(10)
    chain.mine(1)

    vault.harvest({"from": gov})

    chain.sleep(distributor.timePerEpoch())
    chain.mine(1)
    vault.harvest({"from": gov})

    pendingRewards = distributor.getUserRewards(user1)
    print("Pending Rewards: {}".format(pendingRewards))
    vault.deposit(depositAmt, {"from": user1})

    # when user deposits should harvest for them 
    assert distributor.getUserRewards(user1) == 0 
    assert rewardToken.balanceOf(user1) == pendingRewards
    with reverts() : 
        distributor.harvest({"from": user1})

    chain.sleep(distributor.timePerEpoch())
    chain.mine(1)
    vault.harvest({"from": gov})
    assert distributor.getUserRewards(user1) == 0 
    assert pytest.approx(distributor.getUserRewards(user2), rel = 2e-3) == rewardToken.balanceOf(distributor)
    pendingRewards = distributor.getUserRewards(user2)
    vault.harvest({"from": user2})
    assert rewardToken.balanceOf(user2) == pendingRewards


def test_operation_multiple_users(chain, strategy, distributor, gov, token, vault, user1, user2 ,strategist, amount, conf):

    rewardToken = interface.IERC20Extended(conf['targetToken'])
    user_balance_before = token.balanceOf(user1)
    user_balance_before2 = token.balanceOf(user2)

    token.approve(vault.address, amount, {"from": user1})
    vault.deposit(amount, {"from": user1})
    assert token.balanceOf(user1) == user_balance_before - amount 
    assert vault.balance() ==  amount

    chain.sleep(10)
    chain.mine(1)
    with reverts() : 
        distributor.harvest({"from": user1})
    vault.harvest({"from": gov})

    token.approve(vault.address, amount, {"from": user2})
    vault.deposit(amount, {"from": user2})

    chain.sleep(distributor.timePerEpoch())
    chain.mine(1)

    assert distributor.getUserRewards(user1) == rewardToken.balanceOf(vault)
    assert distributor.getUserRewards(user2) == 0

    vault.harvest({"from": gov})

    chain.sleep(distributor.timePerEpoch())
    chain.mine(1)

    vault.harvest({"from": gov})
    
    # there will be some dust here so use pytest.approx
    assert pytest.approx(distributor.getUserRewards(user1) + distributor.getUserRewards(user2), rel = 2e-3) == rewardToken.balanceOf(vault)

    distributor.harvest({"from": user1})
    vault.harvest({"from": user2})

    assert (distributor.getUserRewards(user1) + distributor.getUserRewards(user2)) == 0

    with reverts() : 
        distributor.harvest({"from": user1})

    vault.withdraw(amount, {"from": user1})
    vault.withdraw(amount, {"from": user2})
    assert token.balanceOf(user1) == user_balance_before
    assert token.balanceOf(user2) == user_balance_before2

def test_authorization(chain, strategy, distributor, gov, token, vault, user1, user2,strategist, amount, conf):

    user_balance_before = token.balanceOf(user1)
    token.approve(vault.address, amount, {"from": user1})
    vault.deposit(amount, {"from": user1})
    assert token.balanceOf(user1) == user_balance_before - amount 

    vault.setParamaters(5000, 200, 0, {"from": gov})
    with reverts() : 
        vault.setParamaters(5000, 200, 0, {"from": user1})

    highProfitFee = 2000
    # should fail if gov tries to set profit fee too high
    with reverts() : 
        vault.setParamaters(5000, highProfitFee, 0, {"from": gov})


    vault.setEpochDuration(5000, {"from": gov})
    with reverts() : 
        vault.setEpochDuration(5000, {"from": user1})

    highEpochDuration = 2592000000
    # should fail if gov tries to set Epoch Duration too high
    with reverts() : 
        vault.setEpochDuration(highEpochDuration, {"from": gov})

    with reverts() : 
        vault.deactivate({"from": user1})
    
    vault.deactivate({"from": gov})

    # after deactivating funds should be removed from farm 
    assert token.balanceOf(vault) == amount
    assert vault.balance() ==  amount
    vault.withdraw(amount, {"from": user1})
    assert token.balanceOf(user1) == user_balance_before

