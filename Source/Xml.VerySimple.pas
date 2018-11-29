{ VerySimpleXML v2.2.2 - a lightweight, one-unit, cross-platform XML reader/writer
  for Delphi 2010-XE10.2 by Dennis Spreen
  http://blog.spreendigital.de/2011/11/10/verysimplexml-a-lightweight-delphi-xml-reader-and-writer/

  (c) Copyrights 2011-2018 Dennis D. Spreen <dennis@spreendigital.de>
  This unit is free and can be used for any needs. The introduction of
  any changes and the use of those changed library is permitted without
  limitations. Only requirement:
  This text must be present without changes in all modifications of library.

  * The contents of this file are used with permission, subject to
  * the Mozilla Public License Version 1.1 (the "License"); you may   *
  * not use this file except in compliance with the License. You may  *
  * obtain a copy of the License at                                   *
  * http:  www.mozilla.org/MPL/MPL-1.1.html                           *
  *                                                                   *
  * Software distributed under the License is distributed on an       *
  * "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or    *
  * implied. See the License for the specific language governing      *
  * rights and limitations under the License.                         *
}
{
  XSD schema support and some useful things - made by NevTon.
  Portions copyright (C) 2015-2018 Grzegorz Molenda aka NevTon; ViTESOFT.net; <gmnevton@o2.pl>
}
unit Xml.VerySimple;

interface

{.$DEFINE LOGGING}

uses
  Classes, SysUtils, Generics.Defaults, Generics.Collections;

const
  TXmlSpaces = #$20 + #$0A + #$0D + #9;

type
  TXmlVerySimple = class;
  TXmlNode = class;
  TXmlNodeType = (ntElement, ntText, ntCData, ntProcessingInstr, ntComment, ntDocument, ntDocType, ntXmlDecl);
  TXmlNodeTypes = set of TXmlNodeType;
  TXmlNodeList = class;
  TXmlAttributeType = (atValue, atSingle);
  TXmlNodeSearchType = (nsRecursive, nsSearchWithoutPrefix);
  TXmlNodeSearchTypes = set of TXmlNodeSearchType;
  TXmlOptions = set of (doNodeAutoIndent, doCompact, doCompactWithBreakes, doParseProcessingInstr, doPreserveWhiteSpace, doCaseInsensitive,
    doSearchExcludeNamespacePrefix, doWriteBOM, doSkipHeader);
  TExtractTextOptions = set of (etoDeleteStopChar, etoStopString);

//  {$IFNDEF AUTOREFCOUNT}
//  WeakAttribute = class(TCustomAttribute);
//  {$ENDIF}
{$IF CompilerVersion >= 24}
  TStreamReaderFillBuffer = procedure(var Encoding: TEncoding) of object;

  TXmlStreamReader = class(TStreamReader)
  protected
    FBufferedData: TStringBuilder;
    FNoDataInStream: PBoolean;
    FFillBuffer: TStreamReaderFillBuffer;
    ///	<summary> Call to FillBuffer method of TStreamReader </summary>
    procedure FillBuffer;
  public
    ///	<summary> Extend the TStreamReader with RTTI pointers </summary>
    constructor Create(Stream: TStream; Encoding: TEncoding; DetectBOM: Boolean = False; BufferSize: Integer = 4096);
    ///	<summary> Assures the read buffer holds at least Value characters </summary>
    function PrepareBuffer(Value: Integer): Boolean;
    ///	<summary> Extract text until chars found in StopChars </summary>
    function ReadText(const StopChars: String; Options: TExtractTextOptions): String; virtual;
    ///	<summary> Returns fist char but does not removes it from the buffer </summary>
    function FirstChar: Char;
    ///	<summary> Proceed with the next character(s) (value optional, default 1) </summary>
    procedure IncCharPos(Value: Integer = 1); virtual;
    ///	<summary> Returns True if the first uppercased characters at the current position match Value </summary>
    function IsUppercaseText(const Value: String): Boolean; virtual;
  end;
{$IFEND}

  TXmlAttribute = class(TObject)
  private
    FValue: String;
    procedure SetValue(const Value: String);
  public
    ///	<summary> Attribute name </summary>
    Name: String;
    ///	<summary> Attributes without values are set to atSingle, else to atValue </summary>
    AttributeType: TXmlAttributeType;
    ///	<summary> Create a new attribute </summary>
    constructor Create; virtual;
    ///	<summary> Return the attribute as a String </summary>
    function AsString: String;
    /// <summary> Escapes XML control characters </summar>
    class function Escape(const Value: String): String; virtual;
    ///	<summary> Attribute value (always a String) </summary>
    property Value: String read FValue write SetValue;
  end;

  TXmlAttributeList = class(TObjectList<TXmlAttribute>)
  public
    ///	<summary> The xml document of the attribute list of the node</summary>
    [Weak] Document: TXmlVerySimple;
    ///	<summary> Add a name only attribute </summary>
    function Add(const Name: String): TXmlAttribute; overload; virtual;
    ///	<summary> Returns the attribute given by name (case insensitive), NIL if no attribute found </summary>
    function Find(const Name: String): TXmlAttribute; virtual;
    ///	<summary> Deletes an attribute given by name (case insensitive) </summary>
    procedure Delete(const Name: String); overload; virtual;
    ///	<summary> Returns True if an attribute with the given name is found (case insensitive) </summary>
    function HasAttribute(const AttrName: String): Boolean; virtual;
    ///	<summary> Returns the attributes in string representation </summary>
    function AsString: String; virtual;
    ///	<summary> Returns the attributes in TStrings list representation </summary>
    function AsStrings: TStrings; virtual;
  end;

  TXmlNodeCallBack = reference to function(Node: TXmlNode): Boolean;

  TXmlNode = class(TObject)
  private
    ///	<summary> Name of the node </summary>
    FName,
    FPrefix: String; // Node name
    FLevel: Cardinal; // node level in tree structure
    FIndex: Cardinal; // node index in nodes list structure
    FPrevSibling,           // link to the node's previous sibling or nil if it is the first node
    FNextSibling: TXmlNode; // link to the node's next sibling or nil if it is the last node

    procedure SetName(Value: String);
    function GetName: String;
    function IsSame(const Value1, Value2: String): Boolean;
    ///	<summary> Find a child node by its name in tree </summary>
    function FindNodeRecursive(const Name: String; NodeTypes: TXmlNodeTypes = [ntElement]; const SearchOptions: TXmlNodeSearchTypes = []): TXmlNode; overload; virtual;
    ///	<summary> Find a child node by name and attribute name in tree </summary>
    function FindNodeRecursive(const Name, AttrName: String; NodeTypes: TXmlNodeTypes = [ntElement]; const SearchOptions: TXmlNodeSearchTypes = []): TXmlNode; overload; virtual;
    ///	<summary> Find a child node by name, attribute name and attribute value in tree </summary>
    function FindNodeRecursive(const Name, AttrName, AttrValue: String; NodeTypes: TXmlNodeTypes = [ntElement]; const SearchOptions: TXmlNodeSearchTypes = []): TXmlNode; overload; virtual;
    ///	<summary> Return a list of child nodes with the given name and (optional) node types in tree </summary>
