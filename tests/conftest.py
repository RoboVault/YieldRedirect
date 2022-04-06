import pytest
from brownie import config
from brownie import Contract
from brownie import interface, project

@pytest.fixture
def wftm(interface):
    yield interface.ERC20('0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83')

boo = '0x841FAD6EAe12c286d1Fd18d1d525DFfA75C7EFFE'
lqdr = '0x10b620b2dbAC4Faa7D7FFD71Da486f5D44cd86f9'
beets = '0xF24Bcf4d1e507740041C9cFd2DddB29585aDCe1e'
spookyRouter =  '0xF491e7B69E4244ad4002BC14e878a34207E38c29'
spookyMasterChef = '0x2b2929E785374c651a81A63878Ab22742656DcDd'
lqdrMasterChef = '0x6e2ad6527901c9664f016466b8DA1357a004db0f'
beetsMasterChef = '0x8166994d9ebBe5829EC86Bd81258149B87faCfd3'

oxd = '0xc5A9848b9d145965d821AaeC8fA32aaEE026492d'
solid = '0x888EF71766ca594DED1F0FA3AE64eD2941740A20'

_usdc = '0x04068DA6C83AFCFA0e13ba15A6696662335D5B75'
yvUSDC = '0xEF0210eB96c7EB36AF8ed1c20306462764935607'
zeroAddress = '0x0000000000000000000000000000000000000000'

CONFIG = {

    'USDCFTMyvUSDC': {
        'token': '0x2b4C76d0dc16BE1C31D4C1DC53bF9B45987Fc75c',
        'targetToken' : _usdc,
        'targetVault' : yvUSDC,
        'farmAddress': lqdrMasterChef,
        'farmToken' : lqdr,
        'router' : spookyRouter,
        'weth' : '0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83',
        'pid' : 11,
        'whale' : '0x2b2929E785374c651a81A63878Ab22742656DcDd'
    },

    '0XMIMUSDCyvUSD': {
        'token': '0xbcab7d083Cf6a01e0DdA9ed7F8a02b47d125e682',
        'targetToken' : _usdc,
        'targetVault' : yvUSDC,
        'farmAddress': '0XDAO',
        'farmToken' : oxd,
        'router' : spookyRouter,
        'weth' : '0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83',
        'pid' : 11,
        'whale' : '0xC009BC33201A85800b3593A40a178521a8e60a02'
    },

    'LQDRFTMyvUSDC': {
        'token': '0xe7E90f5a767406efF87Fdad7EB07ef407922EC1D',
        'targetToken' : _usdc,
        'targetVault' : yvUSDC,
        'farmAddress': lqdrMasterChef,
        'farmToken' : lqdr,
        'router' : spookyRouter,
        'weth' : '0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83',
        'pid' : 5,
        'whale' : '0x717BDE1AA46a0Fcd937af339f95361331412C74C'
    },

    'BOOFTMyvUSDC': {
        'token': '0xEc7178F4C41f346b2721907F5cF7628E388A7a58',
        'targetToken' : _usdc,
        'targetVault' : yvUSDC,
        'farmAddress': lqdrMasterChef,
        'farmToken' : lqdr,
        'router' : spookyRouter,
        'weth' : '0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83',
        'pid' : 10,
        'whale' : spookyMasterChef
    },

    'SPIRITFTMyvUSDC': {
        'token': '0x30748322B6E34545DBe0788C421886AEB5297789',
        'targetToken' : _usdc,
        'targetVault' : yvUSDC,
        'farmAddress': lqdrMasterChef,
        'farmToken' : lqdr,
        'router' : spookyRouter,
        'weth' : '0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83',
        'pid' : 2,
        'whale' : '0x9083EA3756BDE6Ee6f27a6e996806FBD37F6F093'
    },


    'BeetsFTMyvUSDC': {
        'token': '0xcdE5a11a4ACB4eE4c805352Cec57E236bdBC3837',
        'targetToken' : _usdc,
        'targetVault' : yvUSDC,
        'farmAddress': beetsMasterChef,
        'farmToken' : beets,
        'router' : spookyRouter,
        'weth' : '0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83',
        'pid' : 9,
        'whale' : '0xa1E849B1d6c2Fd31c63EEf7822e9E0632411ada7'
    },



}



@pytest.fixture
def conf():
    yield CONFIG['BeetsFTMyvUSDC']

@pytest.fixture
def usdc():
    yield interface.IERC20Extended('0x04068DA6C83AFCFA0e13ba15A6696662335D5B75')

@pytest.fixture
def reward_token(conf):
    yield interface.IERC20(conf['farmToken'])

"""
@pytest.fixture
def router(conf):
    yield Contract(conf['router'])
"""

@pytest.fixture
def pid(conf):
    yield conf['pid']


@pytest.fixture
def gov(accounts):
    yield accounts.at("0x7601630eC802952ba1ED2B6e4db16F699A0a5A87", force=True)


@pytest.fixture
def user1(accounts):
    yield accounts[0]

