import unittest.mock

import pytest
from vision.common.blockchains.enums import Blockchain

from vision.validatornode.blockchains.sonic import SonicClient
from vision.validatornode.blockchains.sonic import SonicClientError


@pytest.fixture(scope='module')
@unittest.mock.patch.object(SonicClient, '__init__', lambda self: None)
def sonic_client():
    return SonicClient()


def test_get_blockchain_correct(sonic_client):
    assert sonic_client.get_blockchain() is Blockchain.SONIC
    assert SonicClient.get_blockchain() is Blockchain.SONIC


def test_get_error_class_correct(sonic_client):
    assert sonic_client.get_error_class() is SonicClientError
    assert SonicClient.get_error_class() is SonicClientError