//    function FindNodesRecursive(const Name: String; NodeTypes: TXmlNodeTypes = [ntElement]): TXmlNodeList; virtual;
  protected
    [Weak] FDocument: TXmlVerySimple;
    procedure SetDocument(Value: TXmlVerySimple);
    function GetAttr(const AttrName: String): String; virtual;
    procedure SetAttr(const AttrName: String; const AttrValue: String); virtual;
  public
    ///	<summary> All attributes of the node </summary>
    AttributeList: TXmlAttributeList;
    ///	<summary> List of child nodes, never NIL </summary>
    ChildNodes: TXmlNodeList;
    ///	<summary> The node type, see TXmlNodeType </summary>
    NodeType: TXmlNodeType;
    ///	<summary> Parent node, may be NIL </summary>
    [Weak] ParentNode: TXmlNode;
    ///	<summary> User data value of the node </summary>
    UserData: String;
    ///	<summary> Text value of the node </summary>
    Text: String;
    /// <summary> Creates a new XML node </summary>
    constructor Create(ANodeType: TXmlNodeType = ntElement); virtual;
    ///	<summary> Removes the node from its parent and frees all of its childs </summary>
    destructor Destroy; override;
    /// <summary> Assigns an existing XML node to this </summary>
    procedure Assign(const Node: TXmlNode); virtual;
    ///	<summary> Gets name and prefix (if available) from given value string </summary>
    class procedure GetNameAndPrefix(const Value: String; var Name, Prefix: String);
    ///	<summary> Clears the attributes, the text and all of its child nodes (but not the name) </summary>
    procedure Clear;
    ///	<summary> Find a child node by its name </summary>
    function FindNode(const Name: String; NodeTypes: TXmlNodeTypes = [ntElement]; const SearchOptions: TXmlNodeSearchTypes = []): TXmlNode; overload; virtual;
    ///	<summary> Find a child node by name and attribute name </summary>
    function FindNode(const Name, AttrName: String; NodeTypes: TXmlNodeTypes = [ntElement]; const SearchOptions: TXmlNodeSearchTypes = []): TXmlNode; overload; virtual;
    ///	<summary> Find a child node by name, attribute name and attribute value </summary>
    function FindNode(const Name, AttrName, AttrValue: String; NodeTypes: TXmlNodeTypes = [ntElement]; const SearchOptions: TXmlNodeSearchTypes = []): TXmlNode; overload; virtual;
    ///	<summary> Return a list of child nodes with the given name and (optional) node types </summary>
    function FindNodes(const Name: String; NodeTypes: TXmlNodeTypes = [ntElement]; const SearchWithoutPrefix: Boolean = False): TXmlNodeList; virtual;
    // Loops trough childnodes with given Name
    procedure ScanNodes(Name: String; CallBack: TXmlNodeCallBack; const SearchWithoutPrefix: Boolean = False);
    ///	<summary> Returns True if the node has prefix in Name property </summary>
    function HasPrefix: Boolean; virtual;
    ///	<summary> Returns True if the attribute exists </summary>
    function HasAttribute(const AttrName: String): Boolean; virtual;
    ///	<summary> Returns True if a child node with that name exits </summary>
    function HasChild(const Name: String; NodeTypes: TXmlNodeTypes = [ntElement]): Boolean; virtual;
    ///	<summary> Add a child node with an optional NodeType (default: ntElement)</summary>
    function AddChild(const AName: String; ANodeType: TXmlNodeType = ntElement): TXmlNode; virtual;
    ///	<summary> Removes a child node</summary>
    function RemoveChild(const Node: TXmlNode): Integer; virtual;
    ///	<summary> Moves a child node</summary>
    function MoveChild(const FromNode, ToNode: TXmlNode): TXmlNode; virtual;
    ///	<summary> Add a nodes tree from existing node </summary>
    procedure AddNodes(const RootNode: TXmlNode; const AddRootNode: Boolean = False); virtual;
    ///	<summary> Insert a child node at a specific position with a (optional) NodeType (default: ntElement)</summary>
    function InsertChild(const Name: String; Position: Integer; NodeType: TXmlNodeType = ntElement): TXmlNode; overload; virtual;
    ///	<summary> Insert a child node at a specific position</summary>
    function InsertChild(const NodeToInsert: TXmlNode; Position: Integer): TXmlNode; overload; virtual;
    ///	<summary> Insert a child node before a specific node with a (optional) NodeType (default: ntElement)</summary>
    function InsertChildBefore(const BeforeNode: TXmlNode; const Name: String; NodeType: TXmlNodeType = ntElement): TXmlNode; overload; virtual;
    ///	<summary> Insert a child node before a specific node</summary>
    function InsertChildBefore(const BeforeNode: TXmlNode; const NodeToInsert: TXmlNode): TXmlNode; overload; virtual;
    ///	<summary> Insert a child node after a specific node with a (optional) NodeType (default: ntElement)</summary>
    function InsertChildAfter(const AfterNode: TXmlNode; const Name: String; NodeType: TXmlNodeType = ntElement): TXmlNode; overload; virtual;
    ///	<summary> Insert a child node after a specific node</summary>
    function InsertChildAfter(const AfterNode: TXmlNode; const NodeToInsert: TXmlNode): TXmlNode; overload; virtual;
    ///	<summary> Fluent interface for setting the text of the node </summary>
    function SetText(const Value: String): TXmlNode; virtual;
    ///	<summary> Fluent interface for setting the node attribute given by attribute name and attribute value </summary>
    function SetAttribute(const AttrName, AttrValue: String): TXmlNode; virtual;
    ///	<summary> Returns first child or NIL if there aren't any child nodes </summary>
    function FirstChild: TXmlNode; virtual;
    ///	<summary> Returns last child node or NIL if there aren't any child nodes </summary>
    function LastChild: TXmlNode; virtual;
    ///	<summary> Returns previous sibling </summary>
    function PreviousSibling: TXmlNode; overload; virtual;
    ///	<summary> Returns next sibling </summary>
    function NextSibling: TXmlNode; overload; virtual;
    ///	<summary> Returns True if the node has at least one child node </summary>
    function HasChildNodes: Boolean; virtual;
    ///	<summary> Returns True if the node has a text content and no child nodes </summary>
    function IsTextElement: Boolean; virtual;
    ///	<summary> Fluent interface for setting the node type </summary>
    function SetNodeType(Value: TXmlNodeType): TXmlNode; virtual;
    ///	<summary> Name of the node </summary>
    property Name: String read FName write SetName;
    ///	<summary> Name of the node </summary>
    property NameWithPrefix: String read GetName;
    ///	<summary> Prefix of the node Name </summary>
    property Prefix: String read FPrefix;
    ///	<summary> Attributes of a node, accessible by attribute name (case insensitive) </summary>
    property Attributes[const AttrName: String]: String read GetAttr write SetAttr;
    ///	<summary> The xml document of the node </summary>
    property Document: TXmlVerySimple read FDocument write SetDocument;
    ///	<summary> The node name, same as property Name </summary>
    property NodeName: String read FName write SetName;
    ///	<summary> The node text, same as property Text </summary>
    property NodeValue: String read Text write Text;
    ///	<summary> The node Level in tree </summary>
    property Level: Cardinal read FLevel;
    ///	<summary> The node Index in list </summary>
    property Index: Cardinal read FIndex;
  end;

  TXmlNodeList = class(TObjectList<TXmlNode>)
  private
    function IsSame(const Value1, Value2: String): Boolean;
  public
    ///	<summary> The xml document of the node list </summary>
    [Weak] Document: TXmlVerySimple;
    ///	<summary> The parent node of the node list </summary>
    [Weak] Parent: TXmlNode;
    ///	<summary> Adds a node and sets the parent of the node to the parent of the list </summary>
    function Add(Value: TXmlNode): Integer; overload; virtual;
    ///	<summary> Creates a new node of type NodeType (default ntElement) and adds it to the list </summary>
    function Add(NodeType: TXmlNodeType = ntElement): TXmlNode; overload; virtual;
    ///	<summary> Add a child node with an optional NodeType (default: ntElement)</summary>
    function Add(const Name: String; NodeType: TXmlNodeType = ntElement): TXmlNode; overload; virtual;
    ///	<summary> Inserts a node at the given position </summary>
    function Insert(const Name: String; Position: Integer; NodeType: TXmlNodeType = ntElement): TXmlNode; overload; virtual;
    ///	<summary> Inserts a node at the given position </summary>
    function Insert(const NodeToInsert: TXmlNode; Position: Integer): TXmlNode; overload; virtual;
    ///	<summary> Removes a node at the given position </summary>
    procedure Remove(Index: Integer); overload; virtual;
    ///	<summary> Find a node by its name (case sensitive), returns NIL if no node is found </summary>
    function Find(const Name: String; NodeTypes: TXmlNodeTypes = [ntElement]; const SearchWithoutPrefix: Boolean = False): TXmlNode; overload; virtual;
    ///	<summary> Same as Find(), returnsa a node by its name (case sensitive) </summary>
    function FindNode(const Name: String; NodeTypes: TXmlNodeTypes = [ntElement]; const SearchWithoutPrefix: Boolean = False): TXmlNode; virtual;
    ///	<summary> Find a node that has the the given attribute, returns NIL if no node is found </summary>
    function Find(const Name, AttrName: String; NodeTypes: TXmlNodeTypes = [ntElement]; const SearchWithoutPrefix: Boolean = False): TXmlNode; overload; virtual;
    ///	<summary> Find a node that as the given attribute name and value, returns NIL otherwise </summary>
    function Find(const Name, AttrName, AttrValue: String; NodeTypes: TXmlNodeTypes = [ntElement]; const SearchWithoutPrefix: Boolean = False): TXmlNode; overload; virtual;
    ///	<summary> Return a list of child nodes with the given name and (optional) node types </summary>
    function FindNodes(const Name: String; NodeTypes: TXmlNodeTypes = [ntElement]; const SearchWithoutPrefix: Boolean = False): TXmlNodeList; virtual;
    // Loops trough childnodes with given Name
//    procedure ScanNodes(const Name: String; CallBack: TXmlNodeCallBack);
    ///	<summary> Returns True if the list contains a node with the given name </summary>
    function HasNode(const Name: String; NodeTypes: TXmlNodeTypes = [ntElement]): Boolean; virtual;
    ///	<summary> Returns the first child node, same as .First </summary>
    function FirstChild: TXmlNode; virtual;
    ///	<summary> Returns previous sibling node </summary>
    function PreviousSibling(Node: TXmlNode): TXmlNode; virtual;
    ///	<summary> Returns next sibling node </summary>
    function NextSibling(Node: TXmlNode): TXmlNode; virtual;
    ///	<summary> Returns the node at the given position </summary>
    function Get(Index: Integer): TXmlNode; virtual;
    ///	<summary> Returns the node count of the given name</summary>
    function CountNames(const Name: String; var NodeList: TXmlNodeList; const SearchWithoutPrefix: Boolean = False): Integer; virtual;
  end;

  TXmlEscapeProcedure = reference to procedure (var TextLine: String);
{$IF CompilerVersion < 24}
  TXmlReader = TStreamReader;
{$ELSE}
  TXmlReader = TXmlStreamReader;
{$IFEND}

  TXmlVerySimple = class(TObject)
  private
  protected
    Root: TXmlNode;
    [Weak] FHeader: TXmlNode;
    [Weak] FDocumentElement: TXmlNode;
    SkipIndent: Boolean;
    XmlEscapeProcedure: TXmlEscapeProcedure;
    procedure Parse(Reader: TXmlReader); virtual;
    procedure ParseComment(Reader: TXmlReader; var Parent: TXmlNode); virtual;
    procedure ParseDocType(Reader: TXmlReader; var Parent: TXmlNode); virtual;
    procedure ParseProcessingInstr(Reader: TXmlReader; var Parent: TXmlNode); virtual;
    procedure ParseCData(Reader: TXmlReader; var Parent: TXmlNode); virtual;
    procedure ParseText(const Line: String; Parent: TXmlNode); virtual;
    function ParseTag(Reader: TXmlReader; ParseText: Boolean; var Parent: TXmlNode): TXmlNode; overload; virtual;
    function ParseTag(const TagStr: String; var Parent: TXmlNode): TXmlNode; overload; virtual;
    procedure Walk(Writer: TStreamWriter; const PrefixNode: String; Node: TXmlNode); virtual;
    procedure SetText(const Value: String); virtual;
    function GetText: String; virtual;
    procedure SetEncoding(const Value: String); virtual;
    function GetEncoding: String; virtual;
    procedure SetVersion(const Value: String); virtual;
    function GetVersion: String; virtual;
    procedure Compose(Writer: TStreamWriter); virtual;
    procedure SetStandAlone(const Value: String); virtual;
    function GetStandAlone: String; virtual;
    function GetChildNodes: TXmlNodeList; virtual;
    procedure CreateHeaderNode; virtual;
    function ExtractText(var Line: String; const StopChars: String; Options: TExtractTextOptions): String; virtual;
    procedure SetDocumentElement(Value: TXMlNode); virtual;
    procedure SetNodeAutoIndent(Value: Boolean);
    function GetNodeAutoIndent: Boolean;
    procedure SetPreserveWhitespace(Value: Boolean);
    function GetPreserveWhitespace: Boolean;
    function GetSearchExcludeNamespacePrefix: Boolean;
    function IsSame(const Value1, Value2: String): Boolean;
  public
    ///	<summary> Indent used for the xml output </summary>
    NodeIndentStr: String;
    ///	<summary> LineBreak used for the xml output, default set to sLineBreak which is OS dependent </summary>
    LineBreak: String;
    ///	<summary> Options for xml output like indentation type </summary>
    Options: TXmlOptions;
    ///	<summary> Creates a new XML document parser </summary>
    constructor Create; virtual;
    ///	<summary> Destroys the XML document parser </summary>
    destructor Destroy; override;
    ///	<summary> Deletes all nodes </summary>
    procedure Clear; virtual;
    ///	<summary> Adds a new node to the document, if it's the first ntElement then sets it as .DocumentElement </summary>
    function AddChild(const Name: String; NodeType: TXmlNodeType = ntElement): TXmlNode; virtual;
    ///	<summary> Removes a child node</summary>
    function RemoveChild(const Node: TXmlNode): Integer; virtual;
    ///	<summary> Moves a child node</summary>
    function MoveChild(const FromNode, ToNode: TXmlNode): TXmlNode; virtual;
    ///	<summary> Creates a new node but doesn't adds it to the document nodes </summary>
    function CreateNode(const Name: String; NodeType: TXmlNodeType = ntElement): TXmlNode; virtual;
    /// <summary> Escapes XML control characters </summar>
    class function Escape(const Value: String): String; virtual;
    /// <summary> Translates escaped characters back into XML control characters </summar>
    class function Unescape(const Value: String): String; virtual;
    ///	<summary> Loads the XML from a file </summary>
    function LoadFromFile(const FileName: String; BufferSize: Integer = 4096): TXmlVerySimple; virtual;
    ///	<summary> Loads the XML from a stream </summary>
    function LoadFromStream(const Stream: TStream; BufferSize: Integer = 4096): TXmlVerySimple; virtual;
    ///	<summary> Parse attributes into the attribute list for a given string </summary>
    procedure ParseAttributes(const AttribStr: String; AttributeList: TXmlAttributeList); virtual;
    ///	<summary> Saves the XML to a file </summary>
    function SaveToFile(const FileName: String): TXmlVerySimple; overload; virtual;
    function SaveToFile(const FileName: String; const EscapeProcedure: TXmlEscapeProcedure): TXmlVerySimple; overload; virtual;
    ///	<summary> Saves the XML to a stream, the encoding is specified in the .Encoding property </summary>
    function SaveToStream(const Stream: TStream): TXmlVerySimple; virtual;
    ///	<summary> A list of all root nodes of the document </summary>
    property ChildNodes: TXmlNodeList read GetChildNodes;
    ///	<summary> Returns the first element node </summary>
    property DocumentElement: TXmlNode read FDocumentElement write SetDocumentElement;
    ///	<summary> Specifies the encoding of the XML file, anything else then 'utf-8' is considered as ANSI </summary>
    property Encoding: String read GetEncoding write SetEncoding;
    ///	<summary> XML declarations are stored in here as Attributes </summary>
    property Header: TXmlNode read FHeader;
    ///	<summary> Set to True if all spaces and linebreaks should be included as a text node, same as doPreserve option </summary>
    property NodeAutoIndent: Boolean read GetNodeAutoIndent write SetNodeAutoIndent;
    ///	<summary> Set to True if all spaces and linebreaks should be included as a text node, same as doPreserve option </summary>
    property PreserveWhitespace: Boolean read GetPreserveWhitespace write SetPreserveWhitespace;
    ///	<summary> Defines the xml declaration property "StandAlone", set it to "yes" or "no" </summary>
    property StandAlone: String read GetStandAlone write SetStandAlone;
    ///	<summary> The XML as a string representation </summary>
    property Text: String read GetText write SetText;
    ///	<summary> Defines the xml declaration property "Version", default set to "1.0" </summary>
    property Version: String read GetVersion write SetVersion;
    ///	<summary> The XML as a string representation, same as .Text </summary>
    property Xml: String read GetText write SetText;
  end;

