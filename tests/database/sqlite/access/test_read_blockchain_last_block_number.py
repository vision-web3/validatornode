import unittest.mock

import pytest
import sqlalchemy
import sqlalchemy.exc
from vision.common.blockchains.enums import Blockchain

from vision.validatornode.database.access import \
    read_blockchain_last_block_number
from vision.validatornode.database.models import Blockchain as Blockchain_


@pytest.mark.parametrize('last_block_number', [845626, 2471893])
@unittest.mock.patch('vision.validatornode.database.access.get_session')
def test_read_blockchain_last_block_number_correct(
        mock_get_session, database_session_maker, last_block_number,
        initialized_database_session, blockchain):
    mock_get_session.side_effect = database_session_maker
    statement = sqlalchemy.update(Blockchain_).where(
        Blockchain_.id == blockchain.id).values(
            last_block_number=last_block_number)
    initialized_database_session.execute(statement)
    initialized_database_session.commit()
    read_last_block_number = read_blockchain_last_block_number(
        Blockchain(blockchain.id))
    assert read_last_block_number == last_block_number
