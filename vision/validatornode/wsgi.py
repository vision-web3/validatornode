"""Provides the Vision Validator Node application for deployments on
WSGI-compliant web servers.

"""
from vision.validatornode.application import create_application

application = create_application()