implementation

uses
  StrUtils,
  Rtti
{$IFDEF LOGGING}
  ,uGMUtils
{$ENDIF}
  ;

type
  TStreamWriterHelper = class helper for TStreamWriter
  public
    constructor Create(Stream: TStream; Encoding: TEncoding; WritePreamble: Boolean = True; BufferSize: Integer = 1024); overload;
    constructor Create(Filename: string; Append: Boolean; Encoding: TEncoding; WritePreamble: Boolean = True; BufferSize: Integer = 1024); overload;
  end;

{$IF CompilerVersion < 24}
  TStreamReaderHelper = class helper for TStreamReader
  public
    ///	<summary> Assures the read buffer holds at least Value characters </summary>
    function PrepareBuffer(Value: Integer): Boolean;
    ///	<summary> Extract text until chars found in StopChars </summary>
    function ReadText(const StopChars: String; Options: TExtractTextOptions): String; virtual;
    ///	<summary> Returns fist char but does not removes it from the buffer </summary>
    function FirstChar: Char;
    ///	<summary> Proceed with the next character(s) (value optional, default 1) </summary>
    procedure IncCharPos(Value: Integer = 1); virtual;
    ///	<summary> Returns True if the first uppercased characters at the current position match Value </summary>
    function IsUppercaseText(const Value: String): Boolean; virtual;
  end;
{$ELSE}
  TStreamReaderHelper = class helper for TStreamReader
  public
    procedure GetFillBuffer(var Method: TStreamReaderFillBuffer);
  end;
{$IFEND}

const
{$IF CompilerVersion >= 24} // Delphi XE3+ can use Low(), High() and TEncoding.ANSI
  LowStr = Low(String); // Get string index base, may be 0 (NextGen compiler) or 1 (standard compiler)

{$ELSE} // For any previous Delphi version overwrite High() function and use 1 as string index base
  LowStr = 1;  // Use 1 as string index base

function High(const Value: String): Integer; inline;
begin
  Result := Length(Value);
end;

//Delphi XE3 added PosEx as an overloaded Pos function, so we need to wrap it in every other Delphi version
function Pos(const SubStr, S: string; Offset: Integer): Integer; overload; Inline;
begin
  Result := PosEx(SubStr, S, Offset);
end;
{$IFEND}

{$IF CompilerVersion < 23}  //Delphi XE2 added ANSI as Encoding, in every other Delphi version use TEncoding.Default
type
  TEncodingHelper = class helper for TEncoding
    class function GetANSI: TEncoding; static;
    class property ANSI: TEncoding read GetANSI;
  end;

class function TEncodingHelper.GetANSI: TEncoding;
begin
  Result := TEncoding.Default;
end;
{$IFEND}

{ TVerySimpleXml }

function TXmlVerySimple.AddChild(const Name: String; NodeType: TXmlNodeType = ntElement): TXmlNode;
begin
//  Result := CreateNode(Name, NodeType);
  Result:=Nil; // satisfy compiler
  try
//    Root.ChildNodes.Add(Result);
    Result:=Root.AddChild(Name, NodeType);
  except
    Result.Free;
    raise;
  end;
  if (NodeType = ntElement) and (not Assigned(FDocumentElement)) then
    FDocumentElement := Result;
  Result.Document := Self;
end;

function TXmlVerySimple.RemoveChild(const Node: TXmlNode): Integer;
var
  wasRoot: Boolean;
  Child: TXmlNode;
begin
  Result:=-1;
  if Node <> Nil then begin
    wasRoot:=(DocumentElement = Node);
    Node.Clear;
    Result:=Node.Index;
    Root.ChildNodes.Remove(Result);
    if wasRoot then begin
      if Root.ChildNodes.Count > 0 then begin
        for Child in Root.ChildNodes do begin
          if Child.NodeType = ntElement then begin
            FDocumentElement := Child;
            Exit;
          end;
        end;
        DocumentElement := Nil;
      end
      else
        FDocumentElement := Nil;
    end;
//    Node.Free;
  end;
end;

function TXmlVerySimple.MoveChild(const FromNode, ToNode: TXmlNode): TXmlNode;
begin
  Result:=ToNode;
  if (ToNode <> Nil) and (FromNode <> Nil) then begin
    ToNode.AddNodes(FromNode, True);
    FromNode.ParentNode.RemoveChild(FromNode);
  end;
end;

procedure TXmlVerySimple.Clear;
begin
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'Clear - enter', True);
{$ENDIF}
  FDocumentElement := NIL;
  FHeader := NIL;
  Root.Clear;
  CreateHeaderNode;
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'Clear - leave', True);
{$ENDIF}
end;

constructor TXmlVerySimple.Create;
begin
  inherited;
  Root := TXmlNode.Create;
  Root.FLevel := 0;
//  Root.FIndex := 0;
  Root.NodeType := ntDocument;
  Root.ParentNode := Root;
  Root.Document := Self;
  NodeIndentStr := '  ';
  Options := [doNodeAutoIndent, doWriteBOM{, doCaseInsensitive}];
  LineBreak := sLineBreak;
  XmlEscapeProcedure := Nil;
  CreateHeaderNode;
end;

procedure TXmlVerySimple.CreateHeaderNode;
begin
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'CreateHeaderNode - enter', True);
{$ENDIF}
  if Assigned(FHeader) then begin
  {$IFDEF LOGGING}
    DebugOutputStrToFile('XmlVerySimple.txt', 'CreateHeaderNode - exit', True);
  {$ENDIF}
    Exit;
  end;
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'CreateHeaderNode - create <xml>', True);
{$ENDIF}
  FHeader := Root.ChildNodes.Insert('xml', 0, ntXmlDecl);
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'CreateHeaderNode - set version', True);
{$ENDIF}
  FHeader.Attributes['version'] := '1.0';  // Default XML version
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'CreateHeaderNode - set encoding', True);
{$ENDIF}
  FHeader.Attributes['encoding'] := 'utf-8';
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'CreateHeaderNode - leave', True);
{$ENDIF}
end;

function TXmlVerySimple.CreateNode(const Name: String; NodeType: TXmlNodeType): TXmlNode;
begin
  Result := TXmlNode.Create(NodeType);
  Result.Name := Name;
  Result.Document := Self;
end;

destructor TXmlVerySimple.Destroy;
begin
  Root.ParentNode := NIL;
  Root.Clear;
  Root.Free;
  inherited;
end;

function TXmlVerySimple.GetChildNodes: TXmlNodeList;
begin
  Result := Root.ChildNodes;
end;

function TXmlVerySimple.GetEncoding: String;
begin
  if Assigned(FHeader) and FHeader.HasAttribute('encoding') then
    Result := FHeader.Attributes['encoding']
  else
    Result := '';
end;

function TXmlVerySimple.GetNodeAutoIndent: Boolean;
begin
  Result := doNodeAutoIndent in Options;
end;

function TXmlVerySimple.GetPreserveWhitespace: Boolean;
begin
  Result := doPreserveWhitespace in Options;
end;

function TXmlVerySimple.GetSearchExcludeNamespacePrefix: Boolean;
begin
  Result := doSearchExcludeNamespacePrefix in Options;
end;

function TXmlVerySimple.GetStandAlone: String;
begin
  if Assigned(FHeader) then
    Result := FHeader.Attributes['standalone']
  else
    Result := '';
end;

function TXmlVerySimple.GetVersion: String;
begin
  if Assigned(FHeader) then
    Result := FHeader.Attributes['version']
  else
    Result := '';
end;

function TXmlVerySimple.IsSame(const Value1, Value2: String): Boolean;
var
  prefix1, val1, prefix2, val2: String;
begin
  TXmlNode.GetNameAndPrefix(Value1, val1, prefix1);
  TXmlNode.GetNameAndPrefix(Value2, val2, prefix2);

  if doCaseInsensitive in Options then
    Result := ((CompareText(Value1, Value2) = 0) or ((doSearchExcludeNamespacePrefix in Options) and (CompareText(val1, val2) = 0)))
  else
    Result := ((Value1 = Value2) or ((doSearchExcludeNamespacePrefix in Options) and (val1 = val2)));
end;

function TXmlVerySimple.GetText: String;
var
  Stream: TStringStream;
begin
  if CompareText(Encoding, 'utf-8') = 0 then
    Stream := TStringStream.Create('', TEncoding.UTF8)
  else
    Stream := TStringStream.Create('', TEncoding.ANSI);
  try
    SaveToStream(Stream);
    Result := Stream.DataString;
  finally
    Stream.Free;
  end;
end;

procedure TXmlVerySimple.Compose(Writer: TStreamWriter);
var
  Child: TXmlNode;
begin
  if doCompact in Options then begin
    Writer.NewLine := '';
    LineBreak := '';
  end
  else
    Writer.NewLine := LineBreak;

  SkipIndent := False;
  for Child in Root.ChildNodes do
    Walk(Writer, '', Child);
end;

function TXmlVerySimple.LoadFromFile(const FileName: String; BufferSize: Integer = 4096): TXmlVerySimple;
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(FileName, fmOpenRead + fmShareDenyWrite);
  try
    LoadFromStream(Stream, BufferSize);
  finally
    Stream.Free;
  end;
  Result := Self;
end;

function TXmlVerySimple.LoadFromStream(const Stream: TStream; BufferSize: Integer = 4096): TXmlVerySimple;
var
  Reader: TXmlReader;
begin
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'LoadFromStream - enter', True);
{$ENDIF}
  if Encoding = '' then // none specified then use UTF8 with DetectBom
    Reader := TXmlReader.Create(Stream, TEncoding.UTF8, True, BufferSize)
  else if CompareText(Encoding, 'utf-8') = 0 then
    Reader := TXmlReader.Create(Stream, TEncoding.UTF8, False, BufferSize)
  else if CompareText(Encoding, 'windows-1250') = 0 then
    Reader := TXmlReader.Create(Stream, TEncoding.GetEncoding(1250), False, BufferSize)
  else if CompareText(Encoding, 'iso-8859-2') = 0 then
    Reader := TXmlReader.Create(Stream, TEncoding.GetEncoding(28592), False, BufferSize)
  else
    Reader := TXmlReader.Create(Stream, TEncoding.ANSI, False, BufferSize);
  try
  {$IFDEF LOGGING}
    DebugOutputStrToFile('XmlVerySimple.txt', 'LoadFromStream - before Parse', True);
  {$ENDIF}
    Parse(Reader);
  {$IFDEF LOGGING}
    DebugOutputStrToFile('XmlVerySimple.txt', 'LoadFromStream - after Parse', True);
  {$ENDIF}
  finally
    Reader.Free;
  end;
  Result := Self;
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'LoadFromStream - leave', True);
{$ENDIF}
end;

