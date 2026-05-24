#!/usr/bin/env pwsh
using namespace System.Diagnostics
using namespace System.Collections.Generic
using namespace System.Management.Automation.Language

class TimeLine {
  [List[TimeSpan]]$TimeSpans
  hidden [TimeSpan]$Total

  TimeLine() {
    $this.TimeSpans = [List[TimeSpan]]::new()
  }

  [void] Add([TimeSpan]$TimeSpan) {
    $this.TimeSpans.Add($TimeSpan)
    $this.Total = $this.Total.Add($TimeSpan)
  }

  [TimeSpan] GetTotal() {
    return $this.Total
  }

  [TimeSpan] GetAverage() {
    if ($this.GetCount() -eq 0) {
      return [TimeSpan]::Zero
    }

    return [TimeSpan]::FromTicks($this.GetTotal().Ticks / $this.GetCount())
  }

  [int] GetCount() {
    return $this.TimeSpans.Count
  }
  [string] ToString() {
    return "Total: $([Math]::Round($this.GetTotal().TotalMilliseconds, 2))ms Average: $([Math]::Round($this.GetAverage().TotalMilliseconds, 2))ms Count: $($this.GetCount())"
  }
}

class ExecMeasurement {
  [int]$LineNo
  [TimeSpan]$ExecutionTime
  [string] $Line
  [TimeLine] $TimeLine
  hidden [bool]$Top
  hidden [string]$SourceScript

  [string] ToString() {
    $output = "LineNo: $($this.LineNo.ToString()) ExecTime: $($this.ExecutionTime.ToString()) Line: $($this.Line.ToString()) TimeLine: $($this.TimeLine.ToString()) Top: $($this.Top.ToString()) Script: $($this.SourceScript.ToString())"
    if ($this.Top) {
      return "$([char]27)[91m$output$([char]27)[0m"
    }
    return $output
  }
}


#region AstVisitor
class PSPVisitor : ICustomAstVisitor, ICustomAstVisitor2 {
  [ExecTracer]$tracer = $null
  PSPVisitor([ExecTracer]$tracer) {
    $this.tracer = $tracer
  }
  [Object] VisitElement([object]$element) {
    if ($null -eq $element) {
      return $null
    }
    $res = $element.Visit($this)
    return $res
  }
  [Object] VisitElements([Object]$elements) {
    if ($null -eq $elements -or $elements.Count -eq 0) {
      return $null
    }
    $typeName = $elements.gettype().GenericTypeArguments.Fullname

    $newElements = New-Object -TypeName "System.Collections.Generic.List[$typeName]"
    foreach ($element in $elements) {
      $visitedResult = $element.Visit($this)
      $newElements.add($visitedResult)
    }
    return $newElements
  }
  [StatementAst[]] VisitStatements([object]$Statements) {
    $newStatements = [List[StatementAst]]::new()
    foreach ($statement in $statements) {
      [bool]$instrument = $statement -is [PipelineBaseAst]
      $extent = $statement.Extent
      if ($instrument) {
        $expressionAstCollection = [List[ExpressionAst]]::new()
        $constantExpression = [ConstantExpressionAst]::new($extent, $extent.StartLineNumber - 1)
        $expressionAstCollection.Add($constantExpression)
        $constantProfiler = [ConstantExpressionAst]::new($extent, $this.tracer)
        $constantStartline = [StringConstantExpressionAst]::new($extent, "StartLine", [StringConstantType]::BareWord)
        $invokeMember = [InvokeMemberExpressionAst]::new(
          $extent,
          $constantProfiler,
          $constantStartline,
          $expressionAstCollection,
          $false
        )
        $startLine = [CommandExpressionAst]::new(
          $extent,
          $invokeMember,
          $null
        )
        $pipe = [PipelineAst]::new($extent, $startLine);
        $newStatements.Add($pipe)
      }
      $newStatements.Add($this.VisitElement($statement))
      if ($instrument) {
        $expressionAstCollection = [List[ExpressionAst]]::new()
        $expressionAstCollection.Add([ConstantExpressionAst]::new($extent, $extent.StartLineNumber - 1))
        $endLine = [CommandExpressionAst]::new(
          $extent,
          [InvokeMemberExpressionAst]::new(
            $extent,
            [ConstantExpressionAst]::new($extent, $this.tracer),
            [StringConstantExpressionAst]::new($extent, "EndLine", [StringConstantType]::BareWord),
            $expressionAstCollection,
            $false
          ),
          $null
        )
        $pipe = [PipelineAst]::new($extent, $endLine)
        $newStatements.add($pipe)
      }
    }
    return $newStatements
  }

  [object] VisitScriptBlock([ScriptBlockAst] $scriptBlockAst) {
    $newParamBlock = $this.VisitElement($scriptBlockAst.ParamBlock)
    $newBeginBlock = $this.VisitElement($scriptBlockAst.BeginBlock)
    $newProcessBlock = $this.VisitElement($scriptBlockAst.ProcessBlock)
    $newEndBlock = $this.VisitElement($scriptBlockAst.EndBlock)
    $newdynamicParamBlock = $this.VisitElement($scriptBlockAst.dynamicParamBlock)
    return [ScriptBlockAst]::new($scriptBlockAst.Extent, $newParamBlock, $newBeginBlock, $newProcessBlock, $newEndBlock, $newdynamicParamBlock)
  }


