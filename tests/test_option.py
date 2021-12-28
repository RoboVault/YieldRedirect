#!/usr/bin/python3

import pytest
from brownie import interface


def test_option(accounts, saleContract, optionFactory, optionVaultSimple):
    ohm = interface.ERC20('0x383518188C0C6d7730D91b2c03a03C837814a899')
    dai = interface.ERC20('0x6B175474E89094C44Da98b954EedeAC495271d0F')

    lp = '0x34d7d7Aaf50AD4944B70B320aCB24C95fa2def7c'

    bondPrice = 90429
    decimalAdj = 10000000 

    daiWhale = '0xC2C5A77d9f434F424Df3d39de9e90d95A0Df5Aca'
    ohmWhale = '0xFd31c7d00Ca47653c6Ce64Af53c1571f9C36566a'

    underwriter = accounts[0] #this would be OHM treasury which would allocate % of treasury to put options
    optionHolder = accounts[1]

    putDiscount = 0.9 #how much holder of option can sell OHM for vs bond price 
    premium = 0.01 #cost to insure 1 OHM for X % of bond price 

    sales = saleContract.deploy(250, {"from": underwriter})
    optFactory = optionFactory.deploy(sales, {"from": underwriter})

    ohmInsured = 1000000

    collatAmt = int(ohmInsured*bondPrice*decimalAdj*putDiscount)
    optionSalePrice = collatAmt*premium
    minExcercise = 10000

    dai.transfer(underwriter, collatAmt, {'from' : daiWhale})
    dai.transfer(optionHolder, optionSalePrice, {'from' : daiWhale})
    ohm.transfer(optionHolder, ohmInsured, {'from' : ohmWhale})

    dai.approve(sales.address, optionSalePrice , {"from": optionHolder})
    dai.approve(optFactory.address, collatAmt, {"from": underwriter})


    saleTime = 345600
    expirytime = 2592000
    timeBeforeDeadline = 2591999

    # create the option
    optFactory.createOption(dai, ohm, collatAmt, ohmInsured, minExcercise, optionSalePrice, saleTime, expirytime, timeBeforeDeadline, {"from": underwriter})
    optAddress = optFactory.getOptionsAddress(1)
    optVault = optionVaultSimple.at(optAddress)

    # Deposit option collateral to a yearn vault
    yvDAI = '0xdA816459F1AB5631232FE5e97a05BBBb94970c95'
    optVault.setVaultUsage(yvDAI, True, {"from": underwriter})
    optVault.depositToVault({"from": underwriter})

    # Execute the option
    optionsPurchased = ohmInsured / 10
    sales.purchaseTokens(1, optionsPurchased,{"from": optionHolder})
    assert dai.balanceOf(optionHolder) == optionSalePrice * putDiscount
