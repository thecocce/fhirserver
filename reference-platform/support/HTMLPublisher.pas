unit HTMLPublisher;

interface

uses
  SysUtils,
  EncodeSupport,
  AdvObjects,
  FHIRBase,
  FHIRParserBase,
  FHIRConstants; // todo: really need to sort out how XHTML template is done

Type

  THtmlPublisher = class (TAdvObject)
  private
    FBuilder : TStringBuilder;
    FBaseURL: String;
    FLang: String;
    FVersion: String;
  public
    Constructor Create; Override;
    Destructor Destroy; Override;

    procedure Header(s : String);
    procedure Done;

    procedure Line;
    procedure StartPre;
    procedure endPre;

    procedure Heading(level : integer; text : String);
    procedure StartParagraph;
    procedure EndParagraph;
    procedure AddParagraph(text : String = '');
    procedure AddTextPlain(text : String);
    procedure AddTitle(text : String);
    procedure AddText(text : String; bold, italics : boolean);

    procedure URL(text, url : String; hint : string = '');
    procedure ParaURL(text, url : String);

    procedure StartTable(borders : boolean; clss : String = '');
    procedure StartTableRow;
    procedure StartRowFlip(i : integer);
    procedure StartTableCell(span : integer = 1);
    procedure EndTableCell;
    procedure EndTableRow;
    procedure EndTable;
    procedure AddTableCellURL(text, url : String; hint : String = '');
    procedure AddTableCell(text : String; bold : boolean = false);

    procedure StartList(ordered : boolean = false);
    procedure EndList(ordered : boolean = false);
    procedure StartListItem;
    procedure EndListItem;
    procedure StartBlockQuote;
    procedure EndBlockQuote;

    procedure StartForm(method, action : String);
    procedure TextInput(name : String; length : integer = 20);
    procedure checkbox(name, value, text : String);
    procedure hiddenInput(name, value : String);
    procedure Submit(name : String);
    procedure EndForm;
    procedure writeXhtml(node : TFhirXHtmlNode);
    procedure Spacer;

    function output : String;
    Property BaseURL : String read FBaseURL write FBaseURL;
    Property Lang : String read FLang write FLang;
    Property Version : String read FVersion write FVersion;
  end;



implementation

{ THtmlPublisher }

procedure THtmlPublisher.AddParagraph(text: String);
begin
  StartParagraph;
  AddTextPlain(text);
  EndParagraph;
end;

procedure THtmlPublisher.AddTableCell(text: String; bold: boolean);
begin
  StartTableCell;
  addtext(text, bold, false);
  EndTableCell;
end;

procedure THtmlPublisher.AddTableCellURL(text, url: String; hint : String = '');
begin
  StartTableCell;
  self.URL(text, url, hint);
  EndTableCell;
end;

procedure THtmlPublisher.AddText(text: String; bold, italics: boolean);
begin
  if bold then
    FBuilder.Append('<b>');
  if italics then
    FBuilder.Append('<i>');
  AddTextPlain(text);
  if italics then
    FBuilder.Append('</i>');
  if bold then
    FBuilder.Append('</b>');
end;

procedure THtmlPublisher.AddTextPlain(text: String);
begin
  FBuilder.Append(EncodeXML(text, xmlText));
end;

procedure THtmlPublisher.AddTitle(text: String);
begin
  AddText(text, true, false);
end;

procedure THtmlPublisher.checkbox(name, value, text: String);
begin
  FBuilder.Append('<input type="checkbox" name="'+name+'" value="'+value+'""/> '+text);
end;

constructor THtmlPublisher.Create;
begin
  inherited;
  FBuilder := TStringBuilder.create;
end;

destructor THtmlPublisher.Destroy;
begin
  FBuilder.Free;
  inherited;
end;

procedure THtmlPublisher.Done;
begin
  FBuilder.Append(TFHIRXhtmlComposer.footer(BaseURL, lang));
end;

