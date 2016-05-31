// Some of the commands and command properties are hidden in the default user interface
// to decrease number of the server calls when the form is created on the web client.
// on the thin client, all necessary options are enabled by calling the method in the
// OnOpen handler.
&AtClient
Var ResponseBeforeClose;

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	Var DataProcessorObject, EntireDocument, BoldFont, PlatformVersion, PlatformVersionNumber, SystemInfo, Multipliers;
	Var Line, Data, Counter, Column, Name, Type, TypeList, ChoiceList, Event, FirstRow;
	Var FlagColumnNumber, EventColumnNumber, NumberOfAllColumn, EventColumnWidth, Area, LineNumber;
	Multipliers = New Array;
	Multipliers.Add(10000000); // revision digit
	Multipliers.Add(100000); // subrevision digit
	Multipliers.Add(1000); // version number
	Multipliers.Add(1); // build number
	SystemInfo = New SystemInfo;
	PlatformVersionNumber = 0;
	PlatformVersion = StrReplace(SystemInfo.AppVersion, ".", Chars.LF);
	For Counter = 1 to 4 Do
		PlatformVersionNumber = PlatformVersionNumber + Number(StrGetLine(PlatformVersion, Counter))*Multipliers[Counter-1];
	EndDo;
	If PlatformVersionNumber < 80303641 Then
		Raise NStr("en = 'The data processor requires 1C:Enterprise 8.3.3.641 or later.';ru = 'Для работы обработки требуется ""1С:Предприятие"" версии 8.3.3.641 или старше.'");
	EndIf;
	DataProcessorObject = FormAttributeToValue("Object");
	MetaPath = DataProcessorObject.Metadata().FullName();
	EditAreaBound = New Structure;
	EditAreaBound.Insert("Top", 2);
	EditAreaBound.Insert("Left", 4);
	EditAreaBound.Insert("Right", 0);
	EditAreaBound.Insert("Bottom", 0);
	ColorsInUse = New Structure;
	ColorsInUse.Insert("SelectionBackground", StyleColors.ReportHeaderBackColor);
	ColorsInUse.Insert("OrdinaryBackground", StyleColors.FormBackColor);
	ColorsInUse.Insert("ChoiceBackground", StyleColors.FieldBackColor);
	ColorsInUse.Insert("AllPropertiesBackground", StyleColors.ButtonBackColor);
	// Memory dump types
	DumpType.Add(  1, NStr("en = 'Additional data segment';ru = 'Дополнительный сегмент данных'"), True);
	DumpType.Add(  2, NStr("en = 'Full process memory content';ru = 'Содержимое всей памяти процесса'"), True);
	DumpType.Add(  4, NStr("en = 'Object data';ru = 'Данные объектов'"), False);
	DumpType.Add(  8, NStr("en = 'Only data required for calling stack recovery';ru = 'Оставить только информацию, необходимую для восстановления стека вызовов'"), False);
	DumpType.Add( 16, NStr("en = 'If the stack contains references to module memory, the referenced memory areas must be written';ru = 'Если стек содержит ссылки на память модулей, то добавить флаг включения памяти, на которую есть ссылки'"), False);
	DumpType.Add( 32, NStr("en = 'Unloaded module memory';ru = 'Память из-под выгруженных модулей'"), False);
	DumpType.Add( 64, NStr("en = 'Memory to which references exist';ru = 'Память, на которую есть ссылки'"), False);
	DumpType.Add(128, NStr("en = 'Module file details';ru = 'Подробная информация о файлах модулей'"), False);
	DumpType.Add(256, NStr("en = 'Local thread data';ru = 'Локальные данные потоков'"), False);
	DumpType.Add(512, NStr("en = 'Memory of all available virtual address space'; ru = 'Память из всего доступного виртуального адресного пространства'"), False);
	// Importing the event details table
	ImportEventDetails();
	// Importing the column details table
	ImportColumnDetails();
	EntireDocument = TLEditor.Area(,,,);
	EntireDocument.BackColor = ColorsInUse.OrdinaryBackground;
	// Generating the column type list
	BoldFont = New Font(, , True);
	Line = New Line(SpreadsheetDocumentCellLineType.Dotted, 1);
	Data = DataProcessorObject.GetTemplate("EventPropertyContent");
	ColumnTypes = New Structure;
	Counter = 2;
	For Each Column In ColumnData Do
		// Getting the column type
		Name = Lower(TrimAll(Data.Area(1, Counter).Text));
		Type = Lower(TrimAll(Data.Area(2, Counter).Text));
		If Column.Name = "all" Then
			// All columns except the ALL column itself
			TypeList = New ValueList;
			For Each Column2 In ColumnData Do
				TypeList.Add(Column2.Name, Column2.Text);
			EndDo;
			ColumnTypes.Insert(Name, TypeList);
			Continue;
		ElsIf Type = "nl" Then
			// Special type: the list of all event
			TypeList = New ValueList;
			For Each Event In EventData Do
				TypeList.Add(Event.Name, Event.Text);
			EndDo;
			ColumnTypes.Insert(Name, TypeList);
		ElsIf Type = "s" Or Type = "n" Or Type = "b" Then
			// Primitive types: string (s), number (n), and boolean (b).
			ColumnTypes.Insert(Name, Type);
		Else
			// Custom types
			TypeList = ImportCustomType(Type);
			ColumnTypes.Insert(Name, TypeList);
			If Type = "ll" Then
				ChoiceList = Items.SystemEventsLevel.ChoiceList;
				For Each TypeItem In TypeList Do
					// Adding the value to the choice list
					ChoiceList.Add(TypeItem.Value, TypeItem.Presentation);
					// Set the conditional appetence for the Level column of the SYSTEM table
					NewItem = ThisForm.ConditionalAppearance.Items.Add();
					NewItem.Use = True;
					FieldToCustomize = NewItem.Fields.Items.Add();
					FieldToCustomize.Use = True;
					FieldToCustomize.Field = New DataCompositionField("SystemEventsLevel");
					NewItem.Appearance.SetParameterValue("Text", TypeItem.Presentation);
					NewFilter = NewItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
					NewFilter.LeftValue = New DataCompositionField("SystemEvents.Level");
					NewFilter.ComparisonType = DataCompositionComparisonType.Equal;
					NewFilter.RightValue = TypeItem.Value;
					NewFilter.Use = True;
				EndDo;
			EndIf;
		EndIf;
		Counter = Counter + 1;
	EndDo;
	// Generating the spreadsheet document by templates
	FlagColumnNumber = 1;
	EventColumnNumber = 2;
	NumberOfAllColumn = 3;
	EventColumnWidth = 10;
	// Event selection area title
	Area = TLEditor.Area(1, FlagColumnNumber);
	Area.Text = NStr("en = 'Events';ru = 'Выбор события'");
	Area.Hyperlink = False;
	Area.HorizontalAlign = HorizontalAlign.Left;
	Area.Outline(Line, Line, Line, Line);
	// Generating the left table part (row by row)
	LineNumber = 2;
	EditAreaBound.Top = LineNumber;
	For Each Event In EventData Do
		Event.LineNumber = LineNumber;
		// Row header. Text will be set later.
		Area = TLEditor.Area(LineNumber, EventColumnNumber);
		Area.TextPlacement = SpreadsheetDocumentTextPlacementType.Cut;
		Area.Outline(Line, Line, Line, Line);
		// Flag that shows whether the row is enabled or disabled
		Area = TLEditor.Area(LineNumber, FlagColumnNumber);
		Area.Text = "";
		Area.Hyperlink = True;
		Area.HorizontalAlign = HorizontalAlign.Center;
		Area.BackColor = ColorsInUse.ChoiceBackground;
		Area.Outline(Line, Line, Line, Line);
		// The All flag of the row
		Area = TLEditor.Area(LineNumber, NumberOfAllColumn);
		Area.Text = "";
		Area.Hyperlink = True;
		Area.HorizontalAlign = HorizontalAlign.Center;
		Area.BackColor = ColorsInUse.ChoiceBackground;
		Area.Outline(Line, Line, Line, Line);
		LineNumber = LineNumber + 1;
	EndDo;
	EditAreaBound.Bottom = LineNumber;
	TLEditor.Area(, FlagColumnNumber, , FlagColumnNumber).ColumnWidth = 3;
	TLEditor.Area(, NumberOfAllColumn, , NumberOfAllColumn).ColumnWidth = 3;
	EditAreaBound.Bottom = LineNumber - 1;
	// Generating the column headers
	ColumnNumber = 3;
	For Each Column In ColumnData Do
		Column.ColumnNumber = ColumnNumber;
		// Column header. Text will be set later.
		Area = TLEditor.Area(1, ColumnNumber);
		Area.VerticalAlign = VerticalAlign.Bottom;
		Area.HorizontalAlign = HorizontalAlign.Left;
		Area.Outline(Line, Line, Line, Line);
		// Setting the column width
		TLEditor.Area(, ColumnNumber, , ColumnNumber).ColumnWidth = 4;
		ColumnNumber = ColumnNumber + 1;
	EndDo;
	EditAreaBound.Right = ColumnNumber - 1;
	// Column and row headers will be set from the settings reading handler
	// Placing available cells on the parameter matrix
	For Each Event In EventData Do
		For Each Column In ColumnData Do
			Attribute = Data.Area(Event.LineNumber+1, Column.ColumnNumber-2).Text;
			If Attribute = "+" Then
				Area = TLEditor.Area(Event.LineNumber, Column.ColumnNumber);
				Area.Text = "";
				Area.Hyperlink = True;
				Area.HorizontalAlign = HorizontalAlign.Center;
				Area.BackColor = ColorsInUse.ChoiceBackground;
				Area.Outline(Line, Line, Line, Line);
				Child = Column.Content.Add();
				Child.Name = Event.Name;
				Child.Text = Event.Text;
				Child.ID = Event.GetID();
				Child = Event.Content.Add();
				Child.Name = Column.Name;
				Child.Text = Column.Text;
				Child.ID = Column.GetID();
			EndIf;
		EndDo;
	EndDo;
	// Spreadsheet table parameters
	TLEditor.Area(, 2, , 2).ColumnSizeChangeMode = SizeChangeMode.QuickChange;
	FirstRow = TLEditor.Area(1, , 1, );
	//FirstRow.AutoRowHeight = True;
	FirstRow.AutoRowHeight = False;
	FirstRow.RowHeight = 70;
	FirstRow.TextPlacement = SpreadsheetDocumentTextPlacementType.Auto;
	FirstRow.TextOrientation = 90;
	TLEditor.FixedTop = 1;
	TLEditor.FixedLeft = 3;
	CurrentColumn = -1;
	CurrentRow = -1;
	// Settings the default editor parameters
	DefaultParametersAtServer();
	DisplayNamesPresentations = 1;
	ShowColumnRowHeaders(DisplayNamesPresentations);

		Если ОбщийМодульПовтор.ПолучитьЗначениеНастройкиИлиКонстанты("ИспользоватьСобственныйПереводЭлементовИнтерфейса") Тогда
		ОбщийМодульСервер.ПеревестиРеквизитыФормы(ЭтаФорма);
	КонецЕсли;

EndProcedure
&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	// Showing names or presentations
	DisplayNamesPresentations = ?(Settings["DisplayNamesPresentations"] = Undefined, 1, Settings["DisplayNamesPresentations"]);
	ShowColumnRowHeaders(DisplayNamesPresentations);
EndProcedure
&AtServer
Function ImportCustomType(TypeName)
	Var DataProcessorObject, Types, MustBeSorted, TypeList, LineNumber, TypeStart;
	Var Value, Details;
	DataProcessorObject = FormAttributeToValue("Object");
	Types = DataProcessorObject.GetTemplate("PropertyValues");
	MustBeSorted = False;
	TypeList = New ValueList;
	LineNumber = 1;
	TypeStart = False;
	While True Do
		Value = Types.Area(LineNumber, 1).Text;
		Details = Types.Area(LineNumber, 2).Text;
		LineNumber = LineNumber + 1;
		If Not TypeStart Then
			If Lower(Value) = Lower(TypeName) Then
				// Type details start is found
				TypeStart = True;
				MustBeSorted = ?(Details = TrimAll(Lower(Details)) = "+sort", True, False);
			EndIf;
			Continue;
		EndIf;
		If IsBlankString(Value) And TypeStart Then
			// An empty cell after the type start means the end of type data
			TypeStart = False;
			Break;
		EndIf;
		// Adding the current data to the list
		TypeList.Add(Value, Details);
		If IsBlankString(Types.Area(LineNumber, 2).Text) Then
			// Two in row empty vertical cells mean the end of the custom type details file
			Break;
		EndIf;
	EndDo;
	If MustBeSorted Then
		TypeList.SortByPresentation();
	EndIf;
	Return TypeList;
