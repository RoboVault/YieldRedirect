import pytest
from brownie import interface
from brownie import reverts

def test_transfer_not_supported(vault, strategy, token, amount, user1, user2):

    user_balance_before = token.balanceOf(user1)
    token.approve(vault.address, amount, {"from": user1})
    vault.deposit(amount, {"from": user1})

    assert token.balanceOf(user1) == user_balance_before - amount 
    assert vault.totalBalance() ==  amount

    with reverts():
        vault.transfer(user2, vault.balanceOf(user1), {'from': user1})
    
    vault.approve(user2, vault.balanceOf(user1), {'from': user1})
    with reverts():
        vault.transferFrom(user1, user2, vault.balanceOf(user1), {'from':user2})

    with reverts(): 
        vault.withdraw(amount, {"from": user2})

    vault.withdraw(amount, {"from": user1})

    assert token.balanceOf(user1) == user_balance_before

    with reverts(): 
        vault.withdraw(amount, {"from": user1})