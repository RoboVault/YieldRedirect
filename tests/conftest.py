#!/usr/bin/python3

import pytest


@pytest.fixture
def wftm(interface):
    yield interface.ERC20('0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83')