  [object] VisitNamedBlock([NamedBlockAst] $namedBlockAst) {
    $newTraps = $this.VisitElements($namedBlockAst.Traps)
    $newStatements = $this.VisitStatements($namedBlockAst.Statements)
    $statementBlock = [StatementBlockAst]::new($namedBlockAst.Extent, $newStatements, $newTraps)
    return [NamedBlockAst]::new($namedBlockAst.Extent, $namedBlockAst.BlockKind, $statementBlock, $namedBlockAst.Unnamed)
  }

  [object] VisitFunctionDefinition([FunctionDefinitionAst] $functionDefinitionAst) {
    $newBody = $this.VisitElement($functionDefinitionAst.Body)
    return [FunctionDefinitionAst]::new($functionDefinitionAst.Extent, $functionDefinitionAst.IsFilter, $functionDefinitionAst.IsWorkflow, $functionDefinitionAst.Name, $this.VisitElements($functionDefinitionAst.Parameters), $newBody);
  }

  [object] VisitStatementBlock([StatementBlockAst] $statementBlockAst) {
    $newStatements = $this.VisitStatements($statementBlockAst.Statements)
    $newTraps = $this.VisitElements($statementBlockAst.Traps)
    return [StatementBlockAst]::new($statementBlockAst.Extent, $newStatements, $newTraps)
  }

  [object] VisitIfStatement([IfStatementAst] $ifStmtAst) {
    [Tuple[PipelineBaseAst, StatementBlockAst][]]$newClauses = @(foreach ($clause in $ifStmtAst.Clauses) {
        $newClauseTest = [PipelineBaseAst]$this.VisitElement($clause.Item1)
        $newStatementBlock = [StatementBlockAst]$this.VisitElement($clause.Item2)
        [Tuple[PipelineBaseAst, StatementBlockAst]]::new($newClauseTest, $newStatementBlock)
      }
    )
    $newElseClause = $this.VisitElement($ifStmtAst.ElseClause)
    return [IfStatementAst]::new($ifStmtAst.Extent, $newClauses, $newElseClause)
  }

  [object] VisitTrap([TrapStatementAst] $trapStatementAst) {
    return [TrapStatementAst]::new($trapStatementAst.Extent, $this.VisitElement($trapStatementAst.TrapType), $this.VisitElement($trapStatementAst.Body))
  }

  [object] VisitSwitchStatement([SwitchStatementAst] $switchStatementAst) {
    $newCondition = $this.VisitElement($switchStatementAst.Condition)
    $newClauses = [List[Tuple[ExpressionAst, StatementBlockAst]]]::new()
    $switchStatementAst.Clauses | ForEach-Object {
      $newClauseTest = $this.VisitElement($_.Item1)
      $newStatementBlock = $this.VisitElement($_.Item2)
      $newClauses.Add([Tuple[ExpressionAst, StatementBlockAst]]::new($newClauseTest, $newStatementBlock))
    }
    $newDefault = $this.VisitElement($switchStatementAst.Default)
    return [SwitchStatementAst]::new($switchStatementAst.Extent, $switchStatementAst.Label, $newCondition, $switchStatementAst.Flags, $newClauses, $newDefault)
  }

  [object] VisitDataStatement([DataStatementAst] $dataStatementAst) {
    $newBody = $this.VisitElement($dataStatementAst.Body)
    $newCommandsAllowed = $this.VisitElements($dataStatementAst.CommandsAllowed)
    return [DataStatementAst]::new($dataStatementAst.Extent, $dataStatementAst.Variable, $newCommandsAllowed, $newBody)
  }

  [object] VisitForEachStatement([ForEachStatementAst] $forEachStatementAst) {
    $newVariable = $this.VisitElement($forEachStatementAst.Variable)
    $newCondition = $this.VisitElement($forEachStatementAst.Condition)
    $newBody = $this.VisitElement($forEachStatementAst.Body)
    return [ForEachStatementAst]::new($forEachStatementAst.Extent, $forEachStatementAst.Label, [ForEachFlags]::None, $newVariable, $newCondition, $newBody)
  }

  [object] VisitDoWhileStatement([DoWhileStatementAst] $doWhileStatementAst) {
    $newCondition = $this.VisitElement($doWhileStatementAst.Condition)
    $newBody = $this.VisitElement($doWhileStatementAst.Body)
    return [DoWhileStatementAst]::new($doWhileStatementAst.Extent, $doWhileStatementAst.Label, $newCondition, $newBody)
  }

  [object] VisitForStatement([ForStatementAst] $forStatementAst) {
    $newInitializer = $this.VisitElement($forStatementAst.Initializer)
    $newCondition = $this.VisitElement($forStatementAst.Condition)
    $newIterator = $this.VisitElement($forStatementAst.Iterator)
    $newBody = $this.VisitElement($forStatementAst.Body)
    return [ForStatementAst]::new($forStatementAst.Extent, $forStatementAst.Label, $newInitializer, $newCondition, $newIterator, $newBody)
  }

  [object] VisitWhileStatement([WhileStatementAst] $whileStatementAst) {
    $newCondition = $this.VisitElement($whileStatementAst.Condition)
    $newBody = $this.VisitElement($whileStatementAst.Body)
    return [WhileStatementAst]::new($whileStatementAst.Extent, $whileStatementAst.Label, $newCondition, $newBody)
  }

  [object] VisitCatchClause([CatchClauseAst] $catchClauseAst) {
    $newBody = $this.VisitElement($catchClauseAst.Body)
    $newCatchTypes = $this.VisitElements($catchClauseAst.CatchTypes)
    return [CatchClauseAst]::new($catchClauseAst.Extent, $newCatchTypes, $newBody)
  }

