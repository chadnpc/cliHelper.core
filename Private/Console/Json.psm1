using namespace System
using namespace System.Text
using namespace System.Net.Http
using namespace System.Net.Http.Headers
using namespace System.Collections.Generic
using namespace System.Globalization

using module .\Enums.psm1
using module .\Rendering.psm1
using module .\Syntax.psm1

class SerializerSettings {
  static [string]$DateTimeFormat = "yyyy-MM-ddTHH:mm:ss.ffffffZ"
}


class NewtonsoftJson {
  static [object] Serialize([object]$obj) {
    return [Newtonsoft.Json.JsonConvert]::SerializeObject($obj, [Newtonsoft.Json.Formatting]::Indented)
  }

  static [object] Deserialize([string]$string) {
    $settings = New-Object "Newtonsoft.Json.JsonSerializerSettings"
    if ($global:ErrorActionPreference -eq "Ignore") {
      $settings.Error = {
        param ([object]$eventSender, [Newtonsoft.Json.Serialization.ErrorEventArgs]$errorArgs)
        $currentError = $errorArgs.ErrorContext.Error.Message
        Write-Warning $currentError
        $errorArgs.ErrorContext.Handled = $true
      }
    }

    $obj = [Newtonsoft.Json.JsonConvert]::DeserializeObject($string, [Newtonsoft.Json.Linq.JObject], $settings)
    return [NewtonsoftJson]::ConvertFromJObject($obj)
  }

  hidden static [object] ConvertFromJObject([object]$obj) {
    if ($obj -is [Newtonsoft.Json.Linq.JArray]) {
      $a = @()
      foreach ($entry in $obj.GetEnumerator()) {
        $a += @([NewtonsoftJson]::ConvertFromJObject($entry))
      }
      return $a
    } elseif ($obj -is [Newtonsoft.Json.Linq.JObject]) {
      $h = [ordered]@{}
      foreach ($kvp in $obj.GetEnumerator()) {
        $val = [NewtonsoftJson]::ConvertFromJObject($kvp.value)
        if ($kvp.value -is [Newtonsoft.Json.Linq.JArray]) { $val = @($val) }
        $h += @{ "$($kvp.key)" = $val }
      }
      return $h
    } elseif ($obj -is [Newtonsoft.Json.Linq.JValue]) {
      return $obj.Value
    } else {
      return $obj
    }
  }
}


# .EXAMPLE
# Deserialize a JSON string to [PSCustomObject] (no network call).
# [Json.JsonSerializer]::Deserialize[PSCustomObject]($json, [SerializerOptionsBuilder]::Build())
# .EXAMPLE
#  Deserialize a JSON string to a strongly-typed object (no network call).
#  [Json.JsonSerializer]::Deserialize($json, $targetType, [SerializerOptionsBuilder]::Build())

class SerializerOptionsBuilder {
  static [Json.JsonSerializerOptions] Build() {
    $opts = [Json.JsonSerializerOptions]@{
      PropertyNameCaseInsensitive = $true
      WriteIndented               = $true
    }
    $opts.Converters.Add([Json.Serialization.JsonStringEnumConverter]::new())
    return [SerializerOptionsBuilder]::Build($opts, $true, $false)
  }
  static [Json.JsonSerializerOptions] Build([Json.JsonSerializerOptions]$defaults, [bool]$includeNullProperties, [bool]$pretty) {
    $opts = [Json.JsonSerializerOptions]::new($defaults)
    if (!$includeNullProperties) {
      $opts.DefaultIgnoreCondition = [Json.Serialization.JsonIgnoreCondition]::WhenWritingNull
    }
    $opts.WriteIndented = [bool]$pretty
    return $opts
  }
}


# .SYNOPSIS
# Wrapper around System.Text.Json.
#
# .DESCRIPTION
#     A pure PowerShell implementation of Serializer that wraps System.Text.Json
#     and handles specific .NET types correctly (DateTime, IPAddress, Exception,
#     NameValueCollection, IntPtr) via pre-processing and post-processing, avoiding
#     the need for C# compilation.
#
#     Provides:
#         * Sensible defaults (trailing commas, comment skipping, number-from-string).
#         * Pluggable behavior for Exception, NameValueCollection, DateTime,
#           IPAddress, IntPtr and enum conversion (native to System.Text.Json).
#         * Per-call options building.
#         * Pretty / compact JSON.
#         * Type-safe deep `CopyObject`.
class JsonTextSerializer {
  # True to include null properties when serializing.
  [bool]$IncludeNullProperties = $false

  # Default JsonSerializerOptions - cloned on every call.
  [Json.JsonSerializerOptions]$DefaultOptions

  # Kept for backwards compatibility
  [System.Collections.Generic.List[Json.Serialization.JsonConverter]]$DefaultConverters

  JsonTextSerializer() {
    $this.DefaultOptions = [Json.JsonSerializerOptions]::new()
    $this.DefaultOptions.AllowTrailingCommas = $true
    $this.DefaultOptions.ReadCommentHandling = [Json.JsonCommentHandling]::Skip
    $this.DefaultOptions.NumberHandling = [Json.Serialization.JsonNumberHandling]::AllowReadingFromString
    $this.DefaultOptions.PropertyNameCaseInsensitive = $true

    $this.DefaultConverters = [System.Collections.Generic.List[Json.Serialization.JsonConverter]]::new()
  }

