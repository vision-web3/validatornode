import unittest.mock

import pytest

from vision.validatornode.protocol import get_supported_protocol_versions

with unittest.mock.patch('vision.validatornode.configuration.config'):
    import vision.validatornode.celery  # noqa: F401


@pytest.fixture(scope="session")
def config_dict(protocol_version):
    return {'protocol': str(protocol_version)}


@pytest.fixture(scope="session", params=get_supported_protocol_versions())
def protocol_version(request):
    return request.param