procedure TXmlVerySimple.Parse(Reader: TXmlReader);
var
  Parent, Node: TXmlNode;
  FirstChar: Char;
  ALine: String;
begin
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'Parse - enter', True);
{$ENDIF}
  Clear;
  Parent := Root;

{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'Parse - enter main loop', True);
{$ENDIF}
  while not Reader.EndOfStream do begin
    ALine := Reader.ReadText('<', [etoDeleteStopChar]);
    if ALine <> '' then  // Check for text nodes
    begin
      ParseText(Aline, Parent);
      if Reader.EndOfStream then  // if no chars available then exit
        Break;
    end;
    FirstChar := Reader.FirstChar;
    if FirstChar = '!' then
      if Reader.IsUppercaseText('!--') then  // check for a comment node
        ParseComment(Reader, Parent)
      else
      if Reader.IsUppercaseText('!DOCTYPE') then // check for a doctype node
        ParseDocType(Reader, Parent)
      else
      if Reader.IsUppercaseText('![CDATA[') then // check for a cdata node
        ParseCData(Reader, Parent)
      else
        ParseTag(Reader, False, Parent) // try to parse as tag
    else // Check for XML header / processing instructions
    if FirstChar = '?' then // could be header or processing instruction
      ParseProcessingInstr(Reader, Parent)
    else
    if FirstChar <> '' then
    begin // Parse a tag, the first tag in a document is the DocumentElement
      Node := ParseTag(Reader, True, Parent);
      if (not Assigned(FDocumentElement)) and (Parent = Root) then
        FDocumentElement := Node;
    end;
  end;
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'Parse - leave main loop', True);
{$ENDIF}

  // some xml/html documents does not have this set, so set it up
  if FDocumentElement = Nil then begin
    for Node in Root.ChildNodes do
      if Node.NodeType = ntElement then begin
        FDocumentElement := Node;
        Break;
      end;
  end;
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'Parse - leave', True);
{$ENDIF}
end;

procedure TXmlVerySimple.ParseAttributes(const AttribStr: String; AttributeList: TXmlAttributeList);
var
  Attribute: TXmlAttribute;
  AttrName, AttrText: String;
  Quote: Char;
  Value: String;
