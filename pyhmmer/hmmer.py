# coding: utf-8

import queue
import threading
import typing
import multiprocessing

from .easel import Alphabet, Sequence, SequenceFile
from .plan7 import Pipeline, TopHits, HMM, HMMFile


class _PipelineThread(threading.Thread):

    def __init__(
        self,
        sequences: typing.Iterable[Sequence],
        hmm_queue: queue.Queue[typing.Optional[HMM]]
    ) -> None:
        super().__init__()
        self.pipeline = Pipeline(alphabet=Alphabet.amino())
        self.hits = TopHits()
        self.sequences = sequences
        self.hmm_queue = hmm_queue

    def run(self) -> None:
        while True:
            hmm = self.hmm_queue.get()
            if hmm is None:
                self.hmm_queue.task_done()
                return
            self.pipeline.search(hmm, self.sequences, hits=self.hits)
            self.hmm_queue.task_done()


def hmmsearch(
    hmms: typing.Iterable[HMM],
    sequences: typing.List[Sequence],
    cpus: int = 0
) -> TopHits:
    # count the number of CPUs to use
    _cpus = cpus if cpus > 0 else multiprocessing.cpu_count()

    # create the queue to pass the HMM objects around
    hmm_queue = typing.cast(queue.Queue[typing.Optional[HMM]], queue.Queue())

    # create and launch one pipeline thread per CPU
    threads = []
    for _ in range(_cpus):
        thread = _PipelineThread(sequences, hmm_queue)
        thread.start()
        threads.append(thread)

    # queue the HMMs passed as arguments
    for hmm in hmms:
        hmm_queue.put(hmm)

    # poison-pill the queue so that threads terminate when they
    # have consumed all the HMMs
    for _ in threads:
        hmm_queue.put(None)

    # wait for all HMMs to be processed
    hmm_queue.join()

    # merge the hits from each pipeline and return the merged hits
    hits = threads[0].hits
    for thread in threads[1:]:
        hits += thread.hits
    return hits


# add a very limited CLI so that this module can be invoked in a shell:
#     $ python -m pyhmmer.hmmsearch <hmmfile> <seqdb>
if __name__ == "__main__":

    import argparse
    import sys

    parser = argparse.ArgumentParser()
    parser.add_argument("-j", "--jobs", required=False, default=0, type=int)
    parser.add_argument("hmmfile")
    parser.add_argument("seqdb")
    args = parser.parse_args()

    with SequenceFile(args.seqdb) as seqs:
        sequences = list(seqs)

    with HMMFile(args.hmmfile) as hmms:
        hmmsearch(hmms, sequences, cpus=args.jobs)