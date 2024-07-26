$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host -Object 'Configurando...' -ForegroundColor 'Cyan'

if (-not (Get-Command -Name 'spicetify' -ErrorAction 'SilentlyContinue')) {
  Write-Host -Object 'Spicetify não encontrado.' -ForegroundColor 'Yellow'
  Write-Host -Object 'Instalando para você...' -ForegroundColor 'Cyan'
  $Parametros = @{
    Uri             = 'https://raw.githubusercontent.com/spicetify/cli/main/install.ps1'
    UseBasicParsing = $true
  }
  Invoke-WebRequest @Parametros | Invoke-Expression
}

spicetify path userdata | Out-Null
$caminhoUserDataSpicetify = (spicetify path userdata)
if (-not (Test-Path -Path $caminhoUserDataSpicetify -PathType 'Container' -ErrorAction 'SilentlyContinue')) {
  $caminhoUserDataSpicetify = "$env:APPDATA\spicetify"
}
$caminhoAppMarketplace = "$caminhoUserDataSpicetify\CustomApps\marketplace"
$caminhoTemaMarketplace = "$caminhoUserDataSpicetify\Themes\marketplace"
$temaInstalado = $(
  spicetify path -s | Out-Null
  -not $LASTEXITCODE
)
$temaAtual = (spicetify config current_theme)
$definirTema = $true

Write-Host -Object 'Removendo e criando pastas do Marketplace...' -ForegroundColor 'Cyan'
Remove-Item -Path $caminhoAppMarketplace, $caminhoTemaMarketplace -Recurse -Force -ErrorAction 'SilentlyContinue' | Out-Null
New-Item -Path $caminhoAppMarketplace, $caminhoTemaMarketplace -ItemType 'Directory' -Force | Out-Null

Write-Host -Object 'Baixando Marketplace...' -ForegroundColor 'Cyan'
$caminhoArquivoMarketplace = "$caminhoAppMarketplace\marketplace.zip"
$caminhoPastaDescompactada = "$caminhoAppMarketplace\marketplace-dist"
$Parametros = @{
  Uri             = 'https://github.com/spicetify/marketplace/releases/latest/download/marketplace.zip'
  UseBasicParsing = $true
  OutFile         = $caminhoArquivoMarketplace
}
Invoke-WebRequest @Parametros

Write-Host -Object 'Descompactando e instalando...' -ForegroundColor 'Cyan'
Expand-Archive -Path $caminhoArquivoMarketplace -DestinationPath $caminhoAppMarketplace -Force
Move-Item -Path "$caminhoPastaDescompactada\*" -Destination $caminhoAppMarketplace -Force
Remove-Item -Path $caminhoArquivoMarketplace, $caminhoPastaDescompactada -Force
spicetify config custom_apps spicetify-marketplace- -q
spicetify config custom_apps marketplace
spicetify config inject_css 1 replace_colors 1

Write-Host -Object 'Baixando tema de espaço reservado...' -ForegroundColor 'Cyan'
$Parametros = @{
  Uri             = 'https://raw.githubusercontent.com/spicetify/marketplace/main/resources/color.ini'
  UseBasicParsing = $true
  OutFile         = "$caminhoTemaMarketplace\color.ini"
}
Invoke-WebRequest @Parametros

Write-Host -Object 'Aplicando...' -ForegroundColor 'Cyan'
if ($temaInstalado -and ($temaAtual -ne 'marketplace')) {
  $Host.UI.RawUI.Flushinputbuffer()
  $escolha = $Host.UI.PromptForChoice(
    'Tema local encontrado',
    'Você deseja substituí-lo por um espaço reservado para instalar temas do Marketplace?',
    ('&Sim', '&Não'),
    0
  )
  if ($escolha -eq 1) { $definirTema = $false }
}
if ($definirTema) { spicetify config current_theme marketplace }
spicetify backup
spicetify apply

Write-Host -Object 'Concluído! - Agradeça ao ArthurZinJS & UiBlackHat :)' -ForegroundColor 'Green'
Write-Host -Object 'Se nada aconteceu, verifique as mensagens acima para erros'