  [object] VisitTryStatement([TryStatementAst] $tryStatementAst) {
    $newBody = $this.VisitElement($tryStatementAst.Body)
    $newCatchClauses = $this.VisitElements($tryStatementAst.CatchClauses)
    $newFinally = $this.VisitElement($tryStatementAst.Finally)
    return [TryStatementAst]::new($tryStatementAst.Extent, $newBody, $newCatchClauses, $newFinally)
  }

  [object] VisitDoUntilStatement([DoUntilStatementAst] $doUntilStatementAst) {
    $newCondition = $this.VisitElement($doUntilStatementAst.Condition)
    $newBody = $this.VisitElement($doUntilStatementAst.Body)
    return [DoUntilStatementAst]::new($doUntilStatementAst.Extent, $doUntilStatementAst.Label, $newCondition, $newBody)
  }

  [object] VisitParamBlock([ParamBlockAst] $paramBlockAst) {
    $newAttributes = $this.VisitElements($paramBlockAst.Attributes)
    $newParameters = $this.VisitElements($paramBlockAst.Parameters)
    return [ParamBlockAst]::new($paramBlockAst.Extent, $newAttributes, $newParameters)
  }

  [object] VisitErrorStatement([ErrorStatementAst] $errorStatementAst) {
    return $errorStatementAst
  }

  [object] VisitErrorExpression([ErrorExpressionAst] $errorExpressionAst) {
    return $errorExpressionAst
  }

  [object] VisitTypeConstraint([TypeConstraintAst] $typeConstraintAst) {
    return [TypeConstraintAst]::new($typeConstraintAst.Extent, $typeConstraintAst.TypeName)
  }

  [object] VisitAttribute([AttributeAst] $attributeAst) {
    $newPositionalArguments = $this.VisitElements($attributeAst.PositionalArguments)
    $newNamedArguments = $this.VisitElements($attributeAst.NamedArguments)
    return [AttributeAst]::new($attributeAst.Extent, $attributeAst.TypeName, $newPositionalArguments, $newNamedArguments)
  }

  [object] VisitNamedAttributeArgument([NamedAttributeArgumentAst] $namedAttributeArgumentAst) {
    $newArgument = $this.VisitElement($namedAttributeArgumentAst.Argument)
    return [NamedAttributeArgumentAst]::new($namedAttributeArgumentAst.Extent, $namedAttributeArgumentAst.ArgumentName, $newArgument, $namedAttributeArgumentAst.ExpressionOmitted)
  }

  [object] VisitParameter([ParameterAst] $parameterAst) {
    $newName = $this.VisitElement($parameterAst.Name)
    $newAttributes = $this.VisitElements($parameterAst.Attributes)
    $newDefaultValue = $this.VisitElement($parameterAst.DefaultValue)
    return [ParameterAst]::new($parameterAst.Extent, $newName, $newAttributes, $newDefaultValue)
  }

  [object] VisitBreakStatement([BreakStatementAst] $breakStatementAst) {
    $newLabel = $this.VisitElement($breakStatementAst.Label)
    return [BreakStatementAst]::new($breakStatementAst.Extent, $newLabel)
  }

  [object] VisitContinueStatement([ContinueStatementAst] $continueStatementAst) {
    $newLabel = $this.VisitElement($continueStatementAst.Label)
    return [ContinueStatementAst]::new($continueStatementAst.Extent, $newLabel)
  }

  [object] VisitReturnStatement([ReturnStatementAst] $returnStatementAst) {
    $newPipeline = $this.VisitElement($returnStatementAst.Pipeline)
    return [ReturnStatementAst]::new($returnStatementAst.Extent, $newPipeline)
  }

  [object] VisitExitStatement([ExitStatementAst] $exitStatementAst) {
    $newPipeline = $this.VisitElement($exitStatementAst.Pipeline)
    return [ExitStatementAst]::new($exitStatementAst.Extent, $newPipeline)
  }

  [object] VisitThrowStatement([ThrowStatementAst] $throwStatementAst) {
    $newPipeline = $this.VisitElement($throwStatementAst.Pipeline)
    return [ThrowStatementAst]::new($throwStatementAst.Extent, $newPipeline)
  }

  [object] VisitAssignmentStatement([AssignmentStatementAst] $assignmentStatementAst) {
    $newLeft = $this.VisitElement($assignmentStatementAst.Left)
    $newRight = $this.VisitElement($assignmentStatementAst.Right)
    return [AssignmentStatementAst]::new($assignmentStatementAst.Extent, $newLeft, $assignmentStatementAst.Operator, $newRight, $assignmentStatementAst.ErrorPosition)
  }

  [object] VisitPipeline([PipelineAst] $pipelineAst) {
    $newPipeElements = $this.VisitElements($pipelineAst.PipelineElements)
    return [PipelineAst]::new($pipelineAst.Extent, $newPipeElements)
  }

  [object] VisitCommand([CommandAst] $commandAst) {
    $newCommandElements = $this.VisitElements($commandAst.CommandElements)
    $newRedirections = $this.VisitElements($commandAst.Redirections)
    return [CommandAst]::new($commandAst.Extent, $newCommandElements, $commandAst.InvocationOperator, $newRedirections)
  }

  [object] VisitCommandExpression([CommandExpressionAst] $commandExpressionAst) {
    $newExpression = $this.VisitElement($commandExpressionAst.Expression)
    $newRedirections = $this.VisitElements($commandExpressionAst.Redirections)
    return [CommandExpressionAst]::new($commandExpressionAst.Extent, $newExpression, $newRedirections)
  }

