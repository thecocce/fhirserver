unit FHIRSearchSyntax;


interface

uses
  SysUtils, RegularExpressions,
  StringSupport,
  AdvObjects;

Type
  TFSCompareOperation = (fscoEQ, fscoNE, fscoCO, fscoSW, fscoEW, fscoGT, fscoLT, fscoGE, fscoLE, fscoPR, fscoPO, fscoSS, fscoSB, fscoIN, fscoRE);
  TFSFilterLogicalOperation = (fsloAnd, fsloOr, fsloNot);

  TFSFilterItemType = (fsitParameter, fsitLogical);

  TFSFilter = class (TAdvObject)
  public
    function FilterItemType : TFSFilterItemType; virtual; abstract;
  end;

  TFSFilterParameterPath = class (TAdvObject)
  private
    FName : String;
    FFilter: TFSFilter;
    FNext: TFSFilterParameterPath;
    procedure SetFilter(const Value: TFSFilter);
    procedure SetNext(const Value: TFSFilterParameterPath);
  public
    Destructor Destroy; override;

    Property Name : String read FName write FName;
    Property Filter : TFSFilter read FFilter write SetFilter;
    Property Next : TFSFilterParameterPath read FNext write SetNext;
  end;

  TFSFilterParameter = class (TFSFilter)
  private
    FParamPath : TFSFilterParameterPath;
    FOperation : TFSCompareOperation;
    FValue : String;
    procedure SetParamPath(const Value: TFSFilterParameterPath);
  public
    Destructor Destroy; override;
    function FilterItemType : TFSFilterItemType; override;

    Property ParamPath : TFSFilterParameterPath read FParamPath write SetParamPath;
    Property Operation : TFSCompareOperation read FOperation write FOperation;
    Property Value : String read FValue write FValue;
  end;

  TFSFilterLogical = class (TFSFilter)
  private
    FFilter1 : TFSFilter;
    FOperation : TFSFilterLogicalOperation;
    FFilter2 : TFSFilter;
    procedure SetFilter1(const Value: TFSFilter);
    procedure SetFilter2(const Value: TFSFilter);
  public
    destructor Destroy; override;
    function FilterItemType : TFSFilterItemType; override;

    property Filter1 : TFSFilter read FFilter1 write SetFilter1;
    property Operation : TFSFilterLogicalOperation read FOperation write FOperation;
    property Filter2 : TFSFilter read FFilter2 write SetFilter2;
  end;


  TFSFilterLexType = (fsltEnded, fsltName, fsltString, fsltNUmber, fsltDot, fsltOpen, fsltClose, fsltOpenSq, fsltCloseSq);

  TFSFilterParser = class (TAdvObject)
  private
    original : String;
    cursor: integer;

    function IsDate(s : String): boolean;
    function peek : TFSFilterLexType;
    function peekCh : String;
    function ConsumeName : String;
    function ConsumeToken : String;
    function ConsumeNumberOrDate : String;
    function ConsumeString : String;

    function parse : TFSFilter; overload;
    function parseOpen : TFSFilter;
    function parseLogical(filter : TFSFilter) : TFSFilter;
    function parsePath(name : String) : TFSFilterParameterPath;
    function parseParameter(name: String): TFSFilter;

  public
    class procedure runTests;
    class procedure test(expression : String);
    class function parse(expression : String) : TFSFilter; overload;
  end;

  TFSCharIssuer = class (TAdvObject)
  private
    cursor : char;
  public
    constructor Create; override;
    function next : char;
  end;

const
  CODES_CompareOperation : array [TFSCompareOperation] of string = ('eq', 'ne', 'co', 'sw', 'ew', 'gt', 'lt', 'ge', 'le', 'pr', 'po', 'ss', 'sb', 'in', 're');
  XML_DATE_PATTERN = '[0-9]{4}(-(0[1-9]|1[0-2])(-(0[0-9]|[1-2][0-9]|3[0-1])(T([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](\.[0-9]+)?(Z|(\+|-)((0[0-9]|1[0-3]):[0-5][0-9]|14:00))?)?)?)?';

implementation

{ TFSFilterParameterPath }

destructor TFSFilterParameterPath.Destroy;
begin
  FFilter.Free;
  FNext.Free;
  inherited;
end;

procedure TFSFilterParameterPath.SetFilter(const Value: TFSFilter);
begin
  FFilter.Free;
  FFilter := Value;
end;

procedure TFSFilterParameterPath.SetNext(const Value: TFSFilterParameterPath);
begin
  FNext.Free;
  FNext := Value;
end;

{ TFSFilterParameter }

destructor TFSFilterParameter.Destroy;
begin
  FParamPath.Free;
  inherited;
end;

function TFSFilterParameter.FilterItemType: TFSFilterItemType;
begin
  result := fsitParameter;