EndFunction
&AtServer
Procedure ImportEventDetails()
	Var DataProcessorObject, Data, RowNumber, Area, Value, DataRow, Text;
	DataProcessorObject = FormAttributeToValue("Object");
	// Importing events to the parameter matrix
	Data = DataProcessorObject.GetTemplate("EventPropertyContent");
	RowNumber = 3;
	While True Do
		Area = Data.Area(RowNumber, 1);
		Value = TrimAll(Area.Text);
		If IsBlankString(Value) Then
			Break;
		EndIf;
		DataRow = EventData.Add();
		DataRow.Name = Lower(Value);
		DataRow.Text = Value;
		DataRow.ToolTip = NStr("en = 'Event';ru = 'Событие'") + " " + DataRow.Name;
		RowNumber = RowNumber + 1;
	EndDo;
	// Attempting to find events that have presentations and details
	Data = DataProcessorObject.GetTemplate("Events");
	RowNumber = 1;
	While True Do
		Area = Data.Area(RowNumber, 1);
		Value = Lower(TrimAll(Area.Text));
		If IsBlankString(Value) Then
			Break;
		EndIf;
		Result = EventData.FindRows(New Structure("Name", Value));
		If Result.Count() = 0 Then
			// No event found
			RowNumber = RowNumber + 1;
			Continue;
		EndIf;
		Text = Data.Area(RowNumber, 2).Text;
		If Not IsBlankString(Text) Then
			Result[0].Text = TrimAll(Text);
		EndIf;
		Text = Data.Area(RowNumber, 3).Text;
		If Not IsBlankString(Text) Then
			Result[0].ToolTip = TrimAll(Text);
		EndIf;
		RowNumber = RowNumber + 1;
	EndDo;
EndProcedure
&AtServer
Procedure ImportColumnDetails()
	Var DataProcessorObject, Data, DataRow, ColumnNo, RowNumber, Value, Result, Text;
	DataProcessorObject = FormAttributeToValue("Object");
	// Importing events by parameter matrix
	Data = DataProcessorObject.GetTemplate("EventPropertyContent");
	// Adding the All special column
	DataRow = ColumnData.Add();
	DataRow.Name = "all";
	DataRow.Text = NStr("en = 'All properties'; ru = 'Все свойства'");
	DataRow.ToolTip = NStr("en = 'Select all properties of the event';ru = 'Указание всех свойств выбранного события'");
	ColumnNo = 1;
	While True Do
		Value = TrimAll(Data.Area(1, 1+ColumnNo).Text);
		If IsBlankString(Value) Then
			Break;
		EndIf;
		DataRow = ColumnData.Add();
		DataRow.Name = Lower(Value);
		DataRow.Text = StrReplace(Value, "_", ":");
		DataRow.ToolTip = NStr("en = 'Property';ru = 'Свойство'") + " " + DataRow.Text;
		ColumnNo = ColumnNo + 1;
	EndDo;
	// Attempting to find events that have presentations and details
	Data = DataProcessorObject.GetTemplate("Properties");
	RowNumber = 1;
	While True Do
		Value = Lower(TrimAll(Data.Area(RowNumber, 1).Text));
		If IsBlankString(Value) Then
			Break;
		EndIf;
		Result = ColumnData.FindRows(New Structure("Name", Value));
		If Result.Count() = 0 Then
			// No event found
			RowNumber = RowNumber + 1;
			Continue;
		EndIf;
		Text = Data.Area(RowNumber, 2).Text;
		If Not IsBlankString(Text) Then
			Result[0].Text = TrimAll(Text);
		EndIf;
		Text = Data.Area(RowNumber, 3).Text;
		If Not IsBlankString(Text) Then
			Result[0].ToolTip = TrimAll(Text);
		EndIf;
		RowNumber = RowNumber + 1;
	EndDo;
EndProcedure
&AtServer
Procedure SetColumnVisibility(VisibilityMode)
	Var VisibleColumn, UpperBound, LeftBound, Column, VisibleColumns;
	If VisibilityMode = 0 Then
		// Show all columns
		For Each Column In ColumnData Do
			If Column.Name = "all" Then
				Continue;
			EndIf;
			TLEditor.Area(, Column.ColumnNumber, , Column.ColumnNumber).Visible = True;
		EndDo;
	ElsIf VisibilityMode = 1 Then
		// Using the coordinates to set area once columns are hidden
		VisibleColumn = 3;
		// Show all selected columns
		UpperBound = Items.TLEditor.CurrentArea.Top;
		LeftBound = Items.TLEditor.CurrentArea.Left;
		For Each Column In ColumnData Do
			If Column.Name = "all" Then
				Continue;
			EndIf;
			Leave = False;
			For Each Event In EventData Do
				If TLEditor.Area(Event.LineNumber, Column.ColumnNumber).Text = "V" Then
					Leave = True;
					Break;
				EndIf;
			EndDo;
			If Column.ColumnNumber <= LeftBound Then
				VisibleColumn = ?(Leave, Column.ColumnNumber, VisibleColumn);
			EndIf;
			TLEditor.Area(, Column.ColumnNumber, , Column.ColumnNumber).Visible = Leave;
		EndDo;
		Items.TLEditor.CurrentArea = TLEditor.Area(UpperBound, VisibleColumn);
	ElsIf VisibilityMode = 2 Then
		// Showing all columns for the selected events and hiding the rest.
		// Collecting the columns to be visible.
		VisibleColumn = 1;
		VisibleColumns = New Array;
		For Each Event In EventData Do
			If TLEditor.Area(Event.LineNumber, 1).Text = "V" Then
				Columns = CollectEventColumns(Event.Name);
				For Each Column In Columns Do
					If VisibleColumns.Find(Column.Name) = Undefined Then
						VisibleColumns.Add(Column.Name);
					EndIf;
				EndDo;
			EndIf;
		EndDo;
		// Enabling visibility for the selected columns and disabling for the rest
		UpperBound = Items.TLEditor.CurrentArea.Top;
		LeftBound = Items.TLEditor.CurrentArea.Left;
		For Each Column In ColumnData Do
			If Column.Name = "all" Then
				Visible = True;
			Else
				Visible = ?(VisibleColumns.Find(Column.Name) = Undefined, False, True);
			EndIf;
			TLEditor.Area(, Column.ColumnNumber, , Column.ColumnNumber).Visible = Visible;
			If Column.ColumnNumber <= LeftBound Then
				VisibleColumn = ?(Visible, Column.ColumnNumber, VisibleColumn);
			EndIf;
		EndDo;
		Items.TLEditor.CurrentArea = TLEditor.Area(UpperBound, VisibleColumn);
	EndIf;
EndProcedure
&AtServer
Procedure SetRowVisibility(VisibilityMode)
	Var LeftBound, UpperBound, VisibleRow, Event;
	// Showing all events or hiding disabled events
	LeftBound = Items.TLEditor.CurrentArea.Left;
	UpperBound = Items.TLEditor.CurrentArea.Top;
	VisibleRow = 1;
	For Each Event In EventData Do
		If TLEditor.Area(Event.LineNumber, 1).Text <> "V" And SelectedColumns.FindRows(New Structure("Event", Event.Name)).Count() = 0 Then
			TLEditor.Area(Event.LineNumber, , Event.LineNumber, ).Visible = Not VisibilityMode;
		Else
			If Event.LineNumber <= UpperBound Then
				VisibleRow = Event.LineNumber;
			EndIf;
		EndIf;
	EndDo;
	Items.TLEditor.CurrentArea = TLEditor.Area(VisibleRow, LeftBound);
EndProcedure
&AtServer
Procedure ShowColumnRowHeaders(ViewMode)
	Var EventColumnWidth, Event, CellText, Property;
	EventColumnWidth = 0;
	// Showing row headers
	For Each Event In EventData Do
		If ViewMode = 1 Then
			// Showing details
			CellText = Event.Text;
		Else
			// Showing names
			CellText = StrReplace(Event.Name, "_", ":");
		EndIf;
		TLEditor.Area(Event.LineNumber, 2).Text = CellText;
		EventColumnWidth = Max(EventColumnWidth, min(StrLen(CellText), 30));
	EndDo;
	// Showing column headers
	For Each Property In ColumnData Do
		If ViewMode = 1 Then
			// Showing details
			CellText = Property.Text;
		Else
			// Showing names
			CellText = StrReplace(Property.Name, "_", ":");
		EndIf;
		// Dividing the text into several lines if it is long
		If StrLen(CellText) > 15 Then
			//CellText = Left(CellText, 15) + "...";
			TLEditor.Area(1, Property.ColumnNumber).TextPlacement = SpreadsheetDocumentTextPlacementType.Wrap;
		EndIf;
		TLEditor.Area(1, Property.ColumnNumber).Text = CellText;
	EndDo;
	// Changing width of the event name column
	TLEditor.Area(, 2, , 2).ColumnWidth = EventColumnWidth;
EndProcedure
&AtServer
Procedure EnableThinClientAddons()
	// Showing choice buttons
	Items.DumpLocation.ChoiceButton = True;
	Items.TLLocation.ChoiceButton = True;
	Items.SysTLLocation.ChoiceButton = True;
	// Showing additional commands of the thin client
	Items.RereadFile.Visible = True;
	Items.SaveTemplate.Visible = True;
	Items.SaveAs.Visible = True;
EndProcedure
&AtServer
Procedure DefaultParametersAtServer()
	// Clearing all settings
	FileLocation = "";
	// Memory dumps  (/dump)
	DumpMode = False;
	DumpLocation = "c:\v83\dumps";
	DumpScreenshot = False;
	DumpExternal = False;
	SetDumpType("1100000000");
	Items.DumpGroup.Enabled = DumpMode;
	// Memory control (/mem)
	MemoryMode = False;
	// Leaks (/leaks)
	LeaksMode = False;
	LeaksClient = False;
	LeaksServer = False;
	LeaksModules.Clear();
	LeaksProcedures.Clear();
	Items.LeaksGroup.Enabled = LeaksMode;
	// Full-text search index update (/ftextupd)
	FullTextSearchUpdate = False;
	// Technological log settings (/log)
	TLMode = False;
	TLHistory = 168;
	TLLocation = "c:\v83\logs";
	ClearTLParameters();
	DefaultTLParametersAtServer();
	Items.TLParameters.Enabled = TLMode;
	Items.TLEditor.Enabled = TLMode;
	Items.UnderEditor.Enabled = TLMode;
	// System log settings
	SysTLHistory = 24;
	TLLocation = ""; // Here must be a path to the profile directory but we cannot find it out

	// System event settings
	SystemEvents.Clear();
EndProcedure
&AtServer
Procedure DefaultTLParametersAtServer()
	Var Event, Column;
	Event = EventData.FindByID(GetEvenID("all"));
	Column = ColumnData.FindByID(GetColumnID("all"));
	SetCombination(Event.LineNumber, -1, 1);
	SetCombination(Event.LineNumber, Column.ColumnNumber, 1);
EndProcedure
&AtServer
Procedure ClearTLParameters()
	OnlySelectedColumns = 2;
	While SelectedColumns.Count() > 0 Do
		SetCombination(SelectedColumns[0].Event, ?(IsBlankString(SelectedColumns[0].Column), -1, SelectedColumns[0].Column), 0);
	EndDo;
EndProcedure
&AtServer
Function LoadSettingsFileAtServer(StorageAddress)
	Var Builder, Document, FileName, Data, SuccessfulImport, Reader;
	Var Log, Dump, Memory, QueryPlans, FTextUpdts, Leaks, TechLog, SysTechLog;
	Var FirstElement, FromFile, FromFile2,DumpType, DumpTypeString, Item;
	Var Points, DataRow, NodeList, Node1, Table, EventCondition, Condition;
	Var ColumnCondition, LeadColumnName, Column, Events, CurEvent, Checking, Value;
	DefaultParametersAtServer();
	ClearTLParameters();
	Items["EventsConditionEditor"].Enabled = True;
	Items["ClearRowFilter"].Enabled = True;
	Items["ColumnConditionEditor"].Enabled = True;
	Items["ClearColumnFilter"].Enabled = True;
	// Saving the temporary configuration file
	FileName = GetTempFileName(".xml");
	Data = GetFromTempStorage(StorageAddress);
	Data.Write(FileName);
	DeleteFromTempStorage(StorageAddress);
	// Flag that shows whether import has been completed
	SuccessfulImport = True;
	// Reading the file
	Reader = New XMLReader();
	Reader.OpenFile(FileName);
	Builder = New DOMBuilder();
	Try
		Document = Builder.Read(Reader);
	Except
		Message(ErrorDescription());
		Return False;
	EndTry;
