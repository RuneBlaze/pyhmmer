# coding: utf-8
"""Cython bindings and Python interface to HMMER3.

HMMER is a biological sequence analysis tool that uses profile hidden Markov
models to search for sequence homologs. HMMER3 is maintained by members of the
the `Eddy/Rivas Laboratory <http://eddylab.org/>`_ at Harvard University.

``pyhmmer`` is a module, implemented using the `Cython <https://cython.org/>`_
language, that provides bindings to HMMER3. It directly interacts with the
HMMER internals, which has several advantages over CLI wrappers like
`hmmer-py <https://pypi.org/project/hmmer/>`_.

"""

import collections.abc as _collections_abc
import contextlib as _contextlib
import os as _os

from . import errors
from . import easel
from . import plan7

from .hmmer import hmmsearch, hmmpress


__author__ = "Martin Larralde <martin.larralde@embl.de>"
__license__ = "MIT"
__version__ = "0.1.0-a5"
__all__ = [
    errors.__name__,
    easel.__name__,
    plan7.__name__,
    hmmsearch.__name__,
    hmmpress.__name__
]

# Small addition to the docstring: we want to show a link redirecting to the
# rendered version of the documentation, but this can only work when Python
# is running with docstrings enabled
if __doc__ is not None:
    __doc__ += """See Also:
    An online rendered version of the documentation for this version of the
    library on `Read The Docs <https://pyhmmer.readthedocs.io/en/v{}/>`_.

    """.format(
        # in the even the library is a CI build installed from GitLab, we
        # just redirect to the stable version instead, i.e. not including
        # the local component of the version (everything after the ``+``)
        __version__.split("+")[0]
    )

# Register collections using the `collections.abc` module (this is probably
# not required with later versions of Python)
_collections_abc.Iterator.register(easel.SequenceFile)
_collections_abc.Iterator.register(plan7.HMMFile)
_collections_abc.Sized.register(plan7.Alignment)
_collections_abc.Sequence.register(easel.Bitfield)
_collections_abc.Sequence.register(plan7.Domains)
_collections_abc.Sequence.register(plan7.TopHits)

if hasattr(_contextlib, "AbstractContextManager"):
    _contextlib.AbstractContextManager.register(easel.SequenceFile)
    _contextlib.AbstractContextManager.register(easel.SSIReader)
    _contextlib.AbstractContextManager.register(easel.SSIWriter)
    _contextlib.AbstractContextManager.register(plan7.HMMFile)
