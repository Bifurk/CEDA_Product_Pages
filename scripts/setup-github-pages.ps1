$ErrorActionPreference = "Stop"

function Write-Info($msg) { Write-Host ("[INFO] " + $msg) -ForegroundColor Cyan }
function Write-Warn($msg) { Write-Host ("[WARN] " + $msg) -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host ("[ERR ] " + $msg) -ForegroundColor Red }

Write-Info "CEDA_Product_Pages – automatické nastavení GitHub repozitáře a GitHub Pages"
Write-Info "Repo bude veřejné (public) a vhodné pro sdílení odkazů do Microsoft Teams."
Write-Host ""

# Ensure we run from repo root (script can be called from anywhere)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir "..")
Set-Location $repoRoot

Write-Info ("Aktuální složka: " + (Get-Location).Path)

# Check git
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Write-Err "Git není dostupný v PATH. Nainstaluj Git a zkus to znovu."
  exit 1
}

# Check gh (GitHub CLI)
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  Write-Warn "GitHub CLI (gh) není nainstalované. Doporučuji instalaci, jinak nepůjde automaticky vytvořit repo."
  Write-Host ""
  Write-Host "Instalace přes winget (PowerShell jako uživatel):" -ForegroundColor Yellow
  Write-Host "  winget install -e --id GitHub.cli" -ForegroundColor Yellow
  Write-Host ""
  Write-Host "Po instalaci znovu spusť:" -ForegroundColor Yellow
  Write-Host "  .\scripts\setup-github-pages.ps1" -ForegroundColor Yellow
  exit 1
}

# Check we are inside a git repo
try {
  git rev-parse --is-inside-work-tree | Out-Null
} catch {
  Write-Err "Tahle složka není Git repozitář. Spusť skript v rootu projektu, kde je .git."
  exit 1
}

# Ensure clean working tree (optional but recommended)
$status = git status --porcelain
if ($status) {
  Write-Warn "Máš necommitnuté změny. Doporučuji je nejdřív commitnout (nebo je skript může omylem zahrnout)."
  Write-Host $status
  Write-Host ""
  $cont = Read-Host "Chceš pokračovat i tak? (y/N)"
  if ($cont.ToLower() -ne "y") { exit 1 }
}

# Repo name (fixed per request)
$repoName = "CEDA_Product_Pages"

# Login (interactive)
Write-Info "Kontroluji přihlášení do GitHubu..."
$authOk = $true
try {
  gh auth status | Out-Null
} catch {
  $authOk = $false
}

if (-not $authOk) {
  Write-Info "Nejsi přihlášen. Spustím 'gh auth login' (otevře prohlížeč / device-code)."
  Write-Host ""
  gh auth login -p https -w
}

# Determine owner (user login)
$owner = (gh api user --jq ".login").Trim()
if (-not $owner) {
  Write-Err "Nepodařilo se zjistit uživatelské jméno z GitHub API."
  exit 1
}
Write-Info "Přihlášen jako: $owner"

# Ensure branch main
Write-Info "Nastavuji větev 'main'..."
git branch -M main | Out-Null

# Create repo (if not exists)
$fullRepo = "$owner/$repoName"
Write-Info "Kontroluji existenci repozitáře $fullRepo ..."
$repoExists = $true
try {
  gh repo view $fullRepo | Out-Null
} catch {
  $repoExists = $false
}

if (-not $repoExists) {
  Write-Info "Repo neexistuje → vytvářím veřejné repo a pushuju obsah..."
  # Create repo and push current directory as origin
  gh repo create $repoName --public --source . --remote origin --push
} else {
  Write-Warn "Repo už existuje. Nastavím remote/push, pokud je potřeba."
  $remotes = git remote
  if ($remotes -notcontains "origin") {
    git remote add origin ("https://github.com/$fullRepo.git") | Out-Null
  }
  git push -u origin main
}

# Enable GitHub Pages (from branch main, root)
Write-Info "Zapínám GitHub Pages (branch: main, path: /) ..."
try {
  gh api -X POST "repos/$fullRepo/pages" -f "source[branch]=main" -f "source[path]=/" | Out-Null
} catch {
  # If already exists, update it
  try {
    gh api -X PUT "repos/$fullRepo/pages" -f "source[branch]=main" -f "source[path]=/" | Out-Null
  } catch {
    Write-Warn "Nepodařilo se nastavit Pages přes API. Dá se to ručně: GitHub → Settings → Pages → Deploy from branch: main / (root)."
  }
}

$pagesUrl = "https://$owner.github.io/$repoName/"
Write-Host ""
Write-Info "Hotovo."
Write-Host ""
Write-Host "Odkazy pro Teams (doporučeno používat tyto krátké URL):" -ForegroundColor Green
Write-Host ("  " + $pagesUrl) -ForegroundColor Green
Write-Host ("  " + $pagesUrl + "product.html") -ForegroundColor Green
Write-Host ("  " + $pagesUrl + "pricing.html") -ForegroundColor Green
Write-Host ""
Write-Host "Pozn.: Aktivace Pages může trvat ~1–3 minuty. Pokud vrací 404, chvíli počkej a zkus znovu." -ForegroundColor Yellow


