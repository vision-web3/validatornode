"""Module for BNB-Chain-specific clients and errors. Since the BNB
Smart Chain is Ethereum-compatible, the client implementation inherits
from the vision.validatornode.blockchains.ethereum module.

"""
from vision.common.blockchains.enums import Blockchain

from vision.validatornode.blockchains.base import BlockchainClientError
from vision.validatornode.blockchains.ethereum import EthereumClient
from vision.validatornode.blockchains.ethereum import EthereumClientError


class BnbChainClientError(EthereumClientError):
    """Exception class for all BNB Chain client errors.

    """
    pass


class BnbChainClient(EthereumClient):
    """BNB-Chain-specific blockchain client.

    """
    @classmethod
    def get_blockchain(cls) -> Blockchain:
        # Docstring inherited
        return Blockchain.BNB_CHAIN

    @classmethod
    def get_error_class(cls) -> type[BlockchainClientError]:
        # Docstring inherited
        return BnbChainClientError
