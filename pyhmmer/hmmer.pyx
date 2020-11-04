# coding: utf-8
# cython: language_level=3, linetrace=True

from libc.stdio cimport fprintf, FILE, stdout
from libc.math cimport exp

cimport libeasel
cimport libeasel.sq
cimport libeasel.alphabet
cimport libeasel.getopts
cimport libhmmer.impl_sse.p7_oprofile
cimport libhmmer.modelconfig
cimport libhmmer.p7_hmm
cimport libhmmer.p7_bg
cimport libhmmer.p7_hmmfile
cimport libhmmer.p7_pipeline
cimport libhmmer.p7_profile
cimport libhmmer.p7_tophits
from libeasel cimport eslERRBUFSIZE
from libeasel.alphabet cimport ESL_ALPHABET, esl_alphabet_Create, esl_abc_ValidateType
from libeasel.getopts cimport ESL_GETOPTS, ESL_OPTIONS
from libeasel.sq cimport ESL_SQ
from libhmmer cimport p7_LOCAL
from libhmmer.logsum cimport p7_FLogsumInit
from libhmmer.impl_sse cimport impl_Init
from libhmmer.impl_sse.p7_oprofile cimport P7_OPROFILE
from libhmmer.p7_bg cimport P7_BG
from libhmmer.p7_domain cimport P7_DOMAIN
from libhmmer.p7_hmm cimport P7_HMM
from libhmmer.p7_hmmfile cimport P7_HMMFILE
from libhmmer.p7_pipeline cimport P7_PIPELINE, p7_pipemodes_e
from libhmmer.p7_profile cimport P7_PROFILE
from libhmmer.p7_tophits cimport P7_TOPHITS, P7_HIT

from .easel cimport Alphabet, Sequence

import errno
import os
import io
import warnings

from .errors import AllocationError, UnexpectedError


cdef extern from "hmmsearch.c":
    cdef ESL_OPTIONS* options


cdef class P7Profile:

    cdef P7_PROFILE* _gm

    def __cinit__(self):
        self._gm = NULL

    def __dealloc__(self):
        libhmmer.p7_profile.p7_profile_Destroy(self._gm)


cdef class P7HMM:

    # keep a reference to the Alphabet Python object to avoid deallocation of
    # the inner ESL_ALPHABET; the Python object provides reference counting
    # for free.
    cdef readonly Alphabet alphabet
    cdef P7_HMM* _hmm

    # --- Magic methods ------------------------------------------------------

    def __init__(self, int m, Alphabet alphabet):
        self.alphabet = alphabet
        self._hmm = libhmmer.p7_hmm.p7_hmm_Create(m, alphabet._abc)
        if not self.hmm:
           raise MemoryError("could not allocate C object")

    def __cinit__(self):
        self.alphabet = None
        self._hmm = NULL

    def __dealloc__(self):
        libhmmer.p7_hmm.p7_hmm_Destroy(self._hmm)

    # --- Properties ---------------------------------------------------------

    @property
    def name(self):
        """`bytes`: The name of the HMM.
        """
        return <bytes> self._hmm.name

    @name.setter
    def name(self, bytes name):
        cdef int err = libhmmer.p7_hmm.p7_hmm_SetName(self._hmm, name)
        if err == libeasel.eslEMEM:
            raise MemoryError("could not allocate C string")
        elif err != libeasel.eslOK:
            raise RuntimeError("unexpected error in p7_hmm_SetName: {}".format(err))

    @property
    def accession(self):
        """`bytes`: The accession of the HMM.
        """
        return <bytes> self._hmm.acc

    @accession.setter
    def accession(self, bytes accession):
        cdef int err = libhmmer.p7_hmm.p7_hmm_SetAccession(self._hmm, accession)
        if err == libeasel.eslEMEM:
            raise MemoryError("could not allocate C string")
        elif err != libeasel.eslOK:
            raise RuntimeError("unexpected error in p7_hmm_SetAccession: {}".format(err))

    @property
    def description(self):
        """`bytes`: The description of the HMM.
        """
        return <bytes> self._hmm.desc

    @description.setter
    def description(self, bytes description):
        cdef int err = libhmmer.p7_hmm.p7_hmm_SetDescription(self._hmm, description)
        if err == libeasel.eslEMEM:
            raise MemoryError("could not allocate C string")
        elif err != libeasel.eslOK:
            raise RuntimeError("unexpected error in p7_hmm_SetDescription: {}".format(err))

    # --- Methods ------------------------------------------------------------

    cpdef zero(self):
        """Set all parameters to zero (including model composition).
        """
        libhmmer.p7_hmm.p7_hmm_Zero(self._hmm)


