$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#region Variáveis
$pastaSpicetify = "$env:LOCALAPPDATA\spicetify"
$pastaSpicetifyAntiga = "$HOME\spicetify-cli"
#endregion Variáveis

#region Funções
function Escrever-Sucesso {
  [CmdletBinding()]
  param ()
  process {
    Write-Host -Object ' > OK' -ForegroundColor 'Green'
  }
}

function Escrever-Erro {
  [CmdletBinding()]
  param ()
  process {
    Write-Host -Object ' > ERRO' -ForegroundColor 'Red'
  }
}

function Testar-Admin {
  [CmdletBinding()]
  param ()
  begin {
    Write-Host -Object "Verificando se o script não está sendo executado como administrador..." -NoNewline
  }
  process {
    $usuarioAtual = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    -not $usuarioAtual.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  }
}

function Testar-VersaoPowerShell {
  [CmdletBinding()]
  param ()
  begin {
    $versaoMinimaPS = [version]'5.1'
  }
  process {
    Write-Host -Object 'Verificando se a versão do PowerShell é compatível...' -NoNewline
    $PSVersionTable.PSVersion -ge $versaoMinimaPS
  }
}

function Mover-PastaSpicetifyAntiga {
  [CmdletBinding()]
  param ()
  process {
    if (Test-Path -Path $pastaSpicetifyAntiga) {
      Write-Host -Object 'Movendo a pasta antiga do spicetify...' -NoNewline
      Copy-Item -Path "$pastaSpicetifyAntiga\*" -Destination $pastaSpicetify -Recurse -Force
      Remove-Item -Path $pastaSpicetifyAntiga -Recurse -Force
      Escrever-Sucesso
    }
  }
}

function Obter-Spicetify {
  [CmdletBinding()]
  param ()
  begin {
    if ($env:PROCESSOR_ARCHITECTURE -eq 'AMD64') {
      $arquitetura = 'x64'
    }
    elseif ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') {
      $arquitetura = 'arm64'
    }
    else {
      $arquitetura = 'x32'
    }
    if ($v) {
      if ($v -match '^\d+\.\d+\.\d+$') {
        $versaoAlvo = $v
      }
      else {
        Write-Warning -Message "Você especificou uma versão inválida do spicetify: $v `nA versão deve estar no seguinte formato: 1.2.3"
        Pause
        exit
      }
    }
    else {
      Write-Host -Object 'Buscando a versão mais recente do spicetify...' -NoNewline
      $releaseMaisRecente = Invoke-RestMethod -Uri 'https://api.github.com/repos/spicetify/cli/releases/latest'
      $versaoAlvo = $releaseMaisRecente.tag_name -replace 'v', ''
      Escrever-Sucesso
    }
    $caminhoArquivoZip = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "spicetify.zip")
  }
  process {
    Write-Host -Object "Baixando spicetify v$versaoAlvo..." -NoNewline
    $Parametros = @{
      Uri            = "https://github.com/spicetify/cli/releases/download/v$versaoAlvo/spicetify-$versaoAlvo-windows-$arquitetura.zip"
      UseBasicParsing = $true
      OutFile        = $caminhoArquivoZip
    }
    Invoke-WebRequest @Parametros
    Escrever-Sucesso
  }
  end {
    $caminhoArquivoZip
  }
}

function Adicionar-SpicetifyAoPath {
  [CmdletBinding()]
  param ()
  begin {
    Write-Host -Object 'Tornando o spicetify disponível no PATH...' -NoNewline
    $usuario = [EnvironmentVariableTarget]::User
    $path = [Environment]::GetEnvironmentVariable('PATH', $usuario)
  }
  process {
    $path = $path -replace "$([regex]::Escape($pastaSpicetifyAntiga))\\*;*", ''
    if ($path -notlike "*$pastaSpicetify*") {
      $path = "$path;$pastaSpicetify"
    }
  }
  end {
    [Environment]::SetEnvironmentVariable('PATH', $path, $usuario)
    $env:PATH = $path
    Escrever-Sucesso
  }
}