#Region _CONFIG // <config> element
	Log = Document.GetElementByTagName("config");
	If Log.Count() = 0 Then
		// Supposing if the file contains no <config> element, it is not a log settings file.
		Message(NStr("en = 'The loaded file contains no <config> element. This file is not a technological log settings file.';ru = 'В загружаемом файле отсутствует элемент <config>. Данный файл не является файлом настройки технологического журнала.'"));
		Return False;
	EndIf;
#EndRegion
#Region _DUMP // Dump settings (/dump)
	DumpMode = False;
	DumpLocation = "";
	DumpScreenshot = False;
	DumpExternal = False;
	SetDumpType("1100000000");
	Dump = Document.GetElementByTagName("dump");
	If Dump.Count() > 0 Then
		FirstElement = Dump.Item(0);
		If FirstElement <> Undefined Then
			FromFile = FirstElement.GetAttribute("create");
			DumpMode = ?(FromFile = Undefined, True, XMLValue(Type("Boolean"), FromFile));
			If DumpMode Then
				DumpType = XMLValue(Type("Number"), FirstElement.GetAttribute("type"));
				If DumpType <> Undefined Then
					DumpTypeString = "";
					While DumpType >= 1 Do
						Balance = DumpType % 2;
						DumpType = Int(DumpType/2);
						DumpTypeString = DumpTypeString + String(Balance);
					EndDo;
					DumpTypeString = Left(DumpTypeString+"0000000000", 10);
				Else
					DumpTypeString = "1100000000";
				EndIf;
				SetDumpType(DumpTypeString);
				DumpLocation = FirstElement.GetAttribute("location");
				FromFile = FirstElement.GetAttribute("prntscrn");
				DumpScreenshot = ?(FromFile = Undefined, False, XMLValue(Type("Boolean"), FromFile));
				FromFile = FirstElement.GetAttribute("externaldump");
				DumpExternal = ?(FromFile = Undefined, False, XMLValue(Type("Boolean"), FromFile));
			EndIf;
		EndIf;
	EndIf;
	Items.DumpGroup.Enabled = DumpMode;
#EndRegion
#Region _MEM // Memory leaks on server (/mem)
	Memory = Document.GetElementByTagName("mem");
	If Memory.Count() > 0 Then
		MemoryMode = True;
	Else
		MemoryMode = False;
	EndIf;
#EndRegion
#Region _PLANSQL // Query plan tracking (/planSQL)
	QueryPlans = Document.GetElementByTagName("plansql");
	If QueryPlans.Count() > 0 Then
		QueryPlanMode = True;
	Else
		QueryPlanMode = False;
	EndIf;
#EndRegion
#Region _FTEXTUPD // Full-text search index file update (/ftextupd)
	FTextUpdts = Document.GetElementByTagName("ftextupd");
	If FTextUpdts.Count() > 0 Then
		Element = FTextUpdts.Item(0);
		If Element <> Undefined Then
			Value = Element.GetAttribute("logfiles");
			FullTextSearchUpdate = ?(Value = Undefined, False, XMLValue(Type("Boolean"), Value));
		EndIf;
	Else
		FullTextSearchUpdate = False;
	EndIf;
#EndRegion
#Region _INPUTBYSTRING // логгирование операций ввода по строке (/inputByString)
	InputByString = Document.GetElementByTagName("inputByString");
	If InputByString.Count() > 0 Then
		Element = InputByString.Item(0);
		If Element <> Undefined Then
			Value = Element.GetAttribute("log");
			InputByStringMode = ?(Value = Undefined, False, XMLValue(Type("Boolean"), Value));
		EndIf;
	Else
		InputByStringMode = False;
	EndIf;
#EndRegion
#Region _LEAKS // Leaks (/leaks)
	LeaksMode = False;
	LeaksClient = False;
	LeaksServer = False;
	LeaksModules.Clear();
	LeaksProcedures.Clear();
	Leaks = Document.GetElementByTagName("leaks");
	If Leaks.Count() > 0 Then
		Element = Leaks.Item(0);
		If Element <> Undefined Then
			FromFile = Element.GetAttribute("collect");
			LeaksMode = ?(FromFile = Undefined, False, XMLValue(Type("Boolean"), FromFile));
			Points = Element.GetElementByTagName("point");
			For Each Point In Points Do
				FromFile = Point.GetAttribute("call");
				If FromFile <> Undefined Then
					If Lower(FromFile) = "server" Then
						LeaksServer = True;
					ElsIf Lower(FromFile) = "client" Then
						LeaksClient = True;
					EndIf;
					Continue;
				EndIf;
				FromFile = Point.GetAttribute("proc");
				If FromFile <> Undefined Then
					DataRow = LeaksModules.Add();
					DataRow.Module = FromFile;
					Continue;
				EndIf;
				FromFile = Point.GetAttribute("on");
				FromFile2 = Point.GetAttribute("off");
				If FromFile <> Undefined And FromFile2 <> Undefined Then
					DataRow = LeaksProcedures.Add();
					DataRow.Row1 = FromFile;
					DataRow.Row2 = FromFile2;
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	Items.LeaksGroup.Enabled = LeaksMode;
#EndRegion
#Region _LOG // Log settings (/log)
	TechLog = Document.GetElementByTagName("log");
	If TechLog.Count() > 0 Then
		// Reading only the first log of the existing ones.
		// Data of the first log is enough for 99,99% of users.
		FirstElement = TechLog.Item(0);
		If FirstElement <> Undefined Then
			TLMode = True;
			FromFile = FirstElement.GetAttribute("location");
			TLLocation = ?(FromFile = Undefined, "c:\v82\logs", FromFile);
			FromFile = FirstElement.GetAttribute("history");
			TLHistory = ?(FromFile = Undefined, 168, XMLValue(Type("Number"), FromFile));
			// Reading all <event> elements
			NodeList = FirstElement.GetElementByTagName("event");
			For Each Node1 In NodeList Do
				If Node1.ParentNode <> FirstElement Then
					// Reading only the first level of subordinated nodes
					Continue;
				EndIf;
				// Importing the current <event> node to the value table
				Table = ImportEventFromXMLFile(Node1);
				If Table = Undefined Then
					SuccessfulImport = False;
					Continue;
				EndIf;
				// If the node of the special type <ne property="name" value=""> exists, handling
				// this node in a special way and analyzing no conditions, as they become
				// meaningless.
				Result = Table.FindRows(New Structure("Type, Property, Value", "<>", "name", ""));
				If Result.Count() > 0 Then
					SetCombination("all", -1, 1);
					Continue;
				EndIf;
				// If conditions without the <property="name" value="property_name"> structure
				// exist, handling conditions of all events (bold mark of the "all events" row)
				Result = Table.FindRows(New Structure("Property", "name"));
				If Result.Count() = 0 Then
					For Each Condition In Table Do
						EventCondition = EventsConditions.Add();
						EventCondition.Event = "all";
						EventCondition.Column = Condition.Property;
						EventCondition.Condition = Condition.Type;
						EventCondition.Value = Condition.Value;
					EndDo;
					SetCombination("all", -1, 2);
					Continue;
				EndIf;
				// If more than one <name> property exists, the node is invalid
				If Result.Count() > 1 Then
					SuccessfulImport = False;
					Message(NStr("en = 'The <event> element contains more than one element of the <property=""name"" Value=""PropertyName""> type';ru = 'В элементе <event> обнаружено более одного элемента вида property=""name"" value=""ИмяСвойства""'"));
					Continue;
				Else
					EventName = Result[0].Value;
					// Checking by name whether the event is supported
					If GetEvenID(Lower(EventName)) = Undefined Then
						SuccessfulImport = False;
						Message(FormatMessage(NStr("en = 'The editor does not support the following event: %1%';ru = 'Событие не поддерживается редактором: %1%'"), EventName));
						Continue;
					EndIf;
					// Checking whether the specified construction is one of the
					// <eq property=""name"" Value="Event_name"> type. Other types are not supported.
					If Result[0].Type <> "=" Then
						SuccessfulImport = False;
						Message(FormatMessage(NStr("en = 'Constructions that are distinct from the <eq property=""name"" Value=""%1%""> are not supported';ru = 'Не поддерживается конструкция, отличная от <eq property=""name"" value=""%1%"">'"), EventName));
						Continue;
					EndIf;
					For Each Condition In Table Do
						If Condition.Property = "name" Then
							// Setting the column values is not required because the values will be set
							// in the SetCombination() method.
							Continue;
						EndIf;
						ColumnCondition = EventsConditions.Add();
						ColumnCondition.Event = EventName;
						ColumnCondition.Column = Condition.Property;
						ColumnCondition.Condition = Condition.Type;
						ColumnCondition.Value = Condition.Value;
					EndDo;
					SetCombination(EventName, -1, ?(Table.Count() = 1, 1, 2));
				EndIf;
			EndDo;
			// Reading all <property> elements
			NodeList = FirstElement.GetElementByTagName("property");
			For Each Node1 In NodeList Do
				// Columns with their conditions
				LeadColumnName = Lower(Node1.GetAttribute("name"));
				Column = GetColumnID(LeadColumnName);
				If Column = Undefined Then
					SuccessfulImport = False;
					Message(FormatMessage(NStr("en = 'The editor does not support the following property: %1%';ru = 'Свойство не поддерживается редактором: %1%'"), LeadColumnName));
					Continue;
				EndIf;
				Events = Node1.GetElementByTagName("event");
				If Events.Count() = 0 Then
					// Representation of the column of the "all" event
					SetCombination("all", LeadColumnName, 1);
				Else
					For Each CurEvent In Events Do
						Table = ImportEventFromXMLFile(CurEvent);
						If Table = Undefined Then
							SuccessfulImport = False;
							Continue;
						EndIf;
						// If no <name> property is found, the table contents conditions of the "all" event
						Result = Table.FindRows(New Structure("Property", "name"));
						If Result.Count() = 0 Then
							For Each Condition In Table Do
								ColumnCondition = ColumnConditions.Add();
								ColumnCondition.LeadColumn = LeadColumnName;
								ColumnCondition.Event = "all";
								ColumnCondition.Column = Condition.Property;
								ColumnCondition.Condition = Condition.Type;
								ColumnCondition.Value = Condition.Value;
							EndDo;
							SetCombination("all", LeadColumnName, 3);
							Continue;
						EndIf;
						// If more than one <name> property exists, the node is invalid
						If Result.Count() > 1 Then
							SuccessfulImport = False;
							Message(FormatMessage(NStr("en = 'The <event> element contains more than one element of the <property=""name"" Value=""PropertyName""> type';ru = 'В элементе <event> элемента <property name=""%1%""> обнаружено более одного элемента вида property=""name"" value=""ИмяСвойства""';sys= ''"), "en", LeadColumnName));
							Continue;
						Else
							EventName = Result[0].Value;
							// Checking whether the editor supports the event
							Checking = EventData.FindRows(New Structure("Name", Result[0].Value));
							If Checking.Count() = 0 Then
								SuccessfulImport = False;
								Message(FormatMessage(NStr("en = 'The editor does not support the following property: %1%';ru = 'Свойство не поддерживается редактором: %1%'"), Result[0].Value));
								Continue;
							EndIf;
							// Checking whether the found construction is equal to <eq property="name" value="EventName"/>
							If Result[0].Type <> "=" And Not IsBlankString(Result[0].Value) Then
								SuccessfulImport = False;
								Message(FormatMessage(NStr("en = 'The found construction is distinct from <eq property=""name"" Value=""%1%""> and not supported';ru = 'Не поддерживается конструкция, отличная от <eq property=""name"" value=""%1%"">';"), EventName));
								Continue;
							EndIf;
							For Each Condition In Table Do
								If Condition.Property = "name" And Condition.Type = "<>" Then
									ColumnCondition = SelectedColumns.Add();
									ColumnCondition.Event = "all";
									ColumnCondition.Column = LeadColumnName;
									ColumnCondition.State = 1;
								ElsIf Condition.Property = "name" Then
									Continue;
								Else
									ColumnCondition = ColumnConditions.Add();
									ColumnCondition.LeadColumn = LeadColumnName;
									ColumnCondition.Event = EventName;
									ColumnCondition.Column = Condition.Property;
									ColumnCondition.Condition = Condition.Type;
									ColumnCondition.Value = Condition.Value;
								EndIf;
							EndDo;
							SetCombination(?(IsBlankString(EventName), "all", EventName), LeadColumnName, ?(Table.Count() = 1, 1, 3));
						EndIf;
					EndDo;
				EndIf;
			EndDo;
		EndIf;
	Else
		TLMode = False;
		TLHistory = 168;
		TLLocation = "";
	EndIf;