begin
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'ParseAttributes - enter: ' + AttribStr, True);
{$ENDIF}
  Value := TrimLeft(AttribStr);
  while Value <> '' do begin
    AttrName := ExtractText(Value, ' =', []);
    Value := TrimLeft(Value);

    Attribute := AttributeList.Add(AttrName);
    if (Value = '') or (Value[LowStr]<>'=') then
      Continue;

    Delete(Value, 1, 1);
    Attribute.AttributeType := atValue;
    ExtractText(Value, '''' + '"', []);
    Value := TrimLeft(Value);
    if Value <> '' then
    begin
      Quote := Value[LowStr];
      Delete(Value, 1, 1);
      AttrText := ExtractText(Value, Quote, [etoDeleteStopChar]); // Get Attribute Value
      Attribute.Value := Unescape(AttrText);
      Value := TrimLeft(Value);
    end;
  end;
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'ParseAttributes - leave', True);
{$ENDIF}
end;


procedure TXmlVerySimple.ParseText(const Line: String; Parent: TXmlNode);
var
  SingleChar: Char;
  Node: TXmlNode;
  TextNode: Boolean;
begin
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'ParseText - enter: ' + Line, True);
{$ENDIF}
  if PreserveWhiteSpace then
    TextNode := True
  else begin
    TextNode := False;
    for SingleChar in Line do
      if AnsiStrScan(TXmlSpaces, SingleChar) = NIL then
      begin
        TextNode := True;
        Break;
      end;
  end;

  if TextNode then begin
//    Node := Parent.ChildNodes.Add(ntText);
    Node := Parent.AddChild('', ntText);
    Node.Text := Line;
  end;
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'ParseText - leave', True);
{$ENDIF}
end;

procedure TXmlVerySimple.ParseCData(Reader: TXmlReader; var Parent: TXmlNode);
var
  Node: TXmlNode;
  temp: String;
begin
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'ParseCData - enter', True);
{$ENDIF}
//  Node := Parent.ChildNodes.Add(ntCData);
  Node := Parent.AddChild('', ntCData);
  temp:=Reader.ReadText(']]>', [etoDeleteStopChar, etoStopString]);
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'ParseCData - value: ' + temp, True);
{$ENDIF}
  Node.Text := temp;
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'ParseCData - leave', True);
{$ENDIF}
end;

procedure TXmlVerySimple.ParseComment(Reader: TXmlReader; var Parent: TXmlNode);
var
  Node: TXmlNode;
  temp: String;
begin
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'ParseComment - enter', True);
{$ENDIF}
//  Node := Parent.ChildNodes.Add(ntComment);
  Node := Parent.AddChild('', ntComment);
  temp:=Reader.ReadText('-->', [etoDeleteStopChar, etoStopString]);
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'ParseComment - value: ' + temp, True);
{$ENDIF}
  Node.Text := temp;
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'ParseComment - leave', True);
{$ENDIF}
end;

procedure TXmlVerySimple.ParseDocType(Reader: TXmlReader; var Parent: TXmlNode);
var
  Node: TXmlNode;
  Quote: Char;
  temp: String;
begin
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'ParseDocType - enter', True);
{$ENDIF}
//  Node := Parent.ChildNodes.Add(ntDocType);
  Node := Parent.AddChild('', ntDocType);
  temp:=Reader.ReadText('>[', []);
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'ParseDocType - value: ' + temp, True);
{$ENDIF}
  Node.Text := temp;
  if not Reader.EndOfStream then begin
    Quote := Reader.FirstChar;
    Reader.IncCharPos;
    if Quote = '[' then
      Node.Text := Node.Text + Quote + Reader.ReadText(']',[etoDeleteStopChar]) + ']' +
        Reader.ReadText('>', [etoDeleteStopChar]);
  end;
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'ParseDocType - leave', True);
{$ENDIF}
end;

procedure TXmlVerySimple.ParseProcessingInstr(Reader: TXmlReader; var Parent: TXmlNode);
var
  Node: TXmlNode;
  Tag: String;
begin
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'ParseProcessingInstr - enter', True);
{$ENDIF}
  Reader.IncCharPos; // omit the '?'
  Tag := Reader.ReadText('?>', [etoDeleteStopChar, etoStopString]);
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'ParseProcessingInstr - value: ' + Tag, True);
{$ENDIF}
  Node := ParseTag(Tag, Parent);
  if lowercase(Node.Name) = 'xml' then begin
    // delete old one
    Root.ChildNodes.Remove(FHeader.Index);
    FHeader := Node;
    FHeader.NodeType := ntXmlDecl;
  end
  else begin
    Node.NodeType := ntProcessingInstr;
    if not (doParseProcessingInstr in Options) then begin
      Node.Text := Tag;
      Node.AttributeList.Clear;
    end;
  end;
  Parent := Node.ParentNode;
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'ParseProcessingInstr - leave', True);
{$ENDIF}
end;

function TXmlVerySimple.ParseTag(Reader: TXmlReader; ParseText: Boolean; var Parent: TXmlNode): TXmlNode;
var
  Tag: String;
  ALine: String;
  SingleChar: Char;
begin
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'ParseTag(1) - enter', True);
{$ENDIF}
  Tag := Reader.ReadText('>', [etoDeleteStopChar]);
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'ParseTag(1) - value: ' + Tag, True);
{$ENDIF}
  Result := ParseTag(Tag, Parent);
  if Result = Parent then begin // only non-self closing nodes may have a text
    ALine := Reader.ReadText('<', []);
    ALine := Unescape(ALine);

    if PreserveWhiteSpace then
      Result.Text := ALine
    else
      for SingleChar in ALine do
        if AnsiStrScan(TXmlSpaces, SingleChar) = NIL then
        begin
          Result.Text := ALine;
          Break;
        end;
  end;
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'ParseTag(1) - leave', True);
{$ENDIF}
end;

function TXmlVerySimple.ParseTag(const TagStr: String; var Parent: TXmlNode): TXmlNode;
var
  Node: TXmlNode;
  ALine: String;
  CharPos: Integer;
  Tag: String;
begin
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'ParseTag(2) - enter: ' + TagStr, True);
{$ENDIF}
  // A closing tag does not have any attributes nor text
  if (TagStr <> '') and (TagStr[LowStr] = '/') then begin
    Tag:=TagStr;
    Delete(Tag, 1, 1);
    if (IfThen(GetSearchExcludeNamespacePrefix, Parent.Name, Parent.NameWithPrefix) <> Tag) and
       (IfThen(GetSearchExcludeNamespacePrefix, Parent.ParentNode.Name, Parent.ParentNode.NameWithPrefix) = Tag) then begin
      Result := Parent.ParentNode;
      Parent := Parent.ParentNode.ParentNode;
    end
    else begin
      Result := Parent;
      Parent := Parent.ParentNode;
    end;
  {$IFDEF LOGGING}
    DebugOutputStrToFile('XmlVerySimple.txt', 'ParseTag(2) - exit', True);
  {$ENDIF}
    Exit;
  end;

  // Creat a new new ntElement node
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'ParseTag(2) - add child', True);
{$ENDIF}
//  Node := Parent.ChildNodes.Add;
  Node := Parent.AddChild('');
  Result := Node;
  Tag := TagStr;

  // Check for a self-closing Tag (does not have any text)
  if (Tag <> '') and (Tag[High(Tag)] = '/') then
    Delete(Tag, Length(Tag), 1)
  else
    Parent := Node;

  CharPos := Pos(' ', Tag);
  if CharPos <> 0 then begin // Tag may have attributes
    ALine := Tag;
    Delete(Tag, CharPos, Length(Tag));
    Delete(ALine, 1, CharPos);
    if ALine <> '' then
      ParseAttributes(ALine, Node.AttributeList);
  end;

  Node.Name := Tag;
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'ParseTag(2) - leave', True);
{$ENDIF}
end;


function TXmlVerySimple.SaveToFile(const FileName: String): TXmlVerySimple;
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(FileName, fmCreate);
  try
    SaveToStream(Stream);
  finally
    Stream.Free;
  end;
  Result := Self;
end;

function TXmlVerySimple.SaveToFile(const FileName: String; const EscapeProcedure: TXmlEscapeProcedure): TXmlVerySimple;
begin
  XmlEscapeProcedure:=EscapeProcedure;
  try
    Result := SaveToFile(FileName);
  finally
    XmlEscapeProcedure:=Nil;
  end;
end;

function TXmlVerySimple.SaveToStream(const Stream: TStream): TXmlVerySimple;
var
  Writer: TStreamWriter;
begin
  if CompareText(Self.Encoding, 'utf-8') = 0 then
    Writer := TStreamWriter.Create(Stream, TEncoding.UTF8, (doWriteBOM in Options))
  else if CompareText(Encoding, 'windows-1250') = 0 then
    Writer := TStreamWriter.Create(Stream, TEncoding.GetEncoding(1250), (doWriteBOM in Options))
  else
    Writer := TStreamWriter.Create(Stream, TEncoding.ANSI, (doWriteBOM in Options));
  try
    Compose(Writer);
  finally
    Writer.Free;
  end;
  Result := Self;
end;

procedure TXmlVerySimple.SetDocumentElement(Value: TXMlNode);
begin
  FDocumentElement := Value;
  if Value.ParentNode = NIL then
    Root.ChildNodes.Add(Value);
end;

procedure TXmlVerySimple.SetEncoding(const Value: String);
begin
  CreateHeaderNode;
  FHeader.Attributes['encoding'] := Value;
end;

procedure TXmlVerySimple.SetNodeAutoIndent(Value: Boolean);
begin
  if Value then
    Options := Options + [doNodeAutoIndent]
  else
    Options := Options - [doNodeAutoIndent]
end;

procedure TXmlVerySimple.SetPreserveWhitespace(Value: Boolean);
begin
  if Value then
    Options := Options + [doPreserveWhitespace]
  else
    Options := Options - [doPreserveWhitespace]
end;

procedure TXmlVerySimple.SetStandAlone(const Value: String);
begin
  CreateHeaderNode;
  FHeader.Attributes['standalone'] := Value;
end;

procedure TXmlVerySimple.SetVersion(const Value: String);
begin
  CreateHeaderNode;
  FHeader.Attributes['version'] := Value;
end;


class function TXmlVerySimple.Unescape(const Value: String): String;
//begin
//  Result := ReplaceStr(Value, '&lt;', '<');
//  Result := ReplaceStr(Result, '&gt;', '>');
//  Result := ReplaceStr(Result, '&quot;', '"');
//  Result := ReplaceStr(Result, '&apos;', '''');
//  Result := ReplaceStr(Result, '&amp;', '&');
//end;
var
  sLen, sIndex, cPos: Integer;
  sTemp: String;
begin
  sLen:=Length(Value);
  sIndex := 1;
  Result:=Value;
  while sIndex <= sLen do begin
    case Result[sIndex] of
      '&': begin
        cPos:=PosEx(';', Result, sIndex);
        if cPos > sIndex then begin
          sTemp:=Copy(Result, sIndex + 1, cPos - sIndex);
          try
            if sTemp = 'amp;' then begin
              Delete(Result, sIndex + 1, 4);
              Dec(sLen, 4);
            end
            else if sTemp = 'lt;' then begin
              Result[sIndex]:='<';
              Delete(Result, sIndex + 1, 3);
              Dec(sLen, 3);
            end
            else if sTemp = 'gt;' then begin
              Result[sIndex]:='>';
              Delete(Result, sIndex + 1, 3);
              Dec(sLen, 3);
            end
            else if sTemp = 'quot;' then begin
              Result[sIndex]:='"';
              Delete(Result, sIndex + 1, 5);
              Dec(sLen, 5);
            end
            else if sTemp = 'apos;' then begin
              Result[sIndex]:='''';
              Delete(Result, sIndex + 1, 5);
              Dec(sLen, 5);
            end;
          finally
            sTemp:='';
          end;
        end;
      end;
    end;
    Inc(sIndex);
  end;
end;

procedure TXmlVerySimple.SetText(const Value: String);
var
  Stream: TStringStream;
  utf8: UTF8String;
begin
  utf8:=Value;
  try
    Stream := TStringStream.Create(utf8, TEncoding.UTF8);
    try
  //    Stream.WriteString(Value);
    {$IFDEF LOGGING}
      DebugOutputStrToFile('XmlVerySimple.txt', 'SetText - stream codepage: ' + IntToStr(StringCodePage(utf8)));
      DebugOutputStrToFile('XmlVerySimple.txt', 'SetText - stream size: ' + IntToStr(Stream.Size), True);
    {$ENDIF}
      Stream.Position := 0;
      LoadFromStream(Stream);
    {$IFDEF LOGGING}
      DebugOutputStrToFile('XmlVerySimple.txt', 'SetText - done', True);
    {$ENDIF}
    finally
      Stream.Free;
    end;
  finally
    utf8:='';
  end;
end;

procedure TXmlVerySimple.Walk(Writer: TStreamWriter; const PrefixNode: String; Node: TXmlNode);
var
  Child: TXmlNode;
  Line: String;
  Indent: String;
begin
  if (Node = Root.ChildNodes.First) or (SkipIndent) then begin
    Line := '<';
    SkipIndent := False;
  end
  else
    Line := LineBreak + PrefixNode + '<';

  case Node.NodeType of
    ntComment:
      begin
        Writer.Write(Line + '!--' + Node.Text + '-->');
        Exit;
      end;
    ntDocType:
      begin
        Writer.Write(Line + '!DOCTYPE ' + Node.Text + '>');
        Exit;
      end;
    ntCData:
      begin
        Writer.Write('<![CDATA[' + Node.Text + ']]>');
        Exit;
      end;
    ntText:
      begin
        Writer.Write(Node.Text);
        SkipIndent := True;
        Exit;
      end;
    ntProcessingInstr:
      begin
        if Node.AttributeList.Count > 0 then
          Line := Line + '?' + Trim(Node.Name) + ' ' + Trim(Node.AttributeList.AsString) + '?>'
        else
          Line := Line + '?' + Node.Text + '?>';
        if Assigned(XmlEscapeProcedure) then
          XmlEscapeProcedure(Line);
        Writer.Write(Line);
        Exit;
      end;
    ntXmlDecl:
      begin
        if doSkipHeader in Options then
          Exit;
        if Node.AttributeList.Count > 0 then
          Line := Line + '?' + Trim(Node.Name) + ' ' + Trim(Node.AttributeList.AsString) + '?>'
        else
          Line := Line + '?' + Node.Text + '?>';
        if Assigned(XmlEscapeProcedure) then
          XmlEscapeProcedure(Line);
        Writer.Write(Line);
        Exit;
      end;
  end;

  Line := Line + Trim(Node.NameWithPrefix);
  if Node.AttributeList.Count > 0 then
    Line := Line + ' ' + Trim(Node.AttributeList.AsString);

  // Self closing tags
  if (Node.Text = '') and (not Node.HasChildNodes) then begin
    Writer.Write(Line + '/>');
    Exit;
  end;

  Line := Line + '>';
  if Node.Text <> '' then begin
    Line := Line + Escape(Node.Text);
    if Node.HasChildNodes then
      SkipIndent := True;
  end;

  if Assigned(XmlEscapeProcedure) then
    XmlEscapeProcedure(Line);

  Writer.Write(Line);

  // Set indent for child nodes
  if (doCompact in Options) or (doCompactWithBreakes in Options) then
    Indent := ''
  else
    Indent := PrefixNode + IfThen(GetNodeAutoIndent, NodeIndentStr);

  // Process child nodes
  for Child in Node.ChildNodes do
    Walk(Writer, Indent, Child);

  // If node has child nodes and last child node is not a text node then set indent for closing tag
  if (Node.HasChildNodes) and (not SkipIndent) then
    Indent := LineBreak + PrefixNode
  else
    Indent := '';

  Writer.Write(Indent + '</' + Trim(Node.NameWithPrefix) + '>');
end;


class function TXmlVerySimple.Escape(const Value: String): String;
begin
  Result := TXmlAttribute.Escape(Value);
//  Result := ReplaceStr(Result, '''', '&apos;');
end;

function TXmlVerySimple.ExtractText(var Line: String; const StopChars: String;
  Options: TExtractTextOptions): String;
var
  CharPos, FoundPos: Integer;
  TestChar: Char;
begin
  FoundPos := 0;
  for TestChar in StopChars do begin
    CharPos := Pos(TestChar, Line);
    if (CharPos <> 0) and ((FoundPos = 0) or (CharPos < FoundPos)) then
      FoundPos := CharPos;
  end;

  if FoundPos <> 0 then begin
    Dec(FoundPos);
    Result := Copy(Line, 1, FoundPos);
    if etoDeleteStopChar in Options then
      Inc(FoundPos);
    Delete(Line, 1, FoundPos);
  end
  else begin
    Result := Line;
    Line := '';
  end;
end;

{ TXmlNode }

function TXmlNode.AddChild(const AName: String; ANodeType: TXmlNodeType = ntElement): TXmlNode;
var
  Last: TXmlNode;
begin
  Last:=Nil;
  try
    if ChildNodes.Count > 0 then
      Last:=ChildNodes.Last;
  except
    Last:=Nil;
  end;
  Result:=ChildNodes.Add(AName, ANodeType);
  Result.FPrevSibling:=Nil;
  Result.FNextSibling:=Nil;
  if Last <> Nil then begin
    Result.FPrevSibling:=Last;
    Last.FNextSibling:=Result;
  end;
end;

function TXmlNode.RemoveChild(const Node: TXmlNode): Integer;
begin
  Result:=Node.Index;
  if Node.NextSibling <> Nil then
    Node.NextSibling.FPrevSibling:=Node.PreviousSibling
  else if Node.PreviousSibling <> Nil then // last node, so delete reference within previous node to this, which is about to be deleted
    Node.PreviousSibling.FNextSibling:=Nil;
  ChildNodes.Remove(Result);
end;

function TXmlNode.MoveChild(const FromNode, ToNode: TXmlNode): TXmlNode;
begin
  Result:=Nil;
  if (ToNode <> Nil) and (FromNode <> Nil) then begin
    ToNode.AddNodes(FromNode, True);
    FromNode.ParentNode.RemoveChild(FromNode);
    Result:=ToNode;
  end;
end;

procedure TXmlNode.AddNodes(const RootNode: TXmlNode; const AddRootNode: Boolean = False);
var
  Child, Node: TXmlNode;
  Attribute: TXmlAttribute;
begin
  Child:=Self;
  if AddRootNode then begin
    Child:=AddChild(RootNode.NameWithPrefix, RootNode.NodeType);
    Child.Text:=RootNode.Text;
    for Attribute in RootNode.AttributeList do // add all attributes to child node
      Child.SetAttribute(Attribute.Name, Attribute.Value);
  end;
  for Node in RootNode.ChildNodes do // add all root node child nodes to child node
    Child.AddNodes(Node, True);
end;

procedure TXmlNode.Clear;
begin
  Text := '';
  AttributeList.Clear;
  ChildNodes.Clear;
  UserData:='';
end;

constructor TXmlNode.Create(ANodeType: TXmlNodeType = ntElement);
begin
  ChildNodes := TXmlNodeList.Create;
  ChildNodes.Parent := Self;
  AttributeList := TXmlAttributeList.Create;
  NodeType := ANodeType;
  FName:='';
  FPrefix:='';
  FLevel:=0;
  FIndex:=0;
  UserData:='';
end;

destructor TXmlNode.Destroy;
begin
  Clear;
  ChildNodes.Free;
  AttributeList.Free;
  inherited;
end;

procedure TXmlNode.Assign(const Node: TXmlNode);
var
  Attribute: TXmlAttribute;
begin
  NodeName :=Node.NodeName;
  NodeType :=Node.NodeType;
  NodeValue:=Node.NodeValue;
  UserData :=Node.UserData;
  for Attribute in Node.AttributeList do // add all attributes to node
    SetAttribute(Attribute.Name, Attribute.Value);
  AddNodes(Node);
end;

class procedure TXmlNode.GetNameAndPrefix(const Value: String; var Name, Prefix: String);
var
  i: Integer;
begin
  Prefix:='';
  Name:='';
  i:=Pos(':', Value);
  if i > 0 then begin
    Prefix:=Copy(Value, 1, i - 1);
  end;
  Name:=Copy(Value, i + 1, Length(Value) - i);
end;

procedure TXmlNode.SetName(Value: String);
var
  i: Integer;
begin
  i:=Pos(':', Value);
  if i > 0 then begin // name with prefix
    FPrefix := Copy(Value, 1, i - 1);
    Delete(Value, 1, i);
  end;
  FName := Value;
end;

function TXmlNode.GetName: String;
begin
  Result := FName;
  if HasPrefix then
    Result := FPrefix + ':' + Result;
end;

function TXmlNode.IsSame(const Value1, Value2: String): Boolean;
var
  prefix1, val1, prefix2, val2: String;
begin
  GetNameAndPrefix(Value1, val1, prefix1);
  GetNameAndPrefix(Value2, val2, prefix2);

  Result := ((Assigned(Document) and Document.IsSame(val1, val2)) or // use the documents text comparison
    ((not Assigned(Document)) and (val1 = val2))); // or if not Assigned then compare names case sensitive
end;

{
function RecursiveFindNode(ANode: IXMLNode; const SearchNodeName: string): IXMLNode;
var
  I: Integer;
begin
  if CompareText(ANode.NodeName, SearchNodeName) = 0 then
    Result := ANode
  else if not Assigned(ANode.ChildNodes) then
    Result := nil
  else begin
    for I := 0 to ANode.ChildNodes.Count - 1 do
    begin
      Result := RecursiveFindNode(ANode.ChildNodes[I], SearchNodeName);
      if Assigned(Result) then
        Exit;
    end;
  end;
end;
}

function TXmlNode.FindNodeRecursive(const Name: String; NodeTypes: TXmlNodeTypes = [ntElement]; const SearchOptions: TXmlNodeSearchTypes = []): TXmlNode;
var
  Node: TXmlNode;
  SearchWithoutPrefix: Boolean;
begin
  SearchWithoutPrefix:=(nsSearchWithoutPrefix in SearchOptions);
//  Result := ChildNodes.Find(Name, NodeTypes);
  Result:=Nil;
  for Node in ChildNodes do begin
    if ((NodeTypes = []) or (Node.NodeType in NodeTypes)) and IsSame(IfThen(Document.GetSearchExcludeNamespacePrefix or SearchWithoutPrefix, Node.Name, Node.NameWithPrefix), Name) then begin
      Result:=Node;
      Exit;
    end;
    if Node.HasChildNodes then begin
      Result:=Node.FindNodeRecursive(Name, NodeTypes, SearchOptions);
      if Result <> Nil then
        Exit;
    end;
  end;
end;

function TXmlNode.FindNodeRecursive(const Name, AttrName: String; NodeTypes: TXmlNodeTypes = [ntElement]; const SearchOptions: TXmlNodeSearchTypes = []): TXmlNode;
var
  Node: TXmlNode;
  SearchWithoutPrefix: Boolean;
begin
  SearchWithoutPrefix:=(nsSearchWithoutPrefix in SearchOptions);
//  Result := ChildNodes.Find(Name, AttrName, NodeTypes);
  Result:=Nil;
  for Node in ChildNodes do begin
    if ((NodeTypes = []) or (Node.NodeType in NodeTypes)) and
       ((Name = '') or ((Name <> '') and IsSame(IfThen(Document.GetSearchExcludeNamespacePrefix or SearchWithoutPrefix, Node.Name, Node.NameWithPrefix), Name))) and
       Node.HasAttribute(AttrName) then begin
      Result:=Node;
      Exit;
    end;
    if Node.HasChildNodes then begin
      Result:=Node.FindNodeRecursive(Name, AttrName, NodeTypes, SearchOptions);
      if Result <> Nil then
        Exit;
    end;
  end;
end;

function TXmlNode.FindNodeRecursive(const Name, AttrName, AttrValue: String; NodeTypes: TXmlNodeTypes = [ntElement]; const SearchOptions: TXmlNodeSearchTypes = []): TXmlNode;
var
  Node: TXmlNode;
  SearchWithoutPrefix: Boolean;
begin
  SearchWithoutPrefix:=(nsSearchWithoutPrefix in SearchOptions);
//  Result := ChildNodes.Find(Name, AttrName, NodeTypes);
  Result:=Nil;
  for Node in ChildNodes do begin
    if ((NodeTypes = []) or (Node.NodeType in NodeTypes)) and // if no type specified or node type in types
       ((Name = '') or ((Name <> '') and IsSame(IfThen(Document.GetSearchExcludeNamespacePrefix or SearchWithoutPrefix, Node.Name, Node.NameWithPrefix), Name))) and
       Node.HasAttribute(AttrName) and IsSame(Node.Attributes[AttrName], AttrValue) then begin
      Result:=Node;
      Exit;
    end;
    if Node.HasChildNodes then begin
      Result:=Node.FindNodeRecursive(Name, AttrName, AttrValue, NodeTypes, SearchOptions);
      if Result <> Nil then
        Exit;
    end;
  end;
end;

{
function TXmlNode.FindNodeRecursive(const Name: String; NodeTypes: TXmlNodeTypes = [ntElement]): TXmlNodeList;
begin
  Result := ChildNodes.FindNodes(Name, NodeTypes);
end;
}

function TXmlNode.FindNode(const Name: String; NodeTypes: TXmlNodeTypes = [ntElement]; const SearchOptions: TXmlNodeSearchTypes = []): TXmlNode;
var
  SearchWithoutPrefix: Boolean;
begin
  SearchWithoutPrefix:=(nsSearchWithoutPrefix in SearchOptions);
  if ((NodeTypes = []) or (Self.NodeType in NodeTypes)) and
     IsSame(IfThen(Document.GetSearchExcludeNamespacePrefix or SearchWithoutPrefix, Self.Name, Self.NameWithPrefix), Name) then begin
    Result := Self;
    Exit;
  end;
  Result := ChildNodes.Find(Name, NodeTypes, SearchWithoutPrefix);
  if (Result = Nil) and (nsRecursive in SearchOptions) then
    Result:=FindNodeRecursive(Name, NodeTypes, SearchOptions);
end;

function TXmlNode.FindNode(const Name, AttrName: String; NodeTypes: TXmlNodeTypes = [ntElement]; const SearchOptions: TXmlNodeSearchTypes = []): TXmlNode;
var
  SearchWithoutPrefix: Boolean;
begin
  SearchWithoutPrefix:=(nsSearchWithoutPrefix in SearchOptions);
  if ((NodeTypes = []) or (Self.NodeType in NodeTypes)) and
     ((Name = '') or ((Name <> '') and IsSame(IfThen(Document.GetSearchExcludeNamespacePrefix or SearchWithoutPrefix, Self.Name, Self.NameWithPrefix), Name))) and
     Self.HasAttribute(AttrName) then begin
    Result := Self;
    Exit;
  end;
  Result := ChildNodes.Find(Name, AttrName, NodeTypes, SearchWithoutPrefix);
  if (Result = Nil) and (nsRecursive in SearchOptions) then
    Result:=FindNodeRecursive(Name, AttrName, NodeTypes, SearchOptions);
end;

function TXmlNode.FindNode(const Name, AttrName, AttrValue: String; NodeTypes: TXmlNodeTypes = [ntElement]; const SearchOptions: TXmlNodeSearchTypes = []): TXmlNode;
var
  SearchWithoutPrefix: Boolean;
begin
  SearchWithoutPrefix:=(nsSearchWithoutPrefix in SearchOptions);
  if ((NodeTypes = []) or (Self.NodeType in NodeTypes)) and // if no type specified or node type in types
     ((Name = '') or ((Name <> '') and IsSame(IfThen(Document.GetSearchExcludeNamespacePrefix or SearchWithoutPrefix, Self.Name, Self.NameWithPrefix), Name))) and
     Self.HasAttribute(AttrName) and IsSame(Self.Attributes[AttrName], AttrValue) then begin
    Result := Self;
    Exit;
  end;
  Result := ChildNodes.Find(Name, AttrName, AttrValue, NodeTypes, SearchWithoutPrefix);
  if (Result = Nil) and (nsRecursive in SearchOptions) then
    Result:=FindNodeRecursive(Name, AttrName, AttrValue, NodeTypes, SearchOptions);
end;

function TXmlNode.FindNodes(const Name: String; NodeTypes: TXmlNodeTypes = [ntElement]; const SearchWithoutPrefix: Boolean = False): TXmlNodeList;
begin
  Result := ChildNodes.FindNodes(Name, NodeTypes, SearchWithoutPrefix);
end;

procedure TXmlNode.ScanNodes(Name: String; CallBack: TXmlNodeCallBack; const SearchWithoutPrefix: Boolean = False);
var
  Node: TXmlNode;
begin
  Name := lowercase(Name);
  for Node in ChildNodes do
    if (Name = '') or ((Name <> '') and
                       (LowerCase(IfThen(Document.GetSearchExcludeNamespacePrefix or SearchWithoutPrefix, Node.Name, Node.NameWithPrefix)) = Name)) then begin
      if not CallBack(Node) then
        Break;
    end;
end;

function TXmlNode.FirstChild: TXmlNode;
begin
  Result := ChildNodes.First;
end;

function TXmlNode.GetAttr(const AttrName: String): String;
var
  Attribute: TXmlAttribute;
begin
  Attribute := AttributeList.Find(AttrName);
  if Assigned(Attribute) then
    Result := Attribute.Value
  else
    Result := '';
end;

function TXmlNode.HasPrefix: Boolean;
begin
  Result := (Prefix <> '');
end;

function TXmlNode.HasAttribute(const AttrName: String): Boolean;
begin
  Result := AttributeList.HasAttribute(AttrName);
end;

function TXmlNode.HasChild(const Name: String; NodeTypes: TXmlNodeTypes = [ntElement]): Boolean;
begin
  Result := ChildNodes.HasNode(Name, NodeTypes);
end;

function TXmlNode.HasChildNodes: Boolean;
begin
  Result := (ChildNodes.Count > 0);
end;

function TXmlNode.InsertChild(const Name: String; Position: Integer; NodeType: TXmlNodeType = ntElement): TXmlNode;
begin
  Result := ChildNodes.Insert(Name, Position, NodeType);
  if Assigned(Result) then
    Result.ParentNode := Self;
end;

function TXmlNode.InsertChild(const NodeToInsert: TXmlNode; Position: Integer): TXmlNode;
begin
  Result := ChildNodes.Insert(NodeToInsert, Position);
  if Assigned(Result) then
    Result.ParentNode := Self;
end;

function TXmlNode.InsertChildBefore(const BeforeNode: TXmlNode; const Name: String; NodeType: TXmlNodeType): TXmlNode;
begin
  Result := InsertChild(Name, BeforeNode.Index, NodeType);
end;

function TXmlNode.InsertChildBefore(const BeforeNode, NodeToInsert: TXmlNode): TXmlNode;
begin
  Result := InsertChild(NodeToInsert, BeforeNode.Index);
end;

function TXmlNode.InsertChildAfter(const AfterNode: TXmlNode; const Name: String; NodeType: TXmlNodeType): TXmlNode;
begin
  Result := InsertChild(Name, AfterNode.Index + 1, NodeType);
end;

function TXmlNode.InsertChildAfter(const AfterNode, NodeToInsert: TXmlNode): TXmlNode;
begin
  Result := InsertChild(NodeToInsert, AfterNode.Index + 1);
end;

function TXmlNode.IsTextElement: Boolean;
begin
  Result := (Text <> '') and (not HasChildNodes);
end;

function TXmlNode.LastChild: TXmlNode;
begin
  if ChildNodes.Count > 0 then
    Result := ChildNodes.Last
  else
    Result := NIL;
end;

function TXmlNode.PreviousSibling: TXmlNode;
begin
//  if not Assigned(ParentNode) then
//    Result := NIL
//  else
//    Result := ParentNode.ChildNodes.PreviousSibling(Self);
  Result:=FPrevSibling;
end;

function TXmlNode.NextSibling: TXmlNode;
begin
//  if not Assigned(ParentNode) then
//    Result := NIL
//  else
//    Result := ParentNode.ChildNodes.NextSibling(Self);
  Result:=FNextSibling;
end;

procedure TXmlNode.SetAttr(const AttrName, AttrValue: String);
begin
  SetAttribute(AttrName, AttrValue);
end;

function TXmlNode.SetAttribute(const AttrName, AttrValue: String): TXmlNode;
var
  Attribute: TXmlAttribute;
begin
  Attribute := AttributeList.Find(AttrName); // Search for given name
  if not Assigned(Attribute) then // If attribute is not found, create one
    Attribute := AttributeList.Add(AttrName);
  Attribute.AttributeType := atValue;
  Attribute.Name := AttrName; // this allows rewriting of the attribute name (lower/upper case)
  Attribute.Value := AttrValue;
  Result := Self;
end;

procedure TXmlNode.SetDocument(Value: TXmlVerySimple);
begin
  FDocument := Value;
  AttributeList.Document := Value;
  ChildNodes.Document := Value;
end;

function TXmlNode.SetNodeType(Value: TXmlNodeType): TXmlNode;
begin
  NodeType := Value;
  Result := Self;
end;

function TXmlNode.SetText(const Value: String): TXmlNode;
begin
  Text := Value;
  Result := Self;
end;

{ TXmlAttributeList }

function TXmlAttributeList.Add(const Name: String): TXmlAttribute;
begin
  Result := TXmlAttribute.Create;
  Result.Name := Name;
  try
    Add(Result);
  except
    Result.Free;
    raise;
  end;
end;

function TXmlAttributeList.AsString: String;
var
  Attribute: TXmlAttribute;
begin
  Result := '';
  for Attribute in Self do
    Result := Result + ' ' + Attribute.AsString;
  Result:=Trim(Result);
end;

function TXmlAttributeList.AsStrings: TStrings;
var
  Attribute: TXmlAttribute;
begin
  Result:=TStringList.Create;
  for Attribute in Self do
    Result.Add(Attribute.AsString);
end;

procedure TXmlAttributeList.Delete(const Name: String);
var
  Attribute: TXmlAttribute;
begin
  Attribute := Find(Name);
  if Assigned(Attribute) then
    Remove(Attribute);
end;

function TXmlAttributeList.Find(const Name: String): TXmlAttribute;
var
  Attribute: TXmlAttribute;
begin
  Result := NIL;
  for Attribute in Self do
    if ((Assigned(Document) and Document.IsSame(Attribute.Name, Name)) or // use the documents text comparison
       ((not Assigned(Document)) and (Attribute.Name = Name))) then begin // or if not Assigned then compare names case sensitive
      Result := Attribute;
      Break;
    end;
end;

function TXmlAttributeList.HasAttribute(const AttrName: String): Boolean;
begin
  Result := Assigned(Find(AttrName));
end;

{ TXmlNodeList }

function TXmlNodeList.Add(Value: TXmlNode): Integer;
var
  Index: Integer;
begin
  Index:=-1;
  try
    if Count > 0 then
      Index:=Last.Index;
  except
    Index:=-1;
  end;
  Result := inherited Add(Value);
  Value.ParentNode := Parent;
  Value.FLevel := Parent.Level + 1;
  Value.FIndex := Index + 1;
end;

function TXmlNodeList.Add(NodeType: TXmlNodeType = ntElement): TXmlNode;
begin
  Result := TXmlNode.Create(NodeType);
  try
    Add(Result);
  except
    Result.Free;
    raise;
  end;
  Result.Document := Document;
end;

function TXmlNodeList.Add(const Name: String; NodeType: TXmlNodeType): TXmlNode;
begin
  Result := Add(NodeType);
  Result.Name := Name;
end;

function TXmlNodeList.CountNames(const Name: String; var NodeList: TXmlNodeList; const SearchWithoutPrefix: Boolean): Integer;
begin
  NodeList:=FindNodes(Name, [], SearchWithoutPrefix);
  Result:=NodeList.Count;
end;

function TXmlNodeList.Find(const Name: String; NodeTypes: TXmlNodeTypes = [ntElement]; const SearchWithoutPrefix: Boolean = False): TXmlNode;
var
  Node: TXmlNode;
begin
  Result := NIL;
  for Node in Self do
    if ((NodeTypes = []) or (Node.NodeType in NodeTypes)) and (IsSame(IfThen(Document.GetSearchExcludeNamespacePrefix or SearchWithoutPrefix, Node.Name, Node.NameWithPrefix), Name)) then begin
      Result := Node;
      Break;
    end;
end;

function TXmlNodeList.Find(const Name, AttrName: String; NodeTypes: TXmlNodeTypes = [ntElement]; const SearchWithoutPrefix: Boolean = False): TXmlNode;
var
  Node: TXmlNode;
begin
  Result := NIL;
  for Node in Self do
    if ((NodeTypes = []) or (Node.NodeType in NodeTypes)) and
       ((Name = '') or ((Name <> '') and IsSame(IfThen(Document.GetSearchExcludeNamespacePrefix or SearchWithoutPrefix, Node.Name, Node.NameWithPrefix), Name))) and
       Node.HasAttribute(AttrName) then begin
      Result := Node;
      Break;
    end;
end;

function TXmlNodeList.Find(const Name, AttrName, AttrValue: String; NodeTypes: TXmlNodeTypes = [ntElement]; const SearchWithoutPrefix: Boolean = False): TXmlNode;
var
  Node: TXmlNode;
begin
  Result := NIL;
  for Node in Self do
    if ((NodeTypes = []) or (Node.NodeType in NodeTypes)) and // if no type specified or node type in types
       ((Name = '') or ((Name <> '') and IsSame(IfThen(Document.GetSearchExcludeNamespacePrefix or SearchWithoutPrefix, Node.Name, Node.NameWithPrefix), Name))) and
       Node.HasAttribute(AttrName) and IsSame(Node.Attributes[AttrName], AttrValue) then begin
      Result := Node;
      Break;
    end;
end;

function TXmlNodeList.FindNode(const Name: String; NodeTypes: TXmlNodeTypes = [ntElement]; const SearchWithoutPrefix: Boolean = False): TXmlNode;
begin
  Result := Find(Name, NodeTypes, SearchWithoutPrefix);
end;

function TXmlNodeList.FindNodes(const Name: String; NodeTypes: TXmlNodeTypes = [ntElement]; const SearchWithoutPrefix: Boolean = False): TXmlNodeList;
var
  Node: TXmlNode;
begin
  Result := TXmlNodeList.Create(False);
  Result.Document := Document;
  try
    for Node in Self do
      if ((NodeTypes = []) or (Node.NodeType in NodeTypes)) and IsSame(IfThen(Document.GetSearchExcludeNamespacePrefix or SearchWithoutPrefix, Node.Name, Node.NameWithPrefix), Name) then begin
        Result.Parent := Node.ParentNode;
        Result.Add(Node);
      end;
    Result.Parent := NIL;
  except
    Result.Free;
    raise;
  end;
end;

function TXmlNodeList.FirstChild: TXmlNode;
begin
  Result := First;
end;

function TXmlNodeList.Get(Index: Integer): TXmlNode;
begin
  if (Index < 0) or (Index >= Count) then
    Result := Nil
  else
    Result := Items[Index];
end;

function TXmlNodeList.HasNode(const Name: String; NodeTypes: TXmlNodeTypes = [ntElement]): Boolean;
begin
  Result := Assigned(Find(Name, NodeTypes));
end;

function TXmlNodeList.Insert(const Name: String; Position: Integer; NodeType: TXmlNodeType = ntElement): TXmlNode;
var
  Node, NodeBefore: TXmlNode;
  Index: Integer;
begin
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'Insert - enter', True);
{$ENDIF}
  Node:=Get(Position);
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'Insert - create node', True);
{$ENDIF}
  Index:=0;
  if Node <> Nil then
    Index:=Node.Index;
  Result := TXmlNode.Create;
  try
    Result.FLevel := Parent.Level + 1;
    Result.Document := Document;
    Result.Name := Name;
    Result.NodeType := NodeType;
  {$IFDEF LOGGING}
    DebugOutputStrToFile('XmlVerySimple.txt', 'Insert - insert to list', True);
  {$ENDIF}
    Insert(Position, Result);
    Result.FIndex := Index;
    if Position > 0 then try
      NodeBefore:=Get(Position - 1);
      Result.FPrevSibling := NodeBefore;
      NodeBefore.FNextSibling := Result;
    except
      // discard this
    end;
    if Node <> Nil then begin
      Result.FNextSibling := Node;
      Node.FPrevSibling := Result;
    end;
    // reindex nodes
  {$IFDEF LOGGING}
    DebugOutputStrToFile('XmlVerySimple.txt', 'Insert - reindexing nodes', True);
  {$ENDIF}
    while Node <> Nil do begin
      Node.FIndex:=Index + 1;
      Inc(Index);
      Node:=Node.NextSibling;
    end;
  except
  {$IFDEF LOGGING}
    DebugOutputStrToFile('XmlVerySimple.txt', 'Insert - exception', True);
  {$ENDIF}
    Result.Free;
    raise;
  end;
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'Insert - leave', True);
{$ENDIF}
end;

