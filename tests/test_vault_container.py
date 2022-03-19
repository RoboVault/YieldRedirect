#!/usr/bin/python3

import pytest
from brownie import interface
from brownie import reverts

# TODO - update this tests
def test_vault_container(accounts, vault, chain, wftm):
    usdc = interface.ERC20('0x04068DA6C83AFCFA0e13ba15A6696662335D5B75')

    yvFTM = interface.ERC20('0x0DEC85e74A92c52b7F708c4B10207D9560CEFaf0')
    yvUSDC = interface.ERC20('0xEF0210eB96c7EB36AF8ed1c20306462764935607')

    wftmWhale = '0x51D493C9788F4b6F87EAe50F555DD671c4Cf653E'

    owner = accounts[3]
    depositor = accounts[0] #this would be user that wants to redirect yield from YVDAI to buying OHM
    depositor1 = accounts[1] #this would be user that wants to redirect yield from YVDAI to buying OHM
    user = accounts[2] #this would be user that wants to redirect yield from YVDAI to buying OHM

    router = '0xF491e7B69E4244ad4002BC14e878a34207E38c29'
    container = vault.deploy(wftm, yvUSDC, usdc, yvFTM, router , wftm ,{"from": owner})


    depositAmt = 10000*(10**18)
    wftm.transfer(depositor, depositAmt, {'from' : wftmWhale})
    wftm.transfer(depositor1, depositAmt, {'from' : wftmWhale})

    wftm.approve(container.address, depositAmt , {"from": depositor})

    container.deposit(depositAmt, {"from": depositor} )
    # check strat can't be deployed 
    with reverts():
        container.deployStrat({"from": user} )

    container.deployStrat({"from": owner})
    assert pytest.approx(container.estimatedTotalAssets(), rel = 1e-3) == depositAmt

    chain.sleep(10)

    container.convertProfits({"from": owner})

    chain.sleep(10)

    wftm.transfer(container.address, depositAmt*.01, {"from": wftmWhale})

    wftm.approve(container.address, depositAmt , {"from": depositor1})
    container.deposit(depositAmt, {"from": depositor1} )
    
    container.getUserRewards(depositor1)

    container.convertProfits({"from": owner})

    preClaimBalance = yvUSDC.balanceOf(depositor)
    pendingRewards = container.getUserRewards(depositor)
    container.harvest({"from": depositor})
    assert yvUSDC.balanceOf(depositor) == pendingRewards + preClaimBalance
    container.withdraw(depositAmt, {"from": depositor})
    assert pytest.approx(wftm.balanceOf(depositor)) == depositAmt
    with reverts():
        container.withdraw(depositAmt, {"from": depositor})
        