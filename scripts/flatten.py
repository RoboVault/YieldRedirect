import pytest
from brownie import RedirectVault, RewardDistributor, Strategy0xDAO, StrategyLiquidDriver

def flatten(c):
    print(c)
    f = open("../flattened/flat{}.sol".format(c._name), "w")
    c.get_verification_info()
    f.write(c._flattener.flattened_source)
    f.close()

def main():
    flatten(RedirectVault)
    flatten(RewardDistributor)
    flatten(Strategy0xDAO)
    flatten(StrategyLiquidDriver)