  [object] VisitCommandParameter([CommandParameterAst] $commandParameterAst) {
    $newArgument = $this.VisitElement($commandParameterAst.Argument)
    return [CommandParameterAst]::new($commandParameterAst.Extent, $commandParameterAst.ParameterName, $newArgument, $commandParameterAst.ErrorPosition)
  }

  [object] VisitFileRedirection([FileRedirectionAst] $fileRedirectionAst) {
    $newFile = $this.VisitElement($fileRedirectionAst.Location)
    return [FileRedirectionAst]::new($fileRedirectionAst.Extent, $fileRedirectionAst.FromStream, $newFile, $fileRedirectionAst.Append)
  }

  [object] VisitMergingRedirection([MergingRedirectionAst] $mergingRedirectionAst) {
    return [MergingRedirectionAst]::new($mergingRedirectionAst.Extent, $mergingRedirectionAst.FromStream, $mergingRedirectionAst.ToStream)
  }

  [object] VisitBinaryExpression([BinaryExpressionAst] $binaryExpressionAst) {
    $newLeft = $this.VisitElement($binaryExpressionAst.Left)
    $newRight = $this.VisitElement($binaryExpressionAst.Right)
    return [BinaryExpressionAst]::new($binaryExpressionAst.Extent, $newLeft, $binaryExpressionAst.Operator, $newRight, $binaryExpressionAst.ErrorPosition)
  }

  [object] VisitUnaryExpression([UnaryExpressionAst] $unaryExpressionAst) {
    $newChild = $this.VisitElement($unaryExpressionAst.Child)
    return [UnaryExpressionAst]::new($unaryExpressionAst.Extent, $unaryExpressionAst.TokenKind, $newChild)
  }

  [object] VisitConvertExpression([ConvertExpressionAst] $convertExpressionAst) {
    $newChild = $this.VisitElement($convertExpressionAst.Child)
    $newTypeConstraint = $this.VisitElement($convertExpressionAst.Type)
    return [ConvertExpressionAst]::new($convertExpressionAst.Extent, $newTypeConstraint, $newChild)
  }

  [object] VisitTypeExpression([TypeExpressionAst] $typeExpressionAst) {
    return [TypeExpressionAst]::new($typeExpressionAst.Extent, $typeExpressionAst.TypeName)
  }

  [object] VisitConstantExpression([ConstantExpressionAst] $constantExpressionAst) {
    return [ConstantExpressionAst]::new($constantExpressionAst.Extent, $constantExpressionAst.Value)
  }

  [object] VisitStringConstantExpression([StringConstantExpressionAst] $stringConstantExpressionAst) {
    return [StringConstantExpressionAst]::new($stringConstantExpressionAst.Extent, $stringConstantExpressionAst.Value, $stringConstantExpressionAst.StringConstantType)
  }

  [object] VisitSubExpression([SubExpressionAst] $subExpressionAst) {
    $newStatementBlock = $this.VisitElement($subExpressionAst.SubExpression)
    return [SubExpressionAst]::new($subExpressionAst.Extent, $newStatementBlock)
  }

  [object] VisitUsingExpression([UsingExpressionAst] $usingExpressionAst) {
    $newUsingExpr = $this.VisitElement($usingExpressionAst.SubExpression)
    return [UsingExpressionAst]::new($usingExpressionAst.Extent, $newUsingExpr)
  }

  [object] VisitVariableExpression([VariableExpressionAst] $variableExpressionAst) {
    return [VariableExpressionAst]::new($variableExpressionAst.Extent, $variableExpressionAst.VariablePath.UserPath, $variableExpressionAst.Splatted)
  }

  [object] VisitMemberExpression([MemberExpressionAst] $memberExpressionAst) {
    $newExpr = $this.VisitElement($memberExpressionAst.Expression)
    $newMember = $this.VisitElement($memberExpressionAst.Member)
    return [MemberExpressionAst]::new($memberExpressionAst.Extent, $newExpr, $newMember, $memberExpressionAst.Static)
  }

  [object] VisitInvokeMemberExpression([InvokeMemberExpressionAst] $invokeMemberExpressionAst) {
    $newExpression = $this.VisitElement($invokeMemberExpressionAst.Expression)
    $newMethod = $this.VisitElement($invokeMemberExpressionAst.Member)
    $newArguments = $this.VisitElements($invokeMemberExpressionAst.Arguments)
    return [InvokeMemberExpressionAst]::new($invokeMemberExpressionAst.Extent, $newExpression, $newMethod, $newArguments, $invokeMemberExpressionAst.Static)
  }

  [object] VisitArrayExpression([ArrayExpressionAst] $arrayExpressionAst) {
    $newStatementBlock = $this.VisitElement($arrayExpressionAst.SubExpression)
    return [ArrayExpressionAst]::new($arrayExpressionAst.Extent, $newStatementBlock)
  }

  [object] VisitArrayLiteral([ArrayLiteralAst] $arrayLiteralAst) {
    $newArrayElements = $this.VisitElements($arrayLiteralAst.Elements)
    return [ArrayLiteralAst]::new($arrayLiteralAst.Extent, $newArrayElements)
  }

