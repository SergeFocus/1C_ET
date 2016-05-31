
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	Var DataProcessorObject, Text, ListItem, EventConditions, Condition, DataRow;
	DataProcessorObject = FormAttributeToValue("Object");
	MetaPath = DataProcessorObject.Metadata().FullName();
	Event = Parameters.Event;
	Column = Parameters.Column;
	Text = NStr("en = 'Editing conditions of the <%1%> properties of the <%2%> event'; ru = 'Редактирование условий для свойства <%1%> события <%2%>'");
	Text = StrReplace(Text, "%1%", TrimAll(Column));
	Title = StrReplace(Text, "%2%", TrimAll(Event));
	// Setting the choice list for the column list
	For Each ListItem In Parameters.ColumnList Do
		ColumnList.Add(ListItem.Value, ListItem.Presentation);
	EndDo;
	ColumnList.SortByPresentation();
	// Setting the type list
	TypeList = New Structure;
	// Copying the type table from the parameter to the form
	For Each ColumnType In Parameters.TypeList Do
		TypeList.Insert(ColumnType.Key, ?(TypeOf(ColumnType.Value) = Type("ValueList"), ColumnType.Value.Copy(), ColumnType.Value));
	EndDo;
	// Setting the current conditions
	If Parameters.AllConditions <> Undefined Then
		EventConditions = Parameters.AllConditions.FindRows(New Structure("LeadColumn,Event", Column, Event));
		For Each Condition In EventConditions Do
			DataRow = LogConditions.Add();
			FillPropertyValues(DataRow, Condition);
			DataRow.PresentationColumn = ColumnPresentation(DataRow.Column);
		EndDo;
	EndIf;
EndProcedure
&AtClient
Procedure FinishEditing(Command)
	Var Data, Condition, Item;
	// Putting the conditions into the transportable structure
	Data = New Array;
	For Each Condition In LogConditions Do
		Item = New Structure("Column, Condition, Value, LeadColumn, Event, PresentationColumn");
		FillPropertyValues(Item, Condition);
		Data.Add(Item);
	EndDo;
	Close(Data);
EndProcedure
&AtServer
Function ColumnPresentation(ColumnName)
	Var Result;
	Result = ColumnList.FindByValue(ColumnName);
	If Result = Undefined Then
		Return "<?>";
	Else
		Return Result.Presentation;
	EndIf;
EndFunction
&AtClientAtServerNoContext
Function FieldToEdit(ItemName)
	If ItemName = "LogConditionsPresentationColumn" Then
		Return "Property";
	ElsIf ItemName = "LogConditionsCondition" Then
		Return "Condition";
	ElsIf ItemName = "LogConditionsValue" Then
		Return "Value";
	EndIf;
	Return "";
EndFunction
&AtClient
Procedure LogConditionsBeforeAddRow(Item, Cancel, Copy, Parent, Folder)
	Var FormParameters, AsynchronousCall;
	Cancel = True;
	FormParameters = New Structure;
	FormParameters.Insert("Property", "");
	FormParameters.Insert("Condition", "");
	FormParameters.Insert("Value", "");
	FormParameters.Insert("TypeList", TypeList);
	FormParameters.Insert("ColumnList", ColumnList);
	FormParameters.Insert("CurrentColumn", "");
	AsynchronousCall = New NotifyDescription("LogConditionsBeforeAddRowCompletion", ThisObject);
	OpenForm(MetaPath + ".Form.ConditionEditor", FormParameters, , , , , AsynchronousCall);
EndProcedure
&AtClient
Procedure LogConditionsBeforeAddRowCompletion(Result, ExtendedParameters) Export
	Var ListRow;
	If TypeOf(Result) = Type("Structure") Then
		ListRow = LogConditions.Add();
		ListRow.Column = Result.Property;
		ListRow.PresentationColumn = ColumnPresentation(Result.Property);
		ListRow.Condition = Result.Condition;
		ListRow.Value = Result.Value;
		ListRow.Event = Event;
		ListRow.LeadColumn = Column;
		Items.LogConditions.CurrentRow = ListRow.GetID();
	EndIf;
EndProcedure
&AtClient
Procedure LogConditionsBeforeRowChange(Item, Cancel)
	Var CurrentData, FormParameters, AsynchronousCall;
	Cancel = True;
	CurrentData = Items.LogConditions.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	FormParameters = New Structure;
	FormParameters.Insert("Property", CurrentData.Column);
	FormParameters.Insert("Condition", CurrentData.Condition);
	FormParameters.Insert("Value", CurrentData.Value);
	FormParameters.Insert("TypeList", TypeList);
	FormParameters.Insert("ColumnList", ColumnList);
	FormParameters.Insert("CurrentColumn", FieldToEdit(Items.LogConditions.CurrentItem.Name));
	AsynchronousCall = New NotifyDescription("LogConditionsBeforeRowChangeCompletion", ThisObject);
	OpenForm(MetaPath + ".Form.ConditionEditor", FormParameters, , , , , AsynchronousCall);
EndProcedure
&AtClient
Procedure LogConditionsBeforeRowChangeCompletion(Result, ExtendedParameters) Export
	Var CurrentData;
	If TypeOf(Result) = Type("Structure") Then
		CurrentData = Items.LogConditions.CurrentData;
		CurrentData.Column = Result.Property;
		CurrentData.PresentationColumn = ColumnPresentation(Result.Property);
		CurrentData.Condition = Result.Condition;
		CurrentData.Value = Result.Value;
	EndIf;
EndProcedure