#EndRegion
#Region _DEFAULTLOG // System log settings (/defaultlog)
	SysTechLog = Document.GetElementByTagName("defaultlog");
	If SysTechLog.Count() > 0 Then
		FromFile = SysTechLog[0].GetAttribute("location");
		SysTLLocation = ?(FromFile = Undefined, "", FromFile);
		FromFile = SysTechLog[0].GetAttribute("history");
		SysTLHistory = ?(FromFile = Undefined, 24, XMLValue(Type("Number"), FromFile));
	Else
		SysTLHistory = 24;
		SysTLLocation = "";
	EndIf;
#EndRegion
#Region _SYSTEM // System event settings (/system)
	SysEvents = Document.GetElementByTagName("system");
	If SysEvents.Count() > 0 Then
		SystemLevels = ImportCustomType("ll");
		For Each SysEvent In SysEvents Do
			Level = SysEvent.GetAttribute("level");
			If IsBlankString(Level) Then
				Message(NStr("en = 'The value of the ""level"" attribute in the <system> element is not specified. The element is ignored.';ru = 'В элементе <system> не указано значение атрибута ""level"". Элемент игнорируется.'"));
				Continue;
			EndIf;
			If SystemLevels.FindByValue(Level) = Undefined Then
				Message(FormatMessage(NStr("en = 'Unknown value of the attribute in the <system> element. level = ""%1%"". The element is ignored.';ru = 'В элементе <system> указано неизвестно значение атрибута. level = ""%1%"". Элемент игнорируется.'"), Level));
				Continue;
			EndIf;
			Event = SystemEvents.Add();
			Event.Level = Level;
			Event.Component = SysEvent.GetAttribute("component");
			Event.Class = SysEvent.GetAttribute("class");
		EndDo;
	EndIf;
#EndRegion
	Items.TLParameters.Enabled = TLMode;
	Items.TLEditor.Enabled = TLMode;
	Items.UnderEditor.Enabled = TLMode;
	Reader.Close();
	// Deleting the temporary file
	DeleteFiles(FileName);
	Return SuccessfulImport;
EndFunction
&AtServer
Function GenerateSettingsFileAtServer()
	Var Document, ConditionConversion;
	Var Events, Event, CurEvent, Conditions, Condition, All, Column, WithoutConditions, WithConditions, Property;
	Var Setting, AllNode, Results, Element, SysEvent, Writer, Write, Address;
	Document = New DOMDocument("http://v8.1c.ru/v8/tech-log", "config");
#Region _DUMP // Dump characteristics (dump)
	If DumpMode Then
		Element = AddNodeToCollection(Document, Document.FirstChild, "dump");
		Element.SetAttribute("create", XMLString(True));
		Element.SetAttribute("location", XMLString(DumpLocation));
		Element.SetAttribute("type", XMLString(GetDumpType()));
		Element.SetAttribute("prntscrn", XMLString(DumpScreenshot));
		Element.SetAttribute("externaldump", XMLString(DumpExternal));
	Else
		AddNodeWithAttributes(Document, Document.FirstChild, "dump", New Structure("create", False));
	EndIf;
#EndRegion
#Region _MEM // Memory tracking characteristics (mem)
	If MemoryMode Then
		AddNodeToCollection(Document, Document.FirstChild, "mem");
	EndIf;
#EndRegion
#Region _PLANSQL // Query plan tracking characteristics (plansql)
	If QueryPlanMode Then
		AddNodeToCollection(Document, Document.FirstChild, "plansql");
	EndIf;
#EndRegion
#Region _FTEXTUPD // Full-text search index file update (/ftextupd)
	If FullTextSearchUpdate Then
		AddNodeWithAttributes(Document, Document.FirstChild, "ftextupd", New Structure("logfiles", True));
	EndIf;
#EndRegion
#Region _INPUTBYSTRING // логгирование операций ввода по строке (/inputByString)
	If InputByStringMode Then
		AddNodeWithAttributes(Document, Document.FirstChild, "inputbystring", New Structure("log", True));
	EndIf;
#EndRegion
#Region _LEAKS // Memory leak characteristics (leaks)
	If LeaksMode Then
		Leaks = AddNodeWithAttributes(Document, Document.FirstChild, "leaks", New Structure("collect", True));
		If LeaksClient Then
			AddNodeWithAttributes(Document, Leaks, "point", New Structure("call", "client"));
		EndIf;
		If LeaksServer Then
			AddNodeWithAttributes(Document, Leaks, "point", New Structure("call", "server"));
		EndIf;
		For Each Leak In LeaksModules Do
			AddNodeWithAttributes(Document, Leaks, "point", New Structure("proc", Leak.Module));
		EndDo;
		For Each Leak In LeaksProcedures Do
			AddNodeWithAttributes(Document, Leaks, "point", New Structure("on, off", Leak.Row1, Leak.Row2));
		EndDo;
	EndIf;
#EndRegion
#Region _LOG // Technological log characteristics (log)
	If TLMode Then
		ConditionConversion = New Map;
		ConditionConversion.Insert("=", "eq");
		ConditionConversion.Insert("<>", "ne");
		ConditionConversion.Insert(">", "gt");
		ConditionConversion.Insert(">=", "ge");
		ConditionConversion.Insert("<", "lt");
		ConditionConversion.Insert("<=", "le");
		ConditionConversion.Insert("like", "like");
		TL = AddNodeWithAttributes(Document, Document.FirstChild, "log", New Structure("location,history", TLLocation, TLHistory));
#Region STEP1 // 1. Adding selected events
		SelectedColumns.Sort("Event Asc");
		Events = SelectedColumns.FindRows(New Structure("Column", ""));
		For Each Event In Events Do
			CurEvent = AddNodeToCollection(Document, TL, "event");
			Conditions = EventsConditions.FindRows(New Structure("Event", Event.Event));
			If Event.Event = "all" Then
				// "All events" means "ne" condition (but not "eq"), the value is an empty string.
				// If conditions exist, the event itself must be added.
				If Conditions.Count() = 0 Then
					AddNodeWithAttributes(Document, CurEvent, "ne", New Structure("property,value","name",""));
				EndIf;
			Else
				// Ordinary event
				AddNodeWithAttributes(Document, CurEvent, "eq", New Structure("property,value","name",Event.Event));
			EndIf;
			// Adding event conditions
			For Each Condition In Conditions Do
				AddNodeWithAttributes(Document, CurEvent, ConditionConversion[Condition.Condition],
						New Structure("property,value", StrReplace(Condition.Column, "_", ":"), Condition.Value));
			EndDo;
		EndDo;
#EndRegion
#Region STEP2 // 2. Creating the <property name="all"/> item
		All = SelectedColumns.FindRows(New Structure("Column,Event", "all", "all"));
		If All.Count() = 1 Then
			AddNodeWithAttributes(Document, TL, "property", New Structure("name", "all"));
		EndIf;
#EndRegion
#Region STEP3 // 3. Adding the selected columns. The "All events" row must be handled in a special way.
		SelectedColumns.Sort("Column Asc");
		For Each Column In ColumnData Do
			If Column.Name = "all" Then
				// "all" is a special column, it will be handled last
				Continue;
			EndIf;
			// Attempting to find the current column
			WithoutConditions = SelectedColumns.FindRows(New Structure("Column,State", Column.Name, 1));
			WithConditions = SelectedColumns.FindRows(New Structure("Column,State", Column.Name, 3));
			Property = Undefined;
			// 3.1. Writing all columns without conditions
			If WithoutConditions.Count() > 0 Then
				// <property name="Property">
				Property = AddNodeWithAttributes(Document, TL, "property", New Structure("name", StrReplace(Column.Name, "_", ":")));
				For Each Setting In WithoutConditions Do
					If Setting.Event = "all" And WithoutConditions.Count() = 1 Then
						// Only one check mark is set, the one in the "all" row
						Continue;
					ElsIf Setting.Event = "all" And (WithoutConditions.Count() > 1 Or WithConditions.Count() <> 0) Then
						// Check marks in the "all" row and in some other rows of the current columns are set
						// <event>
						//  <ne property="name" value=""/>
						// </event>
						CurEvent = AddNodeToCollection(Document, Property, "event");
						AddNodeWithAttributes(Document, CurEvent, "ne", New Structure("property,value", "name", ""));
					Else
						// Check marks in any rows but "all" are set
						// <event>
						//  <eq property="name" value="Event"/>
						// </event>
						CurEvent = AddNodeToCollection(Document, Property, "event");
						AddNodeWithAttributes(Document, CurEvent, "eq", New Structure("property,value", "name", Setting.Event));
					EndIf;
				EndDo;
			EndIf;
			// 3.2. Writing all columns with conditions
			If WithConditions.Count() > 0 Then
				If Property = Undefined Then
					// The item with property was already set while specifying the properties
					// without conditions
					//  <property name="Property"
					Property = AddNodeWithAttributes(Document, TL, "property", New Structure("name", StrReplace(Column.Name, "_", ":")));
				EndIf;
				For Each Setting In WithConditions Do
					Conditions = ColumnConditions.FindRows(New Structure("LeadColumn, Event", Setting.Column, Setting.Event));
					// <event>
					CurEvent = AddNodeToCollection(Document, Property, "event");
					If Setting.Event = "all" And Setting.State = 1 Then
						// Just a set check mark.
						// <ne property="name" value=""/>
						AddNodeWithAttributes(Document, CurEvent, "ne", New Structure("property,value", "name", ""));
					ElsIf Setting.Event = "all" And Setting.State = 3 Then
						// Column of the "all" event with a condition.
						// Conditions must be written without the "all" property name,
						// no action is required.
					Else
						// Inserting the name of the events, for which the following conditions are intended.
						// <eq property="name" value="EventName"/>
						AddNodeWithAttributes(Document, CurEvent, "eq", New Structure("property,value", "name", Setting.Event));
					EndIf;
					For Each Condition In Conditions Do
						// <Condition: property="Property value="Value"/>
						AddNodeWithAttributes(Document, CurEvent, ConditionConversion[Condition.Condition],
								New Structure("property,value", StrReplace(Condition.Column, "_", ":"), Condition.Value));
					EndDo;
				EndDo;
			EndIf;
		EndDo;
#EndRegion
#Region STEP4 // 4. Handling the "all" column
		AllNode = Undefined;
		Results = SelectedColumns.FindRows(New Structure("Column", "all"));
		For Each Condition In Results Do
			If Condition.Column = "all" And Condition.Event = "all" And Condition.State = 1 Then
				Continue;
			EndIf;
			If AllNode = Undefined Then
				// <property name="all"/>
				AllNode = AddNodeWithAttributes(Document, TL, "property", New Structure("name", "all"));
			EndIf;
			Conditions = ColumnConditions.FindRows(New Structure("LeadColumn, Event", "all", Condition.Event));
			// <event>
			//  <eq property="name" value="Event"/>
			// </event>
			CurEvent = AddNodeToCollection(Document, AllNode, "event");
			If Condition.Event <> "all" Then
				AddNodeWithAttributes(Document, CurEvent, "eq", New Structure("property,value", "name", Condition.Event));
			EndIf;
			For Each Condition In Conditions Do
				// <Condition property="Property value="Value"/>
				AddNodeWithAttributes(Document, CurEvent, ConditionConversion[Condition.Condition],
						New Structure("property, value", StrReplace(Condition.Column, "_", ":"), Condition.Value));
			EndDo;
		EndDo;
#EndRegion
	EndIf;
#EndRegion
#Region _SYSTEM // System log characteristics
	If Not (IsBlankString(SysTLLocation) And SysTLHistory = 24) Then
		Element = AddNodeToCollection(Document, Document.FirstChild, "defaultlog");
		If Not IsBlankString(SysTLLocation) Then
			Element.SetAttribute("location", XMLString(SysTLLocation));
		EndIf;
		If SysTLHistory <> 24 Then
			Element.SetAttribute("history", XMLString(SysTLHistory));
		EndIf;
	EndIf;
#EndRegion
#Region _DEFAULTLOG // System event characteristics
	If SystemEvents.Count() Then
		For Each SysEvent In SystemEvents Do
			If IsBlankString(SysEvent.Level) Then
				// Skipping the row with empty event level. Rows with empty event level point out an error in the algorithm.
				Continue;
			EndIf;
			Element = AddNodeToCollection(Document, Document.FirstChild, "system");
			Element.SetAttribute("level", XMLString(SysEvent.Level));
			If Not IsBlankString(SysEvent.Component) Then
				Element.SetAttribute("component", XMLString(SysEvent.Component));
			EndIf;
			If Not IsBlankString(SysEvent.Class) Then
				Element.SetAttribute("class", XMLString(SysEvent.Class));
			EndIf;
		EndDo;
	EndIf;