  static [string] GetDateTimeFormat() {
    return [SerializerSettings]::DateTimeFormat
  }

  static [void] SetDateTimeFormat([string]$format) {
    if ([string]::IsNullOrEmpty($format)) {
      throw [System.ArgumentNullException]::new('DateTimeFormat')
    }
    [SerializerSettings]::DateTimeFormat = $format
  }

  [void] SetDefaultOptions([Json.JsonSerializerOptions]$value) {
    if ($null -eq $value) { throw [System.ArgumentNullException]::new('DefaultOptions') }
    $this.DefaultOptions = $value
  }

  [void] SetDefaultConverters([System.Collections.Generic.List[Json.Serialization.JsonConverter]]$value) {
    if ($null -eq $value) { throw [System.ArgumentNullException]::new('DefaultConverters') }
    $this.DefaultConverters = $value
  }

  [void] AddConverter([Json.Serialization.JsonConverter]$converter) {
    if ($null -eq $converter) { throw [System.ArgumentNullException]::new('converter') }
    $this.DefaultConverters.Add($converter)
  }

  hidden [object] PreProcessObject([object]$obj) {
    if ($null -eq $obj) { return $null }

    $type = $obj.GetType()

    if ($type -eq [string] -or $type.IsPrimitive -or $type.IsEnum) {
      return $obj
    }

    if ($obj -is [DateTime]) {
      return $obj.ToString([SerializerSettings]::DateTimeFormat, [System.Globalization.CultureInfo]::InvariantCulture)
    }

    if ($obj -is [System.Net.IPAddress] -or $obj -is [IntPtr]) {
      return $obj.ToString()
    }

    if ($obj -is [System.Exception]) {
      $dict = [ordered]@{}
      foreach ($prop in $type.GetProperties()) {
        if ($prop.Name -ne 'TargetSite') {
          try {
            $val = $prop.GetValue($obj)
            if ($this.IncludeNullProperties -or $null -ne $val) {
              $dict[$prop.Name] = $this.PreProcessObject($val)
            }
          } catch { }
        }
      }
      return $dict
    }

    if ($obj -is [System.Collections.Specialized.NameValueCollection]) {
      $nvc = [System.Collections.Specialized.NameValueCollection]$obj
      $dict = [ordered]@{}
      foreach ($key in $nvc.AllKeys) {
        $vals = $nvc.GetValues($key)
        $safeKey = if ($null -ne $key) { $key } else { "" }
        if ($null -ne $vals -and $vals.Length -gt 0) {
          $validVals = @()
          foreach ($v in $vals) {
            if (![string]::IsNullOrEmpty($v)) {
              $validVals += $v
            }
          }
          if ($validVals.Count -gt 0) {
            $dict[$safeKey] = ($validVals -join ', ')
          } else {
            $dict[$safeKey] = $null
          }
        } else {
          $dict[$safeKey] = $null
        }
      }
      return $dict
    }

    if ($obj -is [System.Collections.IDictionary]) {
      $dict = [ordered]@{}
      $dictObj = [System.Collections.IDictionary]$obj
      foreach ($key in $dictObj.Keys) {
        $val = $dictObj[$key]
        if ($this.IncludeNullProperties -or $null -ne $val) {
          $safeKey = if ($null -ne $key) { $key.ToString() } else { "" }
          $dict[$safeKey] = $this.PreProcessObject($val)
        }
      }
      return $dict
    }

    if ($obj -is [System.Collections.IEnumerable]) {
      $list = [System.Collections.Generic.List[object]]::new()
      foreach ($item in $obj) {
        $list.Add($this.PreProcessObject($item))
      }
      return $list
    }

    if ($obj -is [psobject] -or $obj -is [Management.Automation.PSCustomObject]) {
      $dict = [ordered]@{}
      foreach ($prop in $obj.psobject.Properties) {
        $val = $prop.Value
        if ($this.IncludeNullProperties -or $null -ne $val) {
          $dict[$prop.Name] = $this.PreProcessObject($val)
        }
      }
      return $dict
    }

    $dict = [ordered]@{}
    $props = $type.GetProperties()
    foreach ($prop in $props) {
      if ($prop.CanRead) {
        try {
          $val = $prop.GetValue($obj)
          if ($this.IncludeNullProperties -or $null -ne $val) {
            $dict[$prop.Name] = $this.PreProcessObject($val)
          }
        } catch { }
      }
    }

    if ($dict.Count -eq 0 -and $props.Length -eq 0) {
      return $obj
    }

    return $dict
  }