function TXmlNodeList.Insert(const NodeToInsert: TXmlNode; Position: Integer): TXmlNode;
var
  Node, NodeBefore: TXmlNode;
  Index: Integer;
begin
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'Insert - enter', True);
{$ENDIF}
  Node:=Get(Position);
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'Insert - create node', True);
{$ENDIF}
  Index:=0;
  if Node <> Nil then
    Index:=Node.Index;
  if NodeToInsert = Nil then begin
  {$IFDEF LOGGING}
    DebugOutputStrToFile('XmlVerySimple.txt', 'Insert - null node - exiting', True);
  {$ENDIF}
    Exit;
  end;
  Result := TXmlNode.Create;
  Result.Assign(NodeToInsert);
  try
    Result.FLevel := Parent.Level + 1;
    Result.Document := Document;
//    Result.Name := Name;
//    Result.NodeType := NodeType;
  {$IFDEF LOGGING}
    DebugOutputStrToFile('XmlVerySimple.txt', 'Insert - insert to list', True);
  {$ENDIF}
    Insert(Position, Result);
    Result.FIndex := Index;
    if Position > 0 then try
      NodeBefore:=Get(Position - 1);
      Result.FPrevSibling := NodeBefore;
      NodeBefore.FNextSibling := Result;
    except
      // discard this
    end;
    if Node <> Nil then begin
      Result.FNextSibling := Node;
      Node.FPrevSibling := Result;
    end;
    // reindex nodes
  {$IFDEF LOGGING}
    DebugOutputStrToFile('XmlVerySimple.txt', 'Insert - reindexing nodes', True);
  {$ENDIF}
    while Node <> Nil do begin
      Node.FIndex:=Index + 1;
      Inc(Index);
      Node:=Node.NextSibling;
    end;
  except
  {$IFDEF LOGGING}
    DebugOutputStrToFile('XmlVerySimple.txt', 'Insert - exception', True);
  {$ENDIF}
