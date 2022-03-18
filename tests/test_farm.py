import pytest
from brownie import interface
from brownie import reverts

def test_deposit_withdraw(chain, strategy, distributor, gov, token, yieldRedirect, user1, user2, strategist, amount, conf):

    user_balance_before = token.balanceOf(user1)
    token.approve(yieldRedirect.address, amount, {"from": user1})
    yieldRedirect.deposit(amount, {"from": user1})
    assert token.balanceOf(user1) == user_balance_before - amount 
    assert yieldRedirect.estimatedTotalAssets() ==  amount

    
    with reverts() : 
        yieldRedirect.withdraw(amount, {"from": user2})


    yieldRedirect.withdraw(amount, {"from": user1})

    assert token.balanceOf(user1) == user_balance_before

    with reverts() : 
        yieldRedirect.withdraw(amount, {"from": user1})


def test_operation_harvest(chain, strategy, distributor, gov, token, yieldRedirect, user1, user2, strategist, amount, conf):

    rewardToken = interface.IERC20Extended(conf['targetToken'])
    user_balance_before = token.balanceOf(user1)
    token.approve(yieldRedirect.address, amount, {"from": user1})
    yieldRedirect.deposit(amount, {"from": user1})
    assert token.balanceOf(user1) == user_balance_before - amount 
    assert yieldRedirect.estimatedTotalAssets() ==  amount

    chain.sleep(10)
    chain.mine(1)

    yieldRedirect.convertProfits({"from": gov})

    chain.sleep(distributor.timePerEpoch())
    chain.mine(1)


    yieldRedirect.convertProfits({"from": gov})

    pendingRewards = yieldRedirect.getUserRewards(user1)
    print("Pending Rewards")
    print(pendingRewards)
    yieldRedirect.harvest({"from": user1})

    assert yieldRedirect.getUserRewards(user1) == 0 
    assert rewardToken.balanceOf(user1) == pendingRewards
    with reverts() : 
        yieldRedirect.harvest({"from": user1})

    yieldRedirect.withdraw(amount, {"from": user1})

    assert token.balanceOf(user1) == user_balance_before

def test_operation_withdraw(chain, strategy, distributor, gov, token, yieldRedirect, user1, user2, strategist, amount, conf):

    rewardToken = interface.IERC20Extended(conf['targetToken'])
    user_balance_before = token.balanceOf(user1)
    token.approve(yieldRedirect.address, amount, {"from": user1})
    yieldRedirect.deposit(amount, {"from": user1})
    assert token.balanceOf(user1) == user_balance_before - amount 
    assert yieldRedirect.estimatedTotalAssets() ==  amount

    chain.sleep(10)
    chain.mine(1)

    yieldRedirect.convertProfits({"from": gov})

    chain.sleep(distributor.timePerEpoch())
    chain.mine(1)


    yieldRedirect.convertProfits({"from": gov})

    pendingRewards = yieldRedirect.getUserRewards(user1)
    print("Pending Rewards")
    print(pendingRewards)

def test_multiple_deposits(chain, accounts, gov, token, yieldRedirect, user1, user2, strategist, amount, conf):

    rewardToken = interface.IERC20Extended(conf['targetToken'])
    user_balance_before = token.balanceOf(user1)
    depositAmt = int(amount / 3)
    token.approve(yieldRedirect.address, amount, {"from": user1})
    token.approve(yieldRedirect.address, amount, {"from": user2})

    yieldRedirect.deposit(depositAmt, {"from": user1})
    yieldRedirect.deposit(depositAmt, {"from": user2})

    chain.sleep(10)
    chain.mine(1)

    yieldRedirect.convertProfits({"from": gov})

    chain.sleep(distributor.timePerEpoch())
    chain.mine(1)
    yieldRedirect.convertProfits({"from": gov})

    pendingRewards = yieldRedirect.getUserRewards(user1)
    print("Pending Rewards")
    print(pendingRewards)
    yieldRedirect.deposit(depositAmt, {"from": user1})

    # when user deposits should harvest for them 
    assert yieldRedirect.getUserRewards(user1) == 0 
    assert rewardToken.balanceOf(user1) == pendingRewards
    with reverts() : 
        yieldRedirect.harvest({"from": user1})

    chain.sleep(distributor.timePerEpoch())
    chain.mine(1)
    yieldRedirect.convertProfits({"from": gov})
    assert yieldRedirect.getUserRewards(user1) == 0 
    assert pytest.approx(yieldRedirect.getUserRewards(user2), rel = 2e-3) == rewardToken.balanceOf(yieldRedirect)
    pendingRewards = yieldRedirect.getUserRewards(user2)
    yieldRedirect.harvest({"from": user2})
    assert rewardToken.balanceOf(user2) == pendingRewards