  hidden [object] PostProcessJsonElement([object]$element) {
    if ($null -eq $element) { return $null }

    if ($element -is [Json.JsonElement]) {
      $je = [Json.JsonElement]$element

      switch ($je.ValueKind) {
        'Object' {
          $ht = [ordered]@{}
          foreach ($prop in $je.EnumerateObject()) {
            $ht[$prop.Name] = $this.PostProcessJsonElement($prop.Value)
          }
          return $ht
        }
        'Array' {
          $arr = [System.Collections.Generic.List[object]]::new()
          foreach ($item in $je.EnumerateArray()) {
            $arr.Add($this.PostProcessJsonElement($item))
          }
          return $arr.ToArray()
        }
        'String' { return $je.GetString() }
        'Number' {
          $i = 0
          if ($je.TryGetInt32([ref]$i)) { return $i }
          $l = 0L
          if ($je.TryGetInt64([ref]$l)) { return $l }
          $d = 0.0
          if ($je.TryGetDouble([ref]$d)) { return $d }
          return $je.GetRawText()
        }
        'True' { return $true }
        'False' { return $false }
        'Null' { return $null }
        'Undefined' { return $null }
      }
    }

    if ($element -is [System.Collections.IDictionary]) {
      $ht = [ordered]@{}
      foreach ($key in $element.Keys) {
        $ht[$key] = $this.PostProcessJsonElement($element[$key])
      }
      return $ht
    }

    if ($element -is [System.Collections.IEnumerable] -and $element -isnot [string]) {
      $arr = [System.Collections.Generic.List[object]]::new()
      foreach ($item in $element) {
        $arr.Add($this.PostProcessJsonElement($item))
      }
      return $arr.ToArray()
    }
    return $element
  }

  [object] Deserialize([string]$json, [type]$targetType) {
    if ($null -eq $targetType) { throw [System.ArgumentNullException]::new('targetType') }
    if ($null -eq $json) { throw [System.ArgumentNullException]::new('json') }

    $opts = [SerializerOptionsBuilder]::Build(
      $this.DefaultOptions,
      $this.IncludeNullProperties,
      $false
    )

    foreach ($c in $this.DefaultConverters) {
      if ($null -ne $c) { $opts.Converters.Add($c) }
    }

    $opts.Converters.Add([Json.Serialization.JsonStringEnumConverter]::new())

    if ($targetType -eq [System.Collections.Specialized.NameValueCollection]) {
      $dict = [Json.JsonSerializer]::Deserialize($json, [System.Collections.Generic.Dictionary[string, string]], $opts)
      $nvc = [System.Collections.Specialized.NameValueCollection]::new()
      foreach ($key in $dict.Keys) {
        $val = $dict[$key]
        if ($null -eq $val) {
          $nvc.Add($key, $null)
        } else {
          if ($val.Contains(',')) {
            foreach ($v in $val.Split(',')) {
              $nvc.Add($key, $v.Trim())
            }
          } else {
            $nvc.Add($key, $val)
          }
        }
      }
      return $nvc
    }

    if ($targetType -eq [System.Exception] -or $targetType.IsSubclassOf([System.Exception])) {
      throw [System.NotSupportedException]::new("Deserializing exceptions is not allowed")
    }

    if ($targetType -eq [IntPtr]) {
      throw [System.InvalidOperationException]::new("Properties of type IntPtr cannot be Deserialized from JSON.")
    }

    if ($targetType -eq [System.Net.IPAddress]) {
      $str = [Json.JsonSerializer]::Deserialize($json, [string], $opts)
      return [System.Net.IPAddress]::Parse($str)
    }

    if ($targetType -eq [DateTime]) {
      $str = [Json.JsonSerializer]::Deserialize($json, [string], $opts)
      $val = [DateTime]::MinValue
      if ([DateTime]::TryParse($str, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$val)) {
        return $val
      }
      if ([DateTime]::TryParse($str, [ref]$val)) {
        return $val
      }
      throw [System.FormatException]::new("The JSON value '$str' could not be converted to System.DateTime.")
    }

    try {
      $result = [Json.JsonSerializer]::Deserialize($json, $targetType, $opts)

      if ($targetType -eq [Hashtable] -or $targetType -eq [System.Collections.IDictionary]) {
        return $this.PostProcessJsonElement($result)
      }

      return $result
    } catch {
      if ($targetType.IsEnum) {
        throw [Json.JsonException]::new("String value is not valid for enum type or integer value is not defined in enum $($targetType.Name)", $_.Exception)
      }
      throw
    }
  }

  [object] Deserialize([byte[]]$json, [type]$targetType) {
    if ($null -eq $json) { throw [System.ArgumentNullException]::new('json') }
    return $this.Deserialize([Encoding]::UTF8.GetString($json), $targetType)
  }

  [string] Serialize([object]$obj) {
    return $this.Serialize($obj, $true)
  }
  [string] Serialize([object]$obj, [bool]$pretty) {
    if ($null -eq $obj) { return $null }

    $opts = [SerializerOptionsBuilder]::Build(
      $this.DefaultOptions,
      $this.IncludeNullProperties,
      $pretty
    )

    foreach ($c in $this.DefaultConverters) {
      if ($null -ne $c) { $opts.Converters.Add($c) }
    }

    $opts.Converters.Add([Json.Serialization.JsonStringEnumConverter]::new())

    $processed = $this.PreProcessObject($obj)

    return [Json.JsonSerializer]::Serialize($processed, $opts)
  }