function Instalar-Spicetify {
  [CmdletBinding()]
  param ()
  begin {
    Write-Host -Object 'Instalando o spicetify...'
  }
  process {
    $caminhoArquivoZip = Obter-Spicetify
    Write-Host -Object 'Extraindo spicetify...' -NoNewline
    Expand-Archive -Path $caminhoArquivoZip -DestinationPath $pastaSpicetify -Force
    Escrever-Sucesso
    Adicionar-SpicetifyAoPath
  }
  end {
    Remove-Item -Path $caminhoArquivoZip -Force -ErrorAction 'SilentlyContinue'
    Write-Host -Object 'O spicetify foi instalado com sucesso!' -ForegroundColor 'Green'
  }
}
#endregion Funções

#region Principal
#region Verificações
if (-not (Testar-VersaoPowerShell)) {
  Escrever-Erro
  Write-Warning -Message 'É necessário o PowerShell 5.1 ou superior para executar este script'
  Write-Warning -Message "Você está executando o PowerShell $($PSVersionTable.PSVersion)"
  Write-Host -Object 'Guia de instalação do PowerShell 5.1:'
  Write-Host -Object 'https://learn.microsoft.com/skypeforbusiness/set-up-your-computer-for-windows-powershell/download-and-install-windows-powershell-5-1'
  Write-Host -Object 'Guia de instalação do PowerShell 7:'
  Write-Host -Object 'https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows'
  Pause
  exit
}
else {
  Escrever-Sucesso
}
if (-not (Testar-Admin)) {
  Escrever-Erro
  Write-Warning -Message "O script foi executado como administrador. Isso pode resultar em problemas com o processo de instalação ou comportamento inesperado. Não continue se você não souber o que está fazendo."
  $Host.UI.RawUI.Flushinputbuffer()
  $opcoes = [System.Management.Automation.Host.ChoiceDescription[]] @(
    (New-Object System.Management.Automation.Host.ChoiceDescription '&Sim', 'Abortar instalação.'),
    (New-Object System.Management.Automation.Host.ChoiceDescription '&Não', 'Continuar com a instalação.')
  )
  $escolha = $Host.UI.PromptForChoice('', 'Você deseja abortar o processo de instalação?', $opcoes, 0)
  if ($escolha -eq 0) {
    Write-Host -Object 'Instalação do spicetify abortada' -ForegroundColor 'Yellow'
    Pause
    exit
  }
}
else {
  Escrever-Sucesso
}
#endregion Verificações

#region Spicetify
Mover-PastaSpicetifyAntiga
Instalar-Spicetify
Write-Host -Object "`nExecute" -NoNewline
Write-Host -Object ' spicetify -h ' -NoNewline -ForegroundColor 'Cyan'
Write-Host -Object 'para começar'
#endregion Spicetify

#region Marketplace
$Host.UI.RawUI.Flushinputbuffer()
$opcoes = [System.Management.Automation.Host.ChoiceDescription[]] @(
    (New-Object System.Management.Automation.Host.ChoiceDescription "&Sim", "Instalar o Marketplace do Spicetify."),
    (New-Object System.Management.Automation.Host.ChoiceDescription "&Não", "Não instalar o Marketplace do Spicetify.")
)
$escolha = $Host.UI.PromptForChoice('', "`nVocê também deseja instalar o Marketplace do Spicetify? Ele se tornará disponível dentro do cliente Spotify, onde você pode facilmente instalar temas e extensões.", $opcoes, 0)
if ($escolha -eq 1) {
  Write-Host -Object 'Instalação do Marketplace do spicetify abortada' -ForegroundColor 'Yellow'
}
else {
  Write-Host -Object 'Iniciando o script de instalação do Marketplace do spicetify..'
  $Parametros = @{
    Uri             = 'https://raw.githubusercontent.com/spicetify/spicetify-marketplace/main/resources/install.ps1'
    UseBasicParsing = $true
  }
  Invoke-WebRequest @Parametros | Invoke-Expression
}
#endregion Marketplace
#endregion Principal
