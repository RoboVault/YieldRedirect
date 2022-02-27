import pytest
from brownie import config
from brownie import Contract
from brownie import interface, project


@pytest.fixture
def wftm(interface):
    yield interface.ERC20('0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83')

boo = '0x841FAD6EAe12c286d1Fd18d1d525DFfA75C7EFFE'
lqdr = '0x841FAD6EAe12c286d1Fd18d1d525DFfA75C7EFFE'
spookyRouter =  '0xF491e7B69E4244ad4002BC14e878a34207E38c29'
spookyMasterChef = '0x2b2929E785374c651a81A63878Ab22742656DcDd'
lqdrMasterChef = '0x6e2ad6527901c9664f016466b8DA1357a004db0f'

usdc = '0x04068DA6C83AFCFA0e13ba15A6696662335D5B75'
yvUSDC = '0xEF0210eB96c7EB36AF8ed1c20306462764935607'


CONFIG = {

    'BOOFTMyvUSDC': {
        'token': '0xEc7178F4C41f346b2721907F5cF7628E388A7a58',
        'targetToken' : yvUSDC,
        'swapToken': usdc,
        'farmAddress': spookyMasterChef,
        'farmToken' : boo,
        'router' : spookyRouter,
        'weth' : '0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83',
        'pid' : 0,
        'farmType': 0, 
        'whale' : '0x2b2929E785374c651a81A63878Ab22742656DcDd'
    },


    'LQDRFTMyvUSDC': {
        'token': '0xEc7178F4C41f346b2721907F5cF7628E388A7a58',
        'targetToken' : yvUSDC,
        'swapToken': usdc,
        'farmAddress': lqdrMasterChef,
        'farmToken' : lqdr,
        'router' : spookyRouter,
        'weth' : '0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83',
        'pid' : 0,
        'farmType': 2, 
        'whale' : '0x717BDE1AA46a0Fcd937af339f95361331412C74C'
    }

}

@pytest.fixture
def conf():
    yield CONFIG['BOOFTMyvUSDC']


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
    yield interface.IERC20Extended(conf['token'])


@pytest.fixture
def amount(accounts, token, user1, user2, conf):
    amount = token.balanceOf(conf['whale']) / 3
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
def yieldRedirect(strategist, keeper, gov, conf):
    yieldRedicrectFarm = project.YieldredirectProject.yieldRedirectFarm
    yieldRedirect = yieldRedicrectFarm.deploy(conf['token'], conf['targetToken'], conf['swapToken'], conf['farmAddress'], conf['farmToken'], conf['router'], conf['weth'], conf['pid'], conf['farmType'], {'from': gov})

    yield yieldRedirect

# Function scoped isolation fixture to enable xdist.
# Snapshots the chain before each test and reverts after test completion.
@pytest.fixture(scope="function", autouse=True)
def shared_setup(fn_isolation):
    pass