{ VerySimpleXML v2.7.0 - a lightweight, one-unit, cross-platform XML reader/writer
  for Delphi 2010-XE10.3 by Dennis Spreen
  http://blog.spreendigital.de/2011/11/10/verysimplexml-a-lightweight-delphi-xml-reader-and-writer/

  (c) Copyrights 2011-2026 Dennis D. Spreen <dennis@spreendigital.de>
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
  XPATH support made by NevTon.
  Portions copyright (C) 2015-2026 Grzegorz Molenda aka NevTon; ViTESOFT.net; <gmnevton@o2.pl>
}
unit XML.VerySimple;

interface

{.$DEFINE LOGGING}

uses
  Classes, SysUtils, Generics.Defaults, Generics.Collections;

const
  TXmlSpaces = #$20 + #$0A + #$0D + #9;
  //
  sSourcePosition = #13#10'Pos: %d';
  //
  sParserUnexpected = 'Expected %s but got %s.' + sSourcePosition;
  sInvalidFloatingPt = 'Invalid floating-point constant - expected one or more digits after ".".' + sSourcePosition;
  sInvalidFloatingPtExpt = 'Invalid floating-point constant - expected one or more digits as part of exponent.' + sSourcePosition;
  sUnterminatedString = 'Unterminated string found.' + sSourcePosition;
  sInvalidOperator = 'Invalid operator in source (%s).' + sSourcePosition;
  sInvalidOperatorChar = 'Invalid character in source (%s).' + sSourcePosition;
  sExpectedEOF = 'Expected EOF! There is trailing text in expression.' + sSourcePosition;
  sTooManyArgs = 'Too many arguments ( >65535 ).' + sSourcePosition;
  sExpectedIdentifier = 'Expected an identifier, number or string.' + sSourcePosition;