cdef class P7HMMFile:

    cdef P7_HMMFILE* _hfp
    cdef Alphabet _alphabet

    # --- Magic methods ------------------------------------------------------

    def __cinit__(self):
        self._alphabet = None
        self._hfp = NULL

    def __init__(self, str filename):
        cdef bytes fspath = os.fsencode(filename)
        cdef errbuf = bytearray(eslERRBUFSIZE)

        cdef err = libhmmer.p7_hmmfile.p7_hmmfile_OpenE(fspath, NULL, &self._hfp, errbuf)
        if err == libeasel.eslENOTFOUND:
            raise FileNotFoundError(errno.ENOENT, "no such file or directory: {!r}".format(filename))
        elif err == libeasel.eslEFORMAT:
            raise ValueError("format not recognized by HMMER")

        self._alphabet = Alphabet.__new__(Alphabet)
        self._alphabet._abc = NULL

    def __dealloc__(self):
        if self._hfp:
            warnings.warn("unclosed HMM file", ResourceWarning)
            self.close()

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        self.close()

    def __iter__(self):
        # cdef int err = p7_hmmfile.p7_hmmfile_Position(self._hfp, 0)
        # if err == libeasel.eslEINVAL:
        #     raise io.UnsupportedOperation("file is not seekable")
        return self

    def __next__(self):

        cdef int status
        cdef P7HMM py_hmm
        cdef P7_HMM* hmm = NULL


        with nogil:
            status = libhmmer.p7_hmmfile.p7_hmmfile_Read(self._hfp, &self._alphabet._abc, &hmm)

        if status == libeasel.eslOK:
            py_hmm = P7HMM.__new__(P7HMM)
            py_hmm.alphabet = self._alphabet # keep a reference to the alphabet
            py_hmm._hmm = hmm
            return py_hmm
        elif status == libeasel.eslEOF:
            raise StopIteration()
        elif status == libeasel.eslEMEM:
            raise AllocationError("P7_HMM")
        elif status == libeasel.eslESYS:
            raise OSError(self._hfp.errbuf.decode('ascii'))
        elif status == libeasel.eslEFORMAT:
            raise ValueError("Invalid format in file: {}".format(self._hfp.errbuf.decode('ascii')))
        elif status == libeasel.eslEINCOMPAT:
            alphabet = libeasel.alphabet.esl_abc_DecodeType(self._alphabet.type)
            raise ValueError("HMM is not in the expected {} alphabet".format(alphabet))
        else:
            raise UnexpectedError(status, "p7_hmmfile_Read")


    # --- Utils --------------------------------------------------------------

    cpdef void close(self):
        libhmmer.p7_hmmfile.p7_hmmfile_Close(self._hfp)
        self._hfp = NULL


cdef class P7Alignment:
    pass


cdef class P7Domain:

    cdef P7Hit _hit
    cdef P7_DOMAIN* _dom

    def __cinit__(self):
        self._hit = None
        self._dom = NULL

    @property
    def ienv(self):
        assert self._dom != NULL
        return self._dom.ienv

    @property
    def jenv(self):
        assert self._dom != NULL
        return self._dom.jenv

    @property
    def iali(self):
        assert self._dom != NULL
        return self._dom.iali

    @property
    def jali(self):
        assert self._dom != NULL
        return self._dom.jali


    # @property
    # def c_evalue(self):
    #     assert self._dom != NULL
    #     return exp(self._dom.lnP) * pli->domZ,
    #
    # @property
    # def i_evalue(self):
    #     assert self._dom != NULL
    #     exp(th->hit[h]->dcl[d].lnP) * pli->Z,


