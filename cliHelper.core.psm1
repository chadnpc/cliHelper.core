#!/usr/bin/env pwsh
using namespace System

#Requires -Modules cliHelper.xconvert, cryptobase
#Requires -Psedition Core

# Load all sub-modules :
# use scripts\generate_sub_modules_list.ps1

using module Private\Console\Ansi.psm1
using module Private\Console\Boxes.psm1
using module Private\Console\Charts.psm1
using module Private\Console\Colors.psm1
using module Private\Console\Emojis.psm1
using module Private\Console\Enums.psm1
using module Private\Console\Figlet.psm1
using module Private\Console\Internal.psm1
using module Private\Console\Json.psm1
using module Private\Console\Layout.psm1
using module Private\Console\List.psm1
using module Private\Console\Live.psm1
using module Private\Console\Progress.psm1
using module Private\Console\Prompts.psm1
using module Private\Console\Renderer.psm1
using module Private\Console\Rendering.psm1
using module Private\Console\Spinners.psm1
using module Private\Console\Status.psm1
using module Private\Console\Syntax.psm1
using module Private\Console\Table.psm1
using module Private\Console\TableRenderer.psm1
using module Private\Console\Tables.psm1
using module Private\Console\Tree.psm1
using module Private\Console\Ui.psm1
using module Private\Console\Utilities.psm1
using module Private\Console\Widgets.psm1
using module Private\AntiVirus.psm1
using module Private\Capstone.psm1
using module Private\COMInterop.psm1
using module Private\Config.psm1
using module Private\Connectivity.psm1
using module Private\Console.psm1
using module Private\DllUtils.psm1
using module Private\DNS.psm1
using module Private\Enums.psm1
using module Private\ErrorMan.psm1
using module Private\Exceptions.psm1
using module Private\ExecTracer.psm1
using module Private\FontMan.psm1
using module Private\FTP.psm1
using module Private\Geolocation.psm1
using module Private\HelpTools.psm1
using module Private\IPManagement.psm1
using module Private\Models.psm1
using module Private\MotdGen.psm1
using module Private\Network.psm1
using module Private\Proxy.psm1
using module Private\Result.psm1
using module Private\Runner.psm1
using module Private\Security.psm1
using module Private\Utilities.psm1
using module Private\WebTools.psm1

$global:OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

# Types that will be available to users when they import the module.
# Hint: To automatically update the typestoexport variable you can use:
# scripts\update_exportable_types.ps1

