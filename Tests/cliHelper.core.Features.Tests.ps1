using namespace System.Text
using module ..\cliHelper.core.psm1

class HttpJsonSerializerTestUser {
  [int]    $Id
  [string] $Name
  [string] $Username
  [string] $Email
}

Describe "Feature tests: Console" {
  Context "JSON rendering" {
    It "Tokenizes and parses a JSON object" {
      $json = '{"name":"Ada","count":3,"ok":true,"items":[null,2]}'
      $tokens = [JsonTokenizer]::Tokenize($json)
      $syntax = [JsonParser]::Parse($tokens)

      $tokens.Count | Should Be 21
      $syntax.GetType().Name | Should Be 'JsonObject'
      $syntax.Members.Count | Should Be 4
    }

    It "Renders JSON as styled pretty text" {
      $jsonText = [JsonText]::new([ordered]@{
          service = 'api'
          healthy = $true
          latency = 24
        })

      $segments = $jsonText.Render([RenderOptions]::new(), 80)
      $plain = ($segments | ForEach-Object Text) -join ''

      $plain | Should Match '"service": "api"'
      $plain | Should Match '"healthy": true'
      $plain | Should Match '"latency": 24'
      ($segments | Where-Object { $_.Style -ne [Style]::Plain }).Count -gt 0 | Should Be $true
    }
  }

  Context "List prompt" {
    It "Filters preview output without requiring interactive input" {
      $prompt = [ListPrompt]::new('Pick service')
      $prompt.AddItems([string[]]@('api', 'worker', 'scheduler', 'gateway'))
      $prompt.SearchFilter = 'work'

      $preview = $prompt.Preview()

      ($preview -join '|') | Should Match 'Filter: work'
      ($preview -join '|') | Should Match '> worker'
      ($preview -join '|') | Should Not Match 'scheduler'
    }
  }
  Context "  Json parsers" {
    It "Should expose the Phase 3 JSON parser classes" {
      [JsonToken].Name | Should Be 'JsonToken'
      [JsonTokenizer].Name | Should Be 'JsonTokenizer'
      [JsonParser].Name | Should Be 'JsonParser'
      [JsonText].Name | Should Be 'JsonText'
    }

    It "Should reject invalid JSON with a parser error" {
      $thrown = $false
      try {
        [JsonParser]::Parse('{"name":}') | Out-Null
      } catch {
        $thrown = $true
      }
      $thrown | Should Be $true
    }
  }
  Context "  ListPrompt" {
    It "Should expose searchable list prompt classes" {
      [ListPrompt].Name | Should Be 'ListPrompt'
      [ListPromptState].Name | Should Be 'ListPromptState'
      [ListPromptTree].Name | Should Be 'ListPromptTree'
    }

    It "Should filter state with case-insensitive substring matching" {
      $items = [System.Collections.Generic.List[ListPromptItem]]::new()
      $items.Add([ListPromptItem]::new('API', 'api'))
      $items.Add([ListPromptItem]::new('Worker', 'worker'))
      $state = [ListPromptState]::new($items, 10)
      $state.SetFilter('work')

      $state.FilteredIndexes.Count | Should Be 1
      $state.Current().Data | Should Be 'worker'
    }
  }
  Context "  Syntax features" {
    It "Should expose JSON syntax renderables" {
      [JsonObject].Name | Should Be 'JsonObject'
      [JsonArray].Name | Should Be 'JsonArray'
      [JsonString].Name | Should Be 'JsonString'
      [JsonNumber].Name | Should Be 'JsonNumber'
      [JsonBoolean].Name | Should Be 'JsonBoolean'
      [JsonNull].Name | Should Be 'JsonNull'
    }
  }
  Context " Core rendering" {
    It "Renders Text to console" {
      $text = [Text]::new('Simple text')
      $console = [AnsiConsole]::Console
      $console.Write($text)

      $text.GetType().Name | Should Be 'Text'
      ($null -ne $console.Profile) | Should Be $true
      ($null -ne $console.get_Writer()) | Should Be $true
    }

    It "Renders Markup to console" {
      $markup = [Markup]::new('[yellow]Warning:[/] disk usage high')
      $console = [AnsiConsole]::Console
      $console.Write($markup)
      $markup.GetType().Name | Should Be 'Markup'
    }
  }

  Context " Factory" {
    It "Creates AnsiConsole via factory" {
      $settings = [AnsiConsoleSettings]::new()
      $console = [AnsiConsoleFactory]::Create($settings)

      ($null -ne $console) | Should Be $true
      ($null -ne $console.Profile) | Should Be $true
      ($null -ne $console.get_Writer()) | Should Be $true
    }
  }

  Context " Serializer" {
    It "Serializes and deserializes a basic Hashtable" {
      $s = [JsonTextSerializer]::new()
      $obj = [ordered]@{
        Name = 'Ada Lovelace'
        Born = [datetime]'1815-12-10T00:00:00Z'
        IP   = [System.Net.IPAddress]::Parse('192.168.1.10')
        Tags = @('math', 'poet', 'programmer')
        Nick = $null
      }

      $pretty = $s.Serialize($obj, $true)
      $pretty | Should Match '"Name": "Ada Lovelace"'

      $s.IncludeNullProperties = $true
      $compact = $s.Serialize($obj, $false)
      $compact | Should Match '"Nick":\s*null'
      $s.IncludeNullProperties = $false

      $back = $s.Deserialize($pretty, [hashtable])
      $back['Name'] | Should Be 'Ada Lovelace'
    }

    It "Round-trips NameValueCollection" {
      $s = [JsonTextSerializer]::new()
      $nvc = [System.Collections.Specialized.NameValueCollection]::new()
      $nvc.Add('color', 'red')
      $nvc.Add('color', 'blue')
      $nvc.Add('size', 'large')

      $j = $s.Serialize($nvc, $true)
      $nvcBack = $s.Deserialize($j, [System.Collections.Specialized.NameValueCollection])

      $nvcBack.AllKeys -contains 'color' | Should Be $true
      $nvcBack.AllKeys -contains 'size' | Should Be $true
      ($nvcBack.GetValues('color') -join ', ') | Should Be 'red, blue'
    }

    It "Serializes Exception" {
      $s = [JsonTextSerializer]::new()
      $json = ""
      try { throw [System.InvalidOperationException]::new('Boom!') }
      catch { $json = $s.Serialize($_.Exception, $true) }

      $json | Should Match 'Boom!'
      $json | Should Match 'HResult'
    }

    It "Handles strict enum behavior" {
      $s = [JsonTextSerializer]::new()
      $dow = [System.DayOfWeek]::Wednesday
      $s.Serialize($dow, $false) | Should Be '"Wednesday"'

      $deserialized = $s.Deserialize('"friday"', [System.DayOfWeek])
      $deserialized | Should Be ([System.DayOfWeek]::Friday)

      $thrown = $false
      try {
        $s.Deserialize('"notaday"', [System.DayOfWeek]) | Out-Null
      } catch {
        $thrown = $true
      }
      $thrown | Should Be $true
    }

    It "Clones object via CopyObject" {
      $s = [JsonTextSerializer]::new()
      $obj = [hashtable]@{ Name = 'Ada' }
      $clone = $s.CopyObject($obj, [hashtable])

      $clone['Name'] = 'MUTATED'
      $obj['Name'] | Should Be 'Ada'
      $clone['Name'] | Should Be 'MUTATED'
    }

    It "Respects custom static DateTime format" {
      $s = [JsonTextSerializer]::new()
      [JsonTextSerializer]::SetDateTimeFormat('yyyy-MM-dd')

      $json = $s.Serialize(@{ d = [datetime]'2026-05-23' }, $false)
      $json | Should Match '"2026-05-23"'

      [JsonTextSerializer]::SetDateTimeFormat('yyyy-MM-ddTHH:mm:ss.ffffffZ')
    }
  }

  Context " HttpJsonSerializer" {
    It "Performs static one-shot GET (PSCustomObject)" {
      $job = [HttpJsonSerializer]::GetFromJsonAsync('https://jsonplaceholder.typicode.com/users/1')
      $user = $job | Wait-Job | Receive-Job
      Remove-Job $job

      $user.id | Should Be 1
      ($null -ne $user.name) | Should Be $true
    }

    It "Performs static one-shot GET (strongly-typed)" {
      $job = [HttpJsonSerializer]::GetFromJsonAsync('https://jsonplaceholder.typicode.com/users/1', [HttpJsonSerializerTestUser])
      $typedUser = $job | Wait-Job | Receive-Job
      Remove-Job $job

      $typedUser.Id | Should Be 1
      ($null -ne $typedUser.Name) | Should Be $true
    }

    It "Performs static POST" {
      $newUser = [HttpJsonSerializerTestUser]@{ Id = 0; Name = 'Alice'; Username = 'alice99'; Email = 'alice@example.com' }
      $postJob = [HttpJsonSerializer]::PostAsJsonAsync('https://jsonplaceholder.typicode.com/users', $newUser)
      $result = $postJob | Wait-Job | Receive-Job
      Remove-Job $postJob

      $result.IsSuccess | Should Be $true
      $result.Status.ToString() | Should Be 'Created'
      $result.Body | Should Match 'alice99'
    }

    It "Supports instance-based client with base address" {
      $ser = [HttpJsonSerializer]::new('https://jsonplaceholder.typicode.com')
      $jobs = 1..3 | ForEach-Object {
        $ser.GetFromJsonAsync("/users/$_", [HttpJsonSerializerTestUser])
      }
      $users = [HttpJsonSerializer]::AwaitJobs($jobs)

      $users.Count | Should Be 3
      $users[0].Id | Should Be 1
      $users[1].Id | Should Be 2
      $users[2].Id | Should Be 3

      $ser.Dispose()
    }

    It "Provides static serialization helpers" {
      $testUser = [HttpJsonSerializerTestUser]@{ Id = 7; Name = 'Bob'; Username = 'bob7'; Email = 'bob@example.com' }
      $json = [HttpJsonSerializer]::Serialize($testUser)

      $json | Should Match '"Id":\s*7'
      $json | Should Match '"Name":\s*"Bob"'

      $roundTrip = [HttpJsonSerializer]::Deserialize($json, [HttpJsonSerializerTestUser])
      $roundTrip.Id | Should Be 7
      $roundTrip.Name | Should Be 'Bob'
    }

    It "Performs instance PUT and DELETE" {
      $ser2 = [HttpJsonSerializer]::new('https://jsonplaceholder.typicode.com')

      $putPayload = [HttpJsonSerializerTestUser]@{ Id = 1; Name = 'Updated User'; Username = 'updated'; Email = 'u@example.com' }
      $putJob = $ser2.PutAsJsonAsync('/users/1', $putPayload)
      $putResult = $putJob | Wait-Job | Receive-Job
      Remove-Job $putJob

      $putResult.id | Should Be 1

      $delJob = $ser2.DeleteAsync('/users/1')
      $delResult = $delJob | Wait-Job | Receive-Job
      Remove-Job $delJob

      $delResult.IsSuccess | Should Be $true

      $ser2.Dispose()
    }
  }
}
