"""Module for Avalanche-specific clients and errors. Since the
Avalanche C-Chain is Ethereum-compatible, the client implementation
inherits from the vision.validatornode.blockchains.ethereum module.

"""
from vision.common.blockchains.enums import Blockchain

from vision.validatornode.blockchains.base import BlockchainClientError
from vision.validatornode.blockchains.ethereum import EthereumClient
from vision.validatornode.blockchains.ethereum import EthereumClientError


class AvalancheClientError(EthereumClientError):
    """Exception class for all Avalanche client errors.

    """
    pass


class AvalancheClient(EthereumClient):
    """Avalanche-specific blockchain client.

    """
    @classmethod
    def get_blockchain(cls) -> Blockchain:
        # Docstring inherited
        return Blockchain.AVALANCHE

    @classmethod
    def get_error_class(cls) -> type[BlockchainClientError]:
        # Docstring inherited
        return AvalancheClientError