#EndRegion
	// Retrieving the generated document to the client through a text string in a temporary storage
	Writer = New XMLWriter();
	Writer.SetString(New XMLWriterSettings("UTF-8", , True, False, " "));
	Write = New DOMWriter();
	Write.Write(Document, Writer);
	Address = PutToTempStorage(Writer.Close());
	Return Address;
EndFunction
// The template characteristic is a temporary storage address (if a template from file is
// used) or a data processor template name (if a built-in template is used).
&AtServer
Function LoadTemplateAtServer(TemplateCharacteristic)
	Var Keys, ActionsArray, Document, DataProcessorObject, Cnt, FileString, TempFile, Address;
	Keys = New Structure;
	Keys.Insert("Actions", "actions:");
	Keys.Insert("Template", "template:");
	ActionsArray = New Array;
	// TemplateCharacteristic is a template or file
	If IsTempStorageURL(TemplateCharacteristic) Then
		// Is a file
		Document = New TextDocument;
		Document.SetText(GetFromTempStorage(TemplateCharacteristic));
	Else
		// Is a template
		DataProcessorObject = FormAttributeToValue("Object");
		Document = DataProcessorObject.GetTemplate(TemplateCharacteristic);
	EndIf;
	// The first 4 lines do not content useful for us data. Deleting them.
	For Cnt=1 to 4 Do
		Document.DeleteLine(1);
	EndDo;
	FileString = TrimAll(Document.GetLine(1));
	If Lower(FileString) = Keys.Actions Then
		Document.DeleteLine(1);
		// Two actions maximum
		FileString = TrimAll(Document.GetLine(1));
		If Lower(FileString) <> Keys.Template Then
			ActionsArray.Add(FileString);
			Document.DeleteLine(1);
			FileString = TrimAll(Document.GetLine(1));
		EndIf;
		If Lower(FileString) <> Keys.Template Then
			ActionsArray.Add(FileString);
			Document.DeleteLine(1);
			FileString = TrimAll(Document.GetLine(1));
		EndIf;
	EndIf;
	If Lower(FileString) = Keys.Template Then
		Document.DeleteLine(1);
		TempFile = GetTempFileName("xml");
		Document.Write(TempFile);
		Address = PutToTempStorage(New BinaryData(TempFile));
		LoadSettingsFileAtServer(Address);
	EndIf;
	Return ActionsArray;
EndFunction
&AtServer
Function CollectEventColumns(EventName)
	Var Result;
	Result = EventData.FindRows(New Structure("Name", Lower(EventName)));
	Return Result[0].Content;
EndFunction
&AtServer
Function CollectVLEventColumns(EventName)
	Var Result, List;
	Result = EventData.FindRows(New Structure("Name", Lower(EventName)));
	List = New ValueList;
	For Each Item In Result[0].Content Do
		List.Add(Item.Name, Item.Text);
	EndDo;
	Return List;
EndFunction
&AtServer
Function CollectColumnEvents(ColumnName)
	Var Result;
	Result = ColumnData.FindRows(New Structure("Name", Lower(ColumnName)));
	Return Result[0].Content;
EndFunction

&AtServer
Procedure SetDumpType(DumpFlags = "1100000000")
	Var FlagLength, Cnt, Flag;
	FlagLength = StrLen(DumpFlags);
	For Cnt=1 to 10 Do
		If Cnt > FlagLength Then
			Flag = False;
		Else
			Flag = Boolean(Number(Mid(DumpFlags, Cnt, 1)));
		EndIf;
		DumpType[Cnt-1].Check = Flag;
	EndDo;
EndProcedure
&AtServer
Function GetDumpType()
	Var TypeNumber, Cnt;
	TypeNumber = 0;
	For Cnt=1 to 10 Do
		If DumpType[Cnt-1].Check Then
			TypeNumber = TypeNumber + DumpType[Cnt-1].Value;
		EndIf;
	EndDo;
	Return TypeNumber;
EndFunction
&AtServer
Function GetColumnID(Column)
	Var ParametersType, Result;
	ParameterType = TypeOf(Column);
	If ParameterType = Type("String") Then
		Result = ColumnData.FindRows(New Structure("Name", Column));
	ElsIf ParameterType = Type("Number") Then
		If Column <= 0 Then
			Return Undefined;
		EndIf;
		Result = ColumnData.FindRows(New Structure("ColumnNumber", Column));
	Else
		Return Undefined;
	EndIf;
	If Result = Undefined Or Result.Count() = 0 Then
		Return Undefined; // no data by the column
	Else
		Return Result[0].GetID();
	EndIf;
EndFunction
&AtServer
Function GetEvenID(String)
	Var ParametersType, Result;
	ParameterType = TypeOf(String);
	If ParameterType = Type("String") Then
		Result = EventData.FindRows(New Structure("Name", String));
	ElsIf ParameterType = Type("Number") Then
		If String <= 0 Then
			Return Undefined;
		EndIf;
		Result = EventData.FindRows(New Structure("LineNumber", String));
	Else
		Return Undefined;
	EndIf;
	If Result = Undefined Or Result.Count() = 0 Then
		Return Undefined; // no data by the column
	Else
		Return Result[0].GetID();
	EndIf;
EndFunction
&AtServer
Procedure DeleteCombination(EventName, ColumnName)
	Var Result;
	Result = SelectedColumns.FindRows(New Structure("Event, Column", EventName, ColumnName));
	For Each Combination In Result Do
		SelectedColumns.Delete(Combination);
	EndDo;
EndProcedure
// LineNumber = 0 means the action is enabled for all events of the selected column.
// ColumnNumber = 0 means the action is enabled for all columns of the selected event.
// ColumnNumber = -1 means the value of the first event column is processed.
// The following values can be passed to State:
// 0 - disable;
// 1 - pair without conditions (V)
// 2 - pair with conditions (conditions are in event conditions) (bold V)
// 3 - pair with conditions (conditions are in column conditions) (bold V)
&AtServer
Procedure SetCombination(Val LineNumber, Val ColumnNumber, State)
	Var PlainFont, BoldFont, RowID, Events, Event, ColumnID, Column;
	Var Area, Conditions, Condition, List, Combination;
	PlainFont = New Font( , , False);
	BoldFont = New Font( , , True);
	RowID = GetEvenID(LineNumber);
	If RowID <> Undefined Then
		Event = EventData.FindByID(RowID);
		LineNumber = Event.LineNumber;
	EndIf;
	ColumnID = GetColumnID(ColumnNumber);
	If ColumnID <> Undefined Then
		Column = ColumnData.FindByID(ColumnID);
		ColumnNumber = Column.ColumnNumber;
	EndIf;
	// Event-column pair
	If LineNumber > 0 And ColumnNumber > 0 Then
		DeleteCombination(Event.Name, Column.Name);
		Area = TLEditor.Area(Event.LineNumber, Column.ColumnNumber);
		If State = 0 Then
			Area.Text = "";
			Area.Font = PlainFont;
			Conditions = ColumnConditions.FindRows(New Structure("Event, LeadColumn", Event.Name, Column.Name));
			For Each Condition In Conditions Do
				ColumnConditions.Delete(Condition);
			EndDo;
		ElsIf State = 1 Then
			Area.Text = "V";
		ElsIf State = 2 Or State = 3 Then
			Area.Text = "V";
			Area.Font = BoldFont;
		EndIf;
		// Setting or clearing marks of the "all" column cells
		If Column.Name = "all" Then
			List = CollectEventColumns(Event.Name);
			For Each Item In List Do
				CurColumn = ColumnData.FindByID(Item.ID);
				Area = TLEditor.Area(Event.LineNumber, CurColumn.ColumnNumber);
				If State = 0 Then
					Area.BackColor = ColorsInUse.ChoiceBackground;
				Else
					Area.BackColor = ColorsInUse.AllPropertiesBackground;
				EndIf;
			EndDo;
		EndIf;
		If State <> 0 Then
			Combination = SelectedColumns.Add();
			Combination.Event = Event.Name;
			Combination.Column = Column.Name;
			Combination.State = State;
		EndIf;
		Return;
	EndIf;
	// The first event column (that determines the event visibility)
	If LineNumber > 0 And ColumnNumber = -1 Then
		DeleteCombination(Event.Name, "");
		Area = TLEditor.Area(Event.LineNumber, 1);
		If State = 0 Then
			Area.Text = "";
			Area.Font = PlainFont;
			// Deleting all conditions for the selected event
			Conditions = EventsConditions.FindRows(New Structure("Event", Event.Name));
			For Each Condition In Conditions Do
				EventsConditions.Delete(Condition);
			EndDo;
		ElsIf State = 1 Then
			Area.Text = "V";
		ElsIf State = 2 Then
			Area.Text = "V";
			Area.Font = BoldFont;
		ElsIf State = 3 Then
			Raise FormatMessage(NStr("en = 'Wrong method call parameter: %1%';ru = 'Неверный параметр вызова метода: %1%'"), State);
		EndIf;
		If State <> 0 Then
			Combination = SelectedColumns.Add();
			Combination.Event = Event.Name;
			Combination.Column = "";
			Combination.State = State;
		EndIf;
		Return;
	EndIf;
	// All columns of the event. Only column disabling are handled here (once the "all"
	// column is enabled).
	If LineNumber > 0 And ColumnNumber = 0 Then
		// Handling all event columns
		If State = 0 Then
			List = FormAttributeToValue("EventData");
			Result = List.FindRows(New Structure("Name", Event.Name));
			For Each ContentItem In Result[0].Content Do
				Column = ColumnData.FindByID(ContentItem.ID);
				SetCombination(LineNumber, Column.ColumnNumber, 0);
			EndDo;
		Else
			Raise FormatMessage(NStr("en = 'Wrong method call parameter: %1%';ru = 'Неверный параметр вызова метода: %1%'"), State);
		EndIf;
		Return;
	EndIf;
	If LineNumber > 0 And ColumnNumber = -2 Then
		// The "all" column, which corresponds to the <property="all"/> property.
		Raise NStr("en = 'Mode error: LineNumber > 0 And ColumnNumber = -2';ru = 'Ошибка режима: НомерСтроки > 0 И НомерКолонки = -2'");
		Return;
	EndIf;
	// All events of the columns
	If LineNumber = 0 And ColumnNumber > 0 Then
		Events = CollectColumnEvents(Column.Name);
		For Each Event In Events Do
			SetCombination(EventData.FindByID(Event.ID).LineNumber, Column.ColumnNumber, State);
		EndDo;
		Return;
	EndIf;
	// All events are handled in the other handler
	If LineNumber = -1 And ColumnNumber = -1 Then
		Raise NStr("en = 'Mode error: LineNumber = -1 And ColumnNumber = -1';ru = 'Ошибка режима: НомерСтроки = -1 И НомерКолонки = -1'");
		Return;
	EndIf;
EndProcedure
&AtClientAtServerNoContext
Function AddNodeToCollection(Document, Collection, NodeName)
	Var Node;
	Node = Document.CreateElement(NodeName);
	Collection.AppendChild(Node);
	Return Node;
EndFunction
&AtServerNoContext
Function AddNodeWithAttributes(Document, Parent, NodeName, AttributeStructure = Undefined)
	Var Node, Attribute;
	Node = AddNodeToCollection(Document, Parent, NodeName);
	If AttributeStructure <> Undefined Then
		For Each Attribute In AttributeStructure Do
			Node.SetAttribute(Attribute.Key, XMLString(Attribute.Value));
		EndDo;
	EndIf;
	Return Node;
EndFunction
&AtServerNoContext
Function ImportEventFromXMLFile(RootNode)
	Var HasError, Value, Node, Signs, Table, ColumnCondition, Condition;
	Signs = New Structure;
	Signs.Insert("eq", "=");
	Signs.Insert("ne", "<>");
	Signs.Insert("gt", ">");
	Signs.Insert("ge", ">=");
	Signs.Insert("lt", "<");
	Signs.Insert("le", "<=");
	Signs.Insert("like", "like");
	Table = New ValueTable;
	Table.Columns.Add("Property");// name etc
	Table.Columns.Add("Type"); // eq, ne etc
	Table.Columns.Add("Value");// property name (for name) or condition parameters
	HasError = False;
	For Each Node In RootNode.ChildNodes Do
		ColumnCondition = Table.Add();
		// Verifying the condition
		Condition = Lower(Node.TagName);
		If Signs.Property(Condition, Condition) Then
			ColumnCondition.Type = Condition;
		Else
			HasError = True;
			Message(FormatMessage(NStr("en = 'Incorrect condition kind: %1%';ru = 'Некорректный вид условия: %1%'"), Node.TagName));
		EndIf;
		// The "property" attribute must be presented
		Value = Node.GetAttribute("property");
		If Value <> Undefined Then
			ColumnCondition.Property = StrReplace(Lower(Value), ":", "_");
		Else
			HasError = True;
			Message(FormatMessage(NStr("en = 'The <property> attribute is not found in the %1% element';ru = 'Отсутствует атрибут <property> в элементе %1%'"), Node.TagName));
		EndIf;
		// The "value" attribute must be present
		Value = Node.GetAttribute("value");
		If Value <> Undefined Then
			ColumnCondition.Value = Lower(Value);
		Else
			HasError = True;
			Message(FormatMessage(NStr("en = 'The <value> attribute is not found in the %1% element';ru = 'Отсутствует атрибут <value> в элементе %1%'"), Node.TagName));
		EndIf;
	EndDo;
	Return ?(HasError, Undefined, Table);
