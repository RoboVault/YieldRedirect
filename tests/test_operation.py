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

    vault.withdraw(amount, {"from": user1})

    assert token.balanceOf(user1) == user_balance_before


def test_operation_emergency_withdraw(vault, strategy, distributor, chain, accounts, gov, token, user1, user2, strategist, amount, conf):

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

    vault.emergencyWithdrawAll({"from": user1})
    assert distributor.getUserRewards(user1) == 0 
    assert (targetToken.balanceOf(user1) - target_token_before) == 0


    with reverts() : 
        distributor.harvest({"from": user1})


    assert token.balanceOf(user1) == user_balance_before


def test_operation_sweep_emergency_withdraw(vault, strategy, distributor, chain, accounts, gov, token, user1, user2, strategist, amount, conf):

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

    govBalBefore = targetToken.balanceOf(gov)
    distributor.emergencySweep(targetToken, gov , {"from": gov})
    assert(govBalBefore +  pendingRewards) == targetToken.balanceOf(gov)

    vault.emergencyWithdrawAll({"from": user1})
    assert distributor.getUserRewards(user1) == 0 
    assert (targetToken.balanceOf(user1) - target_token_before) == 0
    assert token.balanceOf(user1) == user_balance_before


def test_operation_disable_vault(vault, strategy, distributor, chain, accounts, gov, token, user1, user2, strategist, amount, conf):

    targetToken = interface.IERC20Extended(conf['targetToken'])
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

    distributor.emergencyDisableVault({"from": gov})
    targetToken = interface.IERC20Extended(distributor.tokenOut())
    assert distributor.tokenOut() == conf['targetToken']

    pendingRewards = distributor.getUserRewards(user1)
    print("Pending Rewards")
    print(pendingRewards)
    target_token_before = targetToken.balanceOf(user1)
    distributor.harvest({"from": user1})

    assert distributor.getUserRewards(user1) == 0 
    assert (targetToken.balanceOf(user1) - target_token_before) == pendingRewards

    # ensure all earned tokens were paid out
    assert distributor.targetBalance() == 0 

    with reverts() : 
        distributor.harvest({"from": user1})

    vault.withdraw(amount, {"from": user1})

    assert token.balanceOf(user1) == user_balance_before


def test_multiple_deposits(chain, strategy, distributor, gov, token, vault, user1, user2 ,strategist, amount, conf):

    targetToken = interface.IERC20Extended(distributor.tokenOut())
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
    assert targetToken.balanceOf(user1) == pendingRewards
    with reverts(): 
        distributor.harvest({"from": user1})

    chain.sleep(distributor.timePerEpoch())
    chain.mine(1)

    vault.harvest({"from": gov})
    user1Rewards = distributor.getUserRewards(user1)
    user2Rewards = distributor.getUserRewards(user2)
    # The sum of user rewards should match the balance of the rewards dist
    assert pytest.approx(user1Rewards + user2Rewards, rel=2e-3) == distributor.targetBalance()
    pendingRewards = distributor.getUserRewards(user2)
    distributor.harvest({"from": user2})
    assert targetToken.balanceOf(user2) == pendingRewards


def test_operation_multiple_users(chain, strategy, distributor, gov, token, vault, user1, user2 ,strategist, amount, conf):

    targetToken = interface.IERC20Extended(distributor.tokenOut())
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

    assert distributor.getUserRewards(user1) == distributor.targetBalance()
    assert distributor.getUserRewards(user2) == 0

    vault.harvest({"from": gov})

    chain.sleep(distributor.timePerEpoch())
    chain.mine(1)

    vault.harvest({"from": gov})
    
    # there will be some dust here so use pytest.approx
    assert pytest.approx(distributor.getUserRewards(user1) + distributor.getUserRewards(user2), rel = 2e-3) == distributor.targetBalance()

    distributor.harvest({"from": user1})
    distributor.harvest({"from": user2})

    assert (distributor.getUserRewards(user1) + distributor.getUserRewards(user2)) == 0

    with reverts() : 
        distributor.harvest({"from": user1})

    vault.withdraw(amount, {"from": user1})
    vault.withdraw(amount, {"from": user2})
    assert token.balanceOf(user1) == user_balance_before
    assert token.balanceOf(user2) == user_balance_before2

def test_operation_multiple_users_emergency_withdraw(chain, strategy, distributor, gov, token, vault, user1, user2 ,strategist, amount, conf):

    targetToken = interface.IERC20Extended(distributor.tokenOut())
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

    assert distributor.getUserRewards(user1) == distributor.targetBalance()
    assert distributor.getUserRewards(user2) == 0

    vault.harvest({"from": gov})

    chain.sleep(distributor.timePerEpoch())
    chain.mine(1)

    vault.harvest({"from": gov})
    
    # there will be some dust here so use pytest.approx
    assert pytest.approx(distributor.getUserRewards(user1) + distributor.getUserRewards(user2), rel = 1e-5) == distributor.targetBalance()

    distributor.emergencyDisableVault({"from": gov})
    targetToken = interface.IERC20Extended(distributor.tokenOut())
    assert distributor.tokenOut() == conf['targetToken']


    assert pytest.approx(distributor.getUserRewards(user1) + distributor.getUserRewards(user2), rel = 1e-5) == distributor.targetBalance()

    user1TaretBefore = targetToken.balanceOf(user1)
    user2TaretBefore = targetToken.balanceOf(user2)

    pendingUser1 = distributor.getUserRewards(user1)
    pendingUser2 = distributor.getUserRewards(user2)

    distributor.harvest({"from": user1})
    distributor.harvest({"from": user2})

    assert (distributor.getUserRewards(user1) + distributor.getUserRewards(user2)) == 0
    assert (user1TaretBefore + pendingUser1) == targetToken.balanceOf(user1)
    assert (user2TaretBefore + pendingUser2) == targetToken.balanceOf(user2)

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

    distributor.setParamaters(5000, 200, 0, {"from": gov})
    with reverts() : 
        distributor.setParamaters(5000, 200, 0, {"from": user1})

    highProfitFee = 2001
    # should fail if gov tries to set profit fee too high
    with reverts() : 
        distributor.setParamaters(5000, highProfitFee, 0, {"from": gov})


    distributor.setEpochDuration(5000, {"from": gov})
    with reverts() : 
        distributor.setEpochDuration(5000, {"from": user1})

    highEpochDuration = 2592000000
    # should fail if gov tries to set Epoch Duration too high
    with reverts() : 
        distributor.setEpochDuration(highEpochDuration, {"from": user1})

    """
    vault.deactivate({"from": gov})

    # after deactivating funds should be removed from farm 
    assert token.balanceOf(distributor) == amount
    assert vault.balance() ==  amount
    vault.withdraw(amount, {"from": user1})
    assert token.balanceOf(user1) == user_balance_before
    """