  [object] CopyObject([object]$o, [type]$targetType) {
    if ($null -eq $o) { return $null }
    $json = $this.Serialize($o, $false)
    return $this.Deserialize($json, $targetType)
  }
}

class HttpJsonSerializer {
  hidden [ValidateNotNull()][HttpClient]$Client
  hidden [ValidateNotNull()][Json.JsonSerializerOptions]$JsonOptions

  # Default — creates a fresh HttpClient
  HttpJsonSerializer() {
    $this.Client = [HttpClient]::new()
    $this.JsonOptions = [SerializerOptionsBuilder]::Build()
    $this._SetDefaultHeaders()
  }

  # Accept a base URI string
  HttpJsonSerializer([string]$baseAddress) {
    $this.Client = [HttpClient]::new()
    $this.Client.BaseAddress = [uri]$baseAddress
    $this.JsonOptions = [SerializerOptionsBuilder]::Build()
    $this._SetDefaultHeaders()
  }
  # Accept a pre-configured HttpClient (for mocking / shared handlers)
  HttpJsonSerializer([HttpClient]$httpClient) {
    $this.Client = $httpClient
    $this.JsonOptions = [SerializerOptionsBuilder]::Build()
    $this._SetDefaultHeaders()
  }
  # Full control — custom client + custom serializer options
  HttpJsonSerializer([HttpClient]$httpClient, [Json.JsonSerializerOptions]$options) {
    $this.Client = $httpClient
    $this.JsonOptions = $options
    $this._SetDefaultHeaders()
  }

  # Serialize any object to a JSON string.
  static [string] Serialize([object]$payload) {
    $options = [SerializerOptionsBuilder]::Build()
    return [Json.JsonSerializer]::Serialize($payload, $options)
  }

  # Deserialize a JSON string into a [PSCustomObject].
  static [PSCustomObject] Deserialize([string]$json) {
    return [PSCustomObject]([NewtonsoftJson]::Deserialize($json))
  }

  # Deserialize a JSON string into a strongly-typed object.
  # $user = [HttpJsonSerializer]::Deserialize($json, [User])
  static [object] Deserialize([string]$json, [type]$targetType) {
    $options = [SerializerOptionsBuilder]::Build()
    return [Json.JsonSerializer]::Deserialize($json, $targetType, $options)
  }

  # .SYNOPSIS
  #     GET a URL and deserialize the response body as [PSCustomObject].
  # .OUTPUTS
  #     System.Management.Automation.Job  (ThreadJob)
  # .EXAMPLE
  #     $job  = $client.GetFromJsonAsync('/users/1')
  #     $user = $job | Wait-Job | Receive-Job
  [System.Management.Automation.Job] GetFromJsonAsync([string]$requestUri) {
    $options = $this.JsonOptions

    return Start-ThreadJob -Name "GET:$requestUri" -ScriptBlock {
      param($c, $uri, $opts)
      $task = $c.GetStringAsync($uri)
      $json = $task.GetAwaiter().GetResult()
      try { ConvertFrom-Json $json } catch { [PSCustomObject](ConvertFrom-Json $json -AsHashtable) }
    } -ArgumentList $this.Client, $requestUri, $options
  }


  # .SYNOPSIS
  #     GET a URL and deserialize the response body as a strongly-typed object.
  # .EXAMPLE
  #     $job  = $client.GetFromJsonAsync('/users/1', [User])
  #     $user = $job | Wait-Job | Receive-Job
  [System.Management.Automation.Job] GetFromJsonAsync([string]$requestUri, [type]$targetType) {
    $options = $this.JsonOptions

    return Start-ThreadJob -Name "GET:$requestUri" -ScriptBlock {
      param($c, $uri, $type, $opts)
      $task = $c.GetStringAsync($uri)
      $json = $task.GetAwaiter().GetResult()
      [System.Text.Json.JsonSerializer]::Deserialize($json, $type, $opts)
    } -ArgumentList $this.Client, $requestUri, $targetType, $options
  }


  # .SYNOPSIS
  #     POST an object serialized as JSON; returns the response as [PSCustomObject].
  # .EXAMPLE
  #     $job    = $client.PostAsJsonAsync('/users', $newUser)
  #     $result = $job | Wait-Job | Receive-Job
  [System.Management.Automation.Job] PostAsJsonAsync([string]$requestUri, [object]$payload) {
    $options = $this.JsonOptions
    $content = $this._Serialize($payload)

    return Start-ThreadJob -Name "POST:$requestUri" -ScriptBlock {
      param($c, $uri, $body, $opts)
      $task = $c.PostAsync($uri, $body)
      $response = $task.GetAwaiter().GetResult()
      $response.EnsureSuccessStatusCode() | Out-Null
      $readTask = $response.Content.ReadAsStringAsync()
      $json = $readTask.GetAwaiter().GetResult()
      try { ConvertFrom-Json $json } catch { [PSCustomObject](ConvertFrom-Json $json -AsHashtable) }
    } -ArgumentList $this.Client, $requestUri, $content, $options
  }