EndFunction
&AtClient
Function ChooseDirectory(Title, CurrentPath) Export
	Var File, ChooseDirectory;
#If Not WebClient Then
	File = New File(CurrentPath+"\aux");
	ChooseDirectory = New FileDialog(FileDialogMode.ChooseDirectory);
	ChooseDirectory.Title = Title;
	ChooseDirectory.Directory = File.Path;
	If ChooseDirectory.Choose() Then
		CurrentPath = ChooseDirectory.Directory + "\";
		Return True;
	EndIf;
	Return False;
#Else
	Return True;
#EndIf
EndFunction
&AtClient
Function RecordPossible()
	Var RecordPossible, Message, SelectedProperties;
	RecordPossible = True;
	If DumpMode Then
		If IsBlankString(DumpLocation) Then
			Message = New UserMessage;
			Message.Text = NStr("en = 'Dump directory is not specified';ru = 'Не задан каталог сохранения дампов'");
			Message.Field = "DumpLocation";
			Message.Message();
			RecordPossible = False;
		EndIf;
	EndIf;
	If TLMode Then
		If IsBlankString(TLLocation) Then
			Message = New UserMessage;
			Message.Text = NStr("en = 'Technological log directory is not specified';ru = 'Не задан каталог хранения технологического журнала'");
			Message.Field = "TLLocation";
			Message.Message();
			RecordPossible = False;
		EndIf;
	EndIf;
	If DumpMode And TLMode And DumpLocation = TLLocation Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'Dumps and technological log cannot be saved to the same directory';ru = 'Нельзя задавать одинаковые каталоги для записи дампов и хранения файлов технологического журнала'");
		Message.Message();
		RecordPossible = False;
	EndIf;
	SelectedProperties = SelectedColumns.FindRows(New Structure("Column", ""));
	If SelectedProperties.Count() = SelectedColumns.Count() Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'No properties are enabled for the technological log. We recommend that you enable the <All properties> property of the <All events> events.';ru = 'В технологический журнал не включено ни одно свойство. Рекомендуется включить свойство <Все свойства> для события <Все события>.'");
		Message.Message();
		RecordPossible = False;
	EndIf;
	Return RecordPossible;
EndFunction
&AtClient
Procedure SaveSettingsFile(FullFileName)
	Var StorageAddress;
	StorageAddress = GenerateSettingsFileAtServer();
#If WebClient Then
	GetFile(StorageAddress, FullFileName, True);
#Else
	GetFile(StorageAddress, FullFileName, False);
#EndIf
EndProcedure
&AtClient
Procedure LoadSettingsFile(Parameters)
	ClearMessages();
	If LoadSettingsFileAtServer(Parameters.StorageAddress) Then
		FileLocation = Parameters.FullFileName;
		// Showing only cells where check marks are set
		OnlySelectedColumns = 2;
		SetColumnVisibility(OnlySelectedColumns);
	Else
		DefaultParametersAtServer();
		Message(FormatMessage(NStr("en = 'Error reading the file: %1%';ru = 'Ошибка чтения файла: %1%'"), Parameters.FullFileName));
	EndIf;

EndProcedure
&AtClient
Procedure LoadTemplateFile(Val TemplateName)
	Var Actions, ActionList, Action;
	Actions = New Structure;
	Actions.Insert("Dump", "pathtodump");
	Actions.Insert("TL", "pathtotl");
	ClearMessages();
	If Lower(Left(TemplateName, 8)) <> "template" Then
		// Is a template from file
		Document = New TextDocument;
		Document.Read(TemplateName);
		TemplateName = PutToTempStorage(Document.GetText());
	EndIf;
	ActionList = LoadTemplateAtServer(TemplateName);
	// Showing only cells where check marks are set
	OnlySelectedColumns = 2;
	SetColumnVisibility(OnlySelectedColumns);
	// Performing all required actions
	For Each Action In ActionList Do
		If Lower(Action) = Actions.Dump Then
			ChooseDirectory(NStr("en = 'Select dump directory';ru = 'Выберите каталог размещения дампов'"), DumpLocation);
		ElsIf Lower(Action) = Actions.TL Then
			ChooseDirectory(NStr("en = 'Select technological log directory';ru = 'Выберите каталог размещения технологического журнала'"), TLLocation);
		EndIf;
	EndDo;
	Modified = True;
EndProcedure
&AtClient
Function GetPathToCommonConfigurationFiles()
	Var File, Text, ConfigurationRow, Separator;
#If Not WebClient Then
	File = New File(BinDir()+"conf\conf.cfg");
	If File.Exist() Then
		Text = New TextReader(file.FullName);
		While True Do
			ConfigurationRow = Text.ReadLine();
			If ConfigurationRow = Undefined Then
				Return "";
			EndIf;
			If IsBlankString(ConfigurationRow) Then
				Continue;
			EndIf;
			Separator = Find(ConfigurationRow, "=");
			If Separator = 0 Then
				Continue;
			EndIf;
			If Lower(Mid(ConfigurationRow, 1, Separator-1)) = "conflocation" Then
				Return Mid(ConfigurationRow, Separator+1)+"\";
				Break;
			EndIf;
		EndDo;
	EndIf;
#EndIf
	Return "";
EndFunction
&AtClient
Procedure OnOpen(Cancel)
	Var NameArray, CommonPath, Path, FileName, File, Notification;
	ОбщийМодульКлиент.СобытиеФормы(ЭтаФорма, 0);
#If Not WebClient Then
	// Enabling additional features
	EnableThinClientAddons();
	// Attempting to find logcfg.xml in the following ordinary locations and open it:
	// 1. bin\conf of the current 1C:Enterprise release;
	// 2. path specified in bin\conf\conf.cfg of the current 1C:Enterprise release.
	// If the application runs in the web client mode, no application catalog exists.
	FileName = "logcfg.xml";
	NameArray = New Array;
	NameArray.Add(BinDir()+"conf\");
	// If conf.cfg exists, retrieving the path it contents
	CommonPath = GetPathToCommonConfigurationFiles();
	If Not IsBlankString(CommonPath) Then
		NameArray.Add(CommonPath);
	EndIf;
	// Reading only the first found file
	For Each Path In NameArray Do
		File = New File(Path+FileName);
		If File.Exist() Then
			Notification = New NotifyDescription("LoadSettingsCompletion", ThisObject);
			BeginPutFile(Notification, "", File.FullName, False, UUID);
			Break;
		EndIf;
	EndDo;
#EndIf
EndProcedure
&AtClient
// Is intended for processing all attempts of loading the logcfg.xml file of the data processor.
Procedure LoadSettingsCompletion(Result, Address, SelectedFileName, ExtendedParameters) Export
	Var Parameters;
	If Result Then
		Parameters = New Structure("FullFileName, StorageAddress", SelectedFileName, Address);
		LoadSettingsFile(Parameters);
		Modified = False;
	EndIf;
EndProcedure
&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	Var Text, Notification;
	If Modified And ResponseBeforeClose <> True Then
		Cancel = True;
		ResponseBeforeClose = Undefined;
		Text = FormatMessage(NStr("en = 'Current technological log file has been modified.%LDo you want to save changes?';ru = 'Текущий файл конфигурации технологического журнала изменен.%LСохранить файл?'"));
		Notification = New NotifyDescription("BeforeCloseCompletion", ThisObject);
		ShowQueryBox(Notification, Text, QuestionDialogMode.YesNoCancel, , DialogReturnCode.Yes);
	EndIf;
EndProcedure
&AtClient
Procedure BeforeCloseCompletion(Result, ExtendedParameters) Export
	If Result = DialogReturnCode.Yes Then
		// Save the current settings file
		ResponseBeforeClose = True;
		SaveFile(Commands.SaveFile);
		Close();
		Return;
	ElsIf Result = DialogReturnCode.Cancel Then
		ResponseBeforeClose = Undefined;
		Return;
	ElsIf Result = DialogReturnCode.No Then
		ResponseBeforeClose = True;
		Close();
		Return;
	EndIf;
	ResponseBeforeClose = Undefined;
EndProcedure
&AtClient
Procedure DumpOnChange(Item)
	Items.DumpGroup.Enabled = DumpMode;
	If DumpMode And IsBlankString(DumpLocation) Then
		ChooseDirectory(NStr("en = 'Select the dump directory';ru = 'Выберите каталог размещения дампов'"), DumpLocation);
	EndIf;
EndProcedure
&AtClient
Procedure LeaksOnChange(Item)
	Items.LeaksGroup.Enabled = LeaksMode;
EndProcedure
&AtClient
Procedure TLModeOnChange(Item)
	Items.TLParameters.Enabled = TLMode;
	Items.TLEditor.Enabled = TLMode;
	Items.ViewParameters.Enabled = TLMode;
	Items.UnderEditor.Enabled = TLMode;
	If TLMode And IsBlankString(TLLocation) Then
		ChooseDirectory(NStr("en = 'Select the technological log directory';ru = 'Выберите каталог размещения технологического журнала'"), TLLocation);
	EndIf;
EndProcedure
&AtClient
Procedure LoadTemplate(Command)
	Var FormParameters, Notification;
	FormParameters = New Structure;
	FormParameters.Insert("PathToTemplates", GetPathToCommonConfigurationFiles());
	Notification = New NotifyDescription("LoadTemplateCompletion", ThisObject);
	OpenForm(MetaPath + ".Form.SelectTemplate", FormParameters, , , , , Notification);
EndProcedure
&AtClient
Procedure LoadTemplateCompletion(Result, ExtendedParameters) Export
	If TypeOf(Result) = Type("String") Then
		LoadTemplateFile(Result);
	EndIf;
EndProcedure
&AtClient
Procedure OpenFile(Command)
	Var Notification, TLFile, ChoiceResult;
#If WebClient Then
	Notification = New NotifyDescription("LoadSettingsCompletion", ThisObject);
	BeginPutFile(Notification, "", "logcfg.xml", True, UUID);
#Else
	TLFile = New FileDialog(FileDialogMode.Open);
	TLFile.Title = NStr("en = 'Select the technological log settings file';ru = 'Выберите файл настройки технологического журнала'");
	TLFile.Filter = NStr("en = 'Technological log settings file (logcfg.xml)|logcfg.xml|XMLfiles (*.xml)|*.xml|All files (*.*)|*.*';ru = 'Файл настройки технологического журнала (logcfg.xml)|logcfg.xml|XML-файлы (*.xml)|*.xml|Все файлы (*.*)|*.*'");
	TLFile.Multiselect = False;
	ChoiceResult = TLFile.Choose();
	If ChoiceResult Then
		Notification = New NotifyDescription("LoadSettingsCompletion", ThisObject);
		BeginPutFile(Notification, "", TLFile.FullFileName, False, UUID);
	EndIf;
#EndIf
EndProcedure
&AtClient
Procedure RereadFile(Command)
	Var Notification, Text;
	If Not IsBlankString(FileLocation) Then
		If Modified Then
			Notification = New NotifyDescription("RereadFileCompletion", ThisObject, FileLocation);
			Text = FormatMessage(NStr("en = 'Loaded configuration file has been modified.%LDo you want to reload the current configuration file?';ru = 'Загруженный файл конфигурации изменен.%LВы уверены, что хотите заново загрузить текущий файл конфигурации?'"));
			ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , DialogReturnCode.No);
			Return;
		EndIf;
		Notification = New NotifyDescription("LoadSettingsCompletion", ThisObject);
		BeginPutFile(Notification, "", FileLocation, False, UUID);
	EndIf;
EndProcedure
&AtClient
Procedure RereadFileCompletion(Result, ExtendedParameters) Export
	Var Notification;
	If Result = DialogReturnCode.Yes Then
		Notification = New NotifyDescription("LoadSettingsCompletion", ThisObject);
		BeginPutFile(Notification, "", ExtendedParameters, False, UUID);
	EndIf;
EndProcedure
&AtClient
Procedure SaveFile(Command)
	Var File, NewName;