$typestoExport = @(
  [AnsiCapabilities], [AnsiCodeBuilder], [AnsiWriter], [AnsiLink], [AnsiMarkupSegment], [AnsiMarkup], [BoxBorder], [NoBoxBorder], [AsciiBoxBorder], [SquareBoxBorder], [RoundedBoxBorder], [HeavyBoxBorder], [DoubleBoxBorder], [BarChartItem], [BarChart], [BreakdownChartItem], [BreakdownChart], [ColorTable], [Color], [RGB], [Emoji], [EmojiParser], [EmojiEmitter], [EmojiGenerator], [VerticalAlignment], [VerticalOverflow], [VerticalOverflowCropping], [InteractionSupport], [CursorDirection], [Justify], [Overflow], [HorizontalAlignment], [JsonTokenType], [Decoration], [ColorSystemSupport], [ColorSystem], [AnsiSupport], [ListPromptInputResult], [BoxBorderPart], [TableBorderPart], [TreeGuidePart], [TreePart], [TablePart], [FigletLayoutMode], [FigletFontName], [Measurement], [RenderOptions], [IRenderable], [IAnsiConsoleCursor], [IAnsiConsoleInput], [IExclusivityMode], [IAnsiConsole], [FigletHeader], [FigletCharacter], [FigletFontParser], [FigletFont], [FigletText], [Cell], [Constants], [DecorationTable], [DefaultExclusivityMode], [ResourceReader], [TypeConverterHelper], [NoopCursor], [NoopExclusivityMode], [ConsoleCoordinate], [ConsoleReader], [ConsoleWriter], [SerializerSettings], [NewtonsoftJson], [SerializerOptionsBuilder], [JsonTextSerializer], [HttpJsonSerializer], [JsonToken], [JsonTokenizer], [JsonParser], [JsonText], [Rows], [Columns], [GridColumn], [Grid], [ListPromptConstants], [ListPromptItem], [ListPromptKeyInput], [ListPromptState], [ListPromptTree], [ListPromptRenderHoo], [ListPrompt], [LiveDisplayContext], [LiveDisplaySession], [LiveDisplay], [ProgressTaskState], [ProgressTask], [ProgressTaskSettings], [ProgressContext], [LiveDisplayRegion], [ConsoleResolver], [ProgressColumn], [TaskDescriptionColumn], [PercentageColumn], [SpinnerColumn], [ProgressBarColumn], [ProgressBarRenderable], [ProgressRenderable], [ProgressLiveSession], [ProgressRefreshThread], [Progress], [ValidationResult], [IPrompt], [TextPrompt], [ConfirmationPrompt], [SelectionChoice], [SelectionPrompt], [MultiSelectionPrompt], [ConsoleRenderer], [RenderableExtensions], [RenderHookScope], [Style], [Segment], [SegmentLine], [MarkupSegmentInfo], [MarkupStyleState], [MarkupStyleStateDelta], [MarkupStyleParser], [Spinner], [SpinnerKnown], [StatusContext], [StatusLiveSession], [Status], [JsonSyntax], [JsonArray], [JsonBoolean], [JsonMember], [JsonNull], [JsonNumber], [JsonObject], [JsonString], [Table], [TableRendererContext], [TableRenderer], [TableCell], [TableColumn], [TableRow], [TableRowCollection], [TableTitle], [TableBorder], [NoTableBorder], [AsciiTableBorder], [SquareTableBorder], [RoundedTableBorder], [HeavyTableBorder], [DoubleTableBorder], [MarkdownTableBorder], [TableMeasurer], [TreeGuide], [LineTreeGuide], [BoldLineTreeGuide], [DoubleLineTreeGuide], [AsciiTreeGuide], [TreeNode], [Tree], [AnsiConsoleFacade], [AnsiConsole], [AnsiConsoleFactory], [AnsiConsoleOutput], [AnsiConsoleSettings], [Profile], [SystemConsoleExtensions], [EnumerableExtensions], [EnumUtils], [StringBuffer], [StringExtensions], [TextWriterExtensions], [EmbeddedResourceReader], [ExceptionInfoResolver], [ExceptionScrubber], [FakeTimeProvider], [FigletReportGenerator], [GitHubIssueAttribute], [ModuleInitializerAttribute], [Padding], [Aligner], [Paragraph], [Text], [Markup], [Align], [Padder], [PanelHeader], [Rule], [Panel], [TextPath], [Calendar], [AVScanResult], [AvScanner], [Capstone], [AttachmentScannerCOM], [IAttachmentExecute], [InstallRequirements], [Requirement], [ProfileConfig], [PsProfile], [dotProfile], [AsyncPingResult], [Connectivity], [ConsoleHelper], [DllUtils], [DNS], [ErrorSeverity], [ResultKind], [HostOS], [MotdArtName], [AVScanResultType], [ATTACHMENT_ACTION], [ATTACHMENT_PROMPT], [Activity], [ActivityLog], [ErrorLog], [ErrorManager], [ErrorMetadata], [ExceptionType], [InstallException], [InstallFailedException], [TimeLine], [ExecMeasurement], [PSPVisitor], [ExecTracer], [FontMan], [FTP], [Geolocation], [HelpTools], [IPManagement], [PsRecord], [NetRouteDiagnostics], [TestNetConnectionResult], [cliart], [MotdGen], [HostsEntry], [HostsFile], [NetworkManager], [NetworkDevice], [DeviceOverrides], [OuiLookup], [NetworkScanner], [Proxy], [shExpMatch], [Result], [Results], [JobResult], [BackgroundJob], [AsyncHandle], [AsyncResult], [ProgressTheme], [JobRunnerOptions], [ThreadRunner], [PsRunner], [Security], [FileTools], [HashTools], [HostTools], [ModuleTools], [ProgressUtil], [StringTools], [dlh]
)
$TypeAcceleratorsClass = [PsObject].Assembly.GetType('System.Management.Automation.TypeAccelerators')
# Add type accelerators for every exportable type.
foreach ($Type in $typestoExport) {
  try {
    [void]$TypeAcceleratorsClass::Add($Type.FullName, $Type)
  } catch {
    # Ignore if already exists
    $null
  }
}
# Remove type accelerators when the module is removed.
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
  foreach ($Type in $typestoExport) {
    $TypeAcceleratorsClass::Remove($Type.FullName)
  }
}.GetNewClosure();

$scripts = @();
$Public = Get-ChildItem "$PSScriptRoot/Public" -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue
$scripts += Get-ChildItem "$PSScriptRoot/Private" -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue
$scripts += $Public

foreach ($file in $scripts) {
  try {
    if ([string]::IsNullOrWhiteSpace($file.fullname)) { continue }
    . "$($file.fullname)"
  } catch {
    Write-Warning "Failed to import function $($file.BaseName): $_"
    $host.UI.WriteErrorLine($_)
  }
}

$Param = @{
  Function = $Public.BaseName
  Cmdlet   = '*'
  Alias    = '*'
  Verbose  = $false
}
Export-ModuleMember @Param
