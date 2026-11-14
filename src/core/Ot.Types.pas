unit Ot.Types;

interface

uses System.SysUtils;

type
  TOtBlockMap = record
    Verified, Received, Requested: TBytes;
    TotalBlocks: Int64;
    BlockSize: Integer;
  end;
  TOtAddOptions = record
    Subfolder, Trackers: string;
    MagnetLink: string;
    Start, Sequential: Boolean;
    NeedsVerification: Boolean;
    DownloadKiB, UploadKiB: Integer;
  end;
  TOtMetaFile = record
    Size: Int64;
    Path: string;
  end;
  TOtMetadata = class
  public
    Name, Comment, Creator, Publisher, PublisherURL, InfoHash, WebSeeds: string;
    CreatedUTC: Int64;
    Pieces, PieceLength: Integer;
    TotalBytes: Int64;
    Files: TArray<TOtMetaFile>;
    Trackers: TArray<string>;
  end;
  TOtSnapshot = record
    TotalBytes: Int64;
    DoneBytes: Int64;
    DownloadRate: Integer;
    UploadRate: Integer;
    Peers: Integer;
    Seeds: Integer;
    State: Integer;
    Progress: Integer; // millionths
    Name: array[0..511] of AnsiChar; // UTF-8
    Error: array[0..511] of AnsiChar;
  end;
  TOtSessionOptions = record
    Size: Cardinal;
    Port, DownloadBytes, UploadBytes, Connections: Integer;
    DiscoveryFlags, StopTrackerTimeout, Reserved: Integer;
  end;
  TOtPartialBlock = record
    Piece, Block, State, Reserved: Integer;
  end;
  TOtPieceHeader = record
    TotalBytes: Int64;
    PieceLength, PieceCount, BlockSize, PartialCount, IsSeed, HaveBytes: Integer;
  end;
  TOtPieceState = record
    TotalBytes: Int64;
    PieceLength, PieceCount, BlockSize: Integer;
    IsSeeding: Boolean;
    HavePieces: TBytes; // MSB-first bitfield
    PartialBlocks: TArray<TOtPartialBlock>;
  end;
  TOtPreparedTask = record
    Paths, Trackers: TArray<string>;
    DownloadBytes, UploadBytes: Integer;
  end;
  TOtSelectionSummary = record
    Count: Integer;
    Bytes: Int64;
    Counts, Selected: array[0..3] of Integer;
  end;

implementation

end.