@pytest.fixture
def user2(accounts):
    yield accounts[6]


@pytest.fixture
def rewards(accounts):
    yield accounts[1]


@pytest.fixture
def guardian(accounts):
    yield accounts[2]


@pytest.fixture
def management(accounts):
    yield accounts[3]


@pytest.fixture
def strategist(accounts):
    yield accounts[4]


@pytest.fixture
def keeper(accounts):
    yield accounts[5]


@pytest.fixture
def token(conf):
    # token_address = "0x04068DA6C83AFCFA0e13ba15A6696662335D5B75"  # USDC
    # token_address = "0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83"  # this should be the address of the ERC-20 used by the strategy/vault (DAI)
    if conf['farmAddress'] == '0XDAO' :
        token = interface.IBaseV1Pair(conf['token'])
    else : 
        token = interface.IUniswapV2Pair(conf['token'])
    yield interface.IUniswapV2Pair(conf['token'])


## Price utility functions
@pytest.fixture
def get_path(weth):
    def get_path(token_in, token_out):
        is_weth = token_in == weth or token_out == weth
        path = [0] * (2 if is_weth else 3)
        path[0] = token_in
        if (is_weth):
            path[1] = token_out
        else:
            path[1] = weth
            path[2] = token_out
        return path
    yield get_path

"""
@pytest.fixture
def token_price(router, usdc, get_path):
    def token_price(token, decimals):
        if (token.address == usdc.address):
            return 1

        path = get_path(usdc, token)
        price = router.getAmountsIn(10 ** decimals, path)[0]

        # add the fee back on
        if (len(path) == 2):
            price = price * (1 - 0.002)
        else:
            price = price * (1 - 0.004)

        return price / (10 ** usdc.decimals())

    yield token_price


@pytest.fixture
def lp_price(token, token_price):
    token0 = interface.IERC20Extended(token.token0())
    token1 = interface.IERC20Extended(token.token1())
    price0 = token_price(token0, token0.decimals())
    price1 = token_price(token1, token1.decimals())
    reserves = token.getReserves()
    totalSupply = token.totalSupply() / (10 ** 18)
    totalAssets = ((reserves[0] / (10 ** token0.decimals()) * price0) + 
                   (reserves[1] / (10 ** token1.decimals()) * price1))
    price = totalAssets / totalSupply 
    yield price
"""

@pytest.fixture
def amount(accounts, token, user1, user2, conf):
    amount = token.balanceOf(conf['whale']) * 0.05
    # In order to get some funds for the token you are about to use,
    # it impersonate an exchange address to use it's funds.
    # reserve = accounts.at("0x39B3bd37208CBaDE74D0fcBDBb12D606295b430a", force=True) # WFTM
    # reserve = accounts.at("0x2dd7C9371965472E5A5fD28fbE165007c61439E1", force=True) # USDC
    reserve = accounts.at(conf['whale'], force=True)
    token.transfer(user1, amount, {"from": reserve})
    token.transfer(user2, amount, {"from": reserve})

    yield amount

@pytest.fixture
def weth():
    token_address = "0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83"
    yield interface.IERC20Extended(token_address)


@pytest.fixture
def weth_amout(user, weth):
    weth_amout = 10 ** weth.decimals()
    user.transfer(weth, weth_amout)
    yield weth_amout


@pytest.fixture
def vault(RedirectVault, strategist, keeper, gov, conf, amount):
    tvlCap = amount * 10
    vault = RedirectVault.deploy(
        conf['token'], 
        "Yield Redirect Test",
        "yrSYMBOL",
        tvlCap,
        conf['router'],
        conf['targetToken'],
        conf['targetVault'],
        gov.address,
        0,
        {'from': gov}
    )

    yield vault


@pytest.fixture
def distributor(RewardDistributor, vault):
    yield RewardDistributor.at(vault.distributor())


@pytest.fixture
def strategy(strategist, keeper, vault, distributor, StrategyLiquidDriver, Strategy0xDAO, StrategyBeethoven ,gov, token, pid, reward_token, conf):
    if conf['farmAddress'] == '0XDAO' :
        strategy = Strategy0xDAO.deploy(vault, token.address, {"from": gov})
        distributor.permitRewardToken(oxd, {'from': gov})
        distributor.permitRewardToken(solid, {'from': gov})
    if conf['farmAddress'] == lqdrMasterChef:
        strategy = StrategyLiquidDriver.deploy(vault, token.address, pid, {"from": gov})
    if conf['farmAddress'] == beetsMasterChef:
        strategy = StrategyBeethoven.deploy(vault, token.address, pid, {"from": gov})


        distributor.permitRewardToken(reward_token, {'from': gov})


    vault.initialize(strategy, {"from": gov})
    yield strategy

# Function scoped isolation fixture to enable xdist.
# Snapshots the chain before each test and reverts after test completion.
@pytest.fixture(scope="function", autouse=True)
def shared_setup(fn_isolation):
    pass