import unittest.mock

import pytest
from vision.common.blockchains.enums import Blockchain

from vision.validatornode.blockchains.avalanche import AvalancheClient
from vision.validatornode.blockchains.base import BlockchainClient
from vision.validatornode.blockchains.bnbchain import BnbChainClient
from vision.validatornode.blockchains.celo import CeloClient
from vision.validatornode.blockchains.cronos import CronosClient
from vision.validatornode.blockchains.ethereum import EthereumClient
from vision.validatornode.blockchains.factory import _blockchain_clients
from vision.validatornode.blockchains.factory import get_blockchain_client
from vision.validatornode.blockchains.factory import \
    initialize_blockchain_clients
from vision.validatornode.blockchains.polygon import PolygonClient
from vision.validatornode.blockchains.solana import SolanaClient
from vision.validatornode.blockchains.sonic import SonicClient


@pytest.fixture(autouse=True)
def clear_blockchain_clients():
    _blockchain_clients.clear()


@pytest.mark.parametrize('blockchain',
                         [blockchain for blockchain in Blockchain])
@unittest.mock.patch(
    'vision.validatornode.blockchains.factory.get_blockchain_config',
    return_value={'active': True})
@unittest.mock.patch(
    'vision.validatornode.blockchains.factory._blockchain_client_classes')
def test_get_blockchain_client_correct(mock_blockchain_client_classes,
                                       mock_get_blockchain_config, blockchain):
    blockchain_client_class = _get_blockchain_client_class(blockchain)
    mock_blockchain_client_classes.__getitem__.return_value = \
        blockchain_client_class
    with unittest.mock.patch.object(blockchain_client_class, '__init__',
                                    lambda self: None):
        initialize_blockchain_clients()
    blockchain_client = get_blockchain_client(blockchain)
    assert isinstance(blockchain_client, BlockchainClient)
    assert isinstance(blockchain_client, blockchain_client_class)


def _get_blockchain_client_class(blockchain):
    if blockchain is Blockchain.AVALANCHE:
        return AvalancheClient
    if blockchain is Blockchain.BNB_CHAIN:
        return BnbChainClient
    if blockchain is Blockchain.CELO:
        return CeloClient
    if blockchain is Blockchain.CRONOS:
        return CronosClient
    if blockchain is Blockchain.ETHEREUM:
        return EthereumClient
    if blockchain is Blockchain.SONIC:
        return SonicClient
    if blockchain is Blockchain.POLYGON:
        return PolygonClient
    if blockchain is Blockchain.SOLANA:
        return SolanaClient
    raise NotImplementedError