#If WebClient Then
	SaveSettingsFile("logcfg.xml");
	Modified = False;
#Else
	If IsBlankString(FileLocation) Then
		// If the name is not specified, executing the "Save as" command
		SaveAs(Commands.SaveAs);
		Return;
	EndIf;
	If Not RecordPossible() Then
		Return;
	EndIf;
	File = New File(FileLocation);
	If File.Exist() Then
		File.SetReadOnly(False);
		// Creating a copy with the .bak extension
		NewName = StrReplace(FileLocation, File.Extension, ".bak");
		// Deleting the backup file
		DeleteFiles(NewName);
		// Creating the backup file
		MoveFile(FileLocation, NewName);
	EndIf;
	SaveSettingsFile(FileLocation);
	Modified = False;
#EndIf
EndProcedure
&AtClient
Procedure SaveAs(Command)
	Var ChoiceDialog, Result, Notification, File, Text, ReadOnlyText;
	If Not RecordPossible() Then
		Return;
	EndIf;
	ChoiceDialog = New FileDialog(FileDialogMode.Save);
	ChoiceDialog.Title = NStr("en = 'Select the directory and name of the file to be saved';ru = 'Выберите каталог и имя сохраняемого файла'");
	ChoiceDialog.FullFileName = "logcfg.xml";
	ChoiceDialog.Filter = NStr("en = 'XML file (*.xml)|*.xml|All files (*.*)|*.*';ru = 'XML-файл (*.xml)|*.xml|Все файлы (*.*)|*.*'");
	Result = ChoiceDialog.Choose();
	If Not Result Then
		Return;
	EndIf;
	Notification = New NotifyDescription("SaveAsCompletion", ThisObject, ChoiceDialog.FullFileName);
	File = New File(ChoiceDialog.FullFileName);
	If File.Exist() Then
		If File.GetReadOnly() Then
			ReadOnlyText = NStr("en = ', which is read only';ru = ' и для него установлен режим ""Только чтение""'", "en");
		Else
			ReadOnlyText = "";
		EndIf;
		Text = FormatMessage(NStr("en = 'Selected directory already contains the %1% file%2%.%LDo you want to replace it?';ru = 'В выбранном каталоге уже есть файл ""%1%""%2%.%LПерезаписать?'"), File.Name, ReadOnlyText);
		ShowQueryBox(Notification, Text, QuestionDialogMode.OKCancel);
	Else
		ExecuteNotifyProcessing(Notification, DialogReturnCode.OK);
	EndIf;
EndProcedure

&AtClient
Procedure SaveAsCompletion(Result, FileName) Export
	Var File;
	If Result = DialogReturnCode.OK Then
		File = New File(FileName);
		If File.Exist() Then
			File.SetReadOnly(False);
			DeleteFiles(FileName);
		EndIf;
		SaveSettingsFile(FileName);
		Modified = False;
	EndIf;
EndProcedure
&AtClient
Procedure SaveTemplate(Command)
	Var StorageAddress, FileText, FormParameters;
#If Not WebClient Then
	If Not RecordPossible() Then
		Return;
	EndIf;
	StorageAddress = GenerateSettingsFileAtServer();
	FileText = GetFromTempStorage(StorageAddress);
	FormParameters = New Structure;
	FormParameters.Insert("PathToTemplates", GetPathToCommonConfigurationFiles());
	FormParameters.Insert("ConfigurationFile", FileText);
	OpenForm(MetaPath + ".Form.SaveTemplate", FormParameters);
#EndIf
EndProcedure
&AtClient
Procedure ShowConfigurationFile(Command)
	Var StorageAddress, FileText, TextDocument;
	If Not RecordPossible() Then
		Return;
	EndIf;
	StorageAddress = GenerateSettingsFileAtServer();
	FileText = GetFromTempStorage(StorageAddress);
	TextDocument = New TextDocument;
	TextDocument.SetText(FileText);
	TextDocument.Show(NStr("en = 'Technological log configuration file';ru = 'Файл конфигурации технологического журнала'"), "");
	DeleteFromTempStorage(StorageAddress);
EndProcedure
&AtClient
Procedure EventConditionEditor(Command)
	Var EventDetails, EventConditions, FormParameters, Notification;
	EventDetails = EventData.FindByID(GetEvenID(Items.TLEditor.CurrentArea.Top));
	EventConditions = EventsConditions.FindRows(New Structure("Event", EventDetails.Name));
	FormParameters = New Structure;
	FormParameters.Insert("Event", EventDetails.Name);
	FormParameters.Insert("ColumnList", CollectVLEventColumns(EventDetails.Name));
	FormParameters.Insert("TypeList", ColumnTypes);
	FormParameters.Insert("AllConditions", EventsConditions);
	Notification = New NotifyDescription("EventConditionEditorCompletion", ThisObject);
	OpenForm(MetaPath + ".Form.EventConditionEditor", FormParameters, , , , , Notification);
EndProcedure
&AtClient
Procedure EventConditionEditorCompletion(Result, ExtendedParameters) Export
	Var EventDetails, HasConditions, Condition, DataRow;
	If TypeOf(Result) = Type("Array") Then
 		Modified = True;
		EventDetails = EventData.FindByID(GetEvenID(Items.TLEditor.CurrentArea.Top));
		// Deleting conditions that existed before editing from the list and then adding
		// conditions made in the dialogue.
 		SetCombination(EventDetails.LineNumber, -1, 0);
		HasConditions = Result.Count() <> 0;
		For Each Condition  In Result Do
			DataRow = EventsConditions.Add();
			FillPropertyValues(DataRow, Condition);
		EndDo;
		// Setting the check mark if it does not set, and specifying conditions
	If HasConditions Then
			SetCombination(EventDetails.LineNumber, -1, 2);
		EndIf;
	EndIf;
EndProcedure
&AtClient
Procedure ColumnConditionEditor(Command)
	Var ColumnDetails, RowDescription, Conditions, FormParameters, Notification;
	ColumnDetails = ColumnData.FindByID(GetColumnID(Items.TLEditor.CurrentArea.Left));
	RowDescription = EventData.FindByID(GetEvenID(Items.TLEditor.CurrentArea.Top));
	Conditions = ColumnConditions.FindRows(New Structure("Event, LeadColumn", RowDescription.Name, ColumnDetails.Name));
	FormParameters = New Structure;
	FormParameters.Insert("Event", RowDescription.Name);
	FormParameters.Insert("Column", ColumnDetails.Name);
	FormParameters.Insert("ColumnList", CollectVLEventColumns(RowDescription.Name));
	FormParameters.Insert("TypeList", ColumnTypes);
	FormParameters.Insert("AllConditions", ColumnConditions);
	Notification = New NotifyDescription("ColumnConditionEditorCompletion", ThisObject);
	OpenForm(MetaPath + ".Form.ColumnConditionEditor", FormParameters, , , , , Notification);
EndProcedure
&AtClient
Procedure ColumnConditionEditorCompletion(Result, ExtendedParameters) Export
	Var ColumnDetails, RowDescription, HasConditions, DataRow;
	If TypeOf(Result) = Type("Array") Then
		Modified = True;
		ColumnDetails = ColumnData.FindByID(GetColumnID(Items.TLEditor.CurrentArea.Left));
		RowDescription = EventData.FindByID(GetEvenID(Items.TLEditor.CurrentArea.Top));
		// Deleting conditions that existed before editing from the list, then adding
		// conditions made in the dialogue.
		SetCombination(RowDescription.LineNumber, ColumnDetails.ColumnNumber, 0);
		HasConditions = Result.Count() <> 0;
		For Each Condition In Result Do
			DataRow = ColumnConditions.Add();
			FillPropertyValues(DataRow, Condition);
		EndDo;
		If HasConditions Then
			SetCombination(RowDescription.LineNumber, ColumnDetails.ColumnNumber, 3);
		EndIf;
	EndIf;
EndProcedure
&AtClient
Procedure ClearTLSettings(Command)
	Var Notification, Text;
	Notification = New NotifyDescription("ClearTLSettingsCompletion", ThisObject);
	Text = NStr("en = 'Do you want to revert to the default technological log settings?';ru = 'Вы уверены в том, что хотите очистить текущие настройки технологического журнала и установить значения по умолчанию?'");
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , DialogReturnCode.No);
EndProcedure
&AtClient
Procedure ClearTLSettingsCompletion(Result, ExtendedParameters) Export
	If Result = DialogReturnCode.Yes Then
		// Clearing all technological log settings and reverting to the default ones.
		ClearTLParameters();
		DefaultTLParametersAtServer();
	EndIf;
EndProcedure
&AtClient
Procedure ResetSysTLSettings(Command)
	SysTLLocation = "";
	SysTLHistory = 24;
	Modified = True;
EndProcedure
&AtClient
Procedure ClearRowFilter(Command)
	Var LineNumber;
	Modified = True;
	LineNumber = Items.TLEditor.CurrentArea.Top;
	SetCombination(LineNumber, -1, 0);
	SetCombination(LineNumber, -1, 1);
EndProcedure
&AtClient
Procedure ClearColumnFilter(Command)
	Var ColumnNumber, LineNumber;
	Modified = True;
	ColumnNumber = Items.TLEditor.CurrentArea.Left;
	LineNumber = Items.TLEditor.CurrentArea.Top;
	SetCombination(LineNumber, ColumnNumber, 0);
	SetCombination(LineNumber, ColumnNumber, 1);
EndProcedure
&AtClient
Procedure EnableEventsByColumn(Command)
	Modified = True;
	SetCombination(0, TLEditor.CurrentArea.Left, 1);
EndProcedure
&AtClient
Procedure DisableEventsByColumn(Command)
	Modified = True;
	SetCombination(0, TLEditor.CurrentArea.Left, 0);
EndProcedure
&AtClient
Procedure OptimalDump(Command)
	Modified = True;
	DumpType.FillChecks(False);
	DumpType[0].Check = True;
	DumpType[1].Check = True;
EndProcedure
&AtClient
Procedure OnlySelectedColumnsOnChange(Item)
	SetColumnVisibility(OnlySelectedColumns);
	CurrentItem = Items.TLEditor;
EndProcedure
&AtClient
Procedure OnlySelectedEventsOnChange(Item)
	SetRowVisibility(OnlySelectedEvents);
	CurrentItem = Items.TLEditor;
EndProcedure
&AtClient
Procedure DisplayNamesPresentationsOnChange(Item)
	ShowColumnRowHeaders(DisplayNamesPresentations);
	CurrentItem = Items.TLEditor;
EndProcedure

&AtClient
Procedure DumpLocationStartChoice(Item, ChoiceData, StandardProcessing)
	ChooseDirectory(NStr("en = 'Select dump directory';ru = 'Выберите каталог размещения дампов'"), DumpLocation);
EndProcedure
&AtClient
Procedure TLLocationStartChoice(Item, ChoiceData, StandardProcessing)
	ChooseDirectory(NStr("en = 'Select technological log file directory';ru = 'Выберите каталог размещения файлов технологического журнала'"), TLLocation);
EndProcedure
&AtClient
Procedure SysTLLocationStartChoice(Item, ChoiceData, StandardProcessing)
	ChooseDirectory(NStr("en = 'Select directory of system technological log files';ru = 'Выберите каталог размещения файлов системного технологического журнала'"), SysTLLocation);
EndProcedure
&AtClient
Procedure TLEditorChioce(Item, Area, StandardProcessing)
	If StrOccurrenceCount(Area.Name, ":") > 0 Or Not Area.Hyperlink Then
		Return;
	EndIf;
	DetachIdleHandler("IdleHandler");
	IdleHandler();
	Modified = True;
	If IsBlankString(Area.Text) Then
		If Area.Left = 1 Then
			SetCombination(Area.Top, -1, 1);
		Else
			SetCombination(Area.Top, -1, 1);
			SetCombination(Area.Top, Area.Left, 1);
		EndIf;
	Else
		If Area.Left = 1 Then
			// Clearing the flag of the event
			SetCombination(Area.Top, -1, 0);
		Else
			// Clearing the flag of the Event*Column combination
			SetCombination(Area.Top, Area.Left, 0);
		EndIf;
	EndIf;
	If OnlySelectedColumns = 2 Then
		SetColumnVisibility(OnlySelectedColumns);
	EndIf;