end;

procedure TFSFilterParameter.SetParamPath(const Value: TFSFilterParameterPath);
begin
  FParamPath.Free;
  FParamPath := Value;
end;

{ TFSFilterLogical }

destructor TFSFilterLogical.Destroy;
begin
  FFilter1.Free;
  FFilter2.Free;
  inherited;
end;

function TFSFilterLogical.FilterItemType: TFSFilterItemType;
begin
  result := fsitLogical;
end;

procedure TFSFilterLogical.SetFilter1(const Value: TFSFilter);
begin
  FFilter1.Free;
  FFilter1 := Value;
end;

procedure TFSFilterLogical.SetFilter2(const Value: TFSFilter);
begin
  FFilter2.Free;
  FFilter2 := Value;
end;

{ TFSFilterParser }

class procedure TFSFilterParser.runTests;
begin
  test('userName eq "bjensen"');
  test('name eq loinc|1234');
  test('name in http://loinc.org/vs/LP234');
  test('date ge 2010-10-10');
  test('code sb snomed|diabetes');
  test('code ss snomed|diabetes-NIDDM-stage-1');
  test('related[type eq comp].target pr false');
end;

class procedure TFSFilterParser.test(expression: String);
var
  filter : TFSFilter;
begin
  filter := parse(expression);
  if filter = nil then
    raise exception.Create('parsing failed - returned nil');
  filter.Free;
end;

class function TFSFilterParser.parse(expression: String): TFSFilter;
var
  this : TFSFilterParser;
begin
  this := TFSFilterParser.Create;
  try
    this.original := expression;
    this.cursor := 1;
    result := this.parse;
  finally
    this.Free;
  end;
end;

function TFSFilterParser.parse : TFSFilter;
begin
  result := parseOpen;
  if cursor <= length(original) then
  begin
    result.Free;
    raise Exception.Create('Expression did not terminate at '+inttostr(cursor));
  end;
end;

function TFSFilterParser.parseOpen: TFSFilter;
var
  s : String;
begin
  if peek = fsltOpen then
  begin
    inc(Cursor);
    result := parseOpen;
    try
      if peek <> fsltClose then
        raise Exception.Create('Expected '')'' at '+inttostr(cursor)+' but found "'+peekCh+'"');
      inc(cursor);
      result.Link;
    finally
      result.Free;
    end;
  end
  else
  begin
    s := ConsumeName;
    if s = 'not' then
      result := parseLogical(nil)
    else
      result := parseParameter(s);
  end;
end;

function TFSFilterParser.parseParameter(name : String): TFSFilter;
var
  s : String;
  i : integer;
  filter : TFSFilterParameter;
begin
  filter := TFSFilterParameter.Create;
  try
    // 1. the path
    filter.ParamPath := parsePath(name);

    if peek <> fsltName then
      raise Exception.Create('Unexpected Character "'+PeekCh+'" at '+inttostr(cursor));
    s := ConsumeName;
    i := StringArrayIndexOfSensitive(CODES_CompareOperation, s);
    if (i < 0) then
      raise Exception.Create('Unknown operation "'+s+'" at '+inttostr(cursor));
    filter.FOperation := TFSCompareOperation(i);

    case peek of
      fsltName : filter.FValue := ConsumeToken;
      fsltNumber : filter.FValue := ConsumeNumberOrDate;
      fsltString : filter.FValue := ConsumeString;
    else
      raise Exception.Create('Unexpected Character "'+PeekCh+'" at '+inttostr(cursor));
    end;

    // check operation / value type results
    case Filter.FOperation of
      fscoPR: if (filter.FValue <> 'true') and (filter.FValue <> 'false') then raise Exception.Create('Value "'+filter.Value+'" not valid for Operation '+CODES_CompareOperation[filter.Operation]+' at '+inttostr(cursor));
      fscoPO: if not IsDate(filter.FValue) then raise Exception.Create('Value "'+filter.Value+'" not valid for Operation '+CODES_CompareOperation[filter.Operation]+' at '+inttostr(cursor));
    end;

    case peek of
      fsltName : result := parseLogical(filter);
      fsltEnded, fsltClose, fsltCloseSq : result := filter.Link as TFSFilter;
    else
      raise Exception.Create('Unexpected Character "'+PeekCh+'" at '+inttostr(cursor));
    end;
  finally
    filter.Free;
  end;
end;

function TFSFilterParser.parseLogical(filter: TFSFilter): TFSFilter;
var
  s : String;
  logical : TFSFilterLogical;