cdef class P7Hit:

    # a reference to the P7TopHits that owns this P7Hit, kept so that the
    # internal data is never deallocated before the Python class.
    cdef P7TopHits _hits

    # a pointer to the P7_HIT
    cdef P7_HIT* _hit

    def __cinit__(self, P7TopHits hits, size_t index):
        assert hits._th != NULL
        assert index < hits._th.N

        self._hits = hits
        self._hit = hits._th.hit[index]

    @property
    def name(self):
        assert self._hit != NULL
        assert self._hit.name != NULL
        return <bytes> self._hit.name

    @property
    def accession(self):
        assert self._hit != NULL
        if self._hit.acc == NULL:
            return None
        return <bytes> self._hit.acc

    @property
    def description(self):
        assert self._hit != NULL
        if self._hit.desc == NULL:
            return None
        return <bytes> self._hit.acc

    @property
    def score(self):
        assert self._hit != NULL
        return self._hit.score

    @property
    def bias(self):
        assert self._hit != NULL
        return self._hit.pre_score - self._hit.score

    @property
    def lnP(self):
        assert self._hit != NULL
        return self._hit.lnP

    # @property
    # def domain(self):


cdef class P7TopHits:

    cdef P7_TOPHITS* _th

    def __init__(self):
        assert self._th == NULL, "called P7TopHits.__init__ more than once"
        self._th = libhmmer.p7_tophits.p7_tophits_Create()
        if self._th == NULL:
            raise AllocationError("P7_TOPHITS")

    def __cinit__(self):
        self._th = NULL

    def __dealloc__(self):
        libhmmer.p7_tophits.p7_tophits_Destroy(self._th)

    def __bool__(self):
        return len(self) > 0

    def __len__(self):
        assert self._th != NULL
        return self._th.N

    def __getitem__(self, index):
        cdef size_t index_
        if index < 0:
            index += self._th.N
        if index >= self._th.N or index < 0:
            raise IndexError("list index out of range")
        return P7Hit(self, index)


    cpdef void sort_by_sortkey(self):
        assert self._th != NULL
        libhmmer.p7_tophits.p7_tophits_SortBySortkey(self._th)

    cpdef void threshold(self, P7Pipeline pipeline):
        assert self._th != NULL
        libhmmer.p7_tophits.p7_tophits_Threshold(self._th, pipeline._pli)


    cpdef void clear(self):
        assert self._th != NULL
        cdef int status = libhmmer.p7_tophits.p7_tophits_Reuse(self._th)
        if status != libeasel.eslOK:
            raise UnexpectedError(status, "p7_tophits_Reuse")


    cpdef void print_targets(self, P7Pipeline pipeline):
        assert self._th != NULL
        libhmmer.p7_tophits.p7_tophits_Targets(stdout, self._th, pipeline._pli, 0)

    cpdef void print_domains(self, P7Pipeline pipeline):
        assert self._th != NULL
        libhmmer.p7_tophits.p7_tophits_Domains(stdout, self._th, pipeline._pli, 0)