  # .SYNOPSIS
  #     PUT an object serialized as JSON; returns the response as [PSCustomObject].
  [System.Management.Automation.Job] PutAsJsonAsync([string]$requestUri, [object]$payload) {
    $options = $this.JsonOptions
    $content = $this._Serialize($payload)

    return Start-ThreadJob -Name "PUT:$requestUri" -ScriptBlock {
      param($c, $uri, $body, $opts)
      $task = $c.PutAsync($uri, $body)
      $response = $task.GetAwaiter().GetResult()
      $response.EnsureSuccessStatusCode() | Out-Null
      $readTask = $response.Content.ReadAsStringAsync()
      $json = $readTask.GetAwaiter().GetResult()
      try { ConvertFrom-Json $json } catch { [PSCustomObject](ConvertFrom-Json $json -AsHashtable) }
    } -ArgumentList $this.Client, $requestUri, $content, $options
  }

  # .SYNOPSIS
  #     PATCH an object serialized as JSON; returns the response as [PSCustomObject].
  [System.Management.Automation.Job] PatchAsJsonAsync([string]$requestUri, [object]$payload) {
    $options = $this.JsonOptions
    $content = $this._Serialize($payload)

    return Start-ThreadJob -Name "PATCH:$requestUri" -ScriptBlock {
      param($c, $uri, $body, $opts)
      $req = [System.Net.Http.HttpRequestMessage]::new(
        [System.Net.Http.HttpMethod]::new('PATCH'), $uri)
      $req.Content = $body
      $task = $c.SendAsync($req)
      $response = $task.GetAwaiter().GetResult()
      $response.EnsureSuccessStatusCode() | Out-Null
      $readTask = $response.Content.ReadAsStringAsync()
      $json = $readTask.GetAwaiter().GetResult()
      try { ConvertFrom-Json $json } catch { [PSCustomObject](ConvertFrom-Json $json -AsHashtable) }
    } -ArgumentList $this.Client, $requestUri, $content, $options
  }

  # .SYNOPSIS
  #     DELETE a resource; returns the HttpResponseMessage status info.
  [System.Management.Automation.Job] DeleteAsync([string]$requestUri) {
    return Start-ThreadJob -Name "DELETE:$requestUri" -ScriptBlock {
      param($c, $uri)
      $task = $c.DeleteAsync($uri)
      $response = $task.GetAwaiter().GetResult()
      [PSCustomObject]@{
        StatusCode   = [int]$response.StatusCode
        Status       = $response.StatusCode.ToString()
        IsSuccess    = $response.IsSuccessStatusCode
        ReasonPhrase = $response.ReasonPhrase
      }
    } -ArgumentList $this.Client, $requestUri
  }

  static [Json.JsonSerializerOptions] GetDefaultJsonOptions() {
    $opts = [Json.JsonSerializerOptions]@{
      PropertyNameCaseInsensitive = $true
      WriteIndented               = $true
    }
    $opts.Converters.Add([Json.Serialization.JsonStringEnumConverter]::new())
    return $opts
  }
  # .SYNOPSIS
  #     [Static] One-shot GET → PSCustomObject. Creates and disposes its own client.
  # .OUTPUTS
  #     System.Management.Automation.Job  (ThreadJob)
  # .EXAMPLE
  #     $job  = [HttpJsonSerializer]::GetFromJsonAsync('https://jsonplaceholder.typicode.com/users/1')
  #     $user = $job | Wait-Job | Receive-Job
  static [System.Management.Automation.Job] GetFromJsonAsync([uri]$uri) {
    $options = [SerializerOptionsBuilder]::Build()
    return Start-ThreadJob -Name "GET:$uri" -ScriptBlock {
      param($u, $opts)
      $c = [System.Net.Http.HttpClient]::new()
      try {
        $c.DefaultRequestHeaders.Accept.Add(
          [System.Net.Http.Headers.MediaTypeWithQualityHeaderValue]::new('application/json'))
        $task = $c.GetStringAsync($u)
        $json = $task.GetAwaiter().GetResult()
        try { ConvertFrom-Json $json } catch { [PSCustomObject](ConvertFrom-Json $json -AsHashtable) }
      } finally { $c.Dispose() }
    } -ArgumentList $uri, $options
  }

  # .SYNOPSIS
  #     [Static] One-shot GET → strongly-typed object.
  # .EXAMPLE
  #     $job  = [HttpJsonSerializer]::GetFromJsonAsync('https://jsonplaceholder.typicode.com/users/1', [User])
  #     $user = $job | Wait-Job | Receive-Job
  static [System.Management.Automation.Job] GetFromJsonAsync([uri]$uri, [type]$targetType) {
    $options = [SerializerOptionsBuilder]::Build()
    return Start-ThreadJob -Name "GET:$uri" -ScriptBlock {
      param($u, $type, $opts)
      $c = [System.Net.Http.HttpClient]::new()
      try {
        $c.DefaultRequestHeaders.Accept.Add(
          [System.Net.Http.Headers.MediaTypeWithQualityHeaderValue]::new('application/json'))
        $task = $c.GetStringAsync($u)
        $json = $task.GetAwaiter().GetResult()
        [System.Text.Json.JsonSerializer]::Deserialize($json, $type, $opts)
      } finally { $c.Dispose() }
    } -ArgumentList $uri, $targetType, $options
  }