  [object] VisitHashtable([HashtableAst] $hashtableAst) {
    $newKeyValuePairs = [List[Tuple[ExpressionAst, StatementAst]]]::new()
    foreach ($keyValuePair in $hashtableAst.KeyValuePairs) {
      $newKey = $this.VisitElement($keyValuePair.Item1);
      $newValue = $this.VisitElement($keyValuePair.Item2);
      $newKeyValuePairs.Add([Tuple[ExpressionAst, StatementAst]]::new($newKey, $newValue))
    }
    return [HashtableAst]::new($hashtableAst.Extent, $newKeyValuePairs)
  }

  [object] VisitScriptBlockExpression([ScriptBlockExpressionAst] $scriptBlockExpressionAst) {
    $newScriptBlock = $this.VisitElement($scriptBlockExpressionAst.ScriptBlock)
    return [ScriptBlockExpressionAst]::new($scriptBlockExpressionAst.Extent, $newScriptBlock)
  }

  [object] VisitParenExpression([ParenExpressionAst] $parenExpressionAst) {
    $newPipeline = $this.VisitElement($parenExpressionAst.Pipeline)
    return [ParenExpressionAst]::new($parenExpressionAst.Extent, $newPipeline)
  }

  [object] VisitExpandableStringExpression([ExpandableStringExpressionAst] $expandableStringExpressionAst) {
    return [ExpandableStringExpressionAst]::new($expandableStringExpressionAst.Extent, $expandableStringExpressionAst.Value, $expandableStringExpressionAst.StringConstantType)
  }

  [object] VisitIndexExpression([IndexExpressionAst] $indexExpressionAst) {
    $newTargetExpression = $this.VisitElement($indexExpressionAst.Target)
    $newIndexExpression = $this.VisitElement($indexExpressionAst.Index)
    return [IndexExpressionAst]::new($indexExpressionAst.Extent, $newTargetExpression, $newIndexExpression)
  }

  [object] VisitAttributedExpression([AttributedExpressionAst] $attributedExpressionAst) {
    $newAttribute = $this.VisitElement($attributedExpressionAst.Attribute)
    $newChild = $this.VisitElement($attributedExpressionAst.Child)
    return [AttributedExpressionAst]::new($attributedExpressionAst.Extent, $newAttribute, $newChild)
  }

  [object] VisitBlockStatement([BlockStatementAst] $blockStatementAst) {
    $newBody = $this.VisitElement($blockStatementAst.Body)
    return [BlockStatementAst]::new($blockStatementAst.Extent, $blockStatementAst.Kind, $newBody)
  }

  [object] VisitTypeDefinition([TypeDefinitionAst] $typeDefinitionAst) {
    $newAttributes = $this.VisitElements($typeDefinitionAst.Attributes)
    $newBaseTypes = $this.VisitElements($typeDefinitionAst.BaseTypes)
    $newMembers = $this.VisitElements($typeDefinitionAst.Members)

    return [TypeDefinitionAst]::new($typeDefinitionAst.Extent, $typeDefinitionAst.Name, $newAttributes, $newMembers, $typeDefinitionAst.TypeAttributes, $newBaseTypes)
  }

  [object] VisitPropertyMember([PropertyMemberAst] $propertyMemberAst) {
    $newPropertyType = $this.VisitElement($propertyMemberAst.PropertyType)
    $newAttributes = $this.VisitElements($propertyMemberAst.Attributes)
    $newInitValue = $this.VisitElement($propertyMemberAst.InitialValue)
    return [PropertyMemberAst]::new($propertyMemberAst.Extent, $propertyMemberAst.Name, $newPropertyType, $newAttributes, $propertyMemberAst.PropertyAttributes, $newInitValue)
  }

  [object] VisitFunctionMember([FunctionMemberAst] $functionMemberAst) {
    $newBody = $this.VisitElement($functionMemberAst.Body)
    $newParameters = $this.VisitElements($functionMemberAst.Parameters)
    $newFunctionDefinition = $this.VisitElement($functionMemberAst.Extent, $false, $false, $functionMemberAst.Name, $newParameters, $newBody)

    $newReturnType = $this.VisitElement($functionMemberAst.ReturnType)
    $newAttributes = $this.VisitElements($functionMemberAst.Attributes)
    return [FunctionMemberAst]::new($functionMemberAst.Extent, $newFunctionDefinition, $newReturnType, $newAttributes, $functionMemberAst.MethodAttributes)
  }

  [object] VisitBaseCtorInvokeMemberExpression([BaseCtorInvokeMemberExpressionAst] $baseCtorAst) {
    $newInvokeMemberExpression = $this.VisitInvokeMemberExpression($baseCtorAst)
    return [BaseCtorInvokeMemberExpressionAst]::new($baseCtorAst.Expression.Extent, $newInvokeMemberExpression.Extent, $newInvokeMemberExpression)
  }

  [object] VisitUsingStatement([UsingStatementAst] $usingStatementAst) {
    $newName = $this.VisitElement($usingStatementAst.Name)
    $newAlias = if ($usingStatementAst.Alias -is [StringConstantExpressionAst]) {
      $this.VisitElement($usingStatementAst.Alias)
    }

    switch ($usingStatementAst.UsingStatementKind) {
      'Module' {
        if ($usingStatementAst.ModuleSpecification -is [HashtableAst]) {
          $newModuleSpec = $this.VisitElement($usingStatementAst.ModuleSpecification)
          if ($newAlias) {
            return [UsingStatementAst]::new($usingStatementAst.Extent, $newName, $newModuleSpec)
          }
          return [UsingStatementAst]::new($usingStatementAst.Extent, $newModuleSpec)
        }
        if ($newAlias) {
          return [UsingStatementAst]::new($usingStatementAst.Extent, $_, $newName, $newAlias)
        }
        return [UsingStatementAst]::new($usingStatementAst.Extent, $_, $newName)
      }

      default {
        if ($newAlias) {
          return [UsingStatementAst]::new($usingStatementAst.Extent, $_, $newName, $newAlias)
        }
        return [UsingStatementAst]::new($usingStatementAst.Extent, $_, $newName)
      }
    }

    throw [System.NotImplementedException]::new()
  }

