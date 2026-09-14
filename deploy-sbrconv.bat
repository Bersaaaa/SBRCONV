@echo off
setlocal enabledelayedexpansion
title sbrconv - Envoi vers GitHub

REM ============================================================================
REM  deploy.bat - sbrconv
REM
REM  A placer a la racine du depot Git local.
REM  A chaque double-clic :
REM    1) recupere les dernieres modifications de GitHub
REM    2) ajoute les fichiers modifies
REM    3) cree un commit
REM    4) envoie les modifications sur GitHub
REM
REM  Depot GitHub :
REM  https://github.com/Bersaaaa/sbrconv
REM ============================================================================

echo ============================================
echo   SBRCONV - Envoi vers GitHub
echo ============================================
echo.

REM Verifie que Git est installe
where git >nul 2>nul
if errorlevel 1 (
    echo [ERREUR] Git n'est pas installe ou introuvable dans le PATH.
    echo Installe Git pour Windows puis relance ce script.
    echo.
    pause
    exit /b 1
)

REM Verifie qu'on est bien dans un depot Git
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (
    echo [ERREUR] Ce dossier n'est pas un depot Git.
    echo.
    echo Place deploy.bat a la racine du dossier
    echo local du projet sbrconv.
    echo.
    pause
    exit /b 1
)

echo --- Depot Git utilise ---
git remote -v
echo.

echo --- Recuperation des dernieres modifications GitHub ---
git pull --no-edit
if errorlevel 1 (
    echo.
    echo [ERREUR] Impossible de recuperer les modifications de GitHub.
    echo Verifie s'il y a un conflit Git a resoudre.
    echo.
    pause
    exit /b 1
)

echo.
echo --- Fichiers modifies ---
git status --short
echo.

set /p msg="Message pour cette mise a jour (Entree = message par defaut) : "
if "%msg%"=="" set msg=Mise a jour sbrconv

echo.
echo --- Ajout des fichiers ---
git add -A

echo.
echo --- Creation du commit ---
git diff --cached --quiet
if not errorlevel 1 (
    echo.
    echo Aucun fichier modifie a envoyer.
    echo.
    pause
    exit /b 0
)

git commit -m "%msg%"
if errorlevel 1 (
    echo.
    echo [ERREUR] Impossible de creer le commit.
    echo.
    pause
    exit /b 1
)

echo.
echo --- Envoi vers GitHub ---
git push
if errorlevel 1 (
    echo.
    echo [ERREUR] L'envoi vers GitHub a echoue.
    echo Verifie ta connexion et les droits du depot.
    echo.
    pause
    exit /b 1
)

echo.
echo ============================================
echo   TERMINE !
echo   Les modifications sont maintenant
echo   envoyees sur GitHub.
echo ============================================
echo.
pause