type
  EXmlVerySimple = class(Exception);
  EXmlNodeException = class(EXmlVerySimple);
  EXmlXPathException = class(EXmlVerySimple);

  TXmlVerySimple = class;
  TXmlNode = class;
  TXmlNodeType = (ntElement, ntAttribute, ntText, ntCData, ntProcessingInstr, ntComment, ntDocument, ntDocType, ntXmlDecl);
  TXmlNodeTypes = set of TXmlNodeType;
  TXmlNodeList = class;
  TXmlAttributeType = (atValue, atSingle);
  TXmlNodeSearchType = (nsRecursive, nsSearchWithoutPrefix);
  TXmlNodeSearchTypes = set of TXmlNodeSearchType;
  TXmlOptions = set of (doNodeAutoIndent, doSmartNodeAutoIndent, doCompact, doCompactWithBreakes, doParseProcessingInstr, doPreserveWhiteSpace, doCaseInsensitive,
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

  TXmlStringHashList = class
  private type
    THashItem = record
      Hash: Cardinal;
      Index: Integer;
    end;
  private
    FCount: Integer;
    StringList: TStringList;
    HashList: Array of THashItem;
  public
    constructor Create;
    destructor Destroy; override;
    //
    procedure Clear;
    function HashOf(const Key: String): Cardinal;
    function Find(const Key: String; var AItem: THashItem): Integer; overload;
    function Find(const Hash: Cardinal; var AItem: THashItem): Integer; overload;
    function Add(const Value: String): Cardinal;
    function GetStrByHash(const Hash: Cardinal): String;
    function GetStrByIndex(const Index: Integer): String;
  end;

  TXmlAttribute = class(TObject)
  private
    ///	<summary> Attribute name </summary>
    FName: Cardinal;
    FValue: Cardinal;
    function GetName: String;
    function Getvalue: String;
    procedure SetName(const Value: String);
    procedure SetValue(const Value: String);
  public
    [Weak] Document: TXmlVerySimple;
    ///	<summary> Attributes without values are set to atSingle, else to atValue </summary>
    AttributeType: TXmlAttributeType;
    ///	<summary> Create a new attribute </summary>
    constructor Create; virtual;
    ///	<summary> Return the attribute as a String </summary>
    function AsString: String;
    /// <summary> Escapes XML control characters </summar>
    class function Escape(const Value: String): String; virtual;
    ///	<summary> Attribute value (always a String) </summary>
    property Name: String read GetName write SetName;
    property Value: String read GetValue write SetValue;
  end;

  TXmlObjectList = class(TObjectList<TObject>)
  public
    ///	<summary> The xml document of the attribute list of the node</summary>
    [Weak] Document: TXmlVerySimple;
  end;

  TXmlAttributeList = class;

  TXmlAttributeEnumerator = class
  private
    FAttributeList: TXmlAttributeList;
    FIndex: Integer;
  public
    constructor Create(List: TXmlAttributeList);
    function GetCurrent: TXmlAttribute;
    function MoveNext: Boolean;
    property Current: TXmlAttribute read GetCurrent;
  end;

  TXmlAttributeList = class(TXmlObjectList)
  public
    function First: TXmlAttribute; reintroduce;
    function Last: TXmlAttribute; reintroduce;
    function GetEnumerator: TXmlAttributeEnumerator; reintroduce;
    ///
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
  TXmlNodeDefinitionPart = (ndpFull, ndpOpen, ndpClose);

  TXmlNode = class(TObject)
  private
    ///	<summary> Name of the node </summary>
    FNameWithPrefix: Cardinal; // Node name
    ///	<summary> All attributes of the node </summary>
    FAttributeList: TXmlAttributeList;
    ///	<summary> List of child nodes, never NIL </summary>
    FChildNodes: TXmlNodeList;
    FLevel: Cardinal; // node level in tree structure
    FIndex: Cardinal; // node index in nodes list structure
    FPrevSibling,           // link to the node's previous sibling or nil if it is the first node
    FNextSibling: TXmlNode; // link to the node's next sibling or nil if it is the last node
    ///	<summary> Text value of the node </summary>
    FText: Cardinal;

    procedure SetName(Value: String);
    function GetName: String;
    function GetNameWithPrefix: String;
    function GetPrefix: String;
    function GetText: String;
    procedure SetText(Value: String);
    function IsSame(const Value1, Value2: String): Boolean;
    ///	<summary> Find a child node by its name in tree </summary>
    function FindNodeRecursive(const Name: String; NodeTypes: TXmlNodeTypes = [ntElement]; const SearchOptions: TXmlNodeSearchTypes = []): TXmlNode; overload; virtual;
    ///	<summary> Find a child node by name and attribute name in tree </summary>
    function FindNodeRecursive(const Name, AttrName: String; NodeTypes: TXmlNodeTypes = [ntElement]; const SearchOptions: TXmlNodeSearchTypes = []): TXmlNode; overload; virtual;
    ///	<summary> Find a child node by name, attribute name and attribute value in tree </summary>
    function FindNodeRecursive(const Name, AttrName, AttrValue: String; NodeTypes: TXmlNodeTypes = [ntElement]; const SearchOptions: TXmlNodeSearchTypes = []): TXmlNode; overload; virtual;
  protected
    [Weak] FDocument: TXmlVerySimple;

    procedure SetDocument(Value: TXmlVerySimple);
    function GetAttr(const AttrName: String): String; virtual;
    procedure SetAttr(const AttrName: String; const AttrValue: String); virtual;
    function GetNodeValue: String; virtual;
    procedure SetNodeValue(const Value: String); virtual;
    procedure Compose(Writer: TStreamWriter; RootNode: TXmlNode); virtual;
    function  ComposeNode(Writer: TStreamWriter; const WhichPart: TXmlNodeDefinitionPart): String; virtual;
    procedure Walk(Writer: TStreamWriter; const LineBreak, PrefixNode: String; Node: TXmlNode; const WalkChildren: Boolean = True; const WhichPart: TXmlNodeDefinitionPart = ndpFull); virtual;
  public
    ///	<summary> The node type, see TXmlNodeType </summary>
    NodeType: TXmlNodeType;
    ///	<summary> Parent node, may be NIL </summary>
    [Weak] ParentNode: TXmlNode;
    ///	<summary> User data value of the node </summary>
    UserData: String;
    /// <summary> Creates a new XML node </summary>
    constructor Create(ANodeType: TXmlNodeType = ntElement); overload; virtual;
    constructor Create(ANode: TXmlNode); overload; virtual;
    ///	<summary> Removes the node from its parent and frees all of its childs </summary>
    destructor Destroy; override;
    //
    procedure CreateAttributeList;
    procedure CreateChildNodes;
    /// <summary> Assigns an existing XML node to this </summary>
    procedure Assign(const Node: TXmlNode); virtual;
    /// <summary> Assigns an existing XML node attributes to this </summary>
    procedure AssignAttributes(const Node: TXmlNode; const AddNotExistingOnly: Boolean = False); virtual;
    ///	<summary> Gets text representation of current node child nodes </summary>
    function AsString: String; virtual;
    ///	<summary> Gets text representation of current node </summary>
    function ToString(const WhichPart: TXmlNodeDefinitionPart): String; virtual;
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
    function HasChild(const Name: String; NodeTypes: TXmlNodeTypes = [ntElement]): Boolean; overload; virtual;
    function HasChild(const Name: String; out Node: TXmlNode; NodeTypes: TXmlNodeTypes = [ntElement]): Boolean; overload; virtual;
    function HasChild(const Name: String; out NodeList: TXmlNodeList; NodeTypes: TXmlNodeTypes = [ntElement]): Boolean; overload; virtual;
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
    //function SetText(const Value: String): TXmlNode; virtual;
    ///	<summary> Fluent interface for setting the node attribute given by attribute name and attribute value </summary>
    function SetAttribute(const AttrName, AttrValue: String): TXmlNode; virtual;
    ///	<summary> Returns first child or NIL if there aren't any child nodes </summary>
    function FirstChild: TXmlNode; overload; virtual;
    function FirstChild(const Name: String): TXmlNode; overload; virtual;
    ///	<summary> Returns last child node or NIL if there aren't any child nodes </summary>
    function LastChild: TXmlNode; overload; virtual;
    function LastChild(const Name: String): TXmlNode; overload; virtual;
    ///	<summary> Returns previous sibling </summary>
    function PreviousSibling: TXmlNode; overload; virtual;
    ///	<summary> Returns next sibling </summary>
    function NextSibling: TXmlNode; overload; virtual;
    ///	<summary> Returns True if the node has at least one child node </summary>
    function HasChildNodes: Boolean; virtual;
    ///	<summary> Returns True if the node has Text child node </summary>
    function HasTextChildNode: Boolean; virtual;
    ///	<summary> Returns True if the node has a text content and no child nodes </summary>
    function IsTextElement: Boolean; virtual;
    ///	<summary> Fluent interface for setting the node type </summary>
    function SetNodeType(Value: TXmlNodeType): TXmlNode; virtual;
    ///	<summary> Name of the node </summary>
    property Name: String read GetName write SetName;
    ///	<summary> Name of the node </summary>
    property NameWithPrefix: String read GetNameWithPrefix;
    ///	<summary> Prefix of the node Name </summary>
    property Prefix: String read GetPrefix;
    ///	<summary> Attributes of a node, accessible by attribute name (case insensitive) </summary>
    property Attributes[const AttrName: String]: String read GetAttr write SetAttr;
    property AttributeList: TXmlAttributeList read FAttributeList;
    ///	<summary> List of child nodes, never NIL </summary>
    property ChildNodes: TXmlNodeList read FChildNodes;
    ///	<summary> The xml document of the node </summary>
    property Document: TXmlVerySimple read FDocument write SetDocument;
    ///	<summary> The node name, same as property Name </summary>
    property NodeName: String read GetName write SetName;
    ///	<summary> The child node text if node has children and first child is text node </summary>
    property NodeValue: String read GetNodeValue write SetNodeValue;
    ///	<summary> The node Level in tree </summary>
    property Level: Cardinal read FLevel;
    ///	<summary> The node Index in list </summary>
    property Index: Cardinal read FIndex;
    ///	<summary> Text value of the node </summary>
    property Text: String read GetText write SetText;
  end;

  TXmlNodeEnumerator = class
  private
    FNodeList: TXmlNodeList;
    FIndex: Integer;
  public
    constructor Create(List: TXmlNodeList);
    function GetCurrent: TXmlNode;
    function MoveNext: Boolean;
    property Current: TXmlNode read GetCurrent;
  end;

  TXmlNodeList = class(TXmlObjectList)
  private
    function IsSame(const Value1, Value2: String): Boolean;
  protected
    procedure FindNodesRecursive(const List: TXmlNodeList; const Name: String; NodeTypes: TXmlNodeTypes = [ntElement]; const SearchWithoutPrefix: Boolean = False); virtual;
  public
    ///	<summary> The parent node of the node list </summary>
    [Weak] Parent: TXmlNode;
    //
    /// <summary> Assigns an existing XML node to this </summary>
    function First: TXmlNode; reintroduce;
    function Last: TXmlNode; reintroduce;
    function GetEnumerator: TXmlNodeEnumerator; reintroduce;
    ///
    ///	<summary> Adds a node and sets the parent of the node to the parent of the list </summary>
    function Add(Value: TXmlNode): Integer; overload; virtual;
    ///	<summary> Adds a node and sets the parent of the node to the parent of the list </summary>
    function Add(Value: TXmlNode; ParentNode: TXmlNode): Integer; overload; virtual;
    ///	<summary> Creates a new node of type NodeType (default ntElement) and adds it to the list </summary>
    function Add(NodeType: TXmlNodeType = ntElement): TXmlNode; overload; virtual;
    ///	<summary> Add a child node with an optional NodeType (default: ntElement)</summary>
    function Add(const Name: String; NodeType: TXmlNodeType = ntElement): TXmlNode; overload; virtual;
    ///	<summary> Add nodes from another list </summary>
    procedure Add(const List: TXmlNodeList); overload; virtual;
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
    function HasNode(const Name: String; NodeTypes: TXmlNodeTypes = [ntElement]): Boolean; overload; virtual;
    function HasNode(const Name: String; out Node: TXmlNode; NodeTypes: TXmlNodeTypes = [ntElement]): Boolean; overload; virtual;
    function HasNode(const Name: String; out NodeList: TXmlNodeList; NodeTypes: TXmlNodeTypes = [ntElement]): Boolean; overload; virtual;
    ///	<summary> Returns the first child node, same as .First </summary>
    function FirstChild: TXmlNode; virtual;
    ///	<summary> Returns the last child node, same as .Last </summary>
    function LastChild: TXmlNode; virtual;
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
    SkipIndent: Boolean; // used internally to tighten the output of xml nodes to string representation
    ParentIndentNode: TXmlNode;
    //
    StringHashList: TXmlStringHashList;
  protected
    Root: TXmlNode;
    [Weak] FHeader: TXmlNode;
    [Weak] FDocumentElement: TXmlNode;
    XmlEscapeProcedure: TXmlEscapeProcedure;
    procedure Parse(Reader: TXmlReader); virtual;
    procedure ParseComment(Reader: TXmlReader; var Parent: TXmlNode); virtual;
    procedure ParseDocType(Reader: TXmlReader; var Parent: TXmlNode); virtual;
    procedure ParseProcessingInstr(Reader: TXmlReader; var Parent: TXmlNode); virtual;
    procedure ParseCData(Reader: TXmlReader; var Parent: TXmlNode); virtual;
    procedure ParseText(const Line: String; Parent: TXmlNode); virtual;
    function ParseTag(Reader: TXmlReader; var Parent: TXmlNode): TXmlNode; overload; virtual;
    function ParseTag(const TagStr: String; var Parent: TXmlNode): TXmlNode; overload; virtual;
    procedure SetText(const Value: String); virtual;
    function GetText: String; virtual;
    procedure SetEncoding(const Value: String); virtual;
    function GetEncoding: String; virtual;
    procedure SetVersion(const Value: String); virtual;
    function GetVersion: String; virtual;
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
    /// <summary> XPath nodes delimiter char </summary>
    XPathDelimiter: Char;
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
    ///	<summary> Selects node by evaluating XPath expression, creates nodes tree if necessary </summary>
    function SelectNode(const XPathExpression: String; RootNode: TXmlNode = Nil): TXmlNode; virtual;
    ///	<summary> Selects nodes by evaluating XPath expression, allways returns a list that must be manually destroyed </summary>
    function SelectNodes(const XPathExpression: String; RootNode: TXmlNode = Nil): TXmlNodeList; virtual;
    ///	<summary> Saves the XML to a file </summary>
    function SaveToFile(const FileName: String): TXmlVerySimple; overload; virtual;
    function SaveToFile(const FileName: String; const EscapeProcedure: TXmlEscapeProcedure): TXmlVerySimple; overload; virtual;
    ///	<summary> Saves the XML to a stream, the encoding is specified in the .Encoding property </summary>
    function SaveToStream(const Stream: TStream; const RootNode: TXmlNode = Nil): TXmlVerySimple; virtual;
    ///	<summary> Remove style sheet for the document </summary>
    procedure RemoveStyleSheet; virtual;
    ///	<summary> Sets style sheet for the document </summary>
    procedure SetStyleSheet(const Path: String); virtual;
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
  CInvalidStrHashId = High(LongWord);
{$IF CompilerVersion >= 24} // Delphi XE3+ can use Low(), High() and TEncoding.ANSI
  LowStr = Low(String); // Get string index base, may be 0 (NextGen compiler) or 1 (standard compiler)

{$ELSE} // For any previous Delphi version overwrite High() function and use 1 as string index base
  LowStr = 1;  // Use 1 as string index base

function High(const Value: String): Integer; overload; inline;
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

{
  Simplified XPath expression evaluator.
    Based on XPath tutorial from: https://www.w3schools.com/xml/xpath_intro.asp

  Currently supported are:
    > Syntax elements:
        nodename                  selects all child nodes of the node
        /                         selects from the root node
        //                        selects in complete subtree
        @                         selects attributes
        .                         selects the current node
        ..                        selects the parrent of the current node


    > Predicates:
        [n]                       selects the n-th subelement of the current element ('n' is a number, first subelement has index 1)
        [@attr]                   selects all subelements that have an attribute named 'attr'
        [@attr='x']               selects all subelements that have an attribute named 'attr' with a value of 'x'
        [@attr="x"]               or
        [node]                    selects all subelements named 'node'
        [node='x']                selects all subelements named node containing text 'x'
        [node="x"]                or


    > Wildcards:
        *                         matches any element node
        @*                        matches any attribute node


    > XPath axes: - !!! NOT SUPPORTED !!!
        ancestor                  selects all ancestors (parent, grandparent, etc.) of the current node
        ancestor-or-self          selects all ancestors (parent, grandparent, etc.) of the current node and the current node itself
        attribute                 selects all attributes of the current node
        child                     selects all children of the current node
        descendant                selects all descendants (children, grandchildren, etc.) of the current node
        descendant-or-self        selects all descendants (children, grandchildren, etc.) of the current node and the current node itself
        following                 selects everything in the document after the closing tag of the current node
        following-sibling         selects all siblings after the current node
        namespace                 selects all namespace nodes of the current node
        parent                    selects the parent of the current node
        preceding                 selects all nodes that appear before the current node in the document, except ancestors, attribute nodes and namespace nodes
        preceding-sibling         selects all siblings before the current node
        self                      selects the current node


    > Location Path Expression:
        An absolute location path:
          /step/step/...

        A relative location path:
          step/step/...

        axisname::nodetest[predicate] - !!! NOT SUPPORTED !!!

      Examples:
        child::book               selects all book nodes that are children of the current node
        attribute::lang           selects the lang attribute of the current node
        child::*                  selects all element children of the current node
        attribute::*              selects all attributes of the current node
        child::text()             selects all text node children of the current node
        child::node()             selects all children of the current node
        descendant::book          selects all book descendants of the current node
        ancestor::book            selects all book ancestors of the current node
        ancestor-or-self::book    selects all book ancestors of the current node - and the current as well if it is a book node
        child::*/child::price     selects all price grandchildren of the current node


    > XPath Operators:
        |       Computes two node-sets          //book | //cd
        +       Addition                        6 + 4
        -       Subtraction                     6 - 4
        *       Multiplication                  6 * 4
        div     Integer division                8 div 4
        =       Equal                           price = 9.80
        !=      Not equal                       price != 9.80
        <       Less than                       price < 9.80
        <=      Less than or equal to           price <= 9.80
        >       Greater than                    price > 9.80
        >=      Greater than or equal to        price >= 9.80
        or      or                              price = 9.80 or price = 9.70
        and     and                             price > 9.00 and price < 9.90
        mod     Modulus (division remainder)    5 mod 2


  Examples:
    bookstore                               selects all nodes with the name "bookstore"
    /bookstore                              selects the root element bookstore
                                              note: If the path starts with a slash ( / ) it always represents an absolute path to an element
    bookstore/book                          selects all book elements that are children of bookstore
    //book                                  selects all book elements no matter where they are in the document
    bookstore//book                         selects all book elements that are descendant of the bookstore element, no matter where they are under the bookstore element
    //@lang                                 selects all attributes that are named lang

    /bookstore/book[1]                      selects the first book element that is the child of the bookstore element
                                              note: In IE 5,6,7,8,9 first node is[0], but according to W3C, it is [1]
    //title[@lang]                          selects all the title elements that have an attribute named lang
    //title[@lang='en']                     selects all the title elements that have a "lang" attribute with a value of "en"
    //title                                 select all titles
    /bookstore/book/title                   select all titles
    /bookstore//title[@lang]                select all titles with lang attribute
    /bookstore/book[3]/*                    select all nodes of the third book
    /bookstore/book[1]/title/@lang          select language of the first book
    /bookstore/book/title/@lang             select all languages
    //title/@lang                           select all languages
    //book//@lang                           select all languages
    /bookstore/*                            selects all the child element nodes of the bookstore element
    //*                                     selects all elements in the document
    //title[@*]                             selects all title elements which have at least one attribute of any kind

  Not working at this time:
    /bookstore/book[last()]                 selects the last book element that is the child of the bookstore element
    /bookstore/book[last()-1]               selects the last but one book element that is the child of the bookstore element
    /bookstore/book[position()<3]           selects the first two book elements that are children of the bookstore element
    /bookstore/book[price>35.00]            selects all the book elements of the bookstore element that have a price element with a value greater than 35.00
    /bookstore/book[price>35.00]/title      selects all the title elements of the book elements of the bookstore element that have a price element with a value greater than 35.00
    /bookstore/book/title[@lang=''en'']     select all english books
    //title[@lang=''en'']                   select all english books
    /bookstore//book[title="Harry Potter"]  select all Harry Potter books
    @lang                                   select lang attribute of the current node
    title                                   select the title subnode of some node
    ./title                                 select the title subnode of some node
    //book/title | //book/price             selects all the title AND price elements of all book elements
    //title | //price                       selects all the title AND price elements in the document
    /bookstore/book/title | //price         selects all the title elements of the book element of the bookstore element AND all the price elements in the document
}
type
// Documentation:
// 1.0) https://www.w3.org/TR/1999/REC-xpath-19991116/#exprlex
// 2.0) https://www.w3.org/TR/2010/REC-xpath20-20101214/#id-predicates
// 3.0) https://www.w3.org/TR/2014/REC-xpath-30-20140408/
// 3.1) https://www.w3.org/TR/2017/REC-xpath-31-20170321/
//
//
// :From-1.0:
// When tokenizing, the longest possible token is always returned.
// For readability, whitespace may be used in expressions even though not explicitly allowed by the grammar:
//   ExprWhitespace may be freely added within patterns before or after any ExprToken.
//
// The following special tokenization rules must be applied in the order specified to disambiguate the ExprToken grammar:
//   - If there is a preceding token and the preceding token is not one of @, ::, (, [ or an Operator,
//     then a * must be recognized as a MultiplyOperator and an NCName must be recognized as an OperatorName.
//   - If the character following an NCName (possibly after intervening ExprWhitespace) is (,
//     then the token must be recognized as a NodeType or a FunctionName.
//   - If the two characters following an NCName (possibly after intervening ExprWhitespace) are ::,
//     then the token must be recognized as an AxisName.
//   - Otherwise, the token MUST NOT be recognized as a MultiplyOperator, an OperatorName, a NodeType, a FunctionName, or an AxisName.
//
// ExprWhitespace ::= (#x20 | #x9 | #xD | #xA)+
//
// regexp quantifiers:
// * - match zero or more
// ? - match zero or one
// + - match one or more

  TXmlXPathPredicateExpression = class
  private
    FRootNode: TXmlNode;
    FSource: String;
    FSourceStart: PChar;
  protected type
    TLexicalToken = (
      lexBof,
      lexEof,
      lexIdent,    // 'nodename'
      lexAttrib,   // '@attribname'
      //lexNameTest, // NameTest ::= '*' | NCName ':' '*' | QName
      //lexNodeType, // NodeType ::= 'comment' | 'text' | 'processing-instruction' | 'node'
      //lexOperator, // Operator ::= OperatorName | MultiplyOperator | '/' | '//' | '|' | '+' | '-' | '=' | '!=' | '<' | '<=' | '>' | '>='
      //lexOperatorName, // OperatorName ::= 'and' | 'or' | 'mod' | 'div' | 'idiv'(2.0)
      //lexOperatorMultiply, // MultiplyOperator ::= '*'
      //lexFunctionName, // FunctionName ::= QName - NodeType
      //lexAxisName, // AxisName ::= 'ancestor' | 'ancestor-or-self' | 'attribute' | 'child' | 'descendant' | 'descendant-or-self' | 'following' | 'following-sibling' | 'namespace'
                   //              | 'parent' | 'preceding' | 'preceding-sibling' | 'self'
      //lexLiteral,  // Literal ::= '"' [^"]* '"' | "'" [^']* "'" ---> string
      lexString,
      //lexNumber,   // Number ::= Digits ('.' Digits?)? | '.' Digits ---> integer or float
                     // Digits ::= [0-9]+
      lexInteger,
      lexFloat,
      lexVariableReference, // VariableReference ::= '$' QName

      lexPlus,         // '+'
      lexMinus,        // '-'
      lexAsterisk,     // '*'
      lexSlash,        // '/'
      lexSlashSlash,   // '//'
      lexPipe,         // '|'
      lexEqualTo,      // '='  or eq
      lexNotEqual,     // '!=' or ne
      lexLessThan,     // '<'  or lt
      lexLessEqual,    // '<=' or le
      lexGreaterThan,  // '>'  or gt
      lexGreaterEqual, // '>=' or ge

      lexLParen,       // '('
      lexRParen,       // ')'
      lexLBracket,     // '['
      lexRBracket,     // ']'
      lexDot,          // '.'
      lexDotDot,       // '..'
      lexAt,           // '@'
      lexComma,        // ','
      lexColon,        // ':'
      lexColonColon    // '::'
    );
    // :From-3.0:
    // The grammar in A.1 EBNF normatively defines built-in precedence among the operators of XQuery.
    // These operators are summarized here to make clear the order of their precedence from lowest to highest.
    // The associativity column indicates the order in which operators of equal precedence in an expression are applied.
    //
    // #   Operator                                                    Associativity
    //  1  , (comma)                                                   either
    //  2  for, let, some, every, if                                   NA
    //  3  or                                                          either
    //  4  and                                                         either
    //  5  eq, ne, lt, le, gt, ge, =, !=, <, <=, >, >=, is, <<, >>     NA
    //  6  ||                                                          left-to-right
    //  7  to                                                          NA
    //  8  +, - (binary)                                               left-to-right
    //  9  *, div, idiv, mod                                           left-to-right
    // 10  union, |                                                    either
    // 11  intersect, except                                           left-to-right
    // 12  instance of                                                 NA
    // 13  treat as                                                    NA
    // 14  castable as                                                 NA
    // 15  cast as                                                     NA
    // 16  -, + (unary)                                                * right-to-left *
    // 17  !                                                           left-to-right
    // 18  /, //                                                       left-to-right
    // 19  [, ]                                                        left-to-right
    //
    // In the "Associativity" column, "either" indicates that all the operators at that level have the associative property:
    //   (i.e., (A op B) op C is equivalent to A op (B op C)), so their associativity is inconsequential.
    //   "NA" (not applicable) indicates that the EBNF does not allow an expression that directly contains multiple operators from that precedence level,
    //   so the question of their associativity does not arise.
    //
    // Note:
    //   Parentheses can be used to override the operator precedence in the usual way.
    //   Square brackets in an expression such as A[B] serve two roles:
    //     they act as an operator causing B to be evaluated once for each item in the value of A, and they act as parentheses enclosing the expression B.
    //
    TLexicalPriority = (
      priNon    = 0, // non-binding operators like ;
      priTop    = 1, //
      priAssign = 2, // assignment operators like =
      priCondOp = 3, // ?, if..then..else
      priBoolOp = 4, // or, and
      priRelOp  = 5, // relational operators like ==, !=/<>, <, >, <=, >=
      priAddOp  = 6, // +, -
      priMulOp  = 7, // *, /
      priSingle = 8, // unary operators like !
      priDotOp  = 9  // . [ (
    );
  private
    procedure SetToken(Token: TLexicalToken; cp: PChar); inline;
  protected
    FCurrPos: PChar;
    FLastLastToken,
    FLastToken,
    FCurrToken: TLexicalToken;
    FStringToken: String;
    FIntegerToken: Int64;
    FFloatToken: Extended;
    FFormat: TFormatSettings;
    //
    class function TokenName(Token: TLexicalToken): String; virtual; // returns the name of a given token type
    function Position: Integer; virtual;
    function IsWhiteSpace(C: Char): Boolean; inline;
    function IsNameTest(const CurrToken: TLexicalToken; const StringToken: String; const CurrPos: PChar): Boolean; // NameTest ::= '*' | NCName ':' '*' | QName
    function IsNodeType: Boolean; // NodeType ::= 'comment' | 'text' | 'processing-instruction' | 'node'
    function IsOperator: Boolean; inline; // Operator ::= OperatorName | MultiplyOperator | '/' | '//' | '|' | '+' | '-' | '=' | '!=' | '<' | '<=' | '>' | '>='
    function IsOperatorName: Boolean; inline; // OperatorName ::= 'and' | 'or' | 'mod' | 'div' | 'idiv'(2.0)
    function IsOperatorMultiply: Boolean; inline; // MultiplyOperator ::= '*'
    function IsFunctionName: Boolean; // FunctionName ::= QName - NodeType
    function IsAxisName: Boolean; // AxisName ::= 'ancestor' | 'ancestor-or-self' | 'attribute' | 'child' | 'descendant' | 'descendant-or-self' | 'following' | 'following-sibling' | 'namespace' | 'parent' | 'preceding' | 'preceding-sibling' | 'self'
    procedure NextToken; virtual; // it implements the lexer for the parser
    procedure ExpectToken(Token: TLexicalToken); virtual;
    procedure EatToken(Token: TLexicalToken); virtual;
    function SkipTokenIf(Token: TLexicalToken): Boolean; virtual;
    procedure ParsePriority(Priority: TLexicalPriority; const Skip: Boolean = False); virtual; // the parser engine
    function IdentToToken: TLexicalToken; virtual;
    procedure Error(const Msg: String); overload; virtual;
    procedure Error(const Msg: String; const Args: Array of const); overload; virtual;
  public
    constructor Create(const ARootNode: TXmlNode; const ASource: String);
    destructor Destroy; override;
    //
    function Parse: TXmlNodeList;
    property Format: TFormatSettings read FFormat write FFormat;
  end;

  TXmlXPathSelectionFlag = (selScanTree);
  TXmlXPathSelectionFlags = set of TXmlXPathSelectionFlag;

  // Source - https://github.com/mremec/omnixml/blob/master/OmniXMLXPath.pas
  TXmlXPathEvaluator = class
  private
    FExpression: String;
    FNodeDelimiter: Char;
    FExpressionPos: Integer;
    //FExpressionParser: TXmlXPathPredicateExpression;
  protected
    procedure GetChildNodes(List: TXMLNodeList; Node: TXMLNode; const Element: String; element_type: TXmlNodeType; Recurse: Boolean);
    procedure EvaluateNode(List: TXMLNodeList; Node: TXmlNode; Element, Predicate: String; Flags: TXmlXPathSelectionFlags);
    procedure EvaluatePart(SrcList, DestList: TXMLNodeList; const Element, Predicate: String; Flags: TXmlXPathSelectionFlags);
    procedure FilterByAttrib(SrcList, DestList: TXmlNodeList; const AttrName, AttrValue: String; const NotEQ: Boolean);
    procedure FilterByChild(SrcList, DestList: TXmlNodeList; const ChildName, ChildValue: String);
    procedure FilterByFunction(SrcList, DestList: TXmlNodeList; ChildName, ChildValue: String);
    procedure FilterNodes(SrcList, DestList: TXMLNodeList; Predicate: String);
  protected
    function GetNextExpressionPart(var Element, Predicate: String; var Flags: TXmlXPathSelectionFlags): Boolean;
    procedure SplitExpression(const Predicate: String; var left, op, right: String);
  public
    constructor Create;
    //
    function Evaluate(RootNode: TXmlNode; const Expression: String; const NodeDelimiter: Char = '/'): TXmlNodeList;
    property NodeDelimiter: Char read FNodeDelimiter write FNodeDelimiter;
  end;

{ TXmlXPathPredicateExpression }

constructor TXmlXPathPredicateExpression.Create(const ARootNode: TXmlNode; const ASource: String);
begin
  GetLocaleFormatSettings(0, FFormat);
  FFormat.ThousandSeparator:=#0;
  FFormat.DecimalSeparator:='.';
  FRootNode:=ARootNode;
  FSource:=ASource;
  FSourceStart:=PChar(FSource);
  FCurrPos:=FSourceStart;
  FLastLastToken:=lexBof;
  FLastToken:=lexBof;
end;

destructor TXmlXPathPredicateExpression.Destroy;
begin
  FStringToken:='';
  FCurrPos:=Nil;
  FSourceStart:=Nil;
  FSource:='';
  FRootNode:=Nil;
  inherited;
end;

procedure TXmlXPathPredicateExpression.SetToken(Token: TLexicalToken; cp: PChar);
begin
  FLastLastToken:=FLastToken;
  FLastToken:=FCurrToken;
  FCurrToken:=Token;
  FCurrPos:=cp;
end;

class function TXmlXPathPredicateExpression.TokenName(Token: TLexicalToken): String;
const
  TokenStr: Array[TLexicalToken] of String = (
    '<bof>', '<eof>', '<ident>', '<attrib>',{ '<name_test>', '<node_type>', '<operator>', '<function_name>', '<axis_name>',}
    '<string>', '<integer>', '<float>', '<variable_reference>',
    '"+"', '"-"', '"*"', '"/"', '"//"', '"|"', '"="', '"<>"', '"<"', '"<="', '">"', '">="',
    '"("', '")"', '"["', '"]"', '"."', '".."', '"@"', '","', '":"', '"::"'
  );
begin
  Result:=TokenStr[Token];
end;

function TXmlXPathPredicateExpression.Position: Integer;
begin
  Result:=FCurrPos - FSourceStart + 1;
end;

function TXmlXPathPredicateExpression.IsWhiteSpace(C: Char): Boolean;
begin
  Result:=False;
  if Integer(C) <= $FF then // (#x20 | #x9 | #xD | #xA)
    Result := (C = ' ') or (C = #$09) or (C = #$0D) or (C = #$0A);
end;

function TXmlXPathPredicateExpression.IsNameTest(const CurrToken: TLexicalToken; const StringToken: String; const CurrPos: PChar): Boolean;
begin
  // NameTest ::= '*' | NCName ':' '*' | QName
  Result:=((CurrToken = lexAsterisk) and not IsOperatorMultiply) or
          ((CurrToken = lexIdent) and (StringToken <> '') and (CurrPos <> #0) and (CurrPos[0] = ':') and (CurrPos[1] = '*')) or
          ((CurrToken = lexIdent) and (StringToken <> ''));
end;

function TXmlXPathPredicateExpression.IsNodeType: Boolean;
begin
  // NodeType ::= 'comment' | 'text' | 'processing-instruction' | 'node'
  Result:=(FCurrToken = lexIdent) and ((FStringToken = 'comment') or (FStringToken = 'text') or (FStringToken = 'processing-instruction') or (FStringToken = 'node'));
end;

function TXmlXPathPredicateExpression.IsOperator: Boolean;
begin
  // Operator ::= OperatorName | MultiplyOperator | '/' | '//' | '|' | '+' | '-' | '=' | '!=' | '<' | '<=' | '>' | '>='
  Result:=IsOperatorName or IsOperatorMultiply or ((FCurrToken > lexVariableReference) and (FCurrToken < lexLParen));
end;

function TXmlXPathPredicateExpression.IsOperatorName: Boolean;
begin
  // OperatorName ::= 'and' | 'or' | 'mod' | 'div' | 'idiv'(2.0)
  Result:=(FCurrToken = lexIdent) and ((FStringToken = 'and') or (FStringToken = 'or') or (FStringToken = 'mod') or (FStringToken = 'div') or (FStringToken = 'idiv'));
end;

function TXmlXPathPredicateExpression.IsOperatorMultiply: Boolean;
begin
// The following special tokenization rules must be applied in the order specified to disambiguate the ExprToken grammar:
//   - If there is a preceding token and the preceding token is not one of @, ::, (, [ or an Operator,
//     then a * must be recognized as a MultiplyOperator and an NCName must be recognized as an OperatorName.
  // MultiplyOperator ::= '*'
  Result:=(FCurrToken = lexAsterisk) and ((FLastToken in [lexAt, lexDotDot, lexLParen, lexLBracket]) or IsOperator);
end;

function TXmlXPathPredicateExpression.IsFunctionName: Boolean; // FunctionName ::= QName - NodeType
begin

end;

function TXmlXPathPredicateExpression.IsAxisName: Boolean; // AxisName ::= 'ancestor' | 'ancestor-or-self' | 'attribute' | 'child' | 'descendant' | 'descendant-or-self' | 'following' | 'following-sibling' | 'namespace' | 'parent' | 'preceding' | 'preceding-sibling' | 'self'
begin

end;

{
      lexNameTest, // NameTest ::= '*' | NCName ':' '*' | QName
      lexNodeType, // NodeType ::= 'comment' | 'text' | 'processing-instruction' | 'node'
      lexOperator, // Operator ::= OperatorName | MultiplyOperator | '/' | '//' | '|' | '+' | '-' | '=' | '!=' | '<' | '<=' | '>' | '>='
                   // OperatorName ::= 'and' | 'or' | 'mod' | 'div' | 'idiv'(2.0)
                   // MultiplyOperator ::= '*'
      lexFunctionName, // FunctionName ::= QName - NodeType
      lexAxisName, // AxisName ::= 'ancestor' | 'ancestor-or-self' | 'attribute' | 'child' | 'descendant' | 'descendant-or-self' | 'following' | 'following-sibling' | 'namespace'
                   //              | 'parent' | 'preceding' | 'preceding-sibling' | 'self'
      //lexLiteral,  // Literal ::= '"' [^"]* '"' | "'" [^']* "'"
      lexString,
      //lexNumber,   // Number ::= Digits ('.' Digits?)? | '.' Digits
                     // Digits ::= [0-9]+
      lexInteger,
      lexFloat,
      lexVariableReference, // VariableReference ::= '$' QName

      lexPlus,         // '+'
      lexMinus,        // '-'
      lexAsterisk,     // '*'
      lexSlash,        // '/'
      lexSlashSlash,   // '//'
      lexPipe,         // '|'
      lexEqualTo,      // '='  or eq
      lexNotEqual,     // '!=' or ne
      lexLessThan,     // '<'  or lt
      lexLessEqual,    // '<=' or le
      lexGreaterThan,  // '>'  or gt
      lexGreaterEqual, // '>=' or ge

      lexLParen,       // '('
      lexRParen,       // ')'
      lexLBracket,     // '['
      lexRBracket,     // ']'
      lexDot,          // '.'
      lexDotDot,       // '..'
      lexAt,           // '@'
      lexComma,        // ','
      lexColon,        // ':'
      lexColonColon    // '::'
}
procedure TXmlXPathPredicateExpression.NextToken;
var
  cp, start: PChar;
begin
  // use local variable so hopefully compiler will use a register
  cp:=FCurrPos;

  // handle whitespace and end of file; consider adding comment support here
  while IsWhiteSpace(cp^) do
    Inc(cp);
  if cp^ = #0 then begin
    FCurrPos:=cp;
    FCurrToken:=lexEof;
    Exit;
  end;

  // determine token type based on first character
  case cp^ of
    'a'..'z', 'A'..'Z', '_': begin // identifier
      start:=cp;
      Inc(cp);
      while True do begin
        case cp^ of
          'a'..'z', 'A'..'Z', '_', '0'..'9':
            Inc(cp);
        else
          Break;
        end;
      end;
      SetString(FStringToken, start, cp - start);
      SetToken(lexIdent, cp);
    end;

    '@': begin // attribute
      start:=cp;
      Inc(cp);
      while True do begin
        case cp^ of
          'a'..'z', 'A'..'Z', '_', '0'..'9':
            Inc(cp);
        else
          Break;
        end;
      end;
      SetString(FStringToken, start, cp - start);
      SetToken(lexAttrib, cp);
    end;

// The following special tokenization rules must be applied in the order specified to disambiguate the ExprToken grammar:
//   - If there is a preceding token and the preceding token is not one of @, ::, (, [, , or an Operator,
//     then a * must be recognized as a MultiplyOperator and an NCName must be recognized as an OperatorName.
//   - If the character following an NCName (possibly after intervening ExprWhitespace) is (,
//     then the token must be recognized as a NodeType or a FunctionName.
//   - If the two characters following an NCName (possibly after intervening ExprWhitespace) are ::,
//     then the token must be recognized as an AxisName.
//   - Otherwise, the token MUST NOT be recognized as a MultiplyOperator, an OperatorName, a NodeType, a FunctionName, or an AxisName.

    '*': begin // NameTest or MultiplyOperator
      if (FLastToken > lexBof) and ((FLastToken in [lexAt, lexDotDot, lexLParen, lexLBracket]) or

         (((FLastToken = lexIdent) and ((FStringToken = 'and') or (FStringToken = 'or') or (FStringToken = 'mod') or (FStringToken = 'div') or (FStringToken = 'idiv'))) or
         ((FCurrToken = lexAsterisk) and ((FLastToken in [lexAt, lexDotDot, lexLParen, lexLBracket]) or IsOperator)) or
         ((FCurrToken > lexVariableReference) and (FCurrToken < lexLParen)))) then


    end;

    '0'..'9': begin // number of some kind
      start:=cp;
      Inc(cp);
      while (cp^ >= '0') and (cp^ <= '9') do
        Inc(cp);

      if (cp^ <> '.') and (cp^ <> 'e') and (cp^ <> 'E') then begin
        SetString(FStringToken, start, cp - start);
        FIntegerToken:=StrToInt64(FStringToken);
        SetToken(lexInteger, cp);
        Exit;
      end;

      if cp^ = '.' then begin
        Inc(cp);
        if not ((cp^ >= '0') and (cp^ <= '9')) then
          Error(sInvalidFloatingPt, [Position]);
        while (cp^ >= '0') and (cp^ <= '9') do
          Inc(cp);
      end;

      if (cp^ = 'e') or (cp^ = 'E') then begin
        Inc(cp);
        if (cp^ = '-') or (cp^ = '+') then
          Inc(cp);
        if not ((cp^ >= '0') and (cp^ <= '9')) then
          Error(sInvalidFloatingPtExpt, [Position]);
        while (cp^ >= '0') and (cp^ <= '9') do
          Inc(cp);
      end;

      SetString(FStringToken, start, cp - start);
      FFloatToken:=StrToFloat(FStringToken, FFormat);
      SetToken(lexFloat, cp);
    end;

    '''': begin // string
      Inc(cp);
      start:=cp;
      while True do begin
        case cp^ of
          #0: Error(sUnterminatedString, [Position]);
          '''': begin
            SetString(FStringToken, start, cp - start);
            SetToken(lexString, cp + 1);
            Break;
          end;
        else
          Inc(cp);
        end;
      end;
    end;

    '"': begin // alt string (easier Pascal embedding)
      Inc(cp);
      start:=cp;
      while True do begin
        case cp^ of
          #0: Error(sUnterminatedString, [Position]);
          '"': begin
            SetString(FStringToken, start, cp - start);
            SetToken(lexString, cp + 1);
            Break;
          end;
        else
          Inc(cp);
        end;
      end;
    end;

    // single-character operators
    '+': SetToken(lexPlus, cp + 1);
    '-': SetToken(lexMinus, cp + 1);
    //'*': SetToken(lexAsterisk, cp + 1);
    '/': SetToken(lexSlash, cp + 1);
    '(': SetToken(lexLParen, cp + 1);
    ')': SetToken(lexRParen, cp + 1);
    '[': SetToken(lexLBracket, cp + 1);
    ']': SetToken(lexRBracket, cp + 1);
    '.': SetToken(lexDot, cp + 1);
//    ';': SetToken(lexSemicolon, cp + 1);
    ',': SetToken(lexComma, cp + 1);
    '=': SetToken(lexEqualTo, cp + 1);
//    '!': SetToken(Self, lexNotEqual, cp + 1);

    ':': begin // multi-character operators
//        Error(sInvalidOperator, [cp[0] + cp[1], Position]);
      if cp[1] = ':' then
        SetToken(lexColonColon, cp + 2)
      else
        SetToken(lexColon, cp + 1);
    end;

    '<': begin
      case cp[1] of
        '=': SetToken(lexLessEqual, cp + 2);
        '>': SetToken(lexNotEqual, cp + 2);
      else
        SetToken(lexLessThan, cp + 1);
      end;
    end;

    '>': begin
      if cp[1] = '=' then
        SetToken(lexGreaterEqual, cp + 2)
      else
        SetToken(lexGreaterThan, cp + 1);
    end;
  else
    Error(sInvalidOperatorChar, [cp^, Position]);
  end;
end;

procedure TXmlXPathPredicateExpression.ExpectToken(Token: TLexicalToken);
begin
  if Token <> FCurrToken then
    Error(sParserUnexpected, [TokenName(Token), TokenName(FCurrToken), Position]);
end;

procedure TXmlXPathPredicateExpression.EatToken(Token: TLexicalToken);
begin
  ExpectToken(Token);
  NextToken;
end;

function TXmlXPathPredicateExpression.SkipTokenIf(Token: TLexicalToken): Boolean;
begin
  Result:=(FCurrToken = Token);
  if Result then
    NextToken;
end;

procedure TXmlXPathPredicateExpression.ParsePriority(Priority: TLexicalPriority; const Skip: Boolean = False);

  function ParseArgs(StopToken: TLexicalToken): Word;
  var
    count: Integer;
  begin
    count:=0;
    if FCurrToken <> StopToken then begin
      repeat
        ParsePriority(priAssign);
//        PopUntil(RootScope); // get back to the function/array property context
        Inc(count);
      until not SkipTokenIf(lexComma);
    end;
    if count > System.High(Word) then
      Error(sTooManyArgs, [Position]);
    Result:=count;
  end;

  procedure ParseFactor(Skip: Boolean);
//  var
//    LWrapper: IInterface;
//    LGroup: IGroup;
//    LOrder: Integer;
  begin
    if Skip then
      NextToken;
    case FCurrToken of
      lexEof: Exit;
      lexIdent: begin
{        case IdentToToken of
          lexBooleanNot,
          lexBooleanAnd,
          lexBooleanOr,
          lexBooleanXor: Exit;
        else
          FCommandStack.AddOpValue(opcLookup, FStringToken, FStringToken);
        end;}
          // create a wrapper for the current identifier; if the identifier
          // denotes an indexed property or a method, grab a new result wrapper
          // for it and make its scope the top one
//          LGroup := nil;
//          LOrder := 0;
//          LWrapper := EnsureWrapper(FStringToken);
//          if Supports(LWrapper, IGroup, LGroup) then
//            LOrder := LGroup.Add(LWrapper);
//          PushWrapperScope(LWrapper);

          // generate program code for searching the wrapper; if we deal with a
          // result wrapper, add code to search it in the group
//        FCommandStack.AddOpValue(opcLookup, FStringToken, FStringToken);
//          if Assigned(LGroup) then
//            FBinding.AddOpValue(opLookupGroup, LOrder);
      end;
{      lexInteger: FCommandStack.AddOpValue(opcPush, FStringToken, FIntegerToken);
      lexFloat:   FCommandStack.AddOpValue(opcPush, FStringToken, FFloatToken);
      lexString:  FCommandStack.AddOpValue(opcPush, FStringToken, FStringToken);}

      lexPlus: begin
        ParsePriority(priAddOp, True);
{        FCommandStack.AddOpArg2(opcInvokeDirect, FCommandStack.AddConst(StatementBuiltinOpName[bioAdd], StatementBuiltinOpName[bioAdd], False), 2); // 2 arg to unary}
        Exit;
      end;

      lexMinus: begin
        // go back on the scope stack to put the other parameter for minus
        // in the scope of the expression
//        PopUntil(RootScope);

        // parse the second operand and add the instruction
//        ParseFactor(True);
        ParsePriority(priAddOp, True);
{        FCommandStack.AddOpArg2(opcInvokeDirect, FCommandStack.AddConst(StatementBuiltinOpName[bioSubtract], StatementBuiltinOpName[bioSubtract], False), 2); // 2 arg to unary}
        Exit; // musn't skip token again
      end;

      lexColon: begin // check if it is "IF" op
{        if not FInsideIF then
          Error(sExpectedIdentifier, [Position]);
        FInsideIF:=False;}
        ParseFactor(True);
      end;

{      lexAsterisk,
      lexQuestionMark: Exit;}

      lexLParen: begin
        ParsePriority(priAssign, True);
        ExpectToken(lexRParen);
      end;
    else
      Error(sExpectedIdentifier, [Position]);
    end;
    NextToken;
  end;

{const
  BuiltinOpMap: Array[TLexicalToken] of TStatementBuiltinOp = (
    // Bof, Eof, Ident, Integer, Float, String
    TStatementBuiltinOp(-1), TStatementBuiltinOp(-1), TStatementBuiltinOp(-1), TStatementBuiltinOp(-1), TStatementBuiltinOp(-1), TStatementBuiltinOp(-1),
    // Plus, Minus, Asterisk, Slash, QuestionMark
    bioAdd, bioSubtract, bioMultiply, bioDivide, bioQuestionMark,
    // EqualTo, NotEqual, LessThan, GreaterThan, LessEqual, GreaterEqual
    bioEqualTo, bioNotEqual, bioLessThan, bioGreaterThan, bioLessEqual, bioGreaterEqual,
    // LParen, RParen, LBracket, RBracket
    TStatementBuiltinOp(-1), TStatementBuiltinOp(-1), TStatementBuiltinOp(-1), TStatementBuiltinOp(-1),
    // Dot, Comma, Colon, Semicolon, Assign
    TStatementBuiltinOp(-1), TStatementBuiltinOp(-1), TStatementBuiltinOp(-1), TStatementBuiltinOp(-1), TStatementBuiltinOp(-1),
    // Not, And, Or, Xor
    bioBooleanNOT, bioBooleanAND, bioBooleanOR, bioBooleanXOR
  );
  BuiltinPriority: Array[TStatementToken] of TPriority = (
    // Bof, Eof, Ident, Integer, Float, String
    priNon, priNon, priNon, priNon, priNon, priNon,
    // Plus, Minus, Asterisk, Slash, QuestionMark
    priAddOp, priAddOp, priMulOp, priMulOp, priCondOp,
    // EqualTo, NotEqual, LessThan, GreaterThan, LessEqual, GreaterEqual
    priRelOp, priRelOp, priRelOp, priRelOp, priRelOp, priRelOp,
    // LParen, RParen, LBracket, RBracket
    priNon, priNon, priNon, priNon,
    // Dot, Comma, Colon, Semicolon, Assign
    priDotOp, priNon, priNon, priNon, priAssign,
    // Not, And, Or, Xor
    priBoolOp, priBoolOp, priBoolOp, priBoolOp
  );}
var
  operatorPriority: TLexicalPriority;
//  builtinOp: TStatementBuiltinOp;
  internalToken: TLexicalToken;
  tokenPair: TLexicalToken;
//label
//  Identificator;
begin
  ParseFactor(Skip);

{  while True do begin
    operatorPriority:=BuiltinPriority[FCurrToken];
    builtinOp:=BuiltinOpMap[FCurrToken];
    internalToken:=IdentToToken;
    if (operatorPriority = priNon) and (internalToken <> TStatementToken(-1)) then begin
      case internalToken of
        lexBooleanNot,
        lexBooleanAnd,
        lexBooleanOr,
        lexBooleanXor: begin
          operatorPriority:=BuiltinPriority[internalToken];
          builtinOp:=BuiltinOpMap[internalToken];
        end;
      end;
    end;
    if operatorPriority <> priNon then begin
//      if FCurrToken = lexIdent then
//        goto Identificator;
      if operatorPriority <= Priority then
        Break;
      // parse the second operand and other params as needed, add the instruction
      if builtinOp = bioQuestionMark then begin
        ParsePriority(priTop, True); // get first arg
        ExpectToken(lexColon);
        ParsePriority(priTop, True);
        FCommandStack.AddOpArg2(opcInvokeDirect, FCommandStack.AddConst(StatementBuiltinOpName[builtinOp], StatementBuiltinOpName[builtinOp], False), 3); // 3 arguments to binary
      end
      else begin
        ParsePriority(operatorPriority, True); // loop for other ops
        FCommandStack.AddOpArg2(opcInvokeDirect, FCommandStack.AddConst(StatementBuiltinOpName[builtinOp], StatementBuiltinOpName[builtinOp], False), 2); // 2 arguments to binary
      end;
    end
    else begin
//      Identificator: // jump for ident
      case FCurrToken of
        lexLParen, lexLBracket: begin // method / procedure call / indexed property
          tokenPair:=Succ(FCurrToken); // select the appropriate closing paranthesis/bracket
//          ScopeStack.Push(RootScope); // the parameters/indexers will be put in the expression scope

          // parse the parameters/indexers of the function/property
          NextToken;
          FCommandStack.AddOpArg(opcInvokeIndirect, ParseArgs(tokenPair));

//          PopParamScope; // pop the scopes for the function
          EatToken(tokenPair);
        end;
        lexDot: begin
          // the next token must be an identifier
          NextToken;

          if FCurrToken = lexEof then
            FStringToken:=''
          else
            ExpectToken(lexIdent);

          // create a wrapper for the token; in case the token represents
          // an indexed property or a method, put on the scope stack the
          // scope of a new result wrapper for that token
//          LGroup := nil;
//          LOrder := 0;
//          LWrapper := EnsureWrapper(FStringToken);
//          if Supports(LWrapper, IGroup, LGroup) then
//            LOrder := LGroup.Add(LWrapper);
//          PushWrapperScope(LWrapper);

          // add the program instruction for the identifier; in case we deal
          // with an indexed property or a method, add code to
          FCommandStack.AddOpValue(opcLookup, FStringToken, FStringToken);
//          if Assigned(LGroup) then
//            FCommandStack.AddOpValue(opLookupGroup, LOrder);
          NextToken;
        end;
        lexIdent: begin // can consider handling custom operators here (lexIdent)
          FCommandStack.AddOpValue(opcLookup, FStringToken, FStringToken);
          NextToken;
        end;
      else
        Break;
      end;
    end;
  end;}
end;

function TXmlXPathPredicateExpression.IdentToToken: TLexicalToken;
var
  ident: String;
begin
  if FCurrToken <> lexIdent then
    Exit(TLexicalToken(-1));

  Result:=TLexicalToken(-1);
{  ident:=LowerCase(FStringToken);
  if ident = 'not' then
    Result:=lexBooleanNot
  else if ident = 'and' then
    Result:=lexBooleanAnd
  else if ident = 'or' then
    Result:=lexBooleanOr
  else if ident = 'xor' then
    Result:=lexBooleanXor;
  ident:='';}
end;

procedure TXmlXPathPredicateExpression.Error(const Msg: String);
begin
  Error(Msg, []);
end;

procedure TXmlXPathPredicateExpression.Error(const Msg: String; const Args: Array of const);
begin
  if Length(Args) = 0 then
    raise EXmlXPathException.Create(Msg)
  else
    raise EXmlXPathException.CreateFmt(Msg, Args);
end;

function TXmlXPathPredicateExpression.Parse: TXmlNodeList;
begin
  Result:=TXmlNodeList.Create(False);
  ParsePriority(priTop, True); // start compiling the expression
  // check if the compilation ended correctly
  if FCurrToken <> lexEof then
    Error(sExpectedEOF, [Position]);
end;

{ TXmlXPathEvaluator }

constructor TXmlXPathEvaluator.Create;
begin
  FExpression:='';
  FExpressionPos:=0;
  FNodeDelimiter:='/';
end;

procedure TXmlXPathEvaluator.GetChildNodes(List: TXMLNodeList; Node: TXMLNode; const Element: String; element_type: TXmlNodeType; Recurse: Boolean);
var
  matchAll: Boolean;
  i: Integer;
  nodeList: TXmlObjectList;
  item: TObject;
  child: TXmlNode;
begin
  matchAll:=(Element = '*');
  if element_type = ntAttribute then
    nodeList:=Node.AttributeList
  else
    nodeList:=Node.ChildNodes;

  if nodeList <> Nil then begin
    for i:=0 to nodeList.Count - 1 do begin
      item:=nodeList.Items[i];
      if (element_type = ntElement) and (matchAll or (TXmlNode(item).NodeName = Element)) then
          List.Add(TXmlNode(item), TXmlNode(item).ParentNode)
      else if (element_type = ntAttribute) and (matchAll or (TXmlAttribute(item).Name = Element)) and (List.IndexOf(Node) = -1) then
        List.Add(Node, Node.ParentNode);

      if Recurse and (element_type = ntElement) then begin
        GetChildNodes(List, TXmlNode(item), Element, element_type, True);
      end;
    end;
  end;

  // if recursion is on and we were iterating over attributes, we must also check child nodes
  if Recurse and (element_type = ntAttribute) and (Node.ChildNodes <> Nil) then begin
    for i:=0 to Node.ChildNodes.Count - 1 do begin
      child:=Node.ChildNodes.Get(i);
      GetChildNodes(List, child, Element, element_type, True);
    end;
  end;
end;

procedure TXmlXPathEvaluator.EvaluateNode(List: TXMLNodeList; Node: TXmlNode; Element, Predicate: String; Flags: TXmlXPathSelectionFlags);
var
  temp_list: TXmlNodeList;
  element_type: TXmlNodeType;
begin
  if Element = '.' then
    List.Add(Node, Node.ParentNode)
  else if Element = '..' then begin
    if Assigned(Node.ParentNode) then
      List.Add(Node.ParentNode, Node.ParentNode.ParentNode);
  end
  else begin
    temp_list:=TXmlNodeList.Create(False);
    temp_list.Document:=List.Document;
    try
      element_type:=ntElement;
      if (Length(Element) > 0) and (Element[1] = '@') then begin
        element_type:=ntAttribute;
        Delete(Element, 1, 1);
      end;
      if Length(Element) > 0 then
        GetChildNodes(temp_list, Node, Element, element_type, selScanTree in Flags)
      else
        temp_list.Add(Node, Node.ParentNode);

      FilterNodes(temp_list, List, Predicate);
    finally
      temp_list.Free;
    end;
  end;
end;

procedure TXmlXPathEvaluator.EvaluatePart(SrcList, DestList: TXMLNodeList; const Element, Predicate: String; Flags: TXmlXPathSelectionFlags);
var
  i: Integer;
begin
  DestList.Clear;
  for i:=0 to SrcList.Count - 1 do begin
    EvaluateNode(DestList, SrcList.Get(i), Element, Predicate, Flags);
  end;
end;

procedure TXmlXPathEvaluator.FilterByAttrib(SrcList, DestList: TXmlNodeList; const AttrName, AttrValue: String; const NotEQ: Boolean);
var
  Node: TXmlNode;
  i: Integer;
  matchAnyValue: Boolean;
begin
  matchAnyValue:=(AttrValue = '*');
  for i:=0 to SrcList.Count - 1 do begin
    Node:=SrcList.Get(i);
    if (Node <> Nil) and (matchAnyValue or ((Node.HasAttribute(AttrName) and (Node.Attributes[AttrName] = AttrValue)) xor NotEQ)) then
      DestList.Add(Node, Node.ParentNode);
  end;
end;

procedure TXmlXPathEvaluator.FilterByChild(SrcList, DestList: TXmlNodeList; const ChildName, ChildValue: String);

  function GetTextChild(Node: TXmlNode): TXmlNode;
  var
    i: Integer;
  begin
    Result:=Nil;
    if (Node = Nil) or (Node.ChildNodes = Nil) then
      Exit;
    for i:=0 to Node.ChildNodes.Count - 1 do begin
      if Node.ChildNodes.Get(i).NodeType = ntText then begin
        Result:=Node.ChildNodes.Get(i);
        Break;
      end;
    end;
  end;

var
  Node: TXmlNode;
  i: Integer;
  matchAnyValue: Boolean;
begin
  matchAnyValue:=(childValue = '*');
  for i:=0 to SrcList.Count - 1 do begin
    Node:=SrcList.Get(i).FindNode(childName);
    if Node <> Nil then begin
      if matchAnyValue then
        DestList.Add(Node, Node.ParentNode) // List.Get(i)
      else begin
        Node:=GetTextChild(Node);
//        if Assigned(Node) and (Node.NodeValue = ChildValue) then
//          DestList.Add(Node, Node.ParentNode); // List.Get(i)
      end;
    end;
  end;
end;

procedure TXmlXPathEvaluator.FilterByFunction(SrcList, DestList: TXmlNodeList; ChildName, ChildValue: String);
var
  Node: TXmlNode;
  i: Integer;
  code: Integer;
  idx: Integer;
begin
  Node:=Nil;
  ChildName:=LowerCase(ChildName);
  if ChildName = 'first()' then
    Node:=SrcList.FirstChild
  else if ChildName = 'last()' then
    Node:=SrcList.LastChild;

  if Length(ChildValue) > 0 then begin // get index
    Val(ChildValue, idx, code);
    if code = 0 then begin // [n]
      i:=-1;
      if Node <> Nil then begin
        i:=Node.Index;
        Inc(i, idx);
      end;

      if (i < 0) or (i >= SrcList.Count) then
        raise EXmlXPathException.CreateFmt('Invalid predicate index [%s]', [ChildName + ChildValue]);

      if Node.ParentNode.ChildNodes <> Nil then
        Node:=Node.ParentNode.ChildNodes.Get(i)
      else
        Node:=Nil;
    end
    else
      raise EXmlXPathException.CreateFmt('Unsupported predicate expression [%s]', [ChildName + ChildValue]);
  end;

  if Node <> Nil then
    DestList.Add(Node, Node.ParentNode); // List.Get(i)
end;

procedure TXmlXPathEvaluator.FilterNodes(SrcList, DestList: TXMLNodeList; Predicate: String);

//  function isExpression(const Expression: String): Boolean;
//  var
//  begin
//    while True do begin
//      if CharInSet(P^, ['a'..'z', 'A'..'Z', '_', '.', '+', '-', '*']) and (P^ <> #0) then
//        Inc(P);
//    end;
//  end;

  procedure Error;
  begin
    raise EXmlXPathException.CreateFmt('Unsupported operator [%s]', [Predicate]);
  end;

var
  code: Integer;
  idx: Integer;
  left, op, right: String;
  is_attrib: Boolean;
  Node: TXmlNode;
//  P, S: PChar;
begin
  if Length(Predicate) = 0 then
    DestList.Add(SrcList)
  else begin
    Val(Predicate, idx, code);
    if code = 0 then begin // [n]
      if (idx <= 0) or (idx > SrcList.Count) then
        raise EXmlXPathException.CreateFmt('Invalid predicate index [%s]', [Predicate]);

      Node:=SrcList.Get(idx - 1);
      DestList.Add(Node, Node.ParentNode);
    end
    else if (Length(Predicate) > 0) then begin
// xpath extensible test examples
// https://www.mimuw.edu.pl/~czarnik/zajecia/xml11/lab07.html
// https://www.w3.org/TR/1999/REC-xpath-19991116/#exprlex
// https://docs.oracle.com/javase/tutorial/jaxp/xslt/xpath.html

// lines commented below are for TXmlXPathPredicateExpression
//      P:=PChar(Expression);
//      S:=P;
//      while True do begin
//        SplitExpression(Predicate, left, op, right);
//        if Length(left) = 0 then // no more expression text to be evaluated
//          Break;
//
//          Predicate:='';
//      end;

      is_attrib:=False;
      SplitExpression(Predicate, left, op, right);
      if Predicate[1] = '@' then begin
        is_attrib:=True;
        Delete(left, 1, 1);
      end;
      //
      if not is_attrib then begin
        if Pos('()', left) > 0 then // [internal function]
          FilterByFunction(SrcList, DestList, left, op + right)
        else if Length(op) = 0 then // [node]
          FilterByChild(SrcList, DestList, left, '*')
        else if (Length(op) > 0) and (op = '=') then // [node='test']
          FilterByChild(SrcList, DestList, left, right)
        else
          Error;
      end
      else begin
        if Length(op) = 0 then // [@attrib]
          FilterByAttrib(SrcList, DestList, left, '*', False)
        else if (Length(op) > 0) and ((op = '=') or (op = '!=')) then // [@attrib='x']
          FilterByAttrib(SrcList, DestList, left, right, (op = '!='))
        else
          Error;
      end;
    end;
  end;
end;

function TXmlXPathEvaluator.GetNextExpressionPart(var Element, Predicate: String; var Flags: TXmlXPathSelectionFlags): Boolean;
var
  endElement: Integer;
  pEndPredicate: Integer;
  pPredicate: Integer;
begin
  if FExpressionPos > Length(FExpression) then
    Result:=False
  else begin
    Flags:=[];
    if FExpression[FExpressionPos] = FNodeDelimiter then begin
      Inc(FExpressionPos); // initial '/' was already taken into account in Evaluate
      if FExpression[FExpressionPos] = FNodeDelimiter then begin
        Inc(FExpressionPos);
        Include(Flags, selScanTree);
      end;
    end;
    endElement:=PosEx(FNodeDelimiter, FExpression, FExpressionPos);
    if endElement = 0 then
      endElement:=Length(FExpression) + 1;
    Element:=Copy(FExpression, FExpressionPos, endElement - FExpressionPos);
    FExpressionPos:=endElement;
    if Element = '' then
      raise EXmlXPathException.CreateFmt('Empty element at position %d', [FExpressionPos]);
    pPredicate:=Pos('[', Element);
    if pPredicate = 0 then begin
      if Pos(']', Element) > 0 then
        raise EXmlXPathException.CreateFmt('Invalid syntax at position %d', [Pos(']', Element)]);
      Predicate:='';
    end
    else begin
      if Element[Length(Element)] <> ']' then
        raise EXmlXPathException.CreateFmt('Invalid syntax at position %d', [FExpressionPos + Length(Element) - 1]);
      pEndPredicate:=Pos(']', Element);
      if pEndPredicate < Length(Element) then begin
        //extract only the first filter
        Dec(FExpressionPos, Length(Element) - pEndPredicate);
        Element:=Copy(Element, 1, pEndPredicate);
      end;
      Predicate:=Copy(Element, pPredicate + 1, Length(Element) - pPredicate - 1);
      Delete(Element, pPredicate, Length(Element)- pPredicate + 1);
    end;
    Result:=True;
  end;
end;

procedure TXmlXPathEvaluator.SplitExpression(const Predicate: String; var left, op, right: String);
var
  pOp, pOpLen: integer;
begin
  pOp:=Pos('=', Predicate);
  if pOp = 0 then begin
    pOp:=Pos('-', Predicate);
    if pOp = 0 then begin
      pOp:=Pos('+', Predicate);
      if pOp = 0 then begin
        left:=Predicate;
        op:='';
        right:='';
        Exit;
      end;
    end;
  end;

  // split expression
  pOpLen:=1;
  if (pOp > 1) and (Predicate[pOp - 1] = '!') then begin // != operator ???
    Inc(pOpLen);
    Dec(pOp);
  end;

  left:=Trim(Copy(Predicate, 1, pOp - 1));
  // op := predicate[pOp];
  op:=Copy(Predicate, pOp, pOpLen);
  right:=Trim(Copy(Predicate, pOp + pOpLen, Length(Predicate)));
  if ((right[1] = '''') and (right[Length(right)] = '''')) or ((right[1] = '"') and (right[Length(right)] = '"')) then
    right:=Copy(right, 2, Length(right) - 2);
end;

function TXmlXPathEvaluator.Evaluate(RootNode: TXmlNode; const Expression: String; const NodeDelimiter: Char = '/'): TXmlNodeList;
var
  element, predicate: String;
  flags: TXmlXPathSelectionFlags;
  list: TXmlNodeList;
begin
  Result:=TXmlNodeList.Create(False);
  Result.Document:=RootNode.Document;

  FExpression := Expression;
  FNodeDelimiter := NodeDelimiter;
  FExpressionPos := 1;

  if Length(Expression) > 0 then begin
    if Expression[1] <> FNodeDelimiter then
      Result.Add(RootNode, RootNode.ParentNode)
    else if (RootNode.ParentNode <> Nil) and (RootNode.ParentNode = RootNode.Document.Root) then // already at root
      Result.Add(RootNode, RootNode.ParentNode)
    else
      Result.Add(RootNode.Document.DocumentElement, RootNode.Document.DocumentElement.ParentNode);

    while GetNextExpressionPart(element, predicate, flags) do begin
      list:=Result;
      Result:=TXmlNodeList.Create(False);
      Result.Document:=list.Document;
      try
        EvaluatePart(list, Result, element, predicate, flags);
      finally
        list.Free;
      end;
    end;
  end;
end;

{ TXmlStringHashList }

constructor TXmlStringHashList.Create;
begin
  FCount := 0;
  StringList := TStringList.Create;
  SetLength(HashList, 0);
end;

destructor TXmlStringHashList.Destroy;
begin
  StringList.Free;
  SetLength(HashList, 0);
end;

procedure TXmlStringHashList.Clear;
begin
  FCount := 0;
  StringList.Clear;
  SetLength(HashList, 0);
end;

function TXmlStringHashList.HashOf(const Key: String): Cardinal;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to Key.Length - 1 do
    Result := ((Result shl 2) or (Result shr 30)) xor Cardinal(Ord(Key.Chars[I]));
end;

function TXmlStringHashList.Find(const Key: String; var AItem: THashItem): Integer;
var
  hash: Cardinal;
  i: Integer;
begin
  Result := -1;
  AItem.Hash := CInvalidStrHashId;
  AItem.Index := -1;
  if FCount = 0 then
    Exit;

  hash := HashOf(Key);
  for i := 0 to FCount - 1 do
    if HashList[i].Hash = hash then begin
      Result := HashList[i].Index;
      AItem := HashList[i];
      Break;
    end;
end;

function TXmlStringHashList.Find(const Hash: Cardinal; var AItem: THashItem): Integer;
var
  i: Integer;
begin
  Result := -1;
  AItem.Hash := CInvalidStrHashId;
  AItem.Index := -1;
  if (Hash = CInvalidStrHashId) or (FCount = 0) then
    Exit;

  for i := 0 to FCount - 1 do
    if HashList[i].Hash = Hash then begin
      Result := HashList[i].Index;
      AItem := HashList[i];
      Break;
    end;
end;

function TXmlStringHashList.Add(const Value: String): Cardinal;
var
  hash: Cardinal;
  hash_item: THashItem;
  existing: THashItem;
  idx: Integer;
begin
  if Length(Value) = 0 then
    Exit(CInvalidStrHashId);

  hash := HashOf(Value);
  if Find(hash, existing) = -1 then begin
    hash_item.Hash := hash;
    hash_item.Index := StringList.Add(Value);
    idx := FCount;
    SetLength(HashList, idx + 1);
    HashList[idx] := hash_item;
    Inc(FCount, 1);
    Result := hash;
  end
  else
    Result := existing.Hash;
end;

function TXmlStringHashList.GetStrByHash(const Hash: Cardinal): String;
var
  i: Integer;
begin
  Result := '';
  if Hash = CInvalidStrHashId then
    Exit;

  for i := 0 to FCount - 1 do
    if HashList[i].Hash = Hash then begin
      Result := StringList.Strings[HashList[i].Index];
      Break;
    end;
end;

function TXmlStringHashList.GetStrByIndex(const Index: Integer): String;
begin
  Result := '';
  if (Index >= 0) and (Index < StringList.Count) then
    Result := StringList.Strings[Index];
end;

{ TVerySimpleXml }

function TXmlVerySimple.AddChild(const Name: String; NodeType: TXmlNodeType = ntElement): TXmlNode;
begin
  Result:=Nil; // satisfy compiler
  try
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
  if (Node = Nil) or (Root.ChildNodes = Nil) then
    Exit;

  wasRoot:=(DocumentElement = Node);
  Node.Clear;
  Result:=Node.Index;
  Root.ChildNodes.Remove(Result);
  if wasRoot then begin
    if Root.ChildNodes.Count > 0 then begin
      for Child in Root.ChildNodes do begin
        if TXmlNode(Child).NodeType = ntElement then begin
          FDocumentElement := Child;
          Exit;
        end;
      end;
      DocumentElement := Nil;
    end
    else
      FDocumentElement := Nil;
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
  StringHashList.Clear;
  CreateHeaderNode;
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'Clear - leave', True);
{$ENDIF}
end;

constructor TXmlVerySimple.Create;
begin
  inherited;
  StringHashList := TXmlStringHashList.Create;
  Root := TXmlNode.Create;
  Root.FLevel := 0;
//  Root.FIndex := 0;
  Root.NodeType := ntDocument;
  Root.ParentNode := Root;
  Root.Document := Self;
  FDocumentElement:=NIL;
  NodeIndentStr := '  ';
  Options := [doNodeAutoIndent, doWriteBOM{, doCaseInsensitive}];
  LineBreak := sLineBreak;
  XmlEscapeProcedure := Nil;
  XPathDelimiter := '/';
  CreateHeaderNode;
end;

procedure TXmlVerySimple.CreateHeaderNode;
//var
//  xmlDecl: TXmlNode;
begin
  {$IFDEF LOGGING}DebugOutputStrToFile('XmlVerySimple.txt', 'CreateHeaderNode - enter', True);{$ENDIF}
  if Assigned(FHeader) then begin
    {$IFDEF LOGGING}DebugOutputStrToFile('XmlVerySimple.txt', 'CreateHeaderNode - exit', True);{$ENDIF}
    Exit;
  end;
  {$IFDEF LOGGING}DebugOutputStrToFile('XmlVerySimple.txt', 'CreateHeaderNode - create <xml>', True);{$ENDIF}
  FHeader := Root.AddChild('xml', ntXmlDecl);
  //xmlDecl := FHeader.AddChild('xml', ntXmlDecl);
  {$IFDEF LOGGING}DebugOutputStrToFile('XmlVerySimple.txt', 'CreateHeaderNode - set version', True);{$ENDIF}
  FHeader.Attributes['version'] := '1.0';  // Default XML version
  //xmlDecl.Attributes['version'] := '1.0';  // Default XML version
  {$IFDEF LOGGING}DebugOutputStrToFile('XmlVerySimple.txt', 'CreateHeaderNode - set encoding', True);{$ENDIF}
  FHeader.Attributes['encoding'] := 'utf-8';
  //xmlDecl.Attributes['encoding'] := 'utf-8';
  {$IFDEF LOGGING}DebugOutputStrToFile('XmlVerySimple.txt', 'CreateHeaderNode - leave', True);{$ENDIF}
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
  StringHashList.Free;
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
  if (Length(Encoding) = 0) or (CompareText(Encoding, 'utf-8') = 0) then
    Stream := TStringStream.Create('', TEncoding.UTF8)
  else
    Stream := TStringStream.Create('', TEncoding.ANSI);
  try
    Stream.Position:=0;
    SaveToStream(Stream);
    Result := Stream.DataString;
  finally
    Stream.Free;
  end;
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
    if ALine <> '' then begin // Check for text nodes
      ParseText(Aline, Parent);
      if Reader.EndOfStream then  // if no chars available then exit
        Break;
    end;
    FirstChar := Reader.FirstChar;
    if FirstChar = '!' then begin
      if Reader.IsUppercaseText('!--') then  // check for a comment node
        ParseComment(Reader, Parent)
      else if Reader.IsUppercaseText('!DOCTYPE') then // check for a doctype node
        ParseDocType(Reader, Parent)
      else if Reader.IsUppercaseText('![CDATA[') then // check for a cdata node
        ParseCData(Reader, Parent)
      else
        ParseTag(Reader, Parent);
    end     // try to parse as tag
    else begin // Check for XML header / processing instructions
      if FirstChar = '?' then // could be header or processing instruction
        ParseProcessingInstr(Reader, Parent)
      else if FirstChar <> '' then begin // Parse a tag, the first tag in a document is the DocumentElement
        Node := ParseTag(Reader, Parent);
        if not Assigned(FDocumentElement) and (Parent = Root) then
          FDocumentElement := Node;
      end;
    end;
  end;
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'Parse - leave main loop', True);
{$ENDIF}

  // some xml/html documents does not have this set, so set it up
  if FDocumentElement = Nil then begin
    if Root.ChildNodes <> Nil then begin
      for Node in Root.ChildNodes do
        if Node.NodeType = ntElement then begin
          FDocumentElement := Node;
          Break;
        end;
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
    if Value <> '' then begin
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

function TXmlVerySimple.SelectNode(const XPathExpression: String; RootNode: TXmlNode = Nil): TXmlNode;
var
  list: TXmlNodeList;
begin
  Result:=Nil;
  list:=SelectNodes(XPathExpression, RootNode);
  try
    if list.Count > 0 then
      Result:=list.Get(0);
  finally
    list.Free;
  end;
end;

function TXmlVerySimple.SelectNodes(const XPathExpression: String; RootNode: TXmlNode = Nil): TXmlNodeList;
var
  xPath: TXmlXPathEvaluator;
//  list: TXmlNodeList;
begin
  if RootNode = Nil then
    RootNode:=Self.Root;

  xPath:=TXmlXPathEvaluator.Create;
  try
    Result:=xPath.Evaluate(RootNode, XPathExpression, XPathDelimiter);
  finally
    FreeAndNil(xPath);
  end;
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
      if AnsiStrScan(TXmlSpaces, SingleChar) = Nil then begin
        TextNode := True;
        Break;
      end;
  end;

  if TextNode then begin
    Node := Parent.AddChild('', ntText);
    Node.Text := Unescape(Line);
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
  Node := Parent.AddChild('', ntCData);
  temp:=Reader.ReadText(']]>', [etoDeleteStopChar, etoStopString]);
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'ParseCData - value: ' + temp, True);
{$ENDIF}
  Node.Text := Unescape(temp);
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
  Node := Parent.AddChild('', ntComment);
  temp:=Reader.ReadText('-->', [etoDeleteStopChar, etoStopString]);
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'ParseComment - value: ' + temp, True);
{$ENDIF}
  Node.Text := Unescape(temp);
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
  Node := Parent.AddChild('', ntDocType);
  temp:=Reader.ReadText('>[', []);
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'ParseDocType - value: ' + temp, True);
{$ENDIF}
  Node.Text := Unescape(temp);
  if not Reader.EndOfStream then begin
    Quote := Reader.FirstChar;
    Reader.IncCharPos;
    if Quote = '[' then
      Node.Text := Node.Text + Quote + Unescape(Reader.ReadText(']',[etoDeleteStopChar])) + ']' + Unescape(Reader.ReadText('>', [etoDeleteStopChar]));
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
  if LowerCase(Node.Name) = 'xml' then begin
    // delete old one
    if Root.ChildNodes <> Nil then
      Root.ChildNodes.Remove(FHeader.Index);
    FHeader := Node;
    FHeader.NodeType := ntXmlDecl;
  end
  else begin
    Node.NodeType := ntProcessingInstr;
    if not (doParseProcessingInstr in Options) then begin
      Node.Text := Unescape(Tag);
      if Node.AttributeList <> Nil then
        Node.AttributeList.Clear;
    end;
  end;
  Parent := Node.ParentNode;
{$IFDEF LOGGING}
  DebugOutputStrToFile('XmlVerySimple.txt', 'ParseProcessingInstr - leave', True);
{$ENDIF}
end;

function TXmlVerySimple.ParseTag(Reader: TXmlReader; var Parent: TXmlNode): TXmlNode;
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

    ParseText(ALine, Parent);
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
  SingleChar: Char;
  Tag, TagName: String;
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
  Node := Parent.AddChild('');
  Result := Node;
  Tag := TagStr;

  // Check for a self-closing Tag (does not have any text)
  if (Tag <> '') and (Tag[High(Tag)] = '/') then
    Delete(Tag, Length(Tag), 1)
  else
    Parent := Node;

  // extract tag name
  CharPos:=0;
  TagName:='';
  for SingleChar in Tag do begin
    Inc(CharPos);
    if AnsiStrScan(TXmlSpaces, SingleChar) <> Nil then begin
      TagName := Copy(Tag, 1, CharPos - 1);
      Break;
    end;
  end;

  if Length(TagName) > 0 then begin // Tag may have attributes
    ALine := Tag;
    Delete(Tag, CharPos, Length(Tag));
    Delete(ALine, 1, CharPos);
    if ALine <> '' then begin
      Node.CreateAttributeList;
      ParseAttributes(ALine, Node.AttributeList);
    end;
  end;

  if Length(TagName) > 0 then
    Node.Name := TagName
  else
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

function TXmlVerySimple.SaveToStream(const Stream: TStream; const RootNode: TXmlNode = Nil): TXmlVerySimple;
const
  BufferSize: Integer = 1024 * 1024; // 1MB buffer, so writing from buffer to disk is less frequent
var
  Writer: TStreamWriter;
begin
  if (Length(Encoding) = 0) or (CompareText(Self.Encoding, 'utf-8') = 0) then
    Writer := TStreamWriter.Create(Stream, TEncoding.UTF8, (doWriteBOM in Options), BufferSize)
  else if CompareText(Encoding, 'windows-1250') = 0 then
    Writer := TStreamWriter.Create(Stream, TEncoding.GetEncoding(1250), (doWriteBOM in Options), BufferSize)
  else
    Writer := TStreamWriter.Create(Stream, TEncoding.ANSI, (doWriteBOM in Options), BufferSize);
  try
    Writer.AutoFlush := False; // save to stream only when buffer is full
    if RootNode = Nil then begin
      Root.Compose(Writer, Root);
//      Root.Compose(Writer, Header); // save header first
//      if Assigned(DocumentElement) then
//        Root.Compose(Writer, DocumentElement); // save document
    end
    else
      RootNode.Compose(Writer, RootNode);
  finally
    Writer.Free;
  end;
  Result := Self;
end;

procedure TXmlVerySimple.RemoveStyleSheet;
var
  Node: TXmlNode;
begin
  Node := Root.FindNode('xml-stylesheet', [ntProcessingInstr], [nsRecursive]);
  if Assigned(Node) then
    Header.RemoveChild(Node);
end;

procedure TXmlVerySimple.SetStyleSheet(const Path: String);
var
  Node: TXmlNode;
begin
//  Options:=Options + [doParseProcessingInstr];
  Node := Root.FindNode('xml-stylesheet', [ntProcessingInstr], [nsRecursive]);
  if not Assigned(Node) then
  begin
    if Assigned(DocumentElement) then
      Node:=Root.InsertChildBefore(DocumentElement, 'xml-stylesheet', ntProcessingInstr)
    else
      Node:=Root.InsertChildAfter(Header, 'xml-stylesheet', ntProcessingInstr);

  end;
  Node.SetAttribute('type', 'text/xsl').SetAttribute('href', ReplaceStr(Path, '\','/'));
end;

procedure TXmlVerySimple.SetDocumentElement(Value: TXMlNode);
begin
  FDocumentElement := Value;
  if Value.ParentNode = Nil then begin
    Root.CreateChildNodes;
    Root.ChildNodes.Add(Value);
  end;
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

class function TXmlVerySimple.Escape(const Value: String): String;
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
  utf8:=UTF8Encode(Value);
  try
    Stream := TStringStream.Create(UTF8ToString(utf8), TEncoding.UTF8);
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
    if (FChildNodes <> Nil) and (FChildNodes.Count > 0) then
      Last:=ChildNodes.Last;
  except
    Last:=Nil;
  end;
  CreateChildNodes;
  Result:=FChildNodes.Add(AName, ANodeType);
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
    if RootNode.AttributeList <> Nil then
      for Attribute in RootNode.AttributeList do // add all attributes to child node
        Child.SetAttribute(Attribute.Name, Attribute.Value);
  end;
  if RootNode.ChildNodes <> Nil then begin
    for Node in RootNode.ChildNodes do // add all root node child nodes to child node
      Child.AddNodes(Node, True);
  end;
end;

procedure TXmlNode.Clear;
begin
  Text := '';
  if FAttributeList <> Nil then
    FAttributeList.Clear;
  if FChildNodes <> Nil then
    FChildNodes.Clear;
  UserData := '';
//  if UserData <> Nil then
//    FreeAndNil(UserData);
end;

constructor TXmlNode.Create(ANodeType: TXmlNodeType = ntElement);
begin
  FChildNodes := Nil;
  FAttributeList := Nil;
  NodeType := ANodeType;
  FNameWithPrefix:=CInvalidStrHashId;
  FText:=CInvalidStrHashId;
  FLevel:=0;
  FIndex:=0;
//  UserData := Nil;
  UserData := '';
end;

constructor TXmlNode.Create(ANode: TXmlNode);
begin
  Create(ANode.NodeType);
  ParentNode := Nil;
  Document := ANode.Document;
  Assign(ANode);
end;

destructor TXmlNode.Destroy;
begin
  Clear;
  if ChildNodes <> Nil then
    ChildNodes.Free;
  if AttributeList <> Nil then
    AttributeList.Free;
  inherited;
end;

procedure TXmlNode.CreateAttributeList;
begin
  if FAttributeList = Nil then begin
    FAttributeList := TXmlAttributeList.Create;
    FAttributeList.Document := Document;
  end;
end;

procedure TXmlNode.CreateChildNodes;
begin
  if FChildNodes = Nil then begin
    FChildNodes := TXmlNodeList.Create;
    FChildNodes.Parent := Self;
    FChildNodes.Document := Document;
  end;
end;

procedure TXmlNode.Assign(const Node: TXmlNode);
begin
  NodeName :=Node.NodeName;
  NodeType :=Node.NodeType;
  //NodeValue:=Node.NodeValue;
  UserData :=Node.UserData;
  Text     :=Node.Text;
  AssignAttributes(Node);
  AddNodes(Node);
end;

procedure TXmlNode.AssignAttributes(const Node: TXmlNode; const AddNotExistingOnly: Boolean = False);
var
  Attribute: TXmlAttribute;
begin
  if Node.AttributeList = Nil then
    Exit;

  for Attribute in Node.AttributeList do begin // add attributes to node
    if AddNotExistingOnly and not HasAttribute(Attribute.Name) then
      SetAttribute(Attribute.Name, Attribute.Value)
    else if not AddNotExistingOnly then
      SetAttribute(Attribute.Name, Attribute.Value); // all
  end;
end;

function TXmlNode.AsString: String;
var
  Stream: TStringStream;
  write_bom: Boolean;
begin
  if not Assigned(FDocument) then begin
//    Stream := TStringStream.Create('', TEncoding.UTF8);
//    try
//      Result := Stream.DataString;
//    finally
//      Stream.Free;
//    end;
    Result := '';
  end
  else begin
    if (Length(FDocument.Encoding) = 0) or (CompareText(FDocument.Encoding, 'utf-8') = 0) then
      Stream := TStringStream.Create('', TEncoding.UTF8)
    else if CompareText(FDocument.Encoding, 'windows-1250') = 0 then
      Stream := TStringStream.Create('', TEncoding.GetEncoding(1250))
    else
      Stream := TStringStream.Create('', TEncoding.ANSI);
    write_bom:=(doWriteBOM in FDocument.Options);
    FDocument.Options:=FDocument.Options - [doWriteBOM];
    try
      FDocument.SaveToStream(Stream, Self);
      Result := Stream.DataString;
    finally
      Stream.Free;
      if write_bom then
        FDocument.Options:=FDocument.Options + [doWriteBOM];
    end;
  end;
end;

function TXmlNode.ToString(const WhichPart: TXmlNodeDefinitionPart): String;
const
  BufferSize: Integer = 1024 * 1024; // 1MB buffer, so writing from buffer to disk is less frequent
var
  Stream: TStringStream;
  Writer: TStreamWriter;
begin
  if not Assigned(FDocument) then begin
    Result := '';
  end
  else begin
    if (Length(FDocument.Encoding) = 0) or (CompareText(FDocument.Encoding, 'utf-8') = 0) then begin
      Stream := TStringStream.Create('', TEncoding.UTF8);
      Writer := TStreamWriter.Create(Stream, TEncoding.UTF8, False, BufferSize);
    end
    else if CompareText(FDocument.Encoding, 'windows-1250') = 0 then begin
      Stream := TStringStream.Create('', TEncoding.GetEncoding(1250));
      Writer := TStreamWriter.Create(Stream, TEncoding.GetEncoding(1250), False, BufferSize);
    end
    else begin
      Stream := TStringStream.Create('', TEncoding.ANSI);
      Writer := TStreamWriter.Create(Stream, TEncoding.ANSI, False, BufferSize);
    end;

    try
      Writer.AutoFlush := False; // save to stream only when buffer is full
      Self.ComposeNode(Writer, WhichPart);
      Writer.Flush;
      Result := Stream.DataString;
    finally
      Writer.Free;
      Stream.Free;
    end;
  end;
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
begin
  FNameWithPrefix := Document.StringHashList.Add(Value);
end;

function TXmlNode.GetName: String;
var
  i: Integer;
begin
  Result := Document.StringHashList.GetStrByHash(FNameWithPrefix);
  i:=Pos(':', Result);
  if i > 0 then
    Delete(Result, 1, i);
end;

function TXmlNode.GetNameWithPrefix: String;
begin
  Result := Document.StringHashList.GetStrByHash(FNameWithPrefix);
end;

function TXmlNode.GetPrefix: String;
var
  i: Integer;
begin
  Result := Document.StringHashList.GetStrByHash(FNameWithPrefix);
  i:=Pos(':', Result);
  if i > 0 then
    Delete(Result, i, Length(Result) - i + 1);
end;

function TXmlNode.GetText: String;
begin
  Result := Document.StringHashList.GetStrByHash(FText);
end;

procedure TXmlNode.SetText(Value: String);
begin
  FText := Document.StringHashList.Add(Value);
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
//  Result := ChildNodes.Find(Name, NodeTypes);
  Result:=Nil;
  if ChildNodes = Nil then
    Exit;
  //
  SearchWithoutPrefix:=(nsSearchWithoutPrefix in SearchOptions);
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
//  Result := ChildNodes.Find(Name, AttrName, NodeTypes);
  Result:=Nil;
  if ChildNodes = Nil then
    Exit;
  //
  SearchWithoutPrefix:=(nsSearchWithoutPrefix in SearchOptions);
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
//  Result := ChildNodes.Find(Name, AttrName, NodeTypes);
  Result:=Nil;
  if ChildNodes = Nil then
    Exit;
  //
  SearchWithoutPrefix:=(nsSearchWithoutPrefix in SearchOptions);
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

function TXmlNode.FindNode(const Name: String; NodeTypes: TXmlNodeTypes = [ntElement]; const SearchOptions: TXmlNodeSearchTypes = []): TXmlNode;
var
  SearchWithoutPrefix: Boolean;
begin
  Result := Nil;
  SearchWithoutPrefix:=(nsSearchWithoutPrefix in SearchOptions);
  if ((NodeTypes = []) or (Self.NodeType in NodeTypes)) and
     IsSame(IfThen(Document.GetSearchExcludeNamespacePrefix or SearchWithoutPrefix, Self.Name, Self.NameWithPrefix), Name) then begin
    Result := Self;
    Exit;
  end;
  if ChildNodes <> Nil then
    Result := ChildNodes.Find(Name, NodeTypes, SearchWithoutPrefix);
  if (Result = Nil) and (nsRecursive in SearchOptions) then
    Result:=FindNodeRecursive(Name, NodeTypes, SearchOptions);
end;

function TXmlNode.FindNode(const Name, AttrName: String; NodeTypes: TXmlNodeTypes = [ntElement]; const SearchOptions: TXmlNodeSearchTypes = []): TXmlNode;
var
  SearchWithoutPrefix: Boolean;
begin
  Result := Nil;
  SearchWithoutPrefix:=(nsSearchWithoutPrefix in SearchOptions);
  if ((NodeTypes = []) or (Self.NodeType in NodeTypes)) and
     ((Name = '') or ((Name <> '') and IsSame(IfThen(Document.GetSearchExcludeNamespacePrefix or SearchWithoutPrefix, Self.Name, Self.NameWithPrefix), Name))) and
     Self.HasAttribute(AttrName) then begin
    Result := Self;
    Exit;
  end;
  if ChildNodes <> Nil then
    Result := ChildNodes.Find(Name, AttrName, NodeTypes, SearchWithoutPrefix);
  if (Result = Nil) and (nsRecursive in SearchOptions) then
    Result:=FindNodeRecursive(Name, AttrName, NodeTypes, SearchOptions);
end;

function TXmlNode.FindNode(const Name, AttrName, AttrValue: String; NodeTypes: TXmlNodeTypes = [ntElement]; const SearchOptions: TXmlNodeSearchTypes = []): TXmlNode;
var
  SearchWithoutPrefix: Boolean;
begin
  Result := Nil;
  SearchWithoutPrefix:=(nsSearchWithoutPrefix in SearchOptions);
  if ((NodeTypes = []) or (Self.NodeType in NodeTypes)) and // if no type specified or node type in types
     ((Name = '') or ((Name <> '') and IsSame(IfThen(Document.GetSearchExcludeNamespacePrefix or SearchWithoutPrefix, Self.Name, Self.NameWithPrefix), Name))) and
     Self.HasAttribute(AttrName) and IsSame(Self.Attributes[AttrName], AttrValue) then begin
    Result := Self;
    Exit;
  end;
  if ChildNodes <> Nil then
    Result := ChildNodes.Find(Name, AttrName, AttrValue, NodeTypes, SearchWithoutPrefix);
  if (Result = Nil) and (nsRecursive in SearchOptions) then
    Result:=FindNodeRecursive(Name, AttrName, AttrValue, NodeTypes, SearchOptions);
end;

function TXmlNode.FindNodes(const Name: String; NodeTypes: TXmlNodeTypes = [ntElement]; const SearchWithoutPrefix: Boolean = False): TXmlNodeList;
begin
  Result := Nil;
  if ChildNodes <> Nil then
    Result := ChildNodes.FindNodes(Name, NodeTypes, SearchWithoutPrefix);
end;

procedure TXmlNode.ScanNodes(Name: String; CallBack: TXmlNodeCallBack; const SearchWithoutPrefix: Boolean = False);
var
  Node: TXmlNode;
begin
  if ChildNodes = Nil then
    Exit;
  //
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
  Result := Nil;
  if ChildNodes <> Nil then
    Result := ChildNodes.First;
end;

function TXmlNode.FirstChild(const Name: String): TXmlNode;
begin
  if Length(Name) > 0 then begin
    Result := FirstChild;
    if not Self.IsSame(Result.NodeName, Name) then
      Result := Nil;
  end
  else
    Result:=FirstChild;
end;

function TXmlNode.GetAttr(const AttrName: String): String;
var
  Attribute: TXmlAttribute;
begin
  Result := '';
  if AttributeList = Nil then
    Exit;

  Attribute := AttributeList.Find(AttrName);
  if Assigned(Attribute) then
    Result := Attribute.Value;
end;

function TXmlNode.GetNodeValue: String;
begin
  Result := '';
  if Self.HasTextChildNode then
    Result := Self.FirstChild.Text;
end;

function TXmlNode.HasPrefix: Boolean;
var
  i: Integer;
  temp: String;
begin
  Result := False;
  temp := Document.StringHashList.GetStrByHash(FNameWithPrefix);
  i:=Pos(':', temp);
  if i > 0 then
    Delete(temp, i, Length(temp) - i + 1);
  Result := Length(temp) > 0;
end;

function TXmlNode.HasAttribute(const AttrName: String): Boolean;
begin
  Result := (AttributeList <> Nil) and AttributeList.HasAttribute(AttrName);
end;

function TXmlNode.HasChild(const Name: String; NodeTypes: TXmlNodeTypes = [ntElement]): Boolean;
begin
  Result := (FChildNodes <> Nil) and FChildNodes.HasNode(Name, NodeTypes);
end;

function TXmlNode.HasChild(const Name: String; out Node: TXmlNode; NodeTypes: TXmlNodeTypes = [ntElement]): Boolean;
begin
  Result := (FChildNodes <> Nil) and FChildNodes.HasNode(Name, Node, NodeTypes);
end;

function TXmlNode.HasChild(const Name: String; out NodeList: TXmlNodeList; NodeTypes: TXmlNodeTypes = [ntElement]): Boolean;
begin
  Result := (FChildNodes <> Nil) and FChildNodes.HasNode(Name, NodeList, NodeTypes);
end;

function TXmlNode.HasChildNodes: Boolean;
begin
  Result := (FChildNodes <> Nil) and (FChildNodes.Count > 0);
end;

function TXmlNode.HasTextChildNode: Boolean;
begin
  Result := Self.HasChildNodes and Self.FirstChild.IsTextElement;
end;

function TXmlNode.InsertChild(const Name: String; Position: Integer; NodeType: TXmlNodeType = ntElement): TXmlNode;
begin
  CreateChildNodes;
  Result := FChildNodes.Insert(Name, Position, NodeType);
  if Assigned(Result) then
    Result.ParentNode := Self;
end;

function TXmlNode.InsertChild(const NodeToInsert: TXmlNode; Position: Integer): TXmlNode;
begin
  CreateChildNodes;
  Result := FChildNodes.Insert(NodeToInsert, Position);
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
  Result := (NodeType in [ntElement, ntText]) and (Text <> ''); // and not HasChildNodes;
end;

function TXmlNode.LastChild: TXmlNode;
begin
  if (FChildNodes <> Nil) and (FChildNodes.Count > 0) then
    Result := FChildNodes.Last
  else
    Result := Nil;
end;

function TXmlNode.LastChild(const Name: String): TXmlNode;
begin
  if Length(Name) > 0 then begin
    Result := LastChild;
    if not Self.IsSame(Result.NodeName, Name) then
      Result := Nil;
  end
  else
    Result:=LastChild;
end;

function TXmlNode.PreviousSibling: TXmlNode;
begin
  Result:=FPrevSibling;
end;

function TXmlNode.NextSibling: TXmlNode;
begin
  Result:=FNextSibling;
end;

procedure TXmlNode.SetAttr(const AttrName, AttrValue: String);
begin
  SetAttribute(AttrName, AttrValue);
end;

procedure TXmlNode.SetNodeValue(const Value: String);
var
  Node: TXmlNode;
begin
  if Self.HasTextChildNode then begin
    Self.FirstChild.Text := Value;
    Exit;
  end
  else if not Self.HasChildNodes then begin
    Node := Self.AddChild('', ntText);
    Node.Text := Value;
    Exit;
  end;

  raise EXmlNodeException.Create('Node has children and can not be text node at the same time !');
end;

function TXmlNode.SetAttribute(const AttrName, AttrValue: String): TXmlNode;
var
  Attribute: TXmlAttribute;
begin
  CreateAttributeList;
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
  if FAttributeList <> Nil then
    FAttributeList.Document := Value;
  if FChildNodes <> Nil then
    FChildNodes.Document := Value;
end;

function TXmlNode.SetNodeType(Value: TXmlNodeType): TXmlNode;
begin
  NodeType := Value;
  Result := Self;
end;

//function TXmlNode.SetText(const Value: String): TXmlNode;
//begin
//  Text := Value;
//  Result := Self;
//end;

procedure TXmlNode.Compose(Writer: TStreamWriter; RootNode: TXmlNode);
var
  Child: TXmlNode;
  LineBreak: String;
begin
  Document.SkipIndent := False;
  Document.ParentIndentNode := Nil;
  if Assigned(FDocument) then begin
    if doCompact in FDocument.Options then begin
      Writer.NewLine := '';
      LineBreak := '';
    end
    else begin
      Writer.NewLine := FDocument.LineBreak;
      LineBreak := FDocument.LineBreak;
    end;

    if RootNode = Nil then
      RootNode:= FDocument.Root;
  end
  else begin
    Writer.NewLine := #13#10; // Windows CRLF
    LineBreak := #13#10;

    if RootNode = Nil then
      RootNode:= Self;
  end;

//  if Assigned(Document.DocumentElement) and (RootNode = Document.DocumentElement) then
//    Walk(Writer, '', RootNode);

  if RootNode.ChildNodes <> Nil then begin
    for Child in RootNode.ChildNodes do
      Walk(Writer, LineBreak, '', Child);
  end;
end;

function TXmlNode.ComposeNode(Writer: TStreamWriter; const WhichPart: TXmlNodeDefinitionPart): String;
var
  LineBreak: String;
begin
  Document.SkipIndent := False;
  Document.ParentIndentNode := Nil;
  if Assigned(FDocument) then begin
    if doCompact in FDocument.Options then begin
      Writer.NewLine := '';
      LineBreak := '';
    end
    else begin
      Writer.NewLine := FDocument.LineBreak;
      LineBreak := FDocument.LineBreak;
    end;
  end
  else begin
    Writer.NewLine := #13#10; // Windows CRLF
    LineBreak := #13#10;
  end;

  Walk(Writer, LineBreak, '', Self, False, WhichPart);
end;

procedure TXmlNode.Walk(Writer: TStreamWriter; const LineBreak, PrefixNode: String; Node: TXmlNode; const WalkChildren: Boolean = True; const WhichPart: TXmlNodeDefinitionPart = ndpFull);
var
  Child: TXmlNode;
  Line: String;
  Indent: String;
begin
  if WhichPart in [ndpFull, ndpOpen] then begin
    if (Assigned(FDocument) and (FDocument.Root.FChildNodes <> Nil) and (Node = FDocument.Root.ChildNodes.First)) or Document.SkipIndent then begin
      Line := '<';
      Document.SkipIndent := False;
    end
    else begin
      if not WalkChildren then begin
        Line := '<';
        Document.SkipIndent := True;
      end
      else
        Line := LineBreak + PrefixNode + '<';
    end;

    case Node.NodeType of
      ntComment: begin
        Writer.Write(Line + '!--' + TXmlVerySimple.Escape(Node.Text) + '-->');
        Exit;
      end;
      ntDocType: begin
        Writer.Write(Line + '!DOCTYPE ' + TXmlVerySimple.Escape(Node.Text) + '>');
        Exit;
      end;
      ntCData: begin
        Writer.Write('<![CDATA[' + TXmlVerySimple.Escape(Node.Text) + ']]>');
        Exit;
      end;
      ntText: begin
        Writer.Write(TXmlVerySimple.Escape(Node.Text));
        if doSmartNodeAutoIndent in FDocument.Options then begin
          if not Document.SkipIndent and (Node.ParentNode <> Nil) and (Document.ParentIndentNode = Nil) then
            Document.ParentIndentNode := Node.ParentNode.ParentNode;
          Document.SkipIndent := True;
        end;
        Exit;
      end;
      ntProcessingInstr: begin
        if (Node.AttributeList <> Nil) and (Node.AttributeList.Count > 0) then
          Line := Line + '?' + Trim(Node.Name) + ' ' + Trim(Node.AttributeList.AsString) + '?>'
        else
          Line := Line + '?' + Node.Text + '?>';
        if Assigned(FDocument) and Assigned(FDocument.XmlEscapeProcedure) then
          FDocument.XmlEscapeProcedure(Line);
        Writer.Write(Line);
        Exit;
      end;
      ntXmlDecl: begin
        if Assigned(FDocument) and (doSkipHeader in FDocument.Options) then
          Exit;
        if (Node.AttributeList <> Nil) and (Node.AttributeList.Count > 0) then
          Line := Line + '?' + Trim(Node.Name) + ' ' + Trim(Node.AttributeList.AsString) + '?>'
        else
          Line := Line + '?' + Node.Text + '?>';
        if Assigned(FDocument) and Assigned(FDocument.XmlEscapeProcedure) then
          FDocument.XmlEscapeProcedure(Line);
        Writer.Write(Line);
        Exit;
      end;
    end;

    Line := Line + Trim(Node.NameWithPrefix);
    if (Node.AttributeList <> Nil) and (Node.AttributeList.Count > 0) then
      Line := Line + ' ' + Trim(Node.AttributeList.AsString);

    // Self closing tags
    if (Length(Node.Text) = 0) and not Node.HasChildNodes then begin
      Writer.Write(Line + '/>');
      Exit;
    end;

    Line := Line + '>';
    if WhichPart = ndpFull then begin
      if Length(Node.Text) > 0 then begin
        Line := Line + TXmlVerySimple.Escape(Node.Text);
        if Node.HasChildNodes then
          Document.SkipIndent := True;
      end;
    end;

    if Assigned(FDocument) and Assigned(FDocument.XmlEscapeProcedure) then
      FDocument.XmlEscapeProcedure(Line);

    Writer.Write(Line);

    if WalkChildren then begin
      // Set indent for child nodes
      if Assigned(FDocument) then begin
        if (doCompact in FDocument.Options) or (doCompactWithBreakes in FDocument.Options) then
          Indent := ''
        else
          Indent := PrefixNode + IfThen(FDocument.GetNodeAutoIndent, FDocument.NodeIndentStr);
      end
      else begin
        Indent := '';
      end;
    end;

    if WalkChildren then begin
      // Process child nodes
      if Node.ChildNodes <> Nil then begin
        for Child in Node.ChildNodes do
          Walk(Writer, LineBreak, Indent, Child, WalkChildren, WhichPart);
      end;

      // If node has child nodes and last child node is not a text node then set indent for closing tag
      if Node.HasChildNodes and not Node.HasTextChildNode and not Document.SkipIndent then
        Indent := LineBreak + PrefixNode
      else
        Indent := '';
    end;
  end;

  if (doSmartNodeAutoIndent in FDocument.Options) and (Document.ParentIndentNode <> Nil) and (Node = Document.ParentIndentNode) then begin
    Document.ParentIndentNode := Nil;
    Document.SkipIndent := False;
    Indent := LineBreak + PrefixNode;
  end;

  if (WhichPart in [ndpFull, ndpClose]) and not (Node.NodeType in [ntComment, ntDocType, ntCData, ntText, ntProcessingInstr, ntXmlDecl]) then
    Writer.Write(Indent + '</' + Trim(Node.NameWithPrefix) + '>');
end;

{ TXmlAttributeEnumerator }

constructor TXmlAttributeEnumerator.Create(List: TXmlAttributeList);
begin
  FAttributeList:=List;
  FIndex:=-1;
end;

function TXmlAttributeEnumerator.GetCurrent: TXmlAttribute;
begin
  Result := TXmlAttribute(FAttributeList.Items[FIndex]);
end;

function TXmlAttributeEnumerator.MoveNext: Boolean;
begin
  Result := FIndex < (FAttributeList.Count - 1);
  if Result then
    Inc(FIndex);
end;

{ TXmlAttributeList }

function TXmlAttributeList.First: TXmlAttribute;
begin
  try
    Result := TXmlAttribute(inherited First);
  except
    Result := Nil;
  end;
end;

function TXmlAttributeList.Last: TXmlAttribute;
begin
  try
    Result := TXmlAttribute(inherited Last);
  except
    Result := Nil;
  end;
end;

function TXmlAttributeList.GetEnumerator: TXmlAttributeEnumerator;
begin
  Result := TXmlAttributeEnumerator.Create(Self);
end;

function TXmlAttributeList.Add(const Name: String): TXmlAttribute;
begin
  Result := TXmlAttribute.Create;
  Result.Document := Document;
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

{ TXmlNodeEnumerator }

constructor TXmlNodeEnumerator.Create(List: TXmlNodeList);
begin
  FNodeList:=List;
  FIndex:=-1;
end;

function TXmlNodeEnumerator.GetCurrent: TXmlNode;
begin
  Result := TXmlNode(FNodeList.Items[FIndex]);
end;

function TXmlNodeEnumerator.MoveNext: Boolean;
begin
  Result := FIndex < (FNodeList.Count - 1);
  if Result then
    Inc(FIndex);
end;

{ TXmlNodeList }

function TXmlNodeList.First: TXmlNode;
begin
  try
    Result := TXmlNode(inherited First);
  except
    Result := Nil;
  end;
end;

function TXmlNodeList.Last: TXmlNode;
begin
  try
    Result := TXmlNode(inherited Last);
  except
    Result := Nil;
  end;
end;

function TXmlNodeList.GetEnumerator: TXmlNodeEnumerator;
begin
  Result := TXmlNodeEnumerator.Create(Self);
end;

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

function TXmlNodeList.Add(Value: TXmlNode; ParentNode: TXmlNode): Integer;
begin
  Parent:=ParentNode;
  Result:=Add(Value);
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

procedure TXmlNodeList.Add(const List: TXmlNodeList);
var
  Node: TXmlNode;
begin
  for Node in List do begin // add all items to list
    Self.Add(Node, Node.ParentNode);
  end;
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

procedure TXmlNodeList.FindNodesRecursive(const List: TXmlNodeList; const Name: String; NodeTypes: TXmlNodeTypes = [ntElement]; const SearchWithoutPrefix: Boolean = False);
var
  Node: TXmlNode;
begin
  for Node in Self do begin
    if ((NodeTypes = []) or (Node.NodeType in NodeTypes)) and IsSame(IfThen(Document.GetSearchExcludeNamespacePrefix or SearchWithoutPrefix, Node.Name, Node.NameWithPrefix), Name) then begin
      List.Parent := Node.ParentNode;
      List.Add(Node);
    end;
    if Node.HasChildNodes then
      Node.ChildNodes.FindNodesRecursive(List, Name, NodeTypes, SearchWithoutPrefix);
  end;
  List.Parent := Nil;
end;

function TXmlNodeList.FindNodes(const Name: String; NodeTypes: TXmlNodeTypes = [ntElement]; const SearchWithoutPrefix: Boolean = False): TXmlNodeList;
var
  Node: TXmlNode;
begin
  Result := TXmlNodeList.Create(False);
  try
    Result.Document := Document;
    FindNodesRecursive(Result, Name, NodeTypes, SearchWithoutPrefix);
  except
    Result.Free;
    raise;
  end;
end;

function TXmlNodeList.FirstChild: TXmlNode;
begin
  Result := First;
end;

function TXmlNodeList.LastChild: TXmlNode;
begin
  Result := Last;
end;

function TXmlNodeList.Get(Index: Integer): TXmlNode;
begin
  if (Index < 0) or (Index >= Count) then
    Result := Nil
  else
    Result := TXmlNode(Items[Index]);
end;

function TXmlNodeList.HasNode(const Name: String; NodeTypes: TXmlNodeTypes = [ntElement]): Boolean;
begin
  Result := Assigned(Find(Name, NodeTypes));
end;

function TXmlNodeList.HasNode(const Name: String; out Node: TXmlNode; NodeTypes: TXmlNodeTypes = [ntElement]): Boolean;
begin
  Node := Find(Name, NodeTypes);
  Result := Assigned(Node);
end;

function TXmlNodeList.HasNode(const Name: String; out NodeList: TXmlNodeList; NodeTypes: TXmlNodeTypes = [ntElement]): Boolean;
begin
  NodeList := FindNodes(Name, NodeTypes);
  Result := (NodeList.Count > 0);
  if not Result then begin
    NodeList.Free;
    NodeList:=Nil;
  end;
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
begin
  Result:=Node.PreviousSibling;
end;

function TXmlNodeList.NextSibling(Node: TXmlNode): TXmlNode;
begin
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
  FName := CInvalidStrHashId;
  FValue := CInvalidStrHashId;
  AttributeType := atSingle;
end;

class function TXmlAttribute.Escape(const Value: String): String;
begin
  Result := TXmlVerySimple.Escape(Value);
end;

function TXmlAttribute.GetName: String;
begin
  Result := Document.StringHashList.GetStrByHash(FName);
end;

function TXmlAttribute.Getvalue: String;
begin
  Result := Document.StringHashList.GetStrByHash(FValue);
end;

procedure TXmlAttribute.SetName(const Value: String);
begin
  FName := Document.StringHashList.Add(Value);
end;

procedure TXmlAttribute.SetValue(const Value: String);
begin
  FValue := Document.StringHashList.Add(Value);
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
      NewLineIndex := 0;     // zeto + 2023-07-28 Jacek
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
