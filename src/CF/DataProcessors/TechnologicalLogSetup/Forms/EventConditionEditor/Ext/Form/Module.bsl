
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	Var DataProcessorObject, Text, Column, EventConditions, DataRow;
	DataProcessorObject = FormAttributeToValue("Object");
	MetaPath = DataProcessorObject.Metadata().FullName();
	If Not IsBlankString(Parameters.Event) Then
		Event = Parameters.Event;
		Text = NStr("en = 'Editing conditions of the <%1%> event'; ru = 'Редактирование условий для события <%1%>'");
		Title = StrReplace(Text, "%1%", TrimAll(Event));
	Else
		Cancel = True;
		Return;
	EndIf;
	// Setting the choice list for the column list
	For Each Column In Parameters.ColumnList Do
		ColumnList.Add(Column.Value, Column.Presentation);
	EndDo;
	ColumnList.SortByPresentation();
	// Setting the type list
	TypeList = New Structure;
	// Coping the type table from the parameter to the form
	For Each ColumnType In Parameters.TypeList Do
		TypeList.Insert(ColumnType.Key, ?(TypeOf(ColumnType.Value) = Type("ValueList"), ColumnType.Value.Copy(), ColumnType.Value));
	EndDo;
	// Setting the current conditions
	If Parameters.AllConditions <> Undefined Then
		EventConditions = Parameters.AllConditions.FindRows(New Structure("Event", Event));
		For Each Condition In EventConditions Do
			DataRow = LogConditions.Add();
			FillPropertyValues(DataRow, Condition);
			DataRow.PresentationColumn = ColumnPresentation(DataRow.Column);
		EndDo;
	EndIf;
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
Procedure FinishEditing(Command)
	Var Data, Item;
	// Putting the conditions into the transportable structure
	Data = New Array;
	For Each Condition In LogConditions Do
		Item = New Structure("Column, Condition, Value, Event, PresentationColumn");
		FillPropertyValues(Item, Condition);
		Data.Add(Item);
	EndDo;
	Close(Data);
EndProcedure
&AtClient
Procedure LogConditionsBeforeRowChange(Item, Cancel)
	Var CurrentData, FormParameters, AsynchronousCall;
	// Calling the condition editor
	CurrentData = Items.LogConditions.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	Cancel = True;
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
Procedure LogConditionsBeforeRowChangeCompletion(Result, AdditionalData) Export
	Var CurrentData;
	If TypeOf(Result) = Type("Structure") Then
		CurrentData = Items.LogConditions.CurrentData;
		CurrentData.Column = Result.Property;
		CurrentData.PresentationColumn = ColumnPresentation(Result.Property);
		CurrentData.Condition = Result.Condition;
		CurrentData.Value = Result.Value;
	EndIf;
EndProcedure
&AtClient
Procedure LogConditionsBeforeAddRow(Item, Cancel, Copy, Parent, Folder)
	Var FormParameters, AsynchronousCall;
	Cancel = True;
	// Calling the condition editor
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
Procedure LogConditionsBeforeAddRowCompletion(Result, AdditionalData) Export
	Var ListRow;
	If TypeOf(Result) = Type("Structure") Then
		ListRow = LogConditions.Add();
		ListRow.Column = Result.Property;
		ListRow.PresentationColumn = ColumnPresentation(Result.Property);
		ListRow.Condition = Result.Condition;
		ListRow.Value = Result.Value;
		ListRow.Event = Event;
		Items.LogConditions.CurrentRow = ListRow.GetID();
	EndIf;
EndProcedure