EndProcedure
&AtClient
Procedure TLEditorOnActivateArea(Item)
	Var CurColumn, CurRow, WithinColumnArea, WithinRowArea, FirstColumn, AllColumn;
	Var EnabledForColumns, EnabledForCommands;
	CurColumn = Items.TLEditor.CurrentArea.Left;
	CurRow = Items.TLEditor.CurrentArea.Top;
	WithinColumnArea = ?(CurColumn >= EditAreaBound.Left And CurColumn <= EditAreaBound.Right, True, False);
	WithinRowArea = ?(CurRow >= EditAreaBound.Top And CurRow <= EditAreaBound.Bottom, True, False);
	FirstColumn = CurColumn = 1;
	AllColumn = CurColumn = 3;
	// Setting column handle command availability
	EnabledForColumns = (WithinColumnArea Or AllColumn) And WithinRowArea And TLEditor.Area(CurRow, CurColumn).Hyperlink;
	If Items["ColumnConditionEditor"].Enabled <> EnabledForColumns Then
		Items["ColumnConditionEditor"].Enabled = EnabledForColumns;
		Items["ClearColumnFilter"].Enabled = EnabledForColumns;
	EndIf;
	// Setting availability of command enable/disable commands, associated with the entire column
	EnabledForCommands = WithinColumnArea And WithinRowArea;
	If Items["EnableEventsByColumn"].Enabled <> EnabledForCommands Then
		Items["EnableEventsByColumn"].Enabled = EnabledForCommands;
		Items["DisableEventsByColumn"].Enabled = EnabledForCommands;
	EndIf;
	// Setting event handle command availability
	If Items["EventsConditionEditor"].Enabled <> WithinRowArea Then
		Items["EventsConditionEditor"].Enabled = WithinRowArea;
		Items["ClearRowFilter"].Enabled = WithinRowArea;
	EndIf;
	// Disabling the header highlight
	If CurRow <> CurrentRow And (CurrentRow >= EditAreaBound.Top And CurrentRow <= EditAreaBound.Bottom) Then
		TLEditor.Area(CurrentRow, 2).BackColor = ColorsInUse.OrdinaryBackground;
	EndIf;
	If CurColumn <> CurrentColumn And (CurrentColumn >= EditAreaBound.Left And CurrentColumn <= EditAreaBound.Right) Then
		TLEditor.Area(1, CurrentColumn).BackColor = ColorsInUse.OrdinaryBackground;
	EndIf;
	AttachIdleHandler("IdleHandler", 0.2, True);
EndProcedure
&AtClient
Procedure IdleHandler()
	Var CurColumn, CurRow, WithinColumnArea, WithinRowArea, FirstColumn, AllColumn, FirstRow, Text;
	CurColumn = Items.TLEditor.CurrentArea.Left;
	CurRow = Items.TLEditor.CurrentArea.Top;
	WithinColumnArea = ?(CurColumn >= EditAreaBound.Left And CurColumn <= EditAreaBound.Right, True, False);
	WithinRowArea = ?(CurRow >= EditAreaBound.Top And CurRow <= EditAreaBound.Bottom, True, False);
	FirstColumn = CurColumn = 1;
	AllColumn = CurColumn = 3;
	FirstRow = CurRow = 1;
	EventName = ?(WithinRowArea, StrReplace(EventData[CurRow-2].Name, "_", ":"), "");
	PropertyName = ?(WithinColumnArea, StrReplace(ColumnData[CurColumn-3].Name, "_", ":"), "");
	// Generating a column tooltip
	If FirstColumn And CurRow = 2 Then
		Text = NStr("en = 'Enable/disable registration of all events in the technological log';ru = 'Включить/выключить регистрацию всех событий в технологическом журнале'");
	ElsIf FirstColumn And WithinRowArea Then
		Text = FormatMessage(NStr("en = 'Enable/disable the ""%1%"" event in the technological log';ru = 'Включить/выключить событие ""%1%"" в технологическом журнале'"), EventName);
	ElsIf AllColumn And WithinRowArea Then
		Text = FormatMessage(NStr("en = 'Enable/disable all properties for the ""%1%"" event';ru = 'Включить/выключить все свойства для события ""%1%""'"), EventName);
	ElsIf WithinColumnArea And (WithinRowArea Or FirstRow) Then
		Text = ColumnData[CurColumn-3].ToolTip;
	Else
		Text = NStr("ru='<Не выбрано свойство>';en = '<Property not selected>'");
	EndIf;
	If Lower(ColumnsToolTip) <> Lower(Text) Then
		ColumnsToolTip = Text;
	EndIf;
	// Generating a row tooltip
	If WithinRowArea Then
		Text = EventData[CurRow-2].ToolTip;
	Else
		Text = NStr("en = '<Event not selected>';ru = '<Не выбрано событие>';");
	EndIf;
	If Lower(EventToolTip) <> Lower(Text) Then
		EventToolTip = Text;
	EndIf;
	// Highlighting row headers
	If CurRow <> CurrentRow Then
		If WithinRowArea Then
			TLEditor.Area(CurRow, 2).BackColor = ColorsInUse.SelectionBackground;
		EndIf;
	EndIf;
	CurrentRow = CurRow;
	// Highlighting column headers
	If CurColumn <> CurrentColumn Then
		If WithinColumnArea Then
			TLEditor.Area(1, CurColumn).BackColor = ColorsInUse.SelectionBackground;
		EndIf;
	EndIf;
	CurrentColumn = CurColumn;
EndProcedure
// Generates a string based on the passed pattern and parameters to be inserted
// (emulates the C function sprintf()).
// Parameters:
//  ToDisplay  - source pattern.
//  Parameter1 - following options are available:
// 		           Array           - all values to be inserted are passed through the
// 		                             array, which is passed as first parameter. The
// 		                             parameter number is equal to the array element
// 		                             index -1. Other parameters are not used.
// 		           Structure       - all values to be inserted are passed through the
// 		                             structure, which is passed as first parameter. The
// 		                             parameter number is equal to the structure item
// 		                             index -1. Other parameters are not used.
//               Any other value - all values are passed obviously. All ParameterX
//                                 variables can be used. In this case maximum 10
//                                 parameters can be passed.
// The source pattern can contain the following escape sequences:
// %T - replaced by Chars.Tab;
// %L - replaced by Chars.LF;
// %% - replaced by %;
// %number;width;format% - parameter to be replaced:
// 	number - mandatory - serial number of parameter (starts with 1), is used for
//            selecting the ParameterX, array element, or structure item (all start with 0)
//            that will be substituted.
// 	width  - optional - width of the field where the parameter is displayed. If the
//            value is greater than 0, the value is left-aligned, if it is less than 0,
//            the value is right-aligned. If the parameter value is wider than the field,
//            it is cut from the right. Default value (0) means no restrictions.
// 	format - optional - format string (similarly to the Format() function). If the
//            value is not set, the standard presentation of the 1C:Enterprise type is
//            used. You cannot use the % character in the format string.
// Example: "%%1%% string contains the 1-st parameter %1;-20% and the 2-nd parameter
//  %2%", "Test", 3.14159265
// Returns:
//  Result string.
//
&AtServerNoContext
Function FormatMessage(Val ToDisplay, Parameter0 = Undefined, Parameter1 = Undefined, Parameter2 = Undefined, Parameter3 = Undefined, Parameter4 = Undefined, Parameter5 = Undefined, Parameter6 = Undefined, Parameter7 = Undefined, Parameter8 = Undefined, Parameter9 = Undefined)
	Var Parameters, Value, ParameterCount, Result;
	Var ParameterStart, ParameterEnd, Parameter, ParameterNumber, FieldWidth, FieldFormat, Counter, Substring, ValueString;
	Var Cnt, EmptySpace;
	// Changing symbols that prevent string correctness analysis
	ToDisplay = StrReplace(ToDisplay, "%T", Char(1));
	ToDisplay = StrReplace(ToDisplay, "%t", Char(1));
	ToDisplay = StrReplace(ToDisplay, "%L", Char(2));
	ToDisplay = StrReplace(ToDisplay, "%l", Char(2));
	ToDisplay = StrReplace(ToDisplay, "%%", Char(3));
	// If no % characters are found, no formatting is required.
	// Returning the string after the macro substitution.
	If StrOccurrenceCount(ToDisplay, "%") = 0 Then
		ToDisplay = StrReplace(ToDisplay, Char(1), Chars.Tab);
		ToDisplay = StrReplace(ToDisplay, Char(2), Chars.LF);
		ToDisplay = StrReplace(ToDisplay, Char(3), "%");
		Return ToDisplay;
	EndIf;
	// If unpaired % are found, the string cannot be formatted.
	If StrOccurrenceCount(ToDisplay, "%") % 2 <> 0 Then
	// Returning the source string (without surrogate characters)
		ToDisplay = StrReplace(ToDisplay, Char(1), "%T");
		ToDisplay = StrReplace(ToDisplay, Char(2), "%L");
		ToDisplay = StrReplace(ToDisplay, Char(3), "%%");
		Return ToDisplay;
	EndIf;
	// Determining how parameters are passed and filling the parameter array
	Parameters = New Array;
	If TypeOf(Parameter0) = Type("Array") Then
		// Parameters are passed in the array, skipping next parameters
		Parameters = Parameter0;
	ElsIf TypeOf(Parameter0) = Type("Structure") Then
		// Parameters are passed in the structure
		For Each Item In Parameter0 Do
			Parameters.Add(Item.Value);
		EndDo;
	Else
		// Parameters are passed through the function parameters. Maximum 10 parameters can
		// be passed. First parameter with the Undefined value stops parameter analysis.
		For Cnt = 0 to 9 Do
			Value = Undefined;
			Execute("Value = Parameter" + Format(Cnt, "NZ=0; NG=0")+";");
			If Value = Undefined Then
				Break;
			EndIf;
			Parameters.Add(Value);
		EndDo;
	EndIf;
	ParameterCount = Parameters.Count();
	// Parsing the parameter and formatting the string
	Result = "";
	While True Do
		ParameterStart = Find(ToDisplay, "%");
		If ParameterStart <> 0 Then
			Result = Result + Mid(ToDisplay, 1, ParameterStart-1);
			ToDisplay = Mid(ToDisplay, ParameterStart+1);
			ParameterEnd = Find(ToDisplay, "%");
			Parameter = Mid(ToDisplay, 1, ParameterEnd-1);
			ToDisplay = Mid(ToDisplay, ParameterEnd+1);
			// Parsing the parameter
			ParameterNumber = 0;
			FieldWidth = 0;
			FieldFormat = "";
			Parameter = StrReplace(Parameter, ";", Chars.LF);
			For Counter = 1 to StrLineCount(Parameter) Do
				Substring = StrGetLine(Parameter, Counter);
				If Counter = 1 Then
					// Parameter number
					Substring = StrReplace(Substring, Chars.NBSp, "");
					Substring = StrReplace(Substring, " ", "");
					ParameterNumber = Number(Substring);
				ElsIf Counter = 2 Then
					// Width and field alignment
					Substring = StrReplace(Substring, Chars.NBSp, "");
					Substring = StrReplace(Substring, " ", "");
					FieldWidth = Number(Substring);
				Else
					// Parameter format string
					FieldFormat = FieldFormat + Substring + ";"
				EndIf;
			EndDo;
			If ParameterNumber > ParameterCount Then
				Return NStr("en = 'Parameter number (" + ParameterNumber + ") in the format string exceeds the number of passed parameters (" + ParameterCount + ").';ru = 'Номер параметра в форматной строке (" + ParameterCount + ") превышает количество переданных параметров (" + ParameterCount + ").'");
			EndIf;
			ValueString = Format(Parameters[ParameterNumber-1], FieldFormat);
			ValueString = StrReplace(ValueString, "%T", Char(1));
			ValueString = StrReplace(ValueString, "%t", Char(1));
			ValueString = StrReplace(ValueString, "%L", Char(2));
			ValueString = StrReplace(ValueString, "%l", Char(2));
			// Defining the field width alignment
			If FieldWidth <> 0 Then
				SimpleWidth = ?(FieldWidth < 0, -FieldWidth, FieldWidth);
				EmptySpace = "";
				For Cnt = 1 to SimpleWidth Do
					EmptySpace = EmptySpace + " ";
				EndDo;
				If FieldWidth > 0 Then
					// Left-aligned
					ValueString = Left(ValueString + EmptySpace, SimpleWidth);
				Else
					// Right-aligned
					ValueString = Right(EmptySpace + ValueString, SimpleWidth);
				EndIf;
			EndIf;
			Result = Result + ValueString;
		Else
			// All parameters have been handled, breaking processing.
			Result = Result + ToDisplay;
			Break;
		EndIf;
	EndDo;
	// Substituting real characters to surrogate ones
	Result = StrReplace(Result, Char(2), Chars.LF);
	Result = StrReplace(Result, Char(3), "%");
	Return Result;
EndFunction
&НаКлиенте
Процедура ПриЗакрытии()
	ОбщийМодульКлиент.СобытиеФормы(ЭтаФорма, 1);
КонецПроцедуры
