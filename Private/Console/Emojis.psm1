using namespace System
using namespace System.Collections.Generic

class Emoji {
  static [hashtable]$Map = @{
    'rocket' = '🚀'; 'white_check_mark' = '✅'; 'x' = '❌'; 'warning' = '⚠️';
    'fire' = '🔥'; 'hourglass' = '⏳'; 'sparkles' = '✨'; 'bug' = '🐛'; 'bulb' = '💡'
  }

  static [string] Replace([string]$text) {
    if ([string]::IsNullOrEmpty($text)) { return $text }
    return [regex]::Replace($text, ':(?<name>[a-zA-Z0-9_+\-]+):', {
        param($m)
        $key = $m.Groups['name'].Value
        if ([Emoji]::Map.ContainsKey($key)) { return [Emoji]::Map[$key] }
        return $m.Value
      }
    )
  }
}

class EmojiParser {
  static [string] Parse([string]$text) { return [Emoji]::Replace($text) }
}

class EmojiEmitter {
}

class EmojiGenerator {
}

