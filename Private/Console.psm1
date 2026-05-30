using namespace System
using namespace System.IO
using namespace System.Linq
using namespace System.Text
using namespace System.Diagnostics
using namespace System.Globalization
using namespace System.ComponentModel
using namespace System.Collections.Generic
using namespace System.Diagnostics.CodeAnalysis
using namespace System.Runtime.InteropServices
using namespace System.Management.Automation

using module .\Console\Ansi.psm1
using module .\Console\Boxes.psm1
using module .\Console\Charts.psm1
using module .\Console\Colors.psm1
using module .\Console\Emojis.psm1
using module .\Console\Figlet.psm1
using module .\Console\Internal.psm1
using module .\Console\Json.psm1
using module .\Console\Layout.psm1
using module .\Console\List.psm1
using module .\Console\Live.psm1
using module .\Console\Progress.psm1
using module .\Console\Prompts.psm1
using module .\Console\Renderer.psm1
using module .\Console\Rendering.psm1
using module .\Console\Spinners.psm1
using module .\Console\Status.psm1
using module .\Console\Syntax.psm1
using module .\Console\Table.psm1
using module .\Console\TableRenderer.psm1
using module .\Console\Tables.psm1
using module .\Console\Tree.psm1
using module .\Console\Ui.psm1
using module .\Console\Utilities.psm1
using module .\Console\Widgets.psm1