  [object] VisitConfigurationDefinition([ConfigurationDefinitionAst]$configDefinitionAst) {
    $newConfig = $this.VisitElement($configDefinitionAst.Body)
    $newInstanceName = $this.VisitElement($configDefinitionAst.InstanceName)
    return [ConfigurationDefinitionAst]::new($configDefinitionAst.Extent, $newConfig, $configDefinitionAst.ConfigurationType, $newInstanceName)
  }

  [object] VisitDynamicKeywordStatement([DynamicKeywordStatementAst]$dynamicKeywordAst) {
    $newElements = $this.VisitElements($dynamicKeywordAst.CommandElements)
    return [DynamicKeywordStatementAst]::new($dynamicKeywordAst.Extent, $newElements)
  }

  # V7 nodes
  [object] VisitTernaryExpression([TernaryExpressionAst]$ternaryExpressionAst) {
    $newCondition = $this.VisitElement($ternaryExpressionAst.Condition)
    $newIfTrue = $this.VisitElement($ternaryExpressionAst.IfTrue)
    $newIfFalse = $this.VisitElement($ternaryExpressionAst.IfFalse)
    return [TernaryExpressionAst]::new($ternaryExpressionAst.Extent, $newCondition, $newIfTrue, $newIfFalse)
  }

  [object] VisitPipelineChain([PipelineChainAst]$pipelineChainAst) {
    $newLhsPipeline = $this.VisitElement($pipelineChainAst.LhsPipelineChain)
    $newRhsPipeline = $this.VisitElement($pipelineChainAst.RhsPipeline)
    return [PipelineChainAst]::new($pipelineChainAst.Extent, $newLhsPipeline, $newRhsPipeline, $pipelineChainAst.Operator, $pipelineChainAst.Background)
  }
}
#endregion

<#
.SYNOPSIS
  The ExecTracer class
.DESCRIPTION
  The ExecTracer class tracks the exact execution time of every individual statement.
  By exclusively relying on static methods and internal class structures, it removes the performance overhead and scope-binding constraints of standard Cmdlet functions.

.EXAMPLE
  $measurements = [ExecTracer]::TraceCommand({
      Get-Service | ForEach-Object {
          $_.name + " is " + $_.Status
      }
  }, $null, $null, "ServiceTrace")

  # To print as table : $measurements | Format-Table
  # To print as string:
  [ExecTracer]::HighlightTop($measurements)


  Measures the anonymous script block and returns the times executed for each line, formatting it into a viewable table.

.EXAMPLE
  $slowestLine = [ExecTracer]::WhyScriptNotFast("c:\scripts\GenerateUsername.ps1", "ExecutionResult", @{ GivenName = "Joe"; Surname = "Smith" }, $null)

  Executes the specified script file with hashtable arguments and stores the result in $ExecutionResult.
  It returns the single slowest [ExecMeasurement] line of execution for performance troubleshooting.
.EXAMPLE
  try {
    [ExecTracer]::TraceCommand({
        Get-Process | ForEach-Object {
            throw "Intentional Error"
        }
    }, $null, $null, "ErrorTraceTest")
  } catch {
    # The command will fail.
    # Retrieve the backwards trace from where it broke:
    [ExecTracer]::GetErrorTrace()
  }
#>
class ExecTracer {
  [int]$Offset
  [TimeLine[]]$TimeLines
  [Stopwatch[]]$StopWatches
  static [System.Collections.Generic.List[hashtable]]$CallLog = @()
  static [System.Collections.Generic.List[string]]$LastErrorStack = [System.Collections.Generic.List[string]]::new()
  static [System.Collections.Concurrent.ConcurrentStack[string]]$Stack = [System.Collections.Concurrent.ConcurrentStack[string]]::new()

  static [string[]] GetErrorTrace() {
    return [ExecTracer]::LastErrorStack.ToArray()
  }

  ExecTracer([IScriptExtent]$extent) {
    $lines = $extent.EndLineNumber
    $this.Offset = $extent.StartLineNumber - 1
    $this.StopWatches = [Stopwatch[]]::new($lines)
    $this.TimeLines = [TimeLine[]]::new($lines)

    for ($i = 0; $i -lt $lines; $i++) {
      $this.StopWatches[$i] = [Stopwatch]::new()
      $this.TimeLines[$i] = [TimeLine]::new()
    }
  }

  static [ExecMeasurement[]] TraceCommand([string]$Path, [string]$ExecutionResultVariable, [hashtable]$Arguments, [string]$Name) {
    return [ExecTracer]::TraceCommand($Path, $ExecutionResultVariable, $Arguments, $Name, 5)
  }

