@echo off
REM Script Helper para Windows - Nginx VPS Setup
REM Facilita comandos comuns durante o desenvolvimento

setlocal enabledelayedexpansion

REM Cores para output
set "GREEN=[92m"
set "BLUE=[94m"
set "YELLOW=[93m"
set "RED=[91m"
set "NC=[0m"

if "%1"=="" goto help
if "%1"=="help" goto help
if "%1"=="status" goto status
if "%1"=="logs" goto logs
if "%1"=="test" goto test
if "%1"=="validate" goto validate
if "%1"=="init-git" goto init-git
if "%1"=="clean" goto clean

:help
echo.
echo %BLUE%Nginx VPS Setup - Comandos Disponiveis (Windows)%NC%
echo.
echo   %GREEN%status%NC%      - Ver status dos arquivos criados
echo   %GREEN%logs%NC%        - Mostrar logs recentes (requer Docker)
echo   %GREEN%test%NC%        - Testar configuracoes Nginx localmente
echo   %GREEN%validate%NC%    - Validar sintaxe dos arquivos
echo   %GREEN%init-git%NC%    - Inicializar repositorio Git
echo   %GREEN%clean%NC%       - Limpar arquivos temporarios
echo.
goto end

:status
echo.
echo %BLUE%Status dos Arquivos Criados:%NC%
echo.
dir /b /s *.md 2>nul | find /c /v "" > temp.txt
set /p MD_COUNT=<temp.txt
echo   Arquivos Markdown: !MD_COUNT!
del temp.txt

dir /b /s *.yml 2>nul | find /c /v "" > temp.txt
set /p YML_COUNT=<temp.txt
echo   Arquivos YAML: !YML_COUNT!
del temp.txt

dir /b /s *.sh 2>nul | find /c /v "" > temp.txt
set /p SH_COUNT=<temp.txt
echo   Scripts Bash: !SH_COUNT!
del temp.txt

dir /b /s *.conf 2>nul | find /c /v "" > temp.txt
set /p CONF_COUNT=<temp.txt
echo   Arquivos Nginx: !CONF_COUNT!
del temp.txt

echo.
echo %GREEN%Estrutura completa criada!%NC%
echo.
goto end

:logs
echo.
echo %BLUE%Logs Recentes:%NC%
echo.
if exist logs\nginx (
    type logs\nginx\*.log | more
) else (
    echo %YELLOW%Nenhum log encontrado. Execute 'docker compose up' primeiro.%NC%
)
echo.
goto end

:test
echo.
echo %BLUE%Testando Configuracoes Nginx...%NC%
echo.
docker run --rm -v %CD%\nginx\nginx.conf:/etc/nginx/nginx.conf:ro -v %CD%\nginx\conf.d:/etc/nginx/conf.d:ro -v %CD%\nginx\snippets:/etc/nginx/snippets:ro nginx:alpine nginx -t
if %errorlevel%==0 (
    echo.
    echo %GREEN%Configuracao valida!%NC%
) else (
    echo.
    echo %RED%Erro na configuracao!%NC%
)
echo.
goto end

:validate
echo.
echo %BLUE%Validando Arquivos...%NC%
echo.

echo Validando docker-compose.yml...
docker compose config >nul 2>&1
if %errorlevel%==0 (
    echo %GREEN%docker-compose.yml: OK%NC%
) else (
    echo %RED%docker-compose.yml: ERRO%NC%
)

echo Validando scripts bash...
if exist scripts\*.sh (
    echo %GREEN%Scripts encontrados: OK%NC%
) else (
    echo %YELLOW%Nenhum script encontrado%NC%
)

echo Validando documentacao...
if exist docs\*.md (
    echo %GREEN%Documentacao encontrada: OK%NC%
) else (
    echo %YELLOW%Nenhuma documentacao encontrada%NC%
)

echo.
echo %GREEN%Validacao concluida!%NC%
echo.
goto end

:init-git
echo.
echo %BLUE%Inicializando Repositorio Git...%NC%
echo.

if exist .git (
    echo %YELLOW%Repositorio Git ja existe!%NC%
) else (
    git init
    echo %GREEN%Repositorio inicializado%NC%
)

echo.
echo Adicionando arquivos...
git add .

echo.
echo Criando primeiro commit...
git commit -m "Initial commit: Nginx VPS Setup v1.0.0"

echo.
echo %GREEN%Git inicializado com sucesso!%NC%
echo.
echo Proximos passos:
echo   1. Crie um repositorio no GitHub
echo   2. Execute: git remote add origin https://github.com/seu-usuario/nginx-vps-setup.git
echo   3. Execute: git branch -M main
echo   4. Execute: git push -u origin main
echo.
goto end

:clean
echo.
echo %BLUE%Limpando Arquivos Temporarios...%NC%
echo.

if exist temp.txt del temp.txt
if exist *.tmp del *.tmp

echo %GREEN%Limpeza concluida!%NC%
echo.
goto end

:end
endlocal
