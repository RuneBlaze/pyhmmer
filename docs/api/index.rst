API Reference
==============

.. toctree::
   :hidden:

   hmmer <hmmer>
   easel <easel>
   plan7 <plan7>
   errors <errors>


.. currentmodule:: pyhmmer

.. automodule:: pyhmmer


.. only:: html

    HMMER
    -----

    .. autosummary::
        :nosignatures:

        pyhmmer.hmmer.hmmsearch
        pyhmmer.hmmer.phmmer
        pyhmmer.hmmer.nhmmer
        pyhmmer.hmmer.hmmpress


    Easel
    -----

    .. autosummary::
       :nosignatures:

       pyhmmer.easel.Alphabet
       pyhmmer.easel.Bitfield
       pyhmmer.easel.DigitalMSA
       pyhmmer.easel.DigitalSequence
       pyhmmer.easel.KeyHash
       pyhmmer.easel.MSA
       pyhmmer.easel.Sequence
       pyhmmer.easel.SequenceFile
       pyhmmer.easel.TextMSA
       pyhmmer.easel.TextSequence
       pyhmmer.easel.SSIReader
       pyhmmer.easel.SSIWriter


    Plan7
    -----

    .. autosummary::
        :nosignatures:

        pyhmmer.plan7.Alignment
        pyhmmer.plan7.Background
        pyhmmer.plan7.Domain
        pyhmmer.plan7.Domains
        pyhmmer.plan7.Hit
        pyhmmer.plan7.HMM
        pyhmmer.plan7.HMMFile
        pyhmmer.plan7.OptimizedProfile
        pyhmmer.plan7.Pipeline
        pyhmmer.plan7.Profile
        pyhmmer.plan7.TopHits


    Errors
    ------

    .. autosummary::
       :nosignatures:

       pyhmmer.errors.AllocationError
       pyhmmer.errors.UnexpectedError
       pyhmmer.errors.EaselError