//    Result.Free;
    raise;
  end;
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'Insert - leave', True);
{$ENDIF}
end;

procedure TXmlNodeList.Remove(Index: Integer);
var
  Node: TXmlNode;
begin
  if Index >= 0 then begin
    Node:=Get(Index);
    if Node <> Nil then
      Node:=Node.NextSibling;
    Delete(Index);
    // reindex nodes
    while Node <> Nil do begin
      Node.FIndex:=Index;
      Inc(Index);
      Node:=Node.NextSibling;
    end;
  end;
end;

function TXmlNodeList.IsSame(const Value1, Value2: String): Boolean;
begin
  Result := ((Assigned(Document) and Document.IsSame(Value1, Value2)) or // use the documents text comparison
            ((not Assigned(Document)) and (Value1 = Value2))); // or if not Assigned then compare names case sensitive
end;

function TXmlNodeList.PreviousSibling(Node: TXmlNode): TXmlNode;
//var
//  Index: Integer;
begin
//  Index := Self.IndexOf(Node);
//  Index := Node.Index;
//  if Index - 1 >= 0 then
//    Result := Self[Index - 1]
//  else
//    Result := NIL;
  Result:=Node.PreviousSibling;
end;

function TXmlNodeList.NextSibling(Node: TXmlNode): TXmlNode;
//var
//  Index: Integer;
begin
//  if (not Assigned(Node)) and (Count > 0) then
//    Result := First
//  else begin
//    Index := Self.IndexOf(Node);
//    Index := Node.Index;
//    if (Index >= 0) and (Index + 1 < Count) then
//      Result := Self[Index + 1]
//    else
//      Result := NIL;
//  end;
  Result:=Node.NextSibling;