# todo : a console-convenience helper class to demo the features
class ConsoleHelper {
  static [void] DemoMarkup() {
    $console = [AnsiConsole]::Console
    $console.MarkupLine('[bold green]Hello from AnsiConsole[/]')
    $console.Write([Panel]::new([Markup]::new('[yellow]Pure PowerShell classes[/]')))
  }
  static [void] DemoTextandMarkup() {
    $console = [AnsiConsole]::Console
    $console.Write([Text]::new('Plain text output'))
    $console.WriteLine('')
    $console.Write([Markup]::new('[yellow]Warning:[/] disk usage high [grey]just kidding :)[/]'))
    $console.WriteLine('')
  }
  static [void] DemoPanelsRulesandAlignment() {
    $console = [AnsiConsole]::Console

    $panel = [Panel]::new([Markup]::new('[green]Build completed[/]'))
    $panel.Header = [PanelHeader]::new('CI Status')

    $aligned = [Align]::Center($panel)

    $console.Write([Rule]::new('Deployment'))
    $console.Write($aligned)
  }
  static [void] DemoTables() {
    $table = [Table]::new()
    [void]$table.AddColumn([TableColumn]::new('Name'))
    [void]$table.AddColumn([TableColumn]::new('Role'))
    [void]$table.AddRow(@('Harvey', 'Closer'))
    [void]$table.AddRow(@('Donna', 'COO'))
    [AnsiConsole]::Console.Write($table)
  }
  static [void] DemoRowsColumnsandGrid() {
    $console = [AnsiConsole]::Console

    $rows = [Rows]::new(@(
        [Markup]::new('[bold]Service A[/]'),
        [Markup]::new('[dim]Healthy[/]')
      ))
    $console.Write($rows)

    $grid = [Grid]::new()
    $grid.AddColumn() | Out-Null
    $grid.AddColumn() | Out-Null
    [void]$grid.AddRow(@(
        [Markup]::new('[bold]Region[/]'),
        [Markup]::new('[bold]Latency[/]')
      ))
    [void]$grid.AddRow(@(
        [Text]::new('us-east-1'),
        [Markup]::new('[green]24 ms[/]')
      ))
    [void]$grid.AddRow(@(
        [Text]::new('eu-west-1'),
        [Markup]::new('[yellow]67 ms[/]')
      ))

    $console.Write($grid)
  }
  static [void] DemoTreeRendering() {
    $tree = [Tree]::new('Root')
    $branch = $tree.Root.AddNode('Branch 1')
    [void]$branch.AddNode('Leaf 1.1')
    [void]$tree.Root.AddNode('Branch 2')
    [AnsiConsole]::Console.Write($tree)
  }
  static [void] DemoJSONRendering() {
    $uri = [uri]'https://jsonplaceholder.typicode.com/todos/1'
    $progressHelper = [type]"ProgressUtil"
    $RequestParams = @{
      Uri    = $uri.AbsoluteUri
      Method = 'GET'
    }
    $result = $progressHelper::WaitJob("Making GET request to $($uri.Host)", { param($rp) Invoke-RestMethod @rp }, $RequestParams)
    $json = $result.Output | ConvertTo-Json
    $tokens = [JsonTokenizer]::Tokenize($json)
    $syntax = [JsonParser]::Parse($tokens)
    [AnsiConsole]::Console.Write([JsonText]::new($syntax))
  }
  static [void] DemoChartsandCalendar() {
    $console = [AnsiConsole]::Console

    $chart = [BarChart]::new()
    $chart.AddItem('API', 92, [Color]::Green) | Out-Null
    $chart.AddItem('DB', 65, [Color]::Yellow) | Out-Null
    $chart.AddItem('IO', 35, [Color]::Red) | Out-Null
    $console.Write($chart)

    $breakdown = [BreakdownChart]::new()
    $breakdown.AddItem('Tests', 120, [Color]::Blue) | Out-Null
    $breakdown.AddItem('Lint', 35, [Color]::Green) | Out-Null
    $breakdown.AddItem('Package', 10, [Color]::Yellow) | Out-Null
    $console.Write($breakdown)

    $calendar = [Calendar]::new(
      [datetime]::new(2026, 5, 22),
      [datetime[]]@(
        [datetime]::new(2026, 5, 1),
        [datetime]::new(2026, 5, 15)
      )
    )
    $console.Write($calendar)
  }
  static [void] DemoProgress() {
    Write-Host "Text before progress bar... line 1"
    Write-Host "Text before progress bar... line 2"
    Write-Host "Text before progress bar... line 3"
    # the test is successfule if by the end of thew progress, all 3 initial lines are still visible (not overwritten)
    $console = [AnsiConsole]::Console
    $progress = [Progress]::new($console)
    $progress.RefreshRateMs = 80
    # $progress.Config = @{}

    $progress.Start([Action[ProgressContext]] {
        param([ProgressContext]$ctx)

        $task = $ctx.AddTask('[green]Loading data[/]', [ProgressTaskSettings]::new())
        foreach ($step in 1..5) {
          Start-Sleep -Milliseconds 1000
          $task.Increment(20)
        }
      }
    )
  }
  static [void] DemoFigletText() {
    $fig = [FigletText]::new([FigletFont]"DEFAULT_3D", 'chadnpc')
    [AnsiConsole]::Console.Write($fig)
  }
  static [object] DemoSearchableListPrompt() {
    $prompt = [ListPrompt]::new('Pick a service')
    $prompt.AddItems([string[]]@('api', 'worker', 'scheduler', 'gateway'))
    $service = $prompt.Show([AnsiConsole]::Console)

    # Non-interactive preview for tests and docs:
    # $prompt.SearchFilter = 'work'
    # $prompt.Preview()
    return $service
  }
  static [object] DemoAnsiInThreadrunner() {
    $jobs = [object[]](
      @{
        n = "[yellow]calc~Primes[/]"
        s = { param($n) (1..$n | Where-Object { $_ -gt 1 -and (1..[Math]::Sqrt($_)) -notcontains $_ -or $_ -eq 2 }).Count }
        a = 1000
      },
      @{
        n = "[yellow]Fibonacci[/]"
        s = { param($n) $a, $b = 0, 1; 1..$n | ForEach-Object { $c = $a; $a = $b; $b = $c + $b; $a } }
        a = 20
      }
    )
    $runnerType = [type]"ThreadRunner"
    $results = $runnerType::Run("", $jobs, 2, "Modern")
    return $results
  }
  static [object] DemoFailingTaskInThreadrunner() {
    $runnerType = [type]"ThreadRunner"
    $results = $runnerType::Run("doing a failing task in the background...", @{
        n           = "[yellow]run fake db operations[/]"
        s           = {
          param($operationCount)
          Start-Sleep -Milliseconds 4000
          throw "idk wtf just happened!"
        }
        a           = 15
        ThrowOnFail = $false
      }
    )
    return $results
  }
  static [void] DemoSimultaneousBackgroundJobsWithFailures() {
    ## run multiple jobs in parallel:
    $Jobs = (
      @{
        Name        = "Compute Primes"
        ScriptBlock = {
          param($count)
          $primes = @(2)
          $n = 3
          while ($primes.Count -lt $count) {
            $isPrime = $true
            foreach ($p in $primes) {
              if (($p * $p) -gt $n) { break }
              if ($n % $p -eq 0) {
                $isPrime = $false
                break
              }
            }
            if ($isPrime) { $primes += $n }
            $n += 2
          }
          return @{
            Count     = $primes.Count
            LastPrime = $primes[-1]
          }
        }
        Arguments   = @(2500)
      },
      @{
        Name        = "Simulate File Processing"
        ScriptBlock = {
          param($fileCount)
          $files = @()
          for ($i = 1; $i -le $fileCount; $i++) {
            $files += "file_$i.txt"
            Start-Sleep -Milliseconds 60
          }
          return @{
            Processed = $files.Count
            Files     = $files[0..3]
          }
        }
        Arguments   = @(30)
      },
      @{
        Name        = "Simulate API Calls"
        ScriptBlock = {
          param($callCount)
          $results = @()
          for ($i = 1; $i -le $callCount; $i++) {
            $results += @{
              Call    = $i
              Status  = "Success"
              Latency = Get-Random -Minimum 50 -Maximum 200
            }
            Start-Sleep -Milliseconds 100
          }
          return $results
        }
        Arguments   = @(15)
      },
      @{
        n = "Data Analysis"
        s = {
          param($iterations)
          $data = @()
          $sum = 0
          for ($i = 1; $i -le $iterations; $i++) {
            $value = Get-Random -Minimum 1 -Maximum 100
            $data += $value
            $sum += $value
            Start-Sleep -Milliseconds 20
          }
          $avg = $sum / $data.Count
          return @{
            TotalRecords = $data.Count
            Average      = [Math]::Round($avg, 2)
          }
        }
        a = @(100)
        t = $false
      },
      @{
        Name        = "DB Operations (Fails)"
        ScriptBlock = {
          param($operationCount)
          Start-Sleep -Milliseconds 500
          throw "Connection to database failed randomly."
        }
        Arguments   = @(15)
      }
    ) -as ([type]"BackgroundJob[]")
    $runnerType = [type]"ThreadRunner"
    # get JobResult[] result
    $results = $runnerType::Run("Doing epic stuff in the background...", $Jobs)
    $results | Out-Null
  }
  static [void] DemoStatus() {
    $writer = [AnsiConsole]::Console.GetWriter()
    $status = [Status]::new($writer)
    $status.RefreshRateMs = 80

    $status.Start('Downloading metadata', [Action[StatusContext]] {
        param([StatusContext]$ctx)
        Start-Sleep -Milliseconds 450
        $ctx.Update('Finishing download')
        Start-Sleep -Milliseconds 250
      }
    )
  }
  static [string] DemoTextPrompt() {
    $textPrompt = [TextPrompt]::new([string], 'Environment')
    $textPrompt.DefaultValue = 'dev'
    $envName = $textPrompt.Show([AnsiConsole]::Console)
    return $envName
  }
  static [bool] DemoConfirmPrompt() {
    $confirm = [ConfirmationPrompt]::new('Deploy now?')
    $confirm.DefaultValue = $false
    $shouldDeploy = $confirm.Show([AnsiConsole]::Console)
    return $shouldDeploy
  }
  static [object] DemoSelectionPrompt() {
    $selection = [SelectionPrompt]::new('Pick a region')
    $selection.AddChoice('US East', 'us-east-1')
    $selection.AddChoice('EU West', 'eu-west-1')
    $selection.AddChoice('AP South', 'ap-south-1')
    $region = $selection.Show([AnsiConsole]::Console)
    return $region
  }
  static [object] DemoMultiSelectionPrompt() {
    $multi = [MultiSelectionPrompt]::new('Select components')
    $multi.AddChoice('API', 'api')
    $multi.AddChoice('Worker', 'worker')
    $multi.AddChoice('Scheduler', 'scheduler')
    $components = $multi.Show([AnsiConsole]::Console);
    return $components
  }
  static [void] DemoCliArt() {
    $art = Create-CliArt "https://pastebin.com/raw/p29UR385" -Taglines "Build. Ship. Repeat."; $art.Replace("x.y.z", "0.3.2");
    $art.Write(15, $false, $true)
  }
  static [OrderedDictionary[string, ErrorRecord]] Run_Interactive_Demos() {
    # [ConsoleHelper].GetMethods().Where({ $_.IsStatic -and $_.Name.StartsWith("Demo") }).Name
    $demos = @{
      DemoMarkup                                 = "Markup rendering"
      DemoTextandMarkup                          = "Detect text and Markup"
      DemoPanelsRulesandAlignment                = "Panels, Rules, and Alignment."
      DemoTables                                 = "Tables."
      DemoRowsColumnsandGrid                     = "Rows, Columns, and Grid."
      DemoTreeRendering                          = "Tree Rendering."
      DemoJSONRendering                          = "JSON preview/rendering."
      DemoChartsandCalendar                      = "Charts and Calendar."
      DemoProgress                               = "Animated Progress."
      DemoFigletText                             = "FigletText rendering."
      DemoSearchableListPrompt                   = "Searchable Interactive ListPrompt."
      DemoAnsiInThreadrunner                     = "Ansi color ouptut in Threadrunner"
      DemoFailingTaskInThreadrunner              = "How threadrunner handles failing tasks"
      DemoSimultaneousBackgroundJobsWithFailures = "Simultaneous Background Jobs with Failures"
      DemoStatus                                 = "Status with Spinner."
      DemoTextPrompt                             = "Text Prompt"
      DemoConfirmPrompt                          = "Confirmation Prompt"
      DemoSelectionPrompt                        = "Selection Prompt"
      DemoMultiSelectionPrompt                   = "MultiSelection Prompt"
      DemoCliArt                                 = "CliArt"
    }
    $failing = [OrderedDictionary[string, ErrorRecord]]::new()
    $demos.Keys.ForEach({
        $method_name = $_
        Write-Console "[+] " -NoNewLine; Write-Console $demos[$_] -f LimeGreen
        try {
          [ConsoleHelper]::$_()
        } catch {
          $failing.Add($method_name, $_)
        } finally {
          $Host.UI.WriteLine("`n`n")
        }
      }
    )
    return $failing
  }
}