  # .SYNOPSIS
  #     [Static] One-shot POST with JSON body.
  # .EXAMPLE
  #     $job    = [HttpJsonSerializer]::PostAsJsonAsync('https://jsonplaceholder.typicode.com/users', $user)
  #     $result = $job | Wait-Job | Receive-Job
  static [System.Management.Automation.Job] PostAsJsonAsync([uri]$uri, [object]$payload) {
    $options = [SerializerOptionsBuilder]::Build()
    $json = [Json.JsonSerializer]::Serialize($payload, $options)
    return Start-ThreadJob -Name "POST:$uri" -ScriptBlock {
      param($u, $j, $opts)
      $c = [System.Net.Http.HttpClient]::new()
      try {
        $body = [System.Net.Http.StringContent]::new(
          $j,
          [System.Text.Encoding]::UTF8,
          'application/json')
        $task = $c.PostAsync($u, $body)
        $response = $task.GetAwaiter().GetResult()
        $readTask = $response.Content.ReadAsStringAsync()
        $respJson = $readTask.GetAwaiter().GetResult()
        [PSCustomObject]@{
          StatusCode = [int]$response.StatusCode
          Status     = $response.StatusCode.ToString()
          IsSuccess  = $response.IsSuccessStatusCode
          Body       = try { ConvertFrom-Json $respJson } catch { [PSCustomObject](ConvertFrom-Json $respJson -AsHashtable) }
        }
      } finally { $c.Dispose() }
    } -ArgumentList $uri, $json, $options
  }

  # .SYNOPSIS
  #     [Static] Wait for one or more jobs and return their output, then clean up.
  # .EXAMPLE
  #     $jobs   = $job1, $job2
  #     $results = [HttpJsonSerializer]::AwaitJobs($jobs)
  static [object[]] AwaitJobs([System.Management.Automation.Job[]]$jobs) {
    $jobs | Wait-Job | Out-Null
    $results = $jobs | Receive-Job
    $jobs | Remove-Job -Force
    return $results
  }

  hidden [void] _SetDefaultHeaders() {
    $this.Client.DefaultRequestHeaders.Accept.Clear()
    $this.Client.DefaultRequestHeaders.Accept.Add(
      [MediaTypeWithQualityHeaderValue]::new('application/json')
    )
  }
  hidden [StringContent] _Serialize([object]$payload) {
    $json = [Json.JsonSerializer]::Serialize($payload, $this.JsonOptions)
    return [StringContent]::new($json, [Encoding]::UTF8, 'application/json')
  }
  hidden [object] _Deserialize([string]$json, [type]$targetType) {
    return [Json.JsonSerializer]::Deserialize($json, $targetType, $this.JsonOptions)
  }
  [void] Dispose() {
    if ($null -ne $this.Client) {
      $this.Client.Dispose()
    }
  }
}

class JsonToken {
  [JsonTokenType]$Type
  [string]$Value
  [int]$Position

  JsonToken([JsonTokenType]$type, [string]$value, [int]$position) {
    $this.Type = $type
    $this.Value = $value
    $this.Position = $position
  }

  [string] ToString() {
    return '{0}({1})@{2}' -f $this.Type, $this.Value, $this.Position
  }
}

class JsonTokenizer {
  hidden [string]$_json
  hidden [int]$_index
  hidden [List[JsonToken]]$_tokens

  static [JsonToken[]] Tokenize([string]$json) {
    $tokenizer = [JsonTokenizer]::new($json)
    return $tokenizer.Tokenize()
  }

  JsonTokenizer([string]$json) {
    if ($null -eq $json) { throw [ArgumentNullException]::new('json') }
    $this._json = $json
    $this._index = 0
    $this._tokens = [List[JsonToken]]::new()
  }

  [JsonToken[]] Tokenize() {
    while ($this._index -lt $this._json.Length) {
      $ch = $this._json[$this._index]
      if ([char]::IsWhiteSpace($ch)) {
        $this._index++
        continue
      }

      switch ($ch) {
        '{' { $this.Add([JsonTokenType]::ObjectStart, '{'); $this._index++; break }
        '}' { $this.Add([JsonTokenType]::ObjectEnd, '}'); $this._index++; break }
        '[' { $this.Add([JsonTokenType]::ArrayStart, '['); $this._index++; break }
        ']' { $this.Add([JsonTokenType]::ArrayEnd, ']'); $this._index++; break }
        ':' { $this.Add([JsonTokenType]::Symbol, ':'); $this._index++; break }
        ',' { $this.Add([JsonTokenType]::Symbol, ','); $this._index++; break }
        '"' { $this.Add([JsonTokenType]::String, $this.ReadString()); break }
        '-' { $this.Add([JsonTokenType]::Number, $this.ReadNumber()); break }
        default {
          if ([char]::IsDigit($ch)) {
            $this.Add([JsonTokenType]::Number, $this.ReadNumber())
          } elseif ($this.StartsWith('true')) {
            $this.Add([JsonTokenType]::Boolean, 'true')
            $this._index += 4
          } elseif ($this.StartsWith('false')) {
            $this.Add([JsonTokenType]::Boolean, 'false')
            $this._index += 5
          } elseif ($this.StartsWith('null')) {
            $this.Add([JsonTokenType]::Null, 'null')
            $this._index += 4
          } else {
            throw [FormatException]::new("Unexpected character '$ch' at position $($this._index).")
          }
        }
      }
    }

    return $this._tokens.ToArray()
  }

