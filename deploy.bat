@echo off
setlocal enabledelayedexpansion
title SBR AUTO - Envoi vers GitHub

REM ============================================================================
REM  deploy.bat
REM
REM  A poser UNE FOIS a la racine de ton depot Git local (le meme dossier que
REM  index.html, schema.sql, README.md). A partir de la, chaque mise a jour se
REM  fait en un double-clic : le script ajoute tous les fichiers modifies,
REM  demande un petit message, et envoie tout sur GitHub. Vercel redeploie
REM  automatiquement quelques secondes apres.
REM
REM  Prerequis (une seule fois, si pas deja fait) :
REM    1) Installer Git pour Windows : https://git-scm.com/download/win
REM    2) Avoir deja clone le depot une premiere fois (ou fait un premier
REM       "git push" manuel) pour que ce dossier soit relie a GitHub.
REM ============================================================================

echo ============================================
echo   SBR AUTO - Envoi des modifications vers GitHub
echo ============================================
echo.

REM Verifie que Git est installe
where git >nul 2>nul
if errorlevel 1 (
    echo [ERREUR] Git n'est pas installe ou introuvable dans le PATH.
    echo Installe-le depuis https://git-scm.com/download/win puis relance ce script.
    echo.
    pause
    exit /b 1
)

REM Verifie qu'on est bien dans un depot Git
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (
    echo [ERREUR] Ce dossier n'est pas un depot Git.
    echo Place ce fichier deploy.bat a la racine de ton depot GitHub clone en local
    echo ^(le meme dossier que index.html et schema.sql^), puis relance-le.
    echo.
    pause
    exit /b 1
)

echo Fichiers detectes comme modifies :
git status --short
echo.

set /p msg="Message pour cette mise a jour (Entree = message par defaut) : "
if "%msg%"=="" set msg=Mise a jour SBR AUTO

echo.
echo --- git add ---
git add -A

echo --- git commit ---
git commit -m "%msg%"
if errorlevel 1 (
    echo.
    echo Rien a envoyer ^(aucun fichier modifie depuis le dernier envoi^).
    echo.
    pause
    exit /b 0
)

REM Recupere d'abord les eventuels changements faits directement sur GitHub
REM (ex: un fichier ajoute a la main sur le site GitHub) - sans ca, l'envoi
REM est refuse par GitHub si les deux versions ont divergees.
echo --- git pull ---
git pull --no-edit
if errorlevel 1 (
    echo.
    echo [ERREUR] Impossible de recuperer les derniers changements de GitHub.
    echo Il y a peut-etre un conflit a resoudre manuellement dans un editeur de code.
    echo.
    pause
    exit /b 1
)

echo --- git push ---
git push
if errorlevel 1 (
    echo.
    echo [ERREUR] L'envoi a echoue. Verifie ta connexion et que ce dossier est bien
    echo relie a ton depot GitHub ^(git remote -v pour verifier^).
    echo.
    pause
    exit /b 1
)

echo.
echo ============================================
echo   Termine ! Vercel va redeployer automatiquement
echo   dans quelques secondes.
echo ============================================
echo.
pause
