#!/usr/bin/python3

import pytest
from brownie import interface
from brownie import reverts


def testFarmContainerLQDRVault(accounts, yieldRedirectFarm, chain):
    wftm = interface.ERC20('0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83')
    lp = interface.ERC20('0x4Fe6f19031239F105F753D1DF8A0d24857D0cAA2')
    farmToken = interface.ERC20('0x10b620b2dbac4faa7d7ffd71da486f5d44cd86f9')
    farmTokenWhale = '0x3Ae658656d1C526144db371FaEf2Fff7170654eE'
    router =  '0x16327E3FbDaCA3bcF7E38F5Af2599D2DDc33aE52'
    masterChef = '0x6e2ad6527901c9664f016466b8DA1357a004db0f'
    pid = 0
    farmType = 2

    lpWhale = '0x717BDE1AA46a0Fcd937af339f95361331412C74C'

    usdc = interface.ERC20('0x04068DA6C83AFCFA0e13ba15A6696662335D5B75')
    yvUSDC = interface.ERC20('0xEF0210eB96c7EB36AF8ed1c20306462764935607')

    gohm = interface.ERC20('0x91fa20244Fb509e8289CA630E5db3E9166233FDc')

    swapAsset = usdc
    rewaredAsset = yvUSDC


    owner = accounts[0]
    container = yieldRedirectFarm.deploy(lp, rewaredAsset, swapAsset, masterChef, farmToken , router , wftm , pid , farmType , {"from": owner})


    depositor = accounts[1] 
    depositor1 = accounts[2] 
    user = accounts[3] 

    depositAmt = 500*(10**18)
    lp.transfer(depositor, depositAmt, {'from' : lpWhale})
    lp.transfer(depositor1, depositAmt, {'from' : lpWhale})

    lp.approve(container.address, depositAmt , {"from": depositor})

    container.deposit(depositAmt, {"from": depositor} )
    assert container.estimatedTotalAssets() == depositAmt
    assert container.balanceOf(depositor) == depositAmt

    # should fail as user has insufficient balance 
    lp.approve(container.address, depositAmt , {"from": user})
    with reverts():
        container.deposit(depositAmt, {"from": user} )
        
    # user should not have permission to call this 
    with reverts():
        container.convertProfits({"from": user})
        
    #farmTokenProfit = 10*(10**18)

    chain.sleep(10)

    #farmToken.transfer(container, farmTokenProfit, {"from": farmTokenWhale} )
    container.convertProfits({"from": owner})

    chain.sleep(10000)

    #boo.transfer(container.address, booTransfer, {"from": booWhale})

    lp.approve(container.address, depositAmt , {"from": depositor1})
    container.deposit(depositAmt, {"from": depositor1} )
    container.getUserRewards(depositor1)


    with reverts() : 
        container.withdraw(depositAmt, {"from": user})

    container.convertProfits({"from": owner})

    chain.sleep(10000)

    container.convertProfits({"from": owner})

    chain.sleep(10000)

    container.convertProfits({"from": owner})

    accumulatedReturns = rewaredAsset.balanceOf(container)
    # due to rounding will likely be some dust in user returns 
    assert pytest.approx(accumulatedReturns, rel=1e-3) == (container.getUserRewards(depositor) + container.getUserRewards(depositor1))

    preHarvestbal = rewaredAsset.balanceOf(depositor)
    pendingRewards = container.getUserRewards(depositor)
    print("Pending Rewards")
    print(pendingRewards)
    preWithdrawAssets = container.estimatedTotalAssets()
    container.harvest({"from": depositor})
    assert rewaredAsset.balanceOf(depositor) == (preHarvestbal + pendingRewards)
    with reverts() : 
        container.harvest({"from": depositor})

    container.withdraw(depositAmt, {"from": depositor})

    # make sure after harvesting then withdrawing no extra rewards are disbursed
    assert rewaredAsset.balanceOf(depositor) == (preHarvestbal + pendingRewards)

    assert lp.balanceOf(depositor) == depositAmt
    with reverts() : 
        container.withdraw(depositAmt, {"from": depositor})

    assert container.estimatedTotalAssets() == (preWithdrawAssets - depositAmt)
    assert container.getUserRewards(depositor) == 0 
 
    chain.sleep(10000)
    container.convertProfits({"from": owner})

    #uses should no longer be receiving rewards after withdrawing 
    assert container.getUserRewards(depositor) == 0 