procedure THtmlPublisher.EndBlockQuote;
begin
  FBuilder.Append('</blockquote>'#13#10);
end;

procedure THtmlPublisher.EndForm;
begin
  FBuilder.Append('</form>'#13#10);
end;

procedure THtmlPublisher.EndList(ordered: boolean);
begin
  if ordered then
    FBuilder.Append('</ol>'#13#10)
  else
    FBuilder.Append('</ul>'#13#10);
end;

procedure THtmlPublisher.EndListItem;
begin
  FBuilder.Append('</li>'#13#10);
end;

procedure THtmlPublisher.EndParagraph;
begin
  FBuilder.Append('<p>'#13#10);
end;

procedure THtmlPublisher.endPre;
begin
  FBuilder.Append('<pre>'#13#10);
end;

procedure THtmlPublisher.EndTable;
begin
  FBuilder.Append('</table>'#13#10);
end;

procedure THtmlPublisher.EndTableCell;
begin
  FBuilder.Append('</td>'#13#10);
end;

procedure THtmlPublisher.EndTableRow;
begin
  FBuilder.Append('</tr>'#13#10);
end;

procedure THtmlPublisher.Header(s: String);
begin
  FBuilder.Append(
  '<?xml version="1.0" encoding="UTF-8"?>'#13#10+
  '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"'#13#10+
  '       "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">'#13#10+
  ''#13#10+
  '<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">'#13#10+
  '<head>'#13#10+
  '    <title>'+s+'FHIR Server</title>'#13#10+
  TFHIRXhtmlComposer.pagelinks+
  FHIR_JS+
  '</head>'#13#10+
  ''#13#10+
  '<body>'#13#10+
  TFHIRXhtmlComposer.Header(nil, BaseURL, Lang, Version)+
  '<h1>'+s+'</h1>'#13#10);
end;

procedure THtmlPublisher.Heading(level: integer; text: String);
begin
  FBuilder.Append('<h'+inttostr(level)+'>');
  AddTextPlain(text);
  FBuilder.Append('</h'+inttostr(level)+'>');
end;

procedure THtmlPublisher.hiddenInput(name, value: String);
begin
  FBuilder.Append('<input type="hidden" name="'+name+'" value="'+value+'"/>');
end;


procedure THtmlPublisher.Line;
begin
  FBuilder.Append('<hr/>'#13#10);
end;

function THtmlPublisher.output: String;
begin
  result := FBuilder.ToString;
end;

procedure THtmlPublisher.ParaURL(text, url: String);
begin
  StartParagraph;
  self.URL(text, url);
  EndParagraph;
end;

procedure THtmlPublisher.Spacer;
begin
  FBuilder.Append('&nbsp;');
end;

procedure THtmlPublisher.StartBlockQuote;
begin
  FBuilder.Append('<blockquote>');
end;

procedure THtmlPublisher.StartForm(method, action: String);
begin
  FBuilder.Append('<form method="'+method+'" action="'+action+'">'#13#10);
end;

procedure THtmlPublisher.StartList(ordered: boolean);
begin
  if ordered then
    FBuilder.Append('<ol>')
  else
    FBuilder.Append('<ul>');
end;

procedure THtmlPublisher.StartListItem;
begin
  FBuilder.Append('<li>');
end;

procedure THtmlPublisher.StartParagraph;
begin
  FBuilder.Append('<p>');
end;

procedure THtmlPublisher.StartPre;
begin
  FBuilder.Append('<pre>'#13#10);
end;

procedure THtmlPublisher.StartRowFlip(i: integer);
begin
  FBuilder.Append('<tr>')
end;

procedure THtmlPublisher.StartTable(borders: boolean; clss : String);
begin
  if clss <> '' then
    clss := ' class="'+clss+'"';
  if borders then
    FBuilder.Append('<table border="1"'+clss+'>')
  else
    FBuilder.Append('<table border="0"'+clss+'>');
end;

procedure THtmlPublisher.StartTableCell;
begin
  if (span <> 1) then
    FBuilder.Append('<td colspan="'+inttostr(span)+'">')
  else
   FBuilder.Append('<td>')
end;

procedure THtmlPublisher.StartTableRow;
begin
  FBuilder.Append('<tr>')
end;

procedure THtmlPublisher.Submit(name: String);
begin
  FBuilder.Append('<input type="submit" value="'+name+'"/>');
end;

procedure THtmlPublisher.TextInput(name: String; length: integer);
begin
  FBuilder.Append('<input type="text" name="'+name+'" size="'+inttostr(length)+'"/>');
end;

procedure THtmlPublisher.URL(text, url, hint: String);
begin
  if (hint <> '') then
    FBuilder.Append('<a href="'+url+'" title="'+EncodeXML(hint, xmlAttribute)+'">')
  else
    FBuilder.Append('<a href="'+url+'">');
  AddTextPlain(text);
  FBuilder.Append('</a>');
end;

procedure THtmlPublisher.writeXhtml(node: TFhirXHtmlNode);
var
  i : integer;
begin
  case node.NodeType of
    fhntElement, fhntDocument:
      begin
        FBuilder.Append('<'+node.Name);
        for i := 0 to node.Attributes.Count - 1 do
          FBuilder.Append(' '+node.Attributes[i].Name+'="'+EncodeXML(node.Attributes[i].value, xmlAttribute)+'"');
        if node.ChildNodes.Count = 0 then
          FBuilder.Append('/>')
        else
        begin
          FBuilder.Append('>');
          for i := 0 to node.ChildNodes.Count - 1 do
            writeXhtml(node.ChildNodes[i]);
          FBuilder.Append('</'+node.Name+'>');
        end;
      end;
    fhntText:
      AddTextPlain(node.Content);
    fhntComment:
      FBuilder.Append('<!-- '+EncodeXML(node.Content, xmlText)+' -->');
  end;
end;

end.