  static [ExecMeasurement[]] TraceCommand([string]$Path, [string]$ExecutionResultVariable, [hashtable]$Arguments, [string]$Name, [int]$Top) {
    if (!(Test-Path $Path)) {
      throw "No such file: '$Path'"
    }

    $Errors = [System.Collections.ObjectModel.Collection[System.Management.Automation.Language.ParseError]]::new()
    $Ast = [System.Management.Automation.Language.Parser]::ParseFile((Get-Item $Path).FullName, [ref]$null, [ref]$Errors)
    if ($Errors.Count -gt 0) {
      Write-Error -Message "Encountered errors while parsing '$Path'"
    }

    $Source = $Path
    if (![string]::IsNullOrEmpty($Name)) {
      $Source = "{0}: {1}$Name" -f $Source, [System.Environment]::NewLine
    }

    $ExecTracer = [ExecTracer]::new($Ast.Extent)
    $visitor = [PSPVisitor]::new($ExecTracer)
    $newAst = $Ast.Visit($visitor)

    $MeasureScriptblock = $newAst.GetScriptBlock()

    $errCountBefore = (Get-Variable -Name Error -ValueOnly -Scope Global).Count
    try {
      if ([string]::IsNullOrEmpty($ExecutionResultVariable)) {
        if ($null -ne $Arguments) {
          $null = & $MeasureScriptblock @Arguments
        } else {
          $null = & $MeasureScriptblock
        }
      } else {
        if ($null -ne $Arguments) {
          $executionResult = . $MeasureScriptblock @Arguments
        } else {
          $executionResult = . $MeasureScriptblock
        }
        Set-Variable -Name $ExecutionResultVariable -Value $executionResult -Scope 1 -ErrorAction SilentlyContinue
      }
    } catch {
      [ExecTracer]::LastErrorStack.Clear()
      $globalError = Get-Variable -Name Error -ValueOnly -Scope Global
      $newErrCount = $globalError.Count - $errCountBefore
      for ($i = 0; $i -lt $newErrCount; $i++) {
        $e = $globalError[$i]
        if ($null -ne $e.ScriptStackTrace) {
          [ExecTracer]::LastErrorStack.Add($e.ScriptStackTrace)
        } elseif ($null -ne $e.Exception -and $null -ne $e.Exception.StackTrace) {
          [ExecTracer]::LastErrorStack.Add($e.Exception.StackTrace)
        }
      }
      Write-Warning "ExecTracer caught an error. Evaluation stack traces saved to [ExecTracer]::LastErrorStack."
      throw $_
    }

    return [ExecTracer]::BuildMeasurements($ExecTracer, $Source, $Ast, $Top)
  }

  static [ExecMeasurement[]] TraceCommand([scriptblock]$ScriptBlock, [string]$ExecutionResultVariable, [hashtable]$Arguments, [string]$Name) {
    return [ExecTracer]::TraceCommand($ScriptBlock, $ExecutionResultVariable, $Arguments, $Name, 5)
  }

  static [ExecMeasurement[]] TraceCommand([scriptblock]$ScriptBlock, [string]$ExecutionResultVariable, [hashtable]$Arguments, [string]$Name, [int]$Top) {
    $Ast = $ScriptBlock.Ast
    $Source = '{{{0}}}' -f [guid]::NewGuid().ToString().Replace('-', '')

    $ssiPropertyInfo = [scriptblock].GetProperty('SessionStateInternal', [System.Reflection.BindingFlags]'Instance,NonPublic')
    $callerSessionState = $null
    if ($null -ne $ssiPropertyInfo) {
      $callerSessionState = $ssiPropertyInfo.GetValue($ScriptBlock)
    }

    if (![string]::IsNullOrEmpty($Name)) {
      $Source = "{0}: {1}$Name" -f $Source, [System.Environment]::NewLine
    }

    $ExecTracer = [ExecTracer]::new($Ast.Extent)
    $visitor = [PSPVisitor]::new($ExecTracer)
    $newAst = $Ast.Visit($visitor)

    $MeasureScriptblock = $newAst.GetScriptBlock()
    if ($null -ne $callerSessionState -and $null -ne $ssiPropertyInfo) {
      $ssiPropertyInfo.SetValue($MeasureScriptblock, $callerSessionState)
    }
    try {
      if ([string]::IsNullOrEmpty($ExecutionResultVariable)) {
        if ($null -ne $Arguments) {
          $null = & $MeasureScriptblock @Arguments
        } else {
          $null = & $MeasureScriptblock
        }
      } else {
        if ($null -ne $Arguments) {
          $executionResult = . $MeasureScriptblock @Arguments
        } else {
          $executionResult = . $MeasureScriptblock
        }
        Set-Variable -Name $ExecutionResultVariable -Value $executionResult -Scope 1 -ErrorAction SilentlyContinue
      }
    } catch {
      [ExecTracer]::LastErrorStack.Clear()

      $internalStack = [ExecTracer]::Stack.ToArray()
      if ($null -ne $internalStack -and $internalStack.Length -gt 0) {
        [ExecTracer]::LastErrorStack.Add("--- ExecTracer Execution Stack ---")
        [ExecTracer]::LastErrorStack.AddRange($internalStack)
        [ExecTracer]::LastErrorStack.Add("")
      }

      [ExecTracer]::LastErrorStack.Add("--- Exception Trace ---")
      if (![string]::IsNullOrEmpty($_.ScriptStackTrace)) {
        [ExecTracer]::LastErrorStack.Add($_.ScriptStackTrace)
      }

      $ex = $_.Exception
      while ($null -ne $ex) {
        if (![string]::IsNullOrEmpty($ex.StackTrace)) {
          [ExecTracer]::LastErrorStack.Add($ex.StackTrace)
        }
        $ex = $ex.InnerException
      }

      $traceOutput = [ExecTracer]::LastErrorStack.ToArray() -join "`n"
      Write-Error "ExecTracer caught an engine error. Traceback recorded:`n$traceOutput"
      throw $_
    }

    return [ExecTracer]::BuildMeasurements($ExecTracer, $Source, $Ast, $Top)
  }