def test_operation_multiple_users(chain, strategy, distributor, gov, token, yieldRedirect, user1, user2, strategist, amount, conf):

    rewardToken = interface.IERC20Extended(conf['targetToken'])
    user_balance_before = token.balanceOf(user1)
    user_balance_before2 = token.balanceOf(user2)

    token.approve(yieldRedirect.address, amount, {"from": user1})
    yieldRedirect.deposit(amount, {"from": user1})
    assert token.balanceOf(user1) == user_balance_before - amount 
    assert yieldRedirect.estimatedTotalAssets() ==  amount

    chain.sleep(10)
    chain.mine(1)
    with reverts() : 
        yieldRedirect.convertProfits({"from": user1})
    yieldRedirect.convertProfits({"from": gov})

    token.approve(yieldRedirect.address, amount, {"from": user2})
    yieldRedirect.deposit(amount, {"from": user2})

    chain.sleep(distributor.timePerEpoch())
    chain.mine(1)

    assert yieldRedirect.getUserRewards(user1) == rewardToken.balanceOf(yieldRedirect)
    assert yieldRedirect.getUserRewards(user2) == 0

    yieldRedirect.convertProfits({"from": gov})

    chain.sleep(distributor.timePerEpoch())
    chain.mine(1)

    yieldRedirect.convertProfits({"from": gov})
    
    # there will be some dust here so use pytest.approx
    assert pytest.approx(yieldRedirect.getUserRewards(user1) + yieldRedirect.getUserRewards(user2), rel = 2e-3) == rewardToken.balanceOf(yieldRedirect)

    yieldRedirect.harvest({"from": user1})
    yieldRedirect.harvest({"from": user2})

    assert (yieldRedirect.getUserRewards(user1) + yieldRedirect.getUserRewards(user2)) == 0

    with reverts() : 
        yieldRedirect.harvest({"from": user1})

    yieldRedirect.withdraw(amount, {"from": user1})
    yieldRedirect.withdraw(amount, {"from": user2})
    assert token.balanceOf(user1) == user_balance_before
    assert token.balanceOf(user2) == user_balance_before2

def test_authorization(chain, strategy, distributor, gov, token, yieldRedirect, user1, user2, strategist, amount, conf):

    user_balance_before = token.balanceOf(user1)
    token.approve(yieldRedirect.address, amount, {"from": user1})
    yieldRedirect.deposit(amount, {"from": user1})
    assert token.balanceOf(user1) == user_balance_before - amount 

    yieldRedirect.setParamaters(5000, 200, 0, {"from": gov})
    with reverts() : 
        yieldRedirect.setParamaters(5000, 200, 0, {"from": user1})

    highProfitFee = 2001
    # should fail if gov tries to set profit fee too high
    with reverts() : 
        yieldRedirect.setParamaters(5000, highProfitFee, 0, {"from": gov})


    yieldRedirect.setEpochDuration(5000, {"from": gov})
    with reverts() : 
        yieldRedirect.setEpochDuration(5000, {"from": user1})

    highEpochDuration = 2592000000
    # should fail if gov tries to set Epoch Duration too high
    with reverts() : 
        yieldRedirect.setEpochDuration(highEpochDuration, {"from": gov})

    with reverts() : 
        yieldRedirect.deactivate({"from": user1})
    
    yieldRedirect.deactivate({"from": gov})

    # after deactivating funds should be removed from farm 
    assert token.balanceOf(yieldRedirect) == amount
    assert yieldRedirect.estimatedTotalAssets() ==  amount
    yieldRedirect.withdraw(amount, {"from": user1})
    assert token.balanceOf(user1) == user_balance_before