cdef class P7Pipeline:

    cdef readonly Alphabet alphabet

    cdef P7_PIPELINE* _pli
    cdef P7_BG* _bg


    def __cinit__(self):
        self._pli = NULL


    def __init__(self, Alphabet alphabet):

        M_hint = 100
        L_hint = 400
        long_targets = False

        self.alphabet = alphabet

        self._pli = libhmmer.p7_pipeline.p7_pipeline_Create(NULL, M_hint, L_hint, long_targets, p7_pipemodes_e.p7_SEARCH_SEQS)
        if self._pli == NULL:
            raise AllocationError("P7_PIPELINE")

        self._bg = libhmmer.p7_bg.p7_bg_Create(alphabet._abc)
        if self._bg == NULL:
            raise AllocationError("P7_BG")


    def __dealloc__(self):
        libhmmer.p7_pipeline.p7_pipeline_Destroy(self._pli)
        libhmmer.p7_bg.p7_bg_Destroy(self._bg)


    cpdef P7TopHits search(self, P7HMM hmm, object seqs, P7TopHits hits = None):
        cdef int           status
        cdef Sequence      seq
        cdef ESL_ALPHABET* abc     = self.alphabet._abc
        cdef P7_BG*        bg      = self._bg
        cdef P7_HMM*       hm      = hmm._hmm
        cdef P7_PROFILE*   gm
        cdef P7_OPROFILE*  om
        cdef P7_TOPHITS*   th
        cdef P7_PIPELINE*  pli     = self._pli
        cdef ESL_SQ*       sq      = NULL

        assert self._pli != NULL

        # check the pipeline was configure with the same alphabet
        if hmm.alphabet != self.alphabet:
            raise ValueError("Wrong alphabet in input HMM: expected {!r}, found {!r}".format(
              self.alphabet,
              hmm.alphabet
            ))

        # make sure the pipeline is set to search mode
        self._pli.mode = p7_pipemodes_e.p7_SEARCH_SEQS

        # get a pointer to the P7_TOPHITS struct to use
        hits = P7TopHits() if hits is None else hits
        th = hits._th

        # get an iterator over the input sequences, with an early return if
        # no sequences were given, and extract the raw pointer to the sequence
        # from the Python object
        seqs_iter = iter(seqs)
        seq = next(seqs_iter, None)
        if seq is None:
            return hits
        sq = seq._sq

        # release the GIL for as long as possible
        with nogil:

            # build the profile from the HMM, using the first sequence length
            # as a hint for the model configuraiton
            gm = libhmmer.p7_profile.p7_profile_Create(hm.M, abc)
            if libhmmer.modelconfig.p7_ProfileConfig(hm, bg, gm, sq.L, p7_LOCAL):
                raise RuntimeError()

            # build the optimized model from the HMM
            om = libhmmer.impl_sse.p7_oprofile.p7_oprofile_Create(hm.M, abc)
            if libhmmer.impl_sse.p7_oprofile.p7_oprofile_Convert(gm, om):
                raise RuntimeError()

            # configure the pipeline for the current HMM
            if libhmmer.p7_pipeline.p7_pli_NewModel(pli, om, bg):
                raise RuntimeError()

            # run the inner loop on all sequences
            while sq != NULL:

                # digitize the sequence if needed
                # if libeasel.sq.esl_sq_Copy(seq._sq, dbsq):
                #     raise RuntimeError()
                if not libeasel.sq.esl_sq_IsDigital(sq):
                    if libeasel.sq.esl_sq_Digitize(abc, sq):
                        raise RuntimeError()

                # configure the profile, background and pipeline for the new sequence
                if libhmmer.p7_pipeline.p7_pli_NewSeq(pli, sq):
                    raise RuntimeError()
                if libhmmer.p7_bg.p7_bg_SetLength(bg, sq.n):
                    raise RuntimeError()
                if libhmmer.impl_sse.p7_oprofile.p7_oprofile_ReconfigLength(om, sq.n):
                    raise RuntimeError()

                # run the pipeline on the sequence
                status = libhmmer.p7_pipeline.p7_Pipeline(pli, om, bg, sq, NULL, th);
                if status != libeasel.eslOK:
                    raise RuntimeError()

                # clear pipeline for reuse for next target
                libhmmer.p7_pipeline.p7_pipeline_Reuse(pli)

                # acquire the GIL just long enough to get the next sequence
                with gil:
                    seq = next(seqs_iter, None)
                    sq = NULL if seq is None else seq._sq

            # deallocate the profile and optimized model
            libhmmer.p7_profile.p7_profile_Destroy(gm)
            libhmmer.impl_sse.p7_oprofile.p7_oprofile_Destroy(om)

        #
        return hits




impl_Init()
p7_FLogsumInit()