  static [ExecMeasurement[]] BuildMeasurements([ExecTracer]$Tracer, [string]$Source, [System.Management.Automation.Language.Ast]$Ast, [int]$Top) {
    [string[]]$lines = $Ast.Extent.ToString() -split '\r?\n' | ForEach-Object TrimEnd

    $executionTimes = [System.Collections.Generic.List[TimeSpan]]::new()
    for ($i = 0; $i -lt $lines.Count; $i++) {
      $executionTimes.Add($Tracer.TimeLines[$i].GetTotal())
    }

    $topLimit = [long]::MaxValue
    if ($Top -gt 0) {
      $topTimeSpan = $executionTimes.ToArray() | Where-Object { $_.Ticks -gt 0 } | Sort-Object -Descending | Select-Object -First $Top | Select-Object -Last 1
      if ($null -ne $topTimeSpan) {
        $topLimit = $topTimeSpan.Ticks
      }
    }

    $results = [System.Collections.Generic.List[ExecMeasurement]]::new()
    for ($i = 0; $i -lt $lines.Count; $i++) {
      $measurement = [ExecMeasurement]::new()
      $measurement.LineNo = $i + 1
      $measurement.ExecutionTime = $executionTimes[$i]
      $measurement.TimeLine = $Tracer.TimeLines[$i]
      $measurement.Line = $lines[$i]
      $measurement.SourceScript = $Source
      $measurement.Top = ($executionTimes[$i].Ticks -gt 0 -and $executionTimes[$i].Ticks -ge $topLimit)
      $results.Add($measurement)
    }

    return $results.ToArray()
  }

  static [ExecMeasurement] WhyScriptNotFast([string]$Path, [string]$ExecutionResultVariable, [hashtable]$Arguments, [string]$Name) {
    $measurements = [ExecTracer]::TraceCommand($Path, $ExecutionResultVariable, $Arguments, $Name, 5)
    return $measurements | Sort-Object ExecutionTime | Select-Object -Last 1
  }
  static [ExecMeasurement] WhyScriptNotFast([scriptblock]$ScriptBlock, [string]$ExecutionResultVariable, [hashtable]$Arguments, [string]$Name) {
    $measurements = [ExecTracer]::TraceCommand($ScriptBlock, $ExecutionResultVariable, $Arguments, $Name, 5)
    return $measurements | Sort-Object ExecutionTime | Select-Object -Last 1
  }

  static [string[]] HighlightTop([ExecMeasurement[]]$Measurements) {
    if ($null -eq $Measurements) { return @() }

    $results = [System.Collections.Generic.List[string]]::new()
    $results.Add("LineNo".PadLeft(6) + " " + "ExecutionTime".PadRight(15) + " " + "Line".PadRight(40) + " " + "TimeLine")
    $results.Add("------".PadLeft(6) + " " + "-------------".PadRight(15) + " " + "----".PadRight(40) + " " + "--------")

    foreach ($m in $Measurements) {
      $lineNoStr = $m.LineNo.ToString().PadLeft(6)
      $execStr = $m.ExecutionTime.ToString("hh\:mm\:ss\.fffffff").PadRight(15)

      $lineText = $m.Line
      if ($null -eq $lineText) { $lineText = "" }
      if ($lineText.Length -gt 38) { $lineText = $lineText.Substring(0, 38) + ".." }

      $output = "$lineNoStr $execStr $($lineText.PadRight(40)) $($m.TimeLine.ToString())"

      if ($m.Top) {
        $results.Add("$([char]27)[91m$output$([char]27)[0m")
      } else {
        $results.Add($output)
      }
    }
    return $results.ToArray()
  }

  [void] StartLine([int] $lineNo) {
    $this.StopWatches[$lineNo - $this.Offset].Start()
  }

  [void] EndLine([int] $lineNo) {
    $lineNo -= $this.Offset
    $this.StopWatches[$lineNo].Stop()
    $this.TimeLines[$lineNo].Add($this.StopWatches[$lineNo].Elapsed)
    $this.StopWatches[$lineNo].Reset()
  }
  static [void] Push([string]$class) {
    $str = "[{0}]" -f $class
    if ([ExecTracer]::Peek() -ne "$class") {
      [ExecTracer]::stack.Push($str)
      $LAST_ERROR = $(Get-Variable -Name Error -ValueOnly)[0]
      [ExecTracer]::CallLog.Add(@{ ($str + ' @ ' + [datetime]::Now.ToShortTimeString()) = $(if ($null -ne $LAST_ERROR) { $LAST_ERROR.ScriptStackTrace } else { [System.Environment]::StackTrace }).Split("`n").Replace("at ", "# ").Trim() })
    }
  }
  static [type] Pop() {
    $result = $null
    if ([ExecTracer]::stack.TryPop([ref]$result)) {
      return $result
    } else {
      throw [System.InvalidOperationException]::new("Stack is empty!")
    }
  }
  static [string] Peek() {
    $result = $null
    if ([ExecTracer]::stack.TryPeek([ref]$result)) {
      return $result
    } else {
      return [string]::Empty
    }
  }
  static [int] GetSize() {
    return [ExecTracer]::stack.Count
  }
  static [bool] IsEmpty() {
    return [ExecTracer]::stack.IsEmpty
  }
}