  hidden [void] Add([JsonTokenType]$type, [string]$value) {
    $this._tokens.Add([JsonToken]::new($type, $value, $this._index))
  }

  hidden [bool] StartsWith([string]$value) {
    if ($this._index + $value.Length -gt $this._json.Length) { return $false }
    return [string]::Compare($this._json, $this._index, $value, 0, $value.Length, [StringComparison]::Ordinal) -eq 0
  }

  hidden [string] ReadString() {
    $start = $this._index
    $this._index++
    $builder = [StringBuilder]::new()

    while ($this._index -lt $this._json.Length) {
      $ch = $this._json[$this._index]
      if ($ch -eq '"') {
        $this._index++
        return $builder.ToString()
      }

      if ($ch -eq '\') {
        $this._index++
        if ($this._index -ge $this._json.Length) {
          throw [FormatException]::new("Unterminated escape sequence at position $($this._index).")
        }

        $escaped = $this._json[$this._index]
        switch ($escaped) {
          '"' { [void]$builder.Append('"'); break }
          '\' { [void]$builder.Append('\'); break }
          '/' { [void]$builder.Append('/'); break }
          'b' { [void]$builder.Append("`b"); break }
          'f' { [void]$builder.Append("`f"); break }
          'n' { [void]$builder.Append("`n"); break }
          'r' { [void]$builder.Append("`r"); break }
          't' { [void]$builder.Append("`t"); break }
          'u' {
            if ($this._index + 4 -ge $this._json.Length) {
              throw [FormatException]::new("Incomplete unicode escape at position $($this._index - 1).")
            }
            $hex = $this._json.Substring($this._index + 1, 4)
            $code = [int]::Parse($hex, [NumberStyles]::HexNumber, [CultureInfo]::InvariantCulture)
            [void]$builder.Append([char]$code)
            $this._index += 4
            break
          }
          default { throw [FormatException]::new("Invalid escape sequence '\$escaped' at position $($this._index - 1).") }
        }
      } else {
        if ([char]::IsControl($ch)) {
          throw [FormatException]::new("Unescaped control character in string at position $($this._index).")
        }
        [void]$builder.Append($ch)
      }

      $this._index++
    }

    throw [FormatException]::new("Unterminated JSON string at position $start.")
  }

  hidden [string] ReadNumber() {
    $start = $this._index
    if ($this._json[$this._index] -eq '-') { $this._index++ }

    if ($this._index -ge $this._json.Length) {
      throw [FormatException]::new("Incomplete number at position $start.")
    }

    if ($this._json[$this._index] -eq '0') {
      $this._index++
    } else {
      if (![char]::IsDigit($this._json[$this._index])) {
        throw [FormatException]::new("Invalid number at position $start.")
      }
      while ($this._index -lt $this._json.Length -and [char]::IsDigit($this._json[$this._index])) {
        $this._index++
      }
    }

    if ($this._index -lt $this._json.Length -and $this._json[$this._index] -eq '.') {
      $this._index++
      if ($this._index -ge $this._json.Length -or ![char]::IsDigit($this._json[$this._index])) {
        throw [FormatException]::new("Invalid fractional number at position $start.")
      }
      while ($this._index -lt $this._json.Length -and [char]::IsDigit($this._json[$this._index])) {
        $this._index++
      }
    }

    if ($this._index -lt $this._json.Length -and ($this._json[$this._index] -eq 'e' -or $this._json[$this._index] -eq 'E')) {
      $this._index++
      if ($this._index -lt $this._json.Length -and ($this._json[$this._index] -eq '+' -or $this._json[$this._index] -eq '-')) {
        $this._index++
      }
      if ($this._index -ge $this._json.Length -or ![char]::IsDigit($this._json[$this._index])) {
        throw [FormatException]::new("Invalid number exponent at position $start.")
      }
      while ($this._index -lt $this._json.Length -and [char]::IsDigit($this._json[$this._index])) {
        $this._index++
      }
    }

    return $this._json.Substring($start, $this._index - $start)
  }
}

class JsonParser {
  hidden [JsonToken[]]$_tokens
  hidden [int]$_index

  static [JsonSyntax] Parse([JsonToken[]]$tokens) {
    $parser = [JsonParser]::new($tokens)
    return $parser.Parse()
  }

