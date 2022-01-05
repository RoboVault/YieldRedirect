#!/usr/bin/python3

import pytest
from brownie import interface
from brownie import reverts


def testFarmContainer(accounts, yieldRedirectFarm, chain):
    wftm = interface.ERC20('0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83')
    booLP = interface.ERC20('0xEc7178F4C41f346b2721907F5cF7628E388A7a58')
    boo = interface.ERC20('0x841FAD6EAe12c286d1Fd18d1d525DFfA75C7EFFE')
    spookyRouter =  '0xF491e7B69E4244ad4002BC14e878a34207E38c29'
    spookyMasterChef = '0x2b2929E785374c651a81A63878Ab22742656DcDd'
    booPid = 0

    booLPWhale = '0x2b2929E785374c651a81A63878Ab22742656DcDd'
    booWhale = '0x2b2929E785374c651a81A63878Ab22742656DcDd'


    usdc = interface.ERC20('0x04068DA6C83AFCFA0e13ba15A6696662335D5B75')
    yvUSDC = interface.ERC20('0xEF0210eB96c7EB36AF8ed1c20306462764935607')

    container = yieldRedirectFarm.deploy(booLP, yvUSDC, usdc, spookyMasterChef, boo , spookyRouter , wftm , booPid , 0 , {"from": accounts[0]})

    wftmWhale = '0x51D493C9788F4b6F87EAe50F555DD671c4Cf653E'

    depositor = accounts[1] 
    depositor1 = accounts[2] 
    user = accounts[3] 

    lpTransfer = 5000*(10**18)
    booTransfer = 500*(10**18)
    booLP.transfer(depositor, lpTransfer, {'from' : booLPWhale})
    booLP.transfer(depositor1, lpTransfer, {'from' : booLPWhale})

    booLP.approve(container.address, lpTransfer , {"from": depositor})

    container.deposit(lpTransfer, {"from": depositor} )
    assert container.estimatedTotalAssets() == lpTransfer

    # should fail as user has insufficient balance 
    booLP.approve(container.address, lpTransfer , {"from": user})
    with reverts():
        container.deposit(lpTransfer, {"from": user} )
        

    chain.sleep(10)

    container.convertProfits({"from": depositor})

    chain.sleep(10000)

    #boo.transfer(container.address, booTransfer, {"from": booWhale})

    booLP.approve(container.address, lpTransfer , {"from": depositor1})
    container.deposit(lpTransfer, {"from": depositor1} )
    container.getUserRewards(depositor1)

    container.convertProfits({"from": depositor})

    chain.sleep(10000)

    container.convertProfits({"from": depositor})

    chain.sleep(10000)

    container.convertProfits({"from": depositor})

    preHarvestbal = yvUSDC.balanceOf(depositor)
    pendingRewards = container.getUserRewards(depositor)
    preWithdrawAssets = container.estimatedTotalAssets()
    container.claimRewards({"from": depositor})
    assert yvUSDC.balanceOf(depositor) == (preHarvestbal + pendingRewards)
    container.withdraw(lpTransfer, {"from": depositor})
    assert booLP.balanceOf(depositor) == lpTransfer
    with reverts() : 
        container.withdraw(lpTransfer, {"from": depositor})

    assert container.estimatedTotalAssets() == (preWithdrawAssets - lpTransfer)
    assert container.getUserRewards(depositor) == 0 
 