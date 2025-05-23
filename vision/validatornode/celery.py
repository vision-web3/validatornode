"""Module for creating and initializing a Celery instance.

"""
import logging
import os
import pathlib
import sys

import celery  # type: ignore
import certifi  # type: ignore
from vision.common.logging import LogFile
from vision.common.logging import LogFormat
from vision.common.logging import initialize_logger

from vision.validatornode.application import initialize_application
from vision.validatornode.configuration import config
from vision.validatornode.configuration import load_config
from vision.validatornode.database import get_engine

_logger = logging.getLogger(__name__)
"""Logger for this module."""


def is_main_module() -> bool:
    """Determine if the current process is a Celery worker process.

    Returns
    -------
    bool
        True if the current process is a Celery worker process.

    """
    potential_celery_markers = [
        'celery', 'worker', 'beat', 'flower', 'report', 'ping'
    ]
    return (__name__ == '__main__'
            or any(marker in sys.argv for marker in potential_celery_markers))


def verify_celery_url_has_ssl() -> bool:
    """Determine if the Celery broker URL has SSL enabled.

    Returns
    -------
    bool
        True if the Celery broker URL has SSL enabled.
    """
    if "CELERY_BROKER" in os.environ:
        url_to_check = os.environ["CELERY_BROKER"]
    else:
        url_to_check = config['celery']['broker']
    return url_to_check.startswith('amqps')


if is_main_module():
    _logger.info('Initializing the Celery application...')
    initialize_application()  # pragma: no cover
else:
    _logger.info('Celery application initialization skipped...')
    load_config(reload=False)

ca_certs = {'ca_certs': certifi.where()} if verify_celery_url_has_ssl() else {}

celery_app = celery.Celery(
    'vision.validatornode', broker=config['celery']['broker'],
    backend=config['celery']['backend'], include=[
        'vision.common.blockchains.tasks',
        'vision.validatornode.business.transfers'
    ], broker_use_ssl=ca_certs)
"""Celery application instance."""


@celery.signals.after_setup_task_logger.connect  # Celery task logger
@celery.signals.after_setup_logger.connect  # Celery logger
def setup_logger(logger: logging.Logger, *args, **kwargs):
    """Sent after the setup of every single task and Celery logger.
    Used to augment logging configuration.

    Parameters
    ----------
    logger: logging.Logger
        Logger object to be augmented.

    """
    log_format = LogFormat.from_name(config['celery']['log']['format'])
    standard_output = config['celery']['log']['console']['enabled']
    if not config['celery']['log']['file']['enabled']:
        log_file = None
    else:
        file_path = pathlib.Path(config['celery']['log']['file']['name'])
        max_bytes = config['celery']['log']['file']['max_bytes']
        backup_count = config['celery']['log']['file']['backup_count']
        log_file = LogFile(file_path, max_bytes, backup_count)
    debug = config['application']['debug']
    try:
        initialize_logger(logger, log_format, standard_output, log_file, debug)
    except Exception:
        logger.critical('unable to initialize logging', exc_info=True)
        sys.exit(1)


# Additional Celery configuration
celery_app.conf.update(
    result_expires=None,
    task_default_exchange='vision.validatornode',
    task_default_queue='vision.validatornode',
    task_default_routing_key='vision.validatornode',
    task_track_started=True,
    worker_enable_remote_control=False,
    # Make sure the broker crashes if it can't connect on startup
    broker_connection_retry=10,
    broker_channel_error_retry=True,
    broker_connection_retry_on_startup=False)


# Source: https://stackoverflow.com/questions/43944787/sqlalchemy-celery-with-scoped-session-error/54751019#54751019 # noqa
@celery.signals.worker_process_init.connect
def prep_db_pool(**kwargs):
    """
    When Celery forks the parent process, it includes the db engine & connection
    pool. However, db connections should not be shared across processes. Thus,
    we instruct the engine to dispose of all existing connections, prompting the
    opening of new ones in child processes as needed.
    More info:
    https://docs.sqlalchemy.org/en/latest/core/pooling.html#using-connection-pools-with-multiprocessing
    """ # noqa
    get_engine().dispose()  # pragma: no cover
