# coding: utf-8
import abc
import collections.abc
import types
import typing

class Alphabet(object):
    @classmethod
    def dna(self) -> Alphabet: ...
    @classmethod
    def rna(self) -> Alphabet: ...
    @classmethod
    def amino(self) -> Alphabet: ...
    def __repr__(self) -> str: ...
    def __eq__(self, other: object) -> bool: ...
    @property
    def K(self) -> int: ...
    @property
    def Kp(self) -> int: ...
    @property
    def symbols(self) -> str: ...

class Bitfield(typing.Sequence[bool]):
    def __init__(self, length: int) -> None: ...
    def __len__(self) -> int: ...
    @typing.overload
    def __getitem__(self, index: int) -> bool: ...
    @typing.overload
    def __getitem__(self, index: slice) -> typing.Sequence[bool]: ...
    def __setitem__(self, index: int, value: bool) -> None: ...
    def count(self, value: bool = True) -> int: ...
    def toggle(self, index: int) -> None: ...

class MSA(abc.ABC):
    @abc.abstractmethod
    def __init__(
        self, nsequences: int, length: typing.Optional[int] = None
    ) -> None: ...
    def __copy__(self) -> MSA: ...
    def __eq__(self, other: object) -> bool: ...
    @abc.abstractmethod
    def copy(self) -> MSA: ...
    def checksum(self) -> int: ...

class TextMSA(MSA):
    def __init__(
        self, nsequences: int, length: typing.Optional[int] = None
    ) -> None: ...
    def __copy__(self) -> TextMSA: ...
    def copy(self) -> TextMSA: ...
    def digitize(self, alphabet: Alphabet) -> DigitalMSA: ...

class DigitalMSA(MSA):
    alphabet: Alphabet
    def __init__(
        self, alphabet: Alphabet, nsequences: int, length: typing.Optional[int] = None
    ) -> None: ...
    def __copy__(self) -> DigitalMSA: ...
    def copy(self) -> DigitalMSA: ...

class Sequence(typing.Sized, abc.ABC):
    @abc.abstractmethod
    def __init__(self) -> None: ...
    def __copy__(self) -> Sequence: ...
    def __len__(self) -> int: ...
    @property
    def accession(self) -> bytes: ...
    @accession.setter
    def accession(self, accession: bytes) -> None: ...
    def checksum(self) -> int: ...
    def clear(self) -> None: ...
    @abc.abstractmethod
    def copy(self) -> Sequence: ...

class TextSequence(Sequence):
    def __init__(
        self,
        name: bytes = None,
        sequence: bytes = None,
        description: bytes = None,
        accession: bytes = None,
        secondary_structure: bytes = None,
    ) -> None: ...
    def copy(self) -> TextSequence: ...
    def digitize(self, alphabet: Alphabet) -> DigitalSequence: ...

class DigitalSequence(Sequence):
    alphabet: Alphabet
    def copy(self) -> DigitalSequence: ...

class SequenceFile(typing.ContextManager[SequenceFile], typing.Iterator[Sequence]):
    @classmethod
    def parse(cls, buffer: bytes, format: str) -> Sequence: ...
    @classmethod
    def parseinto(cls, seq: Sequence, buffer: bytes, format: str) -> Sequence: ...
    def __init__(self, file: str, format: typing.Optional[str] = None) -> None: ...
    def __enter__(self) -> SequenceFile: ...
    def __exit__(
        self,
        exc_type: typing.Optional[typing.Type[BaseException]],
        exc_value: typing.Optional[BaseException],
        traceback: typing.Optional[types.TracebackType],
    ) -> bool: ...
    def __iter__(self) -> SequenceFile: ...
    def __next__(self) -> Sequence: ...
    def read(self) -> typing.Optional[Sequence]: ...
    def read_info(self) -> typing.Optional[Sequence]: ...
    def read_seq(self) -> typing.Optional[Sequence]: ...
    def readinto(self, seq: Sequence) -> typing.Optional[Sequence]: ...
    def readinto_seq(self, seq: Sequence) -> typing.Optional[Sequence]: ...
    def readinto_info(self, seq: Sequence) -> typing.Optional[Sequence]: ...
    def close(self) -> None: ...
    def guess_alphabet(self) -> typing.Optional[Alphabet]: ...
    def set_digital(self, alphabet: Alphabet) -> None: ...

class SSIReader(object):
    def __init__(self, file: str) -> None: ...
    def __enter__(self) -> SSIReader: ...
    def __exit__(
        self,
        exc_type: typing.Optional[typing.Type[BaseException]],
        exc_value: typing.Optional[BaseException],
        traceback: typing.Optional[types.TracebackType],
    ) -> bool: ...
    def close(self) -> None: ...