end;

{ TXmlAttribute }

function TXmlAttribute.AsString: String;
begin
  Result := Name;
  if AttributeType = atSingle then
    Exit;
  Result := Result + '="' + Escape(Value) + '"';
end;

constructor TXmlAttribute.Create;
begin
  AttributeType := atSingle;
end;

class function TXmlAttribute.Escape(const Value: String): String;
//begin
//  Result := ReplaceStr(Value, '&', '&amp;');
//  Result := ReplaceStr(Result, '<', '&lt;');
//  Result := ReplaceStr(Result, '>', '&gt;');
//  Result := ReplaceStr(Result, '"', '&quot;');
//end;
var
  sLen, sIndex: Integer;
begin
  sLen:=Length(Value);
  sIndex := 1;
  Result:=Value;
  while sIndex <= sLen do begin
    case Result[sIndex] of
      '&': begin
        Insert('amp;', Result, sIndex + 1);
        Inc(sIndex, 4);
        Inc(sLen, 4);
      end;
      '<': begin
        Result[sIndex]:='&';
        Insert('lt;', Result, sIndex + 1);
        Inc(sIndex, 3);
        Inc(sLen, 3);
      end;
      '>': begin
        Result[sIndex]:='&';
        Insert('gt;', Result, sIndex + 1);
        Inc(sIndex, 3);
        Inc(sLen, 3);
      end;
      '"': begin
        Result[sIndex]:='&';
        Insert('quot;', Result, sIndex + 1);
        Inc(sIndex, 5);
        Inc(sLen, 5);
      end;
      '''': begin
        Result[sIndex]:='&';
        Insert('apos;', Result, sIndex + 1);
        Inc(sIndex, 5);
        Inc(sLen, 5);
      end;
    end;
    Inc(sIndex);
  end;
end;

procedure TXmlAttribute.SetValue(const Value: String);
begin
  FValue := Value;
  AttributeType := atValue;
end;

{ TStreamWriterHelper }

constructor TStreamWriterHelper.Create(Stream: TStream; Encoding: TEncoding; WritePreamble: Boolean; BufferSize: Integer);
begin
  Create(Stream, Encoding, BufferSize);
  if not WritePreamble then begin
    Self.BaseStream.Position:=0;
    Self.BaseStream.Size:=0;
  end;
end;

constructor TStreamWriterHelper.Create(Filename: string; Append: Boolean; Encoding: TEncoding; WritePreamble: Boolean;
  BufferSize: Integer);
begin
  Create(Filename, Append, Encoding, BufferSize);
  if not WritePreamble then begin
    Self.BaseStream.Position:=0;
    Self.BaseStream.Size:=0;
  end;
end;

{$IF CompilerVersion < 24}

{ TStreamReaderHelper }

function TStreamReaderHelper.FirstChar: Char;
begin
  if PrepareBuffer(1) then
    Result := Self.FBufferedData.Chars[0]
  else
    Result := #0;
end;

procedure TStreamReaderHelper.IncCharPos(Value: Integer);
begin
  if PrepareBuffer(Value) then
    Self.FBufferedData.Remove(0, Value);
end;

function TStreamReaderHelper.IsUppercaseText(const Value: String): Boolean;
var
  ValueLength: Integer;
  Text: String;
begin
  Result := False;
  ValueLength := Length(Value);

  if PrepareBuffer(ValueLength) then begin
    Text := Self.FBufferedData.ToString(0, ValueLength);
    if Text = Value then begin
      Self.FBufferedData.Remove(0, ValueLength);
      Result := True;
    end;
  end;
end;

function TStreamReaderHelper.PrepareBuffer(Value: Integer): Boolean;
begin
  Result := False;

  if Self.FBufferedData = NIL then
    Exit;

  if (Self.FBufferedData.Length < Value) and (not Self.FNoDataInStream) then
    Self.FillBuffer(Self.FEncoding);

  Result := (Self.FBufferedData.Length >= Value);
end;

function TStreamReaderHelper.ReadText(const StopChars: String; Options: TExtractTextOptions): String;
var
  NewLineIndex: Integer;
  PostNewLineIndex: Integer;
  StopChar: Char;
  Found: Boolean;
  TempIndex: Integer;
  StopCharLength: Integer;
begin
  Result := '';
  if Self.FBufferedData = NIL then
    Exit;
  NewLineIndex := 0;
  PostNewLineIndex := 0;
  StopCharLength := Length(StopChars);

  while True do begin
    // if we're searching for a string then assure the buffer is wide enough
    if (etoStopString in Options) and (NewLineIndex + StopCharLength > Self.FBufferedData.Length) and
       (not Self.FNoDataInStream) then
      Self.FillBuffer(Self.FEncoding);

    if NewLineIndex >= Self.FBufferedData.Length then begin
      if Self.FNoDataInStream then begin
        PostNewLineIndex := NewLineIndex;
        Break;
      end
      else begin
        Self.FillBuffer(Self.FEncoding);
        if Self.FBufferedData.Length = 0 then
          Break;
      end;
    end;

    if etoStopString in Options then begin
      if NewLineIndex + StopCharLength - 1 < Self.FBufferedData.Length then begin
        Found := True;
        TempIndex := NewLineIndex;
        for StopChar in StopChars do
          if Self.FBufferedData[TempIndex] <> StopChar then begin
            Found := False;
            Break;
          end
          else
            Inc(TempIndex);

        if Found then begin
          if etoDeleteStopChar in Options then
            PostNewLineIndex := NewLineIndex + StopCharLength
          else
            PostNewLineIndex := NewLineIndex;
          Break;
        end;
      end;
    end
    else begin
      Found := False;
      for StopChar in StopChars do
        if Self.FBufferedData[NewLineIndex] = StopChar then begin
          if etoDeleteStopChar in Options then
            PostNewLineIndex := NewLineIndex + 1
          else
            PostNewLineIndex := NewLineIndex;
          Found := True;
          Break;
        end;
      if Found then
        Break;
    end;

    Inc(NewLineIndex);
  end;

  if NewLineIndex > 0 then
    Result := Self.FBufferedData.ToString(0, NewLineIndex);
  Self.FBufferedData.Remove(0, PostNewLineIndex);
end;

{$ELSE}

{ TXmlStreamReader }

constructor TXmlStreamReader.Create(Stream: TStream; Encoding: TEncoding; DetectBOM: Boolean; BufferSize: Integer);
begin
  inherited;
  FBufferedData := TRttiContext.Create.GetType(TStreamReader).GetField('FBufferedData').GetValue(Self).AsObject as TStringBuilder;
  FNoDataInStream := Pointer(NativeInt(Self) + TRttiContext.Create.GetType(TStreamReader).GetField('FNoDataInStream').Offset);
  GetFillBuffer(FFillBuffer);
end;

function TXmlStreamReader.FirstChar: Char;
begin
  if PrepareBuffer(1) then
    Result := Self.FBufferedData.Chars[0]
  else
    Result := #0;
end;

procedure TXmlStreamReader.IncCharPos(Value: Integer);
begin
  if PrepareBuffer(Value) then
    Self.FBufferedData.Remove(0, Value);
end;

function TXmlStreamReader.IsUppercaseText(const Value: String): Boolean;
var
  ValueLength: Integer;
  Text: String;
begin
  Result := False;
  ValueLength := Length(Value);

  if PrepareBuffer(ValueLength) then begin
    Text := Self.FBufferedData.ToString(0, ValueLength);
    if Text = Value then begin
      Self.FBufferedData.Remove(0, ValueLength);
      Result := True;
    end;
  end;
end;

function TXmlStreamReader.PrepareBuffer(Value: Integer): Boolean;
begin
  Result := False;

  if Self.FBufferedData = NIL then
    Exit;

  if (Self.FBufferedData.Length < Value) and (not Self.FNoDataInStream^) then
    Self.FillBuffer;

  Result := (Self.FBufferedData.Length >= Value);
end;

function TXmlStreamReader.ReadText(const StopChars: String; Options: TExtractTextOptions): String;
var
  NewLineIndex: Integer;
  PostNewLineIndex: Integer;
  StopChar: Char;
  Found: Boolean;
  TempIndex: Integer;
  StopCharLength: Integer;
begin
  Result := '';
  if Self.FBufferedData = NIL then
    Exit;
  NewLineIndex := 0;
  PostNewLineIndex := 0;
  StopCharLength := Length(StopChars);

  while True do begin
    // if we're searching for a string then assure the buffer is wide enough
    if (etoStopString in Options) and (NewLineIndex + StopCharLength > Self.FBufferedData.Length) and
       (not Self.FNoDataInStream^) then
      Self.FillBuffer;

    if NewLineIndex >= Self.FBufferedData.Length then begin
      if Self.FNoDataInStream^ then begin
        PostNewLineIndex := NewLineIndex;
        Break;
      end
      else begin
        Self.FillBuffer;
        if Self.FBufferedData.Length = 0 then
          Break;
      end;
    end;

    if etoStopString in Options then begin
      if NewLineIndex + StopCharLength - 1 < Self.FBufferedData.Length then begin
        Found := True;
        TempIndex := NewLineIndex;
        for StopChar in StopChars do
          if Self.FBufferedData[TempIndex] <> StopChar then begin
            Found := False;
            Break;
          end
          else
            Inc(TempIndex);

        if Found then begin
          if etoDeleteStopChar in Options then
            PostNewLineIndex := NewLineIndex + StopCharLength
          else
            PostNewLineIndex := NewLineIndex;
          Break;
        end;
      end;
    end
    else begin
      Found := False;
      for StopChar in StopChars do
        if Self.FBufferedData[NewLineIndex] = StopChar then begin
          if etoDeleteStopChar in Options then
            PostNewLineIndex := NewLineIndex + 1
          else
            PostNewLineIndex := NewLineIndex;
          Found := True;
          Break;
        end;
      if Found then
        Break;
    end;

    Inc(NewLineIndex);
  end;

  if NewLineIndex > 0 then
    Result := Self.FBufferedData.ToString(0, NewLineIndex);
  Self.FBufferedData.Remove(0, PostNewLineIndex);
end;

procedure TXmlStreamReader.FillBuffer;
var
  TempEncoding: TEncoding;
begin
  TempEncoding := CurrentEncoding;
  FFillBuffer(TempEncoding);
  if TempEncoding <> CurrentEncoding then
    TRttiContext.Create.GetType(TStreamReader).GetField('FEncoding').SetValue(Self, TempEncoding)
end;

{function TXmlStreamReader.NoDataInStream: Boolean;
begin
  Result := TRttiContext.Create.GetType(TStreamReader).GetField('FNoDataInStream').GetValue(Self).AsBoolean;
end;}

{ TStreamReaderHelper }

procedure TStreamReaderHelper.GetFillBuffer(var Method: TStreamReaderFillBuffer);
begin
  TMethod(Method).Code := @TStreamReader.FillBuffer;
  TMethod(Method).Data := Self;
end;

{$IFEND}

end.