#
#
#
# cpdef P7TopHits hmmsearch(P7HMM hmm, object seqs, P7TopHits hits = None):
#
#     cdef int          status
#     cdef Sequence     seq
#     cdef FILE*        ofp     = stdout
#     cdef P7_BG*       bg
#     cdef P7_PROFILE*  gm
#     cdef P7_OPROFILE* om
#     cdef P7_TOPHITS*  th
#     cdef P7_PIPELINE* pli
#     cdef ESL_GETOPTS* go      = NULL
#     cdef ESL_SQ*      dbsq    = NULL # libeasel.sq.esl_sq_Create()
#
#
#     # get an iterator over the input sequences
#     seqs_iter = iter(seqs)
#     hits = P7TopHits() if hits is None else hits
#
#     # get the top
#     th = hits._th
#
#     # release the GIL for as long as possible
#     with nogil:
#
#         # create the background model for the HMM alphabet
#         bg = libhmmer.p7_bg.p7_bg_Create(hmm.alphabet._abc)
#
#         # build optimized model
#         gm = libhmmer.p7_profile.p7_profile_Create(hmm._hmm.M, hmm.alphabet._abc)
#         om = libhmmer.impl_sse.p7_oprofile.p7_oprofile_Create(hmm._hmm.M, hmm.alphabet._abc)
#         if libhmmer.modelconfig.p7_ProfileConfig(hmm._hmm, bg, gm, 100, p7_LOCAL):
#             raise RuntimeError()
#         if libhmmer.impl_sse.p7_oprofile.p7_oprofile_Convert(gm, om):
#             raise RuntimeError()
#
#         # build the processing pipeline and configure it for the current HMM
#         pli = libhmmer.p7_pipeline.p7_pipeline_Create(go, hmm.M, 100, False, p7_pipemodes_e.p7_SEARCH_SEQS) # use same dummy as `hmmseach.c` code
#         if libhmmer.p7_pipeline.p7_pli_NewModel(pli, om, bg):
#             raise RuntimeError()
#
#         # run the inner loop on all sequences
#         while True:
#
#             # acquire the GIL to get the next sequence
#             with gil:
#                 seq = next(seqs_iter, None)
#                 if seq is None:
#                     break
#                 dbsq = seq._sq
#
#             # digitize the sequence
#             # if libeasel.sq.esl_sq_Copy(seq._sq, dbsq):
#             #     raise RuntimeError()
#             if not libeasel.sq.esl_sq_IsDigital(dbsq):
#                 if libeasel.sq.esl_sq_Digitize(hmm.alphabet._abc, dbsq):
#                     raise RuntimeError()
#
#             # configure the profile, background and pipeline for the new sequence
#             if libhmmer.p7_pipeline.p7_pli_NewSeq(pli, dbsq):
#                 raise RuntimeError()
#             if libhmmer.p7_bg.p7_bg_SetLength(bg, dbsq.n):
#                 raise RuntimeError()
#             if libhmmer.impl_sse.p7_oprofile.p7_oprofile_ReconfigLength(om, dbsq.n):
#                 raise RuntimeError()
#
#             # run the pipeline
#             status = libhmmer.p7_pipeline.p7_Pipeline(pli, om, bg, dbsq, seq._sq, th);
#             if status != libeasel.eslOK:
#                 raise RuntimeError()
#
#             # clear dbsq
#             # if libeasel.sq.esl_sq_Reuse(dbsq):
#             #     raise RuntimeError()
#
#             # clear pipeline
#             libhmmer.p7_pipeline.p7_pipeline_Reuse(pli)
#
#         # dealloc
#         libhmmer.p7_pipeline.p7_pipeline_Destroy(pli)
#         libhmmer.p7_bg.p7_bg_Destroy(bg)
#         libhmmer.p7_profile.p7_profile_Destroy(gm)
#         libhmmer.impl_sse.p7_oprofile.p7_oprofile_Destroy(om)
#         # libeasel.sq.esl_sq_Destroy(dbsq)
#
#     #
#     return hits