  static [JsonSyntax] Parse([string]$json) {
    return [JsonParser]::Parse([JsonTokenizer]::Tokenize($json))
  }

  JsonParser([JsonToken[]]$tokens) {
    if ($null -eq $tokens) { throw [ArgumentNullException]::new('tokens') }
    $this._tokens = $tokens
    $this._index = 0
  }

  [JsonSyntax] Parse() {
    $result = $this.ReadValue()
    if ($this._index -lt $this._tokens.Length) {
      $token = $this.Current()
      throw [FormatException]::new("Unexpected token '$($token.Value)' at position $($token.Position).")
    }
    return $result
  }

  hidden [JsonSyntax] ReadValue() {
    if ($this._index -ge $this._tokens.Length) {
      throw [FormatException]::new('Unexpected end of JSON input.')
    }

    $token = $this.Current()
    switch ($token.Type) {
      ([JsonTokenType]::ObjectStart) { return $this.ReadObject() }
      ([JsonTokenType]::ArrayStart) { return $this.ReadArray() }
      ([JsonTokenType]::String) { $this._index++; return [JsonString]::new($token.Value) }
      ([JsonTokenType]::Number) { $this._index++; return [JsonNumber]::new($token.Value) }
      ([JsonTokenType]::Boolean) { $this._index++; return [JsonBoolean]::new($token.Value -eq 'true') }
      ([JsonTokenType]::Null) { $this._index++; return [JsonNull]::new() }
      default { throw [FormatException]::new("Expected JSON value at position $($token.Position), got $($token.Type).") }
    }

    return $null
  }

  hidden [JsonObject] ReadObject() {
    $object = [JsonObject]::new()
    $this.Expect([JsonTokenType]::ObjectStart, $null)
    if ($this.Match([JsonTokenType]::ObjectEnd, $null)) {
      return $object
    }

    while ($true) {
      $name = $this.Expect([JsonTokenType]::String, $null)
      $name.Type = [JsonTokenType]::MemberName
      $this.Expect([JsonTokenType]::Symbol, ':') | Out-Null
      $object.Add($name.Value, $this.ReadValue())

      if ($this.Match([JsonTokenType]::ObjectEnd, $null)) { break }
      $this.Expect([JsonTokenType]::Symbol, ',') | Out-Null
    }

    return $object
  }

  hidden [JsonArray] ReadArray() {
    $array = [JsonArray]::new()
    $this.Expect([JsonTokenType]::ArrayStart, $null)
    if ($this.Match([JsonTokenType]::ArrayEnd, $null)) {
      return $array
    }

    while ($true) {
      $array.Add($this.ReadValue())
      if ($this.Match([JsonTokenType]::ArrayEnd, $null)) { break }
      $this.Expect([JsonTokenType]::Symbol, ',') | Out-Null
    }

    return $array
  }

  hidden [JsonToken] Current() {
    return $this._tokens[$this._index]
  }

  hidden [bool] Match([JsonTokenType]$type, [object]$value) {
    if ($this._index -ge $this._tokens.Length) { return $false }
    $token = $this.Current()
    if ($token.Type -ne $type) { return $false }
    if ($null -ne $value -and $token.Value -ne [string]$value) { return $false }
    $this._index++
    return $true
  }

  hidden [JsonToken] Expect([JsonTokenType]$type, [object]$value) {
    if ($this._index -ge $this._tokens.Length) {
      throw [FormatException]::new("Expected $type but reached end of input.")
    }

    $token = $this.Current()
    if ($token.Type -ne $type -or ($null -ne $value -and $token.Value -ne [string]$value)) {
      $expected = if ($null -ne $value) { "$type '$value'" } else { $type.ToString() }
      throw [FormatException]::new("Expected $expected at position $($token.Position), got $($token.Type) '$($token.Value)'.")
    }

    $this._index++
    return $token
  }
}

class JsonText : IRenderable {
  [object]$Data
  [JsonSyntax]$Syntax

  JsonText([object]$data) {
    $this.Data = $data
    if ($data -is [string]) {
      $trimmed = ([string]$data).TrimStart()
      if ($trimmed.StartsWith('{') -or $trimmed.StartsWith('[') -or $trimmed.StartsWith('"') -or
        $trimmed.StartsWith('true') -or $trimmed.StartsWith('false') -or $trimmed.StartsWith('null') -or
        $trimmed.StartsWith('-') -or ($trimmed.Length -gt 0 -and [char]::IsDigit($trimmed[0]))) {
        $this.Syntax = [JsonParser]::Parse([string]$data)
      } else {
        $this.Syntax = [JsonSyntax]::FromObject($data)
      }
    } else {
      $this.Syntax = [JsonSyntax]::FromObject($data)
    }
  }

  JsonText([JsonSyntax]$syntax) {
    $this.Syntax = $syntax
    $this.Data = $syntax
  }

  [Measurement] Measure([RenderOptions]$options, [int]$maxWidth) {
    return $this.Syntax.Measure($options, $maxWidth)
  }

  [object[]] Render([RenderOptions]$options, [int]$maxWidth) {
    return $this.Syntax.Render($options, $maxWidth)
  }
}

