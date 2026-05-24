
enum ErrorSeverity {
  Warning = 0
  Error = 1
  Critical = 2
  Fatal = 3
}


enum HostOS {
  Windows
  Linux
  MacOS
  FreeBSD
  UNKNOWN
}


enum MotdArtName {
  HitAnyKey
  ColorBlocks
  JelloBlocks
  Burger
  Blocks
  Pizza
  PacmanGhosts
}



# Provides a constants to indicate the result type of antivirus scanning
enum AVScanResultType {
  VirusNotFound
  VirusFound
  FileNotExist
  BlockedByPolicy
}

# Action to be performed upon user confirmation in IAttachmentExecute.Prompt()
enum ATTACHMENT_ACTION : UInt32 {
  ATTACHMENT_ACTION_CANCEL = 0x0
  ATTACHMENT_ACTION_SAVE = 0x1
  ATTACHMENT_ACTION_EXEC = 0x2
}

# Prompt type for IAttachmentExecute.Prompt()
enum ATTACHMENT_PROMPT : UInt32 {
  ATTACHMENT_PROMPT_NONE = 0x0
  ATTACHMENT_PROMPT_SAVE = 0x1
  ATTACHMENT_PROMPT_EXEC = 0x2
  ATTACHMENT_PROMPT_EXEC_OR_SAVE = 0x3
}