begin
  if (filter = nil) then
    s := 'not'
  else
    s := ConsumeName;
  if (s <> 'or') and (s <> 'and') and (s <> 'not') then
    raise Exception.Create('Unexpected Name "'+s+'" at '+inttostr(cursor));

  logical:= TFSFilterLogical.Create;
  try
    logical.FFilter1 := filter.Link as TFSFilter;
    if s = 'or' then
      logical.FOperation := fsloOr
    else if s = 'not' then
      logical.FOperation := fsloNot
    else
      logical.FOperation := fsloAnd;
    logical.FFilter2 := parseOpen;

    result := logical.Link as TFSFilter;
  finally
    logical.Free;
  end;
end;

function TFSFilterParser.parsePath(name: String): TFSFilterParameterPath;
begin
  result := TFSFilterParameterPath.Create;
  try
    result.Name := name;
    if peek = fsltOpenSq then
    begin
      inc(Cursor);
      result.FFilter := parseOpen;
      if peek <> fsltCloseSq then
        raise Exception.Create('Expected '']'' at '+inttostr(cursor)+' but found "'+peekCh+'"');
      inc(cursor);
    end;
    if peek = fsltDot then
    begin
      inc(Cursor);
      if peek <> fsltName then
        raise Exception.Create('Unexpected Character "'+PeekCh+'" at '+inttostr(cursor));
      result.FNext := parsePath(ConsumeName);
    end
    else if result.FFilter <> nil then
      raise Exception.Create('Expected ''.'' at '+inttostr(cursor)+' but found "'+peekCh+'"');

    result.Link;
  finally
    result.Free;
  end;

end;

function TFSFilterParser.peek: TFSFilterLexType;
begin
  while (cursor <= length(original)) and (original[cursor] = ' ') do
    inc(cursor);

  if cursor > length(original) then
    result := fsltEnded
  else
   case original[cursor] of
     'a'..'z', 'A'..'Z' : result := fsltName;
     '0'..'9' : result := fsltNumber;
     '"' : result := fsltString;
     '.' : result := fsltDot;
     '(' : result := fsltOpen;
     ')' : result := fsltClose;
     '[' : result := fsltOpenSq;
     ']' : result := fsltCloseSq;
   else
     raise Exception.Create('Unknown Character "'+PeekCh+'"  at '+inttostr(cursor));
   end;
end;

function TFSFilterParser.peekCh: String;
begin
  if cursor > length(original) then
    result := '[end!]'
  else
    result := original[cursor];
end;

function TFSFilterParser.ConsumeName: String;
var
  i : integer;
begin
  i := cursor;
  repeat
    inc(i);
  until (i > length(original)) or not CharInSet(original[i], ['a'..'z', 'A'..'Z', '-', '_', ':']);
  result := copy(original, cursor, i - cursor);
  cursor := i;
end;

function TFSFilterParser.ConsumeNumberOrDate: String;
var
  i : integer;
begin
  i := cursor;
  repeat
    inc(i);
  until (i > length(original)) or not CharInSet(original[i], ['0'..'9', '.', '-', ':', '+', 'T']);
  result := copy(original, cursor, i - cursor);
  cursor := i;
end;

function TFSFilterParser.ConsumeString: String;
var
  l : integer;
begin
  inc(cursor);
  setLength(result, length(original)); // can't be longer than that
  l := 0;
  while (cursor <= length(original)) and (original[cursor] <> '"') do
  begin
    inc(l);
    if (cursor < length(original)) and (original[cursor] <> '\') then
      result[l] := original[cursor]
    else
    begin
      inc(cursor);
      if (original[cursor] = '"') then
        result[l] := '"'
      else if (original[cursor] = 't') then
        result[l] := #9
      else if (original[cursor] = 'r') then
        result[l] := #13
      else if (original[cursor] = 'n') then
        result[l] := #10
      else
        raise Exception.Create('Unknown escape sequence at '+inttostr(cursor));
    end;
    inc(cursor);
  end;
  SetLength(result, l);
  if (cursor > length(original)) or (original[cursor] <> '"') then
    raise Exception.Create('Problem with string termination at '+inttostr(cursor));
  if result = '' then
    raise Exception.Create('Problem with string at '+inttostr(cursor)+': cannot be empty');

  inc(cursor);
end;

function TFSFilterParser.ConsumeToken: String;
var
  i : integer;
begin
  i := cursor;
  repeat
    inc(i);
  until (i > length(original)) or (Ord(original[i]) <= 32) or StringIsWhitespace(original[i]) or (original[i] = ']') or (original[i] = ']');
  result := copy(original, cursor, i - cursor);
  cursor := i;
end;


function TFSFilterParser.IsDate(s: String): boolean;
var
  reg :  TRegex;
begin
  reg := TRegex.Create(XML_DATE_PATTERN);
  result := reg.IsMatch(s);
end;

{ TFSCharIssuer }

constructor TFSCharIssuer.Create;
begin
  inherited;
  cursor := 'a';
end;

function TFSCharIssuer.next: char;
begin
  result := cursor;
  inc(cursor);
end;